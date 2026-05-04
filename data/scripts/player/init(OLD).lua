package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")

if onServer() then
	local player = Player()
	if (not player:hasScript("player/leadSight.lua")) then
		player():addScript("player/leadSight.lua")
	end
end