--!nonstrict
-- VPN tunnel status widget: one glyph per tun interface. A tunnel counts as
-- up when its name appears in `ip route` output (same check as i3/iftun.sh).
-- Order and glyphs mirror the old polybar module (tun2 tun0 tun3 tun1).

local interval = noctalia.getConfig("interval") or 5

local glyphs = {
	tun0 = noctalia.getConfig("glyph_tun0") or "plug-connected",
	tun1 = noctalia.getConfig("glyph_tun1") or "world",
	tun2 = noctalia.getConfig("glyph_tun2") or "network",
	tun3 = noctalia.getConfig("glyph_tun3") or "server",
}

local colorActive = noctalia.getConfig("color_active") or "#FFFFFF"
local colorInactive = noctalia.getConfig("color_inactive") or "#707880"

local order = { "tun2", "tun0", "tun3", "tun1" }

local busy = false

local function render(statuses)
	local container = barWidget.isVertical() and ui.column or ui.row
	local children = {}
	local up = {}
	for _, iface in ipairs(order) do
		local active = statuses[iface]
		table.insert(children, ui.glyph({
			key = iface,
			name = glyphs[iface],
			size = 14,
			color = active and colorActive or colorInactive,
		}))
		if active then
			table.insert(up, iface)
		end
	end
	barWidget.render(container({ gap = 6, align = "center" }, children))
	if #up == 0 then
		barWidget.setTooltip("VPN: all tunnels down")
	else
		barWidget.setTooltip("VPN up: " .. table.concat(up, " "))
	end
end

local function poke(result)
	busy = false
	local statuses = {}
	if result and result.exitCode == 0 then
		for _, iface in ipairs(order) do
			statuses[iface] = string.find(result.stdout, iface, 1, true) ~= nil
		end
	end
	render(statuses)
end

function update()
	noctalia.setUpdateInterval(interval * 1000)
	if busy then
		return
	end
	busy = true
	noctalia.runAsync("ip route", poke)
end