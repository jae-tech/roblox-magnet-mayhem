import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
assert.equal(process.argv.length, 3, 'Usage: node scripts/test-hud.mjs <luau executable>');
const source = fs.readFileSync(path.join(root, 'src/client/Controllers/HudController.luau'), 'utf8');
const start = source.indexOf('\tlocal function update()');
const end = source.indexOf('\t-- Subscribe', start);
assert(start >= 0 && end > start, 'HUD update presentation slice boundaries missing');
const update = source.slice(start, end);
const tools = path.join(root, '.tools');
fs.mkdirSync(tools, { recursive: true });
const directory = fs.mkdtempSync(path.join(tools, 'hud-regression-'));
try {
  const script = path.join(directory, 'run.luau');
  fs.writeFileSync(script, `--!strict
-- Mocked real HUD presentation slice; NOT Roblox adapter or Studio proof.
local Definitions = require("../../src/shared/CollectibleDefinitions")
local Magnets = require("../../src/shared/MagnetDefinitions")
local Inventory = require("../../src/shared/InventoryRules")
local attributes: { [string]: any } = { DataReady = true, StorageMode = "Preview", DataStatus = "Preview" }
local player = {}
function player:GetAttribute(name: string): any
	return attributes[name]
end
local label: any = {}
local note: any = {}
local shopNote: any = {}
local button: any = {}
local sellButton: any = {}
local shopButton: any = {}
local shopPanel = { Visible = false }
local currentMagnet: any = {}
local buyButtons: { [number]: any } = { {}, {}, {} }
local buyCoolingDown = false
local panel = { Visible = false }
local alive = true
local feedbackText: string? = nil
local saleCoolingDown = false
local rows: { [string]: any } = {}
for id in Definitions do
	if Definitions[id].kind == "Metal" then
		rows[id] = {}
	end
end
local Color3 = {}
function Color3.fromRGB(red: number, green: number, blue: number): string
	return tostring(red) .. "," .. tostring(green) .. "," .. tostring(blue)
end
${update}
local function expect(coins: number, total: number, payout: number)
	update()
	assert(label.Text == "Coins: " .. tostring(coins) .. "\\n" .. (feedbackText or "Pick up coins or sell metal") .. "\\nPreview: progress is not saved", label.Text)
	assert(button.Text == "Inventory: " .. tostring(total) .. (if panel.Visible then "  [Close]" else "  [Open]"), button.Text)
	assert(sellButton.Text == (if saleCoolingDown then "Selling..." elseif total > 0 then "Sell all (+" .. tostring(payout) .. " coins)" else "Sell all (empty)"), sellButton.Text)
	assert(sellButton.Active == (total > 0 and not saleCoolingDown))
	assert(sellButton.Selectable == (total > 0 and not saleCoolingDown))
	assert(sellButton.AutoButtonColor == (total > 0 and not saleCoolingDown))
	assert(sellButton.BackgroundColor3 == (if total > 0 and not saleCoolingDown then "45,115,65" else "55,65,70"))
	for id, row in rows do
		local definition = Definitions[id]
		local value = attributes[Inventory.attributePrefix .. id]
		local count = if typeof(value) == "number" then value else 0
		assert(rows[id].Text == definition.name .. "  x" .. tostring(count))
	end
end
expect(0, 0, 0)
print("PASS HUD missing attributes safely display zero and disable sale")
attributes[Inventory.attributePrefix .. "bolt"] = 1
expect(0, 1, 1)
print("PASS HUD partial replication uses zero for absent metal attributes")
attributes.Coins = "invalid"
attributes[Inventory.attributePrefix .. "gear"] = "invalid"
expect(0, 1, 1)
print("PASS HUD non-number attributes safely fall back to zero")
attributes.Coins = 0
for id in rows do
	attributes[Inventory.attributePrefix .. id] = 1
end
attributes[Inventory.attributePrefix .. "coin"] = 100
assert(rows.coin == nil)
expect(0, 3, 9)
panel.Visible = true
expect(0, 3, 9)
print("PASS HUD metal counts estimate nine coins, ignore coin attribute, and toggle open/close text")
attributes.Coins = 9
for id in rows do
	attributes[Inventory.attributePrefix .. id] = 0
end
expect(9, 0, 0)
print("PASS HUD sold inventory resets counts and displays credited coins")
attributes[Inventory.attributePrefix .. "bolt"] = 1
saleCoolingDown = true
feedbackText = "Sold metal: +9 coins"
expect(9, 1, 1)
print("PASS HUD feedback survives attribute updates and selling state disables available inventory")
saleCoolingDown = false
feedbackText = nil
expect(9, 1, 1)
print("PASS HUD cooldown release restores authoritative count/value and default hint")
attributes.Coins = 24
attributes.MagnetTier = 1
update()
assert(currentMagnet.Text == "Equipped: Starter | Range: 12 studs")
assert(buyButtons[1].Text == "Equipped" and not buyButtons[1].Active)
assert(buyButtons[2].Text == "Need 1 more coins" and not buyButtons[2].Active)
assert(buyButtons[3].Text == "Locked" and not buyButtons[3].Active)
assert(shopButton.Text == "Shop [Open]")
print("PASS shop displays equipped tier, exact shortfall and locked future tier")
attributes.Coins = 25
update()
assert(buyButtons[2].Text == "Buy Iron (25 coins)" and buyButtons[2].Active)
assert(buyButtons[2].Selectable and buyButtons[2].AutoButtonColor)
buyCoolingDown = true
shopPanel.Visible = true
update()
assert(buyButtons[2].Text == "Buying..." and not buyButtons[2].Active)
assert(not buyButtons[2].Selectable and not buyButtons[2].AutoButtonColor)
assert(shopButton.Text == "Shop [Close]")
print("PASS exact affordability enables next tier, cooldown disables buy, panel toggles text")
buyCoolingDown = false
attributes.Coins = 100
attributes.MagnetTier = 2
update()
assert(currentMagnet.Text == "Equipped: Iron | Range: 18 studs")
assert(buyButtons[1].Text == "Owned" and not buyButtons[1].Active)
assert(buyButtons[2].Text == "Equipped" and not buyButtons[2].Active)
assert(buyButtons[3].Text == "Buy Gold (100 coins)" and buyButtons[3].Active)
attributes.MagnetTier = 3
update()
assert(currentMagnet.Text == "Equipped: Gold | Range: 24 studs")
for _, buyButton in buyButtons do assert(not buyButton.Active) end
print("PASS replicated upgrades expose next tier and max-tier has no further purchases")
for _, invalid in { -1, 1.5, 0/0, math.huge, 4, "2", {} } do
  attributes.MagnetTier = invalid
  update()
  assert(currentMagnet.Text == "Equipped: Starter | Range: 12 studs")
end
attributes.MagnetTier = 1
for _, invalid in { -1, 1.5, 0/0, math.huge, 9007199254740992, "25", {} } do
  attributes.Coins = invalid
  update()
  assert(buyButtons[2].Text == "Need 25 more coins" and not buyButtons[2].Active)
end
print("PASS malformed replicated tier/balance use safe presentation fallback")
attributes.Coins = 100
attributes.MagnetTier = 1
attributes.Inventory_bolt = 1
attributes.DataReady = false
attributes.StorageMode = "Persistent"
attributes.DataStatus = "Loading"
update()
assert(string.find(label.Text, "Coins: --", 1, true))
assert(note.Text == "Loading saved progress..." and shopNote.Text == note.Text)
assert(sellButton.Text == "Data unavailable" and not sellButton.Active)
assert(currentMagnet.Text == "Waiting for saved magnet...")
for _, buyButton in buyButtons do assert(not buyButton.Active and buyButton.Text == "Data unavailable") end
print("PASS loading disables sale/purchases and hides unconfirmed coin/magnet presentation")
for status, text in { Error = "Data unavailable - rejoin to retry", Closing = "Saving before leaving..." } do
  attributes.DataStatus = status
  update()
  assert(note.Text == text and not sellButton.Active and not buyButtons[2].Active)
end
print("PASS load error and closing show explicit nonready status without re-enabling transactions")
attributes.DataReady = true
for status, text in { Ready = "Progress loaded", Dirty = "Waiting for auto-save", Saving = "Saving progress...", Saved = "Progress saved", SaveDelayed = "Save delayed - retrying" } do
  attributes.DataStatus = status
  update()
  assert(note.Text == text and shopNote.Text == text)
  assert(string.find(label.Text, text, 1, true))
  assert(sellButton.Active and buyButtons[2].Active)
end
print("PASS persistent status transitions show loaded/dirty/saving/saved/delayed without false Preview claims")
attributes.StorageMode = "Preview"
attributes.DataStatus = "Preview"
update()
assert(note.Text == "Preview: progress is not saved")
print("PASS Studio Preview explicitly warns progress is not saved")
print("15 mocked HUD presentation checks passed; Roblox adapters/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked HUD presentation regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
