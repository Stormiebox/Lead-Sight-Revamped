package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")

if onServer() then
	local player = Player()
	if player and player.hasScript and player.addScript and (not player:hasScript("player/leadSight.lua")) then
		player:addScriptOnce("player/leadSight.lua")
	end
end
