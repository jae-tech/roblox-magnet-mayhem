import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const compileOnly = process.argv[3] === '--compile-only';
assert(process.argv.length === 3 || (process.argv.length === 4 && compileOnly), 'Usage: node scripts/test-panel-scroll.mjs <luau executable> [--compile-only]');
const source = fs.readFileSync(path.join(root, 'src/client/Controllers/HudController.luau'), 'utf8');
const begin = source.indexOf('\t-- Fill the remaining safe viewport');
const end = source.indexOf('\tlocal panel = createPanel("Inventory")', begin);
assert(begin >= 0 && end > begin, 'Actual panel factory extraction boundaries missing');
const factory = source.slice(begin, end);
const destroyBegin = source.indexOf('\tgui.Destroying:Connect(function()');
const destroyEnd = source.indexOf('\tbutton.Activated:Connect(function()', destroyBegin);
assert(destroyBegin >= 0 && destroyEnd > destroyBegin, 'Actual panel cleanup extraction boundaries missing');
const cleanup = source.slice(destroyBegin, destroyEnd);
for (const panel of ['Inventory', 'Shop', 'CollectionBook']) {
  assert(source.includes(`createPanel("${panel}")`), `${panel} must use the shared scrolling factory`);
}
const tools = path.join(root, '.tools');
fs.mkdirSync(tools, { recursive: true });
const directory = fs.mkdtempSync(path.join(tools, 'panel-scroll-regression-'));
try {
  const script = path.join(directory, 'run.luau');
  fs.writeFileSync(script, `--!strict
-- Extracted real factory with scalar mocks: NOT engine wheel/touch/Studio proof.
local function signal()
  local callbacks = {}
  local event = {}
  function event:Connect(callback)
    local connection = { active = true }
    function connection:Disconnect() self.active = false end
    table.insert(callbacks, { connection = connection, callback = callback })
    return connection
  end
  function event:Fire()
    for _, item in callbacks do if item.connection.active then item.callback() end end
  end
  function event:count()
    local count = 0
    for _, item in callbacks do if item.connection.active then count += 1 end end
    return count
  end
  return event
end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
local UDim2 = {
  new = function(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end,
  fromOffset = function(x, y) return { X = UDim.new(0, x), Y = UDim.new(0, y) } end,
}
local Color3 = { fromRGB = function(...) return {...} end }
local Enum = setmetatable({}, { __index = function(_, key) return setmetatable({}, { __index = function(_, value) return key .. "." .. value end }) end })
local created = {}
local Instance = {}
function Instance.new(className)
  local props = { ClassName = className, children = {}, signals = {}, Destroying = signal(),
    AbsoluteContentSize = Vector2.new(0, 0), AbsoluteWindowSize = Vector2.new(420, 280), CanvasPosition = Vector2.new(0, 0) }
  local object = {}
  function object:GetPropertyChangedSignal(name)
    if not props.signals[name] then props.signals[name] = signal() end
    return props.signals[name]
  end
  function object:FindFirstChildOfClass(class)
    for _, child in props.children do if child.ClassName == class then return child end end
    return nil
  end
  setmetatable(object, { __index = props, __newindex = function(_, key, value)
    props[key] = value
    if key == "Parent" and value then table.insert(value.children, object) end
    if props.signals[key] then props.signals[key]:Fire() end
  end })
  table.insert(created, object)
  return object
end
local gui = Instance.new("ScreenGui")
local alive = true
local connections = {}
${factory}
${cleanup}
local function check(name) print("PASS " .. name) end
local panels = {}
for _, name in { "Inventory", "Shop", "CollectionBook" } do
  local panel = createPanel(name)
  panels[name] = panel
  assert(panel.AutomaticCanvasSize == Enum.AutomaticSize.None)
  assert(panel.ScrollingDirection == Enum.ScrollingDirection.Y)
  assert(panel.CanvasSize.X.Offset == 0)
end
local shop = panels.Shop
local layout = shop:FindFirstChildOfClass("UIListLayout")
shop.Visible = true
-- Shop: title28,current36,three(description38+button40),note40,8gaps*8 = 402.
local shopContentHeight = 28 + 36 + 3 * (38 + 40) + 40 + 8 * 8
layout.AbsoluteContentSize = Vector2.new(0, shopContentHeight)
assert(shop.CanvasSize.Y.Offset == shopContentHeight + 24)
assert(shop.CanvasSize.Y.Offset - shop.AbsoluteWindowSize.Y > 100)
-- A full canvas must permit the final purchase/note, not one mouse-wheel notch.
local bottom = shop.CanvasSize.Y.Offset - shop.AbsoluteWindowSize.Y
shop.Visible = false
shop.CanvasPosition = Vector2.new(20, bottom)
shop.Visible = true
assert(shop.CanvasPosition.X == 0 and shop.CanvasPosition.Y == bottom)
check("shop canvas includes every row and vertical padding, preserving reachable full bottom")
shop.CanvasPosition = Vector2.new(0, 9999)
shop.AbsoluteWindowSize = Vector2.new(420, 380)
assert(shop.CanvasPosition.Y == shop.CanvasSize.Y.Offset - 380)
layout.AbsoluteContentSize = Vector2.new(0, 60)
assert(shop.CanvasSize.Y.Offset == 84 and shop.CanvasPosition.Y == 0)
check("viewport resize and content shrink clamp stale scroll position without short canvas")
shop.Visible = false
shop.CanvasPosition = Vector2.new(10, -20)
shop.Visible = true
assert(shop.CanvasPosition.X == 0 and shop.CanvasPosition.Y == 0)
layout.AbsoluteContentSize = Vector2.new(0, 100.25)
assert(shop.CanvasSize.Y.Offset == 125)
local retainedHeight = shop.CanvasSize.Y.Offset
local retainedPosition = 30
shop.AbsoluteWindowSize = Vector2.new(420, 60)
shop.CanvasPosition = Vector2.new(0, retainedPosition)
shop.Visible = false
layout.AbsoluteContentSize = Vector2.new(0, 0)
assert(shop.CanvasSize.Y.Offset == retainedHeight and shop.CanvasPosition.Y == retainedPosition)
-- Reopening uses restored actual measurement rather than resetting while hidden.
layout.AbsoluteContentSize = Vector2.new(0, 100.25)
shop.Visible = true
assert(shop.CanvasSize.Y.Offset == retainedHeight and shop.CanvasPosition.Y == retainedPosition)
check("visibility restores scroll, ignores hidden measurement collapse, and rounds fractional height upward")
for name, panel in panels do
  local list = panel:FindFirstChildOfClass("UIListLayout")
  panel.Visible = true
  list.AbsoluteContentSize = Vector2.new(0, 600)
  assert(panel.CanvasSize.Y.Offset == 624, name)
end
check("inventory, shop and collection book share the same explicit resize behavior")
local signalCount = 0
for _, object in created do
  for _, event in object.signals do signalCount += event:count() end
end
assert(signalCount >= 9)
gui.Destroying:Fire()
assert(not alive)
for _, object in created do for _, event in object.signals do assert(event:count() == 0) end end
local prior = shop.CanvasSize.Y.Offset
layout.AbsoluteContentSize = Vector2.new(0, 1000)
assert(shop.CanvasSize.Y.Offset == prior)
check("HUD destruction disconnects resize listeners; later property changes cannot mutate dead panels")
print("5 mocked panel scrolling checks passed; Roblox wheel/touch/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], compileOnly ? ['--null', script] : [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (compileOnly) process.stdout.write('STATIC ONLY: generated Luau compiled; behavior assertions NOT RUN\n');
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked panel scrolling regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
