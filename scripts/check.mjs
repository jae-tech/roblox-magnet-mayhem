import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);
const args = process.argv.slice(2);
const allowed = new Set(['--luau', '--analyze', '--compile', '--rojo']);
const overrides = {};
for (let i = 0; i < args.length; i += 2) {
  assert(allowed.has(args[i]) && args[i + 1], `Invalid argument: ${args[i]}`);
  overrides[args[i].slice(2)] = args[i + 1];
}

function filesUnder(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? filesUnder(file) : [file];
  });
}

function run(command, commandArgs, optional = false) {
  const result = spawnSync(command, commandArgs, { encoding: 'utf8', timeout: 30000 });
  if (optional && result.error?.code === 'ENOENT') {
    console.log(`NOT RUN: ${command} unavailable`);
    return false;
  }
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, `${command} failed (exit ${result.status})`);
  return true;
}

function tool(name, fallback) {
  if (overrides[name]) return overrides[name];
  const local = path.join(root, '.tools', 'luau', `${fallback}.exe`);
  return fs.existsSync(local) ? local : fallback;
}

const project = JSON.parse(fs.readFileSync('default.project.json', 'utf8'));
assert.equal(project.tree.$className, 'DataModel');
assert.equal(project.tree.ReplicatedStorage.Shared.$path, 'src/shared');
assert.equal(project.tree.ServerScriptService.Server.$path, 'src/server');
assert.equal(project.tree.StarterPlayer.StarterPlayerScripts.Client.$path, 'src/client');
assert.equal(project.tree.Workspace.PrototypeFloor.$properties.Anchored, true);
assert.equal(project.tree.Workspace.PrototypeSpawn.$className, 'SpawnLocation');

const sources = filesUnder('src').filter(file => file.endsWith('.luau'));
const tests = filesUnder('tests').filter(file => file.endsWith('.luau'));
for (const file of [...sources, ...tests]) {
  const source = fs.readFileSync(file, 'utf8');
  assert(source.startsWith('--!strict'), `${file}: missing strict mode`);
  assert(!/[ \t]+$/m.test(source), `${file}: trailing whitespace`);
  if (file.startsWith('src')) {
    assert(!/DataStoreService|MarketplaceService|CollectionBook|ChainCombo|MagnetFusion/.test(source),
      `${file}: deferred system introduced`);
  }
}
for (const file of ['PRD.md', 'AGENTS.md', 'README.md', 'docs/STUDIO_VERIFICATION.md']) {
  assert(fs.existsSync(file), `Missing documentation: ${file}`);
}
console.log(`PASS structure/scope/strict headers: ${sources.length} source modules`);

run(tool('luau', 'luau'), ['tests/run.luau'], true);
run(tool('luau', 'luau'), ['tests/adversarial.luau'], true);
run(tool('analyze', 'luau-analyze'), ['src/shared', 'tests'], true);
run(tool('compile', 'luau-compile'), ['--null', ...sources, ...tests], true);
console.log('NOT RUN: full Roblox-aware typecheck (Roblox type environment not configured)');

fs.mkdirSync('build', { recursive: true });
const rojo = overrides.rojo ?? 'rojo';
if (run(rojo, ['build', 'default.project.json', '-o', 'build/MagnetMayhem.rbxlx'], true)) {
  assert(fs.statSync('build/MagnetMayhem.rbxlx').size > 0);
  run(rojo, ['sourcemap', 'default.project.json', '--output', 'build/sourcemap.json']);
  const map = JSON.parse(fs.readFileSync('build/sourcemap.json', 'utf8'));
  const nodes = [];
  function visit(node) { nodes.push(node); (node.children ?? []).forEach(visit); }
  visit(map);
  assert(nodes.some(node => node.name === 'main' && node.className === 'Script'));
  assert(nodes.some(node => node.name === 'main' && node.className === 'LocalScript'));
  console.log('PASS Rojo build and Script/LocalScript sourcemap mapping');
}
run('git', ['diff', '--check']);
console.log('CHECKS FINISHED: available checks passed; NOT RUN items are not successes.');
