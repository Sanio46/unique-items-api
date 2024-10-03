--VERSION 1.2

---@class ModReference
UniqueItemsAPI = RegisterMod("Unique Items API", 1)
UniqueItemsAPI.SaveManager = include("uniqueitems_src.save_manager")
local saveManager = UniqueItemsAPI.SaveManager
saveManager.Init(UniqueItemsAPI)
UniqueItemsAPI.Game = Game()
UniqueItemsAPI.ItemConfig = Isaac.GetItemConfig()

include("uniqueitems_src.uniqueItemsAPI")
include("uniqueitems_src.uniqueObjectLogic")
local mcm = include("uniqueitems_src.modConfigMenu")
UniqueItemsAPI.Version = "1.2"

function UniqueItemsAPI:OnPostGameStarted()
	local noItems = true
	for _, objectTable in pairs(UniqueItemsAPI.ObjectData) do
		if next(objectTable) then
			noItems = false
			break
		end
	end
	mcm:GenerateModConfigMenu(noItems)
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, UniqueItemsAPI.OnPostGameStarted)

---@param playerData {Name: string, IsTainted: boolean}
local function getPlayerSaveIndex(playerData)
	local name = playerData.Name
	local taintedSuffix = playerData.IsTainted and ".B" or ""
	name = name .. taintedSuffix
	return name
end

---@param objectTypeName string
---@param objectName string
local function getObjectSaveIndex(objectTypeName, objectName)
	return table.concat({ objectTypeName, objectName }, "_")
end

function UniqueItemsAPI:OnPreDataSave(saveData)
	local arbitrarySave = saveData.file.other
	arbitrarySave.DisableAll = UniqueItemsAPI.DisableAll
	arbitrarySave.RandomizeAll = UniqueItemsAPI.RandomizeAll
	arbitrarySave.AllObjectData = {}

	for tableName, tableData in pairs(UniqueItemsAPI.ObjectData) do
		for _, objectData in pairs(tableData) do
			local curMod = objectData.SelectedModIndex
			local state = curMod == -1 and "Randomized" or curMod == 0 and "Disabled" or objectData.AllMods[curMod]
			local objectSave = {
				PlayerData = {},
				State = state
			}
			for playerType, playerData in pairs(objectData.AllPlayers) do
				local playerSaveIndex = getPlayerSaveIndex(UniqueItemsAPI.RegisteredCharacters[playerType])
				curMod = playerData.SelectedModIndex
				state = curMod == -1 and "Randomized" or curMod == 0 and "Disabled" or playerData.ModData[curMod]
					.ModName
				objectSave.PlayerData[playerSaveIndex] = state
			end
			local objectSaveIndex = getObjectSaveIndex(tableName, objectData.Name)
			arbitrarySave.AllObjectData[objectSaveIndex] = objectSave
		end
	end
	return saveData
end

saveManager.AddCallback(saveManager.Utility.CustomCallback.PRE_DATA_SAVE, UniqueItemsAPI.OnPreDataSave)

---@param state string
---@return integer?
local function getObjectState(mods, state)
	if state == "Randomized" then
		return -1
	elseif state == "Disabled" then
		return 0
	else
		for index, modName in ipairs(mods) do
			if modName == state then
				return index
			end
		end
	end
end

local function extractObjectIndexData(objectSaveIndex)
	local sepStart, sepEnd = string.find(objectSaveIndex, "_")
	local objectTypeName = string.sub(objectSaveIndex, 1, sepStart - 1)
	local objectName = string.sub(objectSaveIndex, sepEnd + 1, -1)

	return objectTypeName, objectName
end

local function extractPlayerIndexData(playerSaveIndex)
	local name = playerSaveIndex
	local start2 = string.sub(playerSaveIndex, -2, -1)
	local isTainted = start2 == ".B"
	if isTainted then
		name = string.sub(name, 1, -3)
	end

	return name, isTainted
end

---@param state string
---@return integer?
local function getPlayerModsObjectState(mods, state)
	if state == "Randomized" then
		return -1
	elseif state == "Disabled" then
		return 0
	else
		for index, modData in ipairs(mods) do
			if modData.ModName == state then
				return index
			end
		end
	end
end

function UniqueItemsAPI:OnPreDataLoad(saveData)
	if saveData.APIData then
		return UniqueItemsAPI.SaveManager.Utility.PatchSaveFile({}, UniqueItemsAPI.SaveManager.DEFAULT_SAVE) --Completely wipe pre-existing save data
	end
end

saveManager.AddCallback(saveManager.Utility.CustomCallback.PRE_DATA_LOAD, UniqueItemsAPI.OnPreDataLoad)

function UniqueItemsAPI:OnPostDataLoad(saveData)
	local arbitrarySave = saveData.file.other

	Isaac.RunCallback(UniqueItemsAPI.Callbacks.LOAD_UNIQUE_ITEMS)

	UniqueItemsAPI.DisableAll = arbitrarySave.DisableAll
	UniqueItemsAPI.RandomizeAll = arbitrarySave.RandomizeAll
	
	for objectSaveIndex, objectSave in pairs(arbitrarySave.AllObjectData) do
		local objectTypeName, objectName = extractObjectIndexData(objectSaveIndex)
		if not UniqueItemsAPI.ObjectData[objectTypeName] then goto continue end
		local objectLookup = UniqueItemsAPI.ObjectLookupTable[objectTypeName][objectName]
		if not objectLookup or not objectLookup.ObjectData then goto continue end
		local objectData = objectLookup.ObjectData
		if objectData.Name == objectName then
			local objectState = getObjectState(objectData.AllMods, objectSave.State)
			if not objectState then
				objectState = 1
			end
			objectData.SelectedModIndex = objectState
			for playerSaveIndex, playerSaveState in pairs(objectSave.PlayerData) do
				local name, isTainted = extractPlayerIndexData(playerSaveIndex)
				local playerData = objectLookup.CharacterLookupTable[isTainted and "Tainted" or "Normal"][name]
				if not playerData then goto continue end
				local playerState = getPlayerModsObjectState(playerData.ModData, playerSaveState)
				if not playerState then
					playerState = 1
				end
				playerData.SelectedModIndex = playerState
			end
		end

		::continue::
	end
end

saveManager.AddCallback(saveManager.Utility.CustomCallback.POST_DATA_LOAD, UniqueItemsAPI.OnPostDataLoad)
