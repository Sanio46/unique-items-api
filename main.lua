--VERSION 1.2

---@class ModReference
UniqueItemsAPI = RegisterMod("Unique Items API", 1)
UniqueItemsAPI.Game = Game()

include("uniqueitems_src.uniqueItemsAPI")
include("uniqueitems_src.uniqueObjectLogic")
--local mcm = include("uniqueitems_src.modConfigMenu")
--local saveData = include("uniqueitems_src.saveData")
local CurVersion = "1.2"
--saveData:initAPI(api)


UniqueItemsAPI.RandomRNG = RNG()
UniqueItemsAPI.RunSeededRNG = RNG()
UniqueItemsAPI.RandomRNG:SetSeed(Random() + 1, 35)
function UniqueItemsAPI:RandomNum(lower, upper)
	if upper then
		return UniqueItemsAPI.RandomRNG:RandomInt((upper - lower) + 1) + lower
	elseif lower then
		return UniqueItemsAPI.RandomRNG:RandomInt(lower) + 1
	else
		return UniqueItemsAPI.RandomRNG:RandomFloat()
	end
end

function UniqueItemsAPI:OnPostGameStarted()
	local noItems = true
	for _, objectTable in pairs(UniqueItemsAPI.ObjectData) do
		if next(objectTable) then
			noItems = false
			break
		end
	end
	--mcm:GenerateModConfigMenu(api, CurVersion, noItems)
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, UniqueItemsAPI.OnPostGameStarted)
