local nameMap = require("uniqueitems_src.nameMap")

--#region Class definitions

---@class UniqueObjectData
---@field SelectedModIndex integer
---@field SelectedPlayerIndex integer
---@field AllMods string[]
---@field AllPlayers UniqueObjectPlayerData[]
---@field Name string
---@field DisplayName string

---@class UniqueObjectPlayerData
---@field SelectedModIndex integer
---@field TempDisable boolean
---@field ModData UniqueObjectModData[]

---@class UniqueObjectModData
---@field ModName string
---@field SpritePath string[]
---@field CostumeSpritePath string
---@field NullCostume integer

---@class UniqueObjectParams
---@field ModName string
---@field PlayerType PlayerType
---@field ObjectID integer
---@field Anm2 string
---@field SpritePath string[]
---@field DisableByDefault boolean
---@field CostumeSpritePath string | nil
---@field NullCostume NullItemID | nil
---@field SwordProjectile {Beam: string, Splash: string} | nil

---@class OldObjectParams: UniqueObjectParams
---@field ItemSprite string | string[]
---@field ItemID CollectibleType
---@field FamiliarVariant FamiliarVariant
---@field FamiliarSprite string | string[]
---@field KnifeVariant integer
---@field KnifeSprite string | string[]
---@field DisabledOnFirstLoad boolean

--#endregion
--#region Variables

local lastRegisteredMod = ""

UniqueItemsAPI.RandomizeAll = false
UniqueItemsAPI.DisableAll = false
UniqueItemsAPI.RegisteredMods = {}
---@type {Name: string, IsTainted: boolean}[]
UniqueItemsAPI.RegisteredCharacters = {}

---@type {Collectibles: UniqueObjectData[], Familiars: UniqueObjectData[], Knives: UniqueObjectData[]}
UniqueItemsAPI.ObjectLookupTable = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

---@type {Normal: UniqueObjectPlayerData[], Tainted: UniqueObjectPlayerData[]}
UniqueItemsAPI.CharacterLookupTable = {
	Normal = {},
	Tainted = {}
}

---@type {Collectibles: UniqueObjectData[], Familiars: UniqueObjectData[], Knives: UniqueObjectData[]}
UniqueItemsAPI.ObjectData = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}
UniqueItemsAPI.ObjectModifiers = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}
---@enum UniqueObjectType
UniqueItemsAPI.ObjectType = {
	ITEM = 1,
	FAMILIAR = 2,
	KNIFE = 3
}
local objectTypeToTableName = {
	[UniqueItemsAPI.ObjectType.ITEM] = "Collectibles",
	[UniqueItemsAPI.ObjectType.FAMILIAR] = "Familiars",
	[UniqueItemsAPI.ObjectType.KNIFE] = "Knives",
}

for playerType = 0, PlayerType.NUM_PLAYER_TYPES - 1 do
	local isTainted = playerType >= PlayerType.PLAYER_ISAAC_B
	UniqueItemsAPI.RegisteredCharacters[playerType] = {
		Name = isTainted and "Tainted " .. nameMap.TaintedCharacters[playerType] or nameMap.NormalCharacters[playerType],
		IsTainted = isTainted
	}
end

--#endregion
--#region Helper functions

---@param funcName string
---@param invalidVar any
---@param varName string
---@param expectedType string
---@param extraLayer? boolean
local function callArgumentError(funcName, invalidVar, varName, expectedType, extraLayer)
	local err = "Something went wrong in " .. funcName .. "!"

	if expectedType ~= nil then
		err = "Bad Argument '" ..
			varName ..
			"' in " ..
			funcName ..
			" (Attempt to index a " ..
			type(invalidVar) .. " value, field '" .. tostring(invalidVar) .. "', expected " .. expectedType .. ")."
	end
	err = "[UniqueItemsAPI] " .. err
	error(err, extraLayer and 4 or 3)
	Isaac.DebugString(err)
end

---@param funcName string
---@param invalidVar any
---@param num integer
---@param expectedType string
---@param extraLayer? boolean
local function callArgumentNumberError(funcName, invalidVar, num, expectedType, extraLayer)
	local err = "Something went wrong in " .. funcName .. "!"

	if expectedType ~= nil then
		err = "Bad Argument #" ..
			num ..
			" in " ..
			funcName ..
			" (Attempt to index a " ..
			type(invalidVar) .. " value, field '" .. tostring(invalidVar) .. "', expected " .. expectedType .. ")."
	end
	err = "[UniqueItemsAPI] " .. err
	error(err, extraLayer and 4 or 3)
	Isaac.DebugString(err)
end

---@param err string
---@param extraLayer? boolean
local function callError(err, extraLayer)
	err = "[UniqueItemsAPI] " .. err
	error(err, extraLayer and 4 or 3)
	Isaac.DebugString(err)
end

function UniqueItemsAPI.GetFirstAlivePlayer()
	for index = 0, UniqueItemsAPI.Game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(index)
		if not player:IsCoopGhost() then return player end
	end
end

---@param ent Entity
function UniqueItemsAPI.TryGetPlayer(ent)
	if ent:ToPlayer() then return ent:ToPlayer() end
	local spawnEnt = ent.SpawnerEntity
	if ent.Type == EntityType.ENTITY_PICKUP then
		for index = 0, UniqueItemsAPI.Game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(index)
			if not player:IsDead()
				and not player:IsCoopGhost()
			then
				return player
			end
		end
	end
	if not spawnEnt then return end

	if spawnEnt:ToPlayer() then
		return spawnEnt:ToPlayer()
	elseif spawnEnt:ToFamiliar() and spawnEnt:ToFamiliar().Player then
		return spawnEnt:ToFamiliar().Player
	else
		UniqueItemsAPI.TryGetPlayer(ent.SpawnerEntity)
	end
end

---@return "Collectibles" | "Familiars" | "Knives"
local function getUniqueObjectName(objectType)
	return objectTypeToTableName[objectType]
end

--#endregion
--#region API

---@param name string
function UniqueItemsAPI.IsModRegistered(name)
	if #UniqueItemsAPI.RegisteredMods == 0 then
		return false
	end
	for _, modName in pairs(UniqueItemsAPI.RegisteredMods) do
		if name == modName then
			return true
		end
	end
	return false
end

---@param name string
---@param isTainted boolean
function UniqueItemsAPI.IsCharacterRegistered(name, isTainted)
	local funcName = "IsCharacterRegistered"
	if name == nil or type(name) ~= "string" then
		callArgumentNumberError(funcName, name, 1, "string")
		return
	end
	if isTainted == nil then
		isTainted = false
	elseif type(isTainted) ~= "boolean" then
		callArgumentNumberError(funcName, isTainted, 2, "boolean")
		return
	end
	local playerType = Isaac.GetPlayerTypeByName(name, isTainted)
	return UniqueItemsAPI.RegisteredCharacters[playerType] ~= nil
end

---@param objectID integer
---@param objectType UniqueObjectType
function UniqueItemsAPI.IsObjectIDRegistered(objectID, objectType)
	local uniqueTable = getUniqueObjectName(objectType)
	return UniqueItemsAPI.ObjectData[uniqueTable][objectID] ~= nil
end

---@param modName string
function UniqueItemsAPI.RegisterMod(modName)
	local funcName = "RegisterMod"
	if UniqueItemsAPI.IsModRegistered(modName) then return end
	if modName == nil or type(modName) ~= "string" then
		callArgumentNumberError(funcName, modName, 1, "string")
		return
	end
	table.insert(UniqueItemsAPI.RegisteredMods, modName)
	lastRegisteredMod = modName
end

---@param name string
---@param isTainted boolean
---@param displayName? string
function UniqueItemsAPI.RegisterCharacter(name, isTainted, displayName)
	local funcName = "RegisterCharacter"
	if name == nil or type(name) ~= "string" then
		callArgumentNumberError(funcName, name, 1, "string")
		return
	end
	if isTainted == nil then
		isTainted = false
	elseif type(isTainted) ~= "boolean" then
		callArgumentNumberError(funcName, isTainted, 2, "boolean")
		return
	end
	local playerType = Isaac.GetPlayerTypeByName(name, isTainted)
	if playerType == -1 then return end
	if isTainted and not displayName then
		displayName = "Tainted " .. name
	end
	displayName = displayName or name
	UniqueItemsAPI.RegisteredCharacters[playerType] = {
		Name = displayName or name,
		IsTainted = isTainted
	}
end

---@param objectID CollectibleType
---@param itemName string
---@param objectType UniqueObjectType
function UniqueItemsAPI.AssignObjectName(objectID, itemName, objectType)
	local funcName = "RegisterObject"
	if objectID == nil or type(objectID) ~= "number" then
		callArgumentNumberError(funcName, objectID, 1, "number")
		return
	end
	if itemName == nil and type(itemName) ~= "string" then
		callArgumentNumberError(funcName, itemName, 2, "string")
		return
	end
	local uniqueItemTable = objectTypeToTableName[objectType]

	if not UniqueItemsAPI.ObjectData[uniqueItemTable][objectID] then
		callError("Error in" .. funcName .. ". Object is not registered. Please use UniqueItemsAPI.AssignUniqueObject.")
		return
	end
	UniqueItemsAPI.ObjectData[uniqueItemTable][objectID].DisplayName = itemName
end

---@param funcName string
---@param params UniqueObjectParams
---@param dataType UniqueObjectType
local function shouldDataBeAdded(funcName, params, dataType)
	local shouldAdd = true

	if params.PlayerType == nil
		or type(params.PlayerType) ~= "number"
	then
		callArgumentError(funcName, params.PlayerType, "PlayerType", "number", true)
		return
	elseif params.PlayerType == -1 then
		return
	end
	if lastRegisteredMod == "" then
		local err = "Error in " .. funcName .. ", no mods registered to add to!"
		callError(err, true)
	end

	if params.ObjectID == nil
		or type(params.ObjectID) ~= "number"
	then
		callArgumentError(funcName, params.ObjectID, "ID", "number", true)
	end
	if (params.SpritePath == nil and params.Anm2 == nil)
		or (params.SpritePath ~= nil and type(params.SpritePath) ~= "table"
			or params.Anm2 ~= nil and type(params.Anm2) ~= "string")
	then
		callArgumentError(funcName, params.SpritePath, "SpritePath", "table", true)
	end

	if dataType == UniqueItemsAPI.ObjectType.ITEM then
		if params.CostumeSpritePath ~= nil then
			if type(params.CostumeSpritePath) ~= "string" then
				callArgumentError(funcName, params.CostumeSpritePath, "CostumeSpritePath", "string", true)
			end
		end
		if params.NullCostume ~= nil then
			if type(params.NullCostume) ~= "number" then
				callArgumentError(funcName, params.NullCostume, "NullCostume", "NullItemID", true)
			elseif params.NullCostume == -1 then
				local err = "Bad Enumeration 'NullCostume' in " ..
					funcName .. " (Costume returns -1, and does not exist)"
				callError(err, true)
			end
		end
	elseif dataType == UniqueItemsAPI.ObjectType.KNIFE then
		if params.SwordProjectile ~= nil then
			if type(params.SwordProjectile) ~= "table" then
				callArgumentError(funcName, params.SwordProjectile, "KnifeSprite", "table")
			end
		end
	end

	return shouldAdd
end

---@param objectID integer
---@param objectType UniqueObjectType
---@param playerType? PlayerType
---@return UniqueObjectPlayerData?
---@overload fun(objectID: integer, objectType: UniqueObjectType): UniqueObjectData
function UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	local uniqueItemTable = getUniqueObjectName(objectType)
	local objectData = UniqueItemsAPI.ObjectData[uniqueItemTable][objectID]
	if not objectData then return end
	if playerType then
		return objectData.AllPlayers[playerType]
	else
		return objectData
	end
end

---@param params UniqueObjectParams
---@param objectType UniqueObjectType
function UniqueItemsAPI.AssignUniqueObject(params, objectType)
	local funcName = "AssignUniqueObject"
	if not shouldDataBeAdded(funcName, params, objectType) then return end

	local uniqueItemTable = getUniqueObjectName(objectType)
	if not UniqueItemsAPI.ObjectData[uniqueItemTable][params.ObjectID] then
		local objectData = {}
		objectData.SelectedModIndex = 1
		objectData.SelectedPlayerIndex = 1
		objectData.AllMods = {}
		objectData.AllPlayers = {}
		objectData.Name = nameMap[uniqueItemTable][params.ObjectID] or params.ObjectID
		objectData.DisplayName = tonumber(objectData.Name) and
		string.gsub(uniqueItemTable, 1, -2) .. " ID " .. objectData.Name or objectData.Name
		UniqueItemsAPI.ObjectData[uniqueItemTable][params.ObjectID] = objectData
		UniqueItemsAPI.ObjectLookupTable[objectData.Name] = objectData
	end

	---@type UniqueObjectData
	local objectData = UniqueItemsAPI.ObjectData[uniqueItemTable][params.ObjectID]
	local shouldAdd = true
	for _, modName in pairs(objectData.AllMods) do
		if modName == lastRegisteredMod then
			shouldAdd = false
			break
		end
	end
	if shouldAdd then
		table.insert(objectData.AllMods, lastRegisteredMod)
	end

	if not objectData.AllPlayers[params.PlayerType] then
		local playerData = {}
		playerData.SelectedModIndex = params.DisableByDefault and 0 or 1
		playerData.ModData = {}
		objectData.AllPlayers[params.PlayerType] = playerData
		local charType = UniqueItemsAPI.RegisteredCharacters[params.PlayerType].IsTainted and "Tainted" or "Normal"
		local playerName = UniqueItemsAPI.RegisteredCharacters[params.PlayerType].Name
		UniqueItemsAPI.CharacterLookupTable[charType][playerName] = playerData
	end
	local playerData = UniqueItemsAPI.GetObjectData(params.ObjectID, objectType, params.PlayerType)
	---@cast playerData UniqueObjectPlayerData
	local modStats = {
		ModName = lastRegisteredMod,
		SpritePath = params.SpritePath,
		CostumeSpritePath = params.CostumeSpritePath,
		NullCostume = params.NullCostume
	}
	table.insert(playerData.ModData, modStats)
end

local function shouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, table)
	if modifierName == nil or type(modifierName) ~= "string" then
		callArgumentNumberError(funcName, modifierName, 1, "string", true)
		return false
	elseif funcCondition == nil or type(funcCondition) ~= "function" then
		callArgumentNumberError(funcName, funcCondition, 2, "function", true)
		return false
	elseif funcCallback == nil or type(funcCallback) ~= "function" then
		callArgumentNumberError(funcName, funcCallback, 3, "function", true)
		return false
	end
	for i, v in ipairs(table) do
		if v.Name == modifierName then
			v.Condition = funcCondition
			v.Callback = funcCallback
			return false
		end
	end
	return true
end

---@param modifierName string
---@param funcCondition function
---@param funcCallback function
---@param objectType UniqueObjectType
function UniqueItemsAPI.AssignObjectModifier(modifierName, funcCondition, funcCallback, objectType)
	local funcName = "AddUniqueObjectModifier"
	local objectName = getUniqueObjectName(objectType)

	if shouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, UniqueItemsAPI.ObjectModifiers[objectName]) then
		table.insert(UniqueItemsAPI.ObjectModifiers[objectName],
			{ Name = modifierName, Condition = funcCondition, Callback = funcCallback })
	end
end

---@param modifierName string
---@param objectType UniqueObjectType
function UniqueItemsAPI.RemoveObjectModifier(modifierName, objectType)
	local objectName = getUniqueObjectName(objectType)
	local objectTable = UniqueItemsAPI.ObjectModifiers[objectName]

	for i, v in ipairs(objectTable) do
		if v.Name == modifierName then
			table.remove(objectTable, i)
			return
		end
	end
end

---@param params UniqueObjectParams
---@param objectType UniqueObjectType
local function patchObjectDataWithModifiers(params, objectType)
	local objectName = getUniqueObjectName(objectType)
	for _, funcs in ipairs(UniqueItemsAPI.ObjectModifiers[objectName]) do
		if funcs.Condition(params) == true then
			params = funcs.Callback(params) or params
		end
	end
	return params
end

---@param objectID integer
---@param entityOrPlayerType Entity | PlayerType
---@param noModifier? boolean
---@param objectType UniqueObjectType
---@return UniqueObjectParams | nil
function UniqueItemsAPI.GetObjectParams(objectID, entityOrPlayerType, noModifier, objectType)
	local playerType = entityOrPlayerType
	local player
	if type(entityOrPlayerType) ~= "number" then
		---@cast entityOrPlayerType Entity
		player = UniqueItemsAPI.TryGetPlayer(entityOrPlayerType)
		if not player then return end
		playerType = player:GetPlayerType()
	end
	---@cast playerType PlayerType
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData then return end
	local params = {}
	local modData = playerData.ModData[playerData.SelectedModIndex]

	if UniqueItemsAPI.IsObjectRandomized(playerData) and type(entityOrPlayerType) ~= "number" then
		local ent = entityOrPlayerType
		---@cast ent Entity
		modData = playerData.ModData[ent:GetData().UniqueItemsRandomIndex]
	end

	for varName, value in pairs(modData) do
		params[varName] = value
	end

	if player then
		params.Player = player
	end

	params.PlayerType = playerType
	params.ItemID = objectID
	params.ItemType = objectType

	if noModifier then return params end

	params = patchObjectDataWithModifiers(params, objectType)

	return params
end

---@param objectID integer
---@param playerType PlayerType
---@param objectType UniqueObjectType
function UniqueItemsAPI.GetCurrentObjectMod(objectID, playerType, objectType)
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData then return end
	return playerData.ModData[playerData.SelectedModIndex]
end

---@param objectID integer
---@param playerType PlayerType
---@param bool boolean
---@param objectType UniqueObjectType
function UniqueItemsAPI.SetIsCharacterObjectEnabled(objectID, playerType, bool, objectType)
	if not bool or type(bool) ~= "boolean" then return end
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData then return end
	playerData.TempDisable = not bool
end

---@param playerData UniqueObjectPlayerData
function UniqueItemsAPI.IsObjectDisabled(playerData)
	return playerData.SelectedModIndex == 0 or playerData.TempDisable or UniqueItemsAPI.DisableAll
end

---@param playerData UniqueObjectPlayerData
function UniqueItemsAPI.IsObjectRandomized(playerData)
	return playerData.SelectedModIndex == -1 or UniqueItemsAPI.RandomizeAll
end

--#endregion
--#region Deprecated

---@deprecated
---@param id integer
---@param name string
function UniqueItemsAPI.RegisterItem(id, name)
	if not name then return end
	UniqueItemsAPI.AssignObjectName(id, name, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param id integer
---@param name string
function UniqueItemsAPI.RegisterFamiliar(id, name)
	if not name then return end
	UniqueItemsAPI.AssignObjectName(id, name, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param id integer
---@param name string
function UniqueItemsAPI.RegisterKnife(id, name)
	if not name then return end
	UniqueItemsAPI.AssignObjectName(id, name, UniqueItemsAPI.ObjectType.KNIFE)
end

---@deprecated
---@param itemID integer
function UniqueItemsAPI.IsItemRegistered(itemID)
	return UniqueItemsAPI.IsObjectIDRegistered(itemID, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param familiarVariant FamiliarVariant
function UniqueItemsAPI.IsFamiliarRegistered(familiarVariant)
	return  UniqueItemsAPI.IsObjectIDRegistered(familiarVariant, UniqueItemsAPI.ObjectType.FAMILIAR)

end

---@deprecated
---@param knifeVariant KnifeVariant
function UniqueItemsAPI.IsKnifeRegistered(knifeVariant)
	return  UniqueItemsAPI.IsObjectIDRegistered(knifeVariant, UniqueItemsAPI.ObjectType.KNIFE)
end

---@param spritePath string[] | string
---@return string | string[], boolean
local function manageSpritePath(spritePath)
	if type(spritePath) == "table" then
		return spritePath, false
	elseif string.find(spritePath, ".anm2") then
		return spritePath, true
	else
		return { spritePath }, false
	end
end

---@deprecated
---@param params OldObjectParams
function UniqueItemsAPI.AddCharacterItem(params)
	params.ObjectID = params.ItemID
	local spritePath, isAnm2 = manageSpritePath(params.ItemSprite)
	if isAnm2 then
		---@cast spritePath string
		params.Anm2 = spritePath
	else
		---@cast spritePath string[]
		params.SpritePath = spritePath
	end
	params.DisableByDefault = params.DisabledOnFirstLoad
	UniqueItemsAPI.AssignUniqueObject(params, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param params OldObjectParams
function UniqueItemsAPI.AddCharacterFamiliar(params)
	params.ObjectID = params.FamiliarVariant
	local spritePath, isAnm2 = manageSpritePath(params.FamiliarSprite)
	if isAnm2 then
		---@cast spritePath string
		params.Anm2 = spritePath
	else
		---@cast spritePath string[]
		params.SpritePath = spritePath
	end
	UniqueItemsAPI.AssignUniqueObject(params, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param params OldObjectParams
function UniqueItemsAPI.AddCharacterKnife(params)
	params.ObjectID = params.KnifeVariant
	local spritePath, isAnm2 = manageSpritePath(params.KnifeSprite)
	if isAnm2 then
		---@cast spritePath string
		params.Anm2 = spritePath
	else
		---@cast spritePath string[]
		params.SpritePath = spritePath
	end
	UniqueItemsAPI.AssignUniqueObject(params, UniqueItemsAPI.ObjectType.KNIFE)
end

---@deprecated
---@param modifierName string
---@param funcCondition function
---@param funcCallback function
function UniqueItemsAPI.AddItemModifier(modifierName, funcCondition, funcCallback)
	UniqueItemsAPI.AssignObjectModifier(modifierName, funcCondition, funcCallback, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param modifierName string
---@param funcCondition function
---@param funcCallback function
function UniqueItemsAPI.AddFamiliarModifier(modifierName, funcCondition, funcCallback)
	UniqueItemsAPI.AssignObjectModifier(modifierName, funcCondition, funcCallback, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param modifierName string
---@param funcCondition function
---@param funcCallback function
function UniqueItemsAPI.AddKnifeModifier(modifierName, funcCondition, funcCallback)
	UniqueItemsAPI.AssignObjectModifier(modifierName, funcCondition, funcCallback, UniqueItemsAPI.ObjectType.KNIFE)
end

---@deprecated
---@param modifierName string
function UniqueItemsAPI.RemoveItemModifier(modifierName)
	UniqueItemsAPI.RemoveObjectModifier(modifierName, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param modifierName string
function UniqueItemsAPI.RemoveFamiliarModifier(modifierName)
	UniqueItemsAPI.RemoveObjectModifier(modifierName, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param modifierName string
function UniqueItemsAPI.RemoveKnifeModifier(modifierName)
	UniqueItemsAPI.RemoveObjectModifier(modifierName, UniqueItemsAPI.ObjectType.KNIFE)
end

---@deprecated
---@param itemID CollectibleType
---@param player EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueObjectParams | nil
function UniqueItemsAPI.GetItemParams(itemID, player, noModifier)
	local params = UniqueItemsAPI.GetObjectParams(itemID, player, noModifier, UniqueItemsAPI.ObjectType.ITEM)
	---@cast params OldObjectParams
	if params then
		params.ItemID = params.ObjectID
		params.ItemSprite = params.SpritePath or params.Anm2
	end
	return params
end

---@deprecated
---@param familiarVariant FamiliarVariant
---@param familiar EntityFamiliar | EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueObjectParams | nil
function UniqueItemsAPI.GetFamiliarParams(familiarVariant, familiar, noModifier)
	local params = UniqueItemsAPI.GetObjectParams(familiarVariant, familiar, noModifier,
		UniqueItemsAPI.ObjectType.FAMILIAR)
	---@cast params OldObjectParams
	if params then
		params.FamiliarVariant = params.ObjectID
		params.FamiliarSprite = params.SpritePath or params.Anm2
	end
	return params
end

---@deprecated
---@param knifeVariant KnifeVariant
---@param knife EntityKnife | EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueObjectParams | nil
function UniqueItemsAPI.GetKnifeParams(knifeVariant, knife, noModifier)
	local params = UniqueItemsAPI.GetObjectParams(knifeVariant, knife, noModifier, UniqueItemsAPI.ObjectType.KNIFE)
	---@cast params OldObjectParams
	if params then
		params.KnifeVariant = params.ObjectID
		params.KnifeSprite = params.SpritePath or params.Anm2
		params.DisabledOnFirstLoad = params.DisableByDefault
	end
	return params
end

---@deprecated
---@param itemID CollectibleType
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentItemMod(itemID, playerType)
	UniqueItemsAPI.GetCurrentObjectMod(itemID, playerType, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param familiarVariant FamiliarVariant
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentFamiliarMod(familiarVariant, playerType)
	UniqueItemsAPI.GetCurrentObjectMod(familiarVariant, playerType, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param knifeVariant KnifeVariant
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentKnifeMod(knifeVariant, playerType)
	UniqueItemsAPI.GetCurrentObjectMod(knifeVariant, playerType, UniqueItemsAPI.ObjectType.KNIFE)
end

---@deprecated
---@param itemID CollectibleType
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterItem(itemID, playerType, bool)
	UniqueItemsAPI.SetIsCharacterObjectEnabled(itemID, playerType, bool, UniqueItemsAPI.ObjectType.ITEM)
end

---@deprecated
---@param familiarVariant FamiliarVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterFamiliar(familiarVariant, playerType, bool)
	UniqueItemsAPI.SetIsCharacterObjectEnabled(familiarVariant, playerType, bool, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param knifeVariant KnifeVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterKnife(knifeVariant, playerType, bool)
	UniqueItemsAPI.SetIsCharacterObjectEnabled(knifeVariant, playerType, bool, UniqueItemsAPI.ObjectType.FAMILIAR)
end

--#endregion
