--!nonstrict
-- Work VPN client counters + up/down/equal arrows vs the previous sample.
-- Port of ~/i3/polybar-vpn-stats.sh: same tunnel groups, same colors,
-- previous values persisted across restarts (polybar_vpn_cache equivalent).

local interval = noctalia.getConfig("interval") or 10
local url = noctalia.getConfig("url") or "http://10.7.33.33:8001/api/stats"

local glyphs = {
	noctalia.getConfig("glyph_1") or "shield-check",
	noctalia.getConfig("glyph_2") or "shield",
	noctalia.getConfig("glyph_3") or "server",
	noctalia.getConfig("glyph_total") or "activity",
}

local colorValue = noctalia.getConfig("color_value") or "#C5C8C6"
local colorIcon = noctalia.getConfig("color_icon") or "#C5C8C6"
local colorTotal = noctalia.getConfig("color_total") or "#2E8B57"
local colorUp = noctalia.getConfig("color_up") or "#00FF00"
local colorDown = noctalia.getConfig("color_down") or "#FF0000"
local colorEqual = noctalia.getConfig("color_equal") or "#4682B4"

local groups = {
	{ "tun21", "tun22", "tun23", "tun24", "tun25", "tun26", "tun27", "tun27" },
	{ "tun0", "tun1", "tun2", "tun3", "tun6", "tun7", "tun8", "tun9" },
	{ "tun10", "tun11", "tun12", "tun13" },
}

local dataDir = noctalia.pluginDataDir()
local prevFile = dataDir .. "/prev.json"
local prev = {}

local function loadPrev()
	local raw = noctalia.readFile(prevFile)
	if raw then
		local decoded = noctalia.json.decode(raw)
		if type(decoded) == "table" then
			prev = decoded
		end
	end
end

local function savePrev()
	noctalia.writeFile(prevFile, noctalia.json.encode(prev))
end

local function arrowGlyph(cur, old)
	if cur > old then
		return "arrow-up", colorUp
	elseif cur < old then
		return "arrow-down", colorDown
	end
	return "line-dashed", colorEqual
end

local function sumValues(data, keys)
	local total = 0
	for _, key in ipairs(keys) do
		local v = data[key]
		total = total + (type(v) == "number" and v or 0)
	end
	return total
end

local function render(values, valid)
	local container = barWidget.isVertical() and ui.column or ui.row
	local children = {}
	local tip = {}
	for i = 1, 3 do
		local cur = values[i]
		local deltaName, deltaColor = arrowGlyph(cur, prev[i] or cur)
		table.insert(children, ui.glyph({ key = "g" .. i, name = glyphs[i], size = 14, color = colorIcon }))
		table.insert(children, ui.label({ key = "v" .. i, text = tostring(cur), color = colorValue }))
		table.insert(children, ui.glyph({ key = "a" .. i, name = deltaName, size = 12, color = deltaColor }))
		table.insert(tip, "g" .. i .. ": " .. cur .. " " .. (deltaName == "circle-dot" and "=" or ""))
	end
	local total = values[4]
	local totalName, totalColor = arrowGlyph(total, prev[4] or total)
	table.insert(children, ui.glyph({ key = "t", name = glyphs[4], size = 14, color = colorTotal }))
	table.insert(children, ui.label({ key = "tv", text = tostring(total), color = colorValue }))
	table.insert(children, ui.glyph({ key = "ta", name = totalName, size = 12, color = totalColor }))

	barWidget.render(container({ gap = 6, align = "center" }, children))
	table.insert(tip, "total: " .. total)
	if not valid then
		barWidget.setTooltip("VPN stats: no data")
	else
		barWidget.setTooltip("VPN stats — " .. table.concat(tip, "  "))
	end
end

local busy = false

local function poke(res)
	busy = false
	if not (res and res.ok and res.status == 200) then
		render({ 0, 0, 0, 0 }, false)
		return
	end
	local data = noctalia.json.decode(res.body)
	if type(data) ~= "table" then
		render({ 0, 0, 0, 0 }, false)
		return
	end
	local values = {}
	for i = 1, 3 do
		values[i] = sumValues(data, groups[i])
	end
	values[4] = values[1] + values[2] + values[3]

	if prev[4] == nil then
		prev = values
	end
	render(values, true)
	prev = values
	savePrev()
end

function update()
	noctalia.setUpdateInterval(interval * 1000)
	if busy then
		return
	end
	busy = true
	noctalia.http({ url = url }, poke)
end

loadPrev()
