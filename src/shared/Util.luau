-- Util.luau
-- Small formatting / math helpers shared by server (and client).

local Util = {}

-- formatMoney(1234567) -> "$1,234,567"  (floors, handles negatives)
function Util.formatMoney(n)
	n = math.floor(tonumber(n) or 0)
	local negative = n < 0
	n = math.abs(n)
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	out = s .. out
	if negative then
		out = "-" .. out
	end
	return "$" .. out
end

-- formatTime(83) -> "1:23" ; formatTime(45) -> "0:45"
function Util.formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

-- formatRate(123) -> "+$123/s" (for the HUD income line)
function Util.formatRate(n)
	return "+" .. Util.formatMoney(n) .. "/s"
end

function Util.clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end
	return value
end

-- Rounds a number to the given decimal places (default 0).
function Util.round(n, places)
	places = places or 0
	local mult = 10 ^ places
	return math.floor(n * mult + 0.5) / mult
end

return Util

-- Polish pass 18 Nov: reviewed; no change needed.
