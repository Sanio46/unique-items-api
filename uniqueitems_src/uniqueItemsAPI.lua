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
---@field PlayerType PlayerType
---@field ObjectID integer
---@field ModName string
---@field Anm2 string
---@field SpritePath string[]
---@field DisableByDefault boolean
---@field CostumeSpritePath string | nil
---@field NullCostume NullItemID | nil
---@field SwordProjectile {Beam: string, Splash: string} | nil
---@field GlobalMod boolean

---@class UniqueObjectParams: UniqueObjectModData
---@field Player EntityPlayer?
---@field ObjectEntity Entity

---@class OldObjectParams: UniqueObjectParams
---@field ItemSprite string | string[]
---@field ItemID CollectibleType
---@field FamiliarVariant FamiliarVariant
---@field FamiliarSprite string | string[]
---@field KnifeVariant integer
---@field KnifeSprite string | string[]
---@field DisabledOnFirstLoad boolean
---@field KnifeEntity EntityKnife

--#endregion
--#region Variables

local lastRegisteredMod = ""

UniqueItemsAPI.RandomizeAll = false
UniqueItemsAPI.DisableAll = false
UniqueItemsAPI.RegisteredMods = {}
---@type {Name: string, DisplayName: string, IsTainted: boolean}[]
UniqueItemsAPI.RegisteredCharacters = {}

---@class ObjectLookupTable
---@field ObjectData UniqueObjectData
---@field CharacterLookupTable {Normal: UniqueObjectPlayerData[], Tainted: UniqueObjectPlayerData[]}

---@class UniqueObjectModifier
---@field Name string
---@field Condition function
---@field Callback function

---@type {Collectibles: ObjectLookupTable[], Familiars: ObjectLookupTable[], Knives: ObjectLookupTable[]}
UniqueItemsAPI.ObjectLookupTable = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

---@type {Collectibles: UniqueObjectData[], Familiars: UniqueObjectData[], Knives: UniqueObjectData[]}
UniqueItemsAPI.ObjectData = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

---@type {Collectibles: UniqueObjectModifier[], Familiars: UniqueObjectModifier[], Knives: UniqueObjectModifier[]}
UniqueItemsAPI.ObjectModifiers = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

---@enum UniqueObjectType
UniqueItemsAPI.ObjectType = {
	COLLECTIBLE = 1,
	FAMILIAR = 2,
	KNIFE = 3
}

local objectTypeToTableName = {
	[UniqueItemsAPI.ObjectType.COLLECTIBLE] = "Collectibles",
	[UniqueItemsAPI.ObjectType.FAMILIAR] = "Familiars",
	[UniqueItemsAPI.ObjectType.KNIFE] = "Knives",
}

UniqueItemsAPI.Callbacks = {
	LOAD_UNIQUE_ITEMS = "__UNIQUE_ITEMS_API_LOAD_UNIQUE_ITEMS"
}

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

UniqueItemsAPI.RegisteredMods = {}

UniqueItemsAPI.RegisteredCharacters = {}

local normalDisplayNames = {
	[PlayerType.PLAYER_BLUEBABY] = "Blue Baby",
	[PlayerType.PLAYER_LAZARUS2] = "Lazarus (Risen)",
	[PlayerType.PLAYER_BLACKJUDAS] = "Dark Judas",
}

local taintedDisplayNames = {
	[PlayerType.PLAYER_BLUEBABY_B] = "Blue Baby",
	[PlayerType.PLAYER_LAZARUS2_B] = "Lazarus (Dead)",
	[PlayerType.PLAYER_JACOB2_B] = "Jacob (Ghost)",
}

for playerType = 0, PlayerType.NUM_PLAYER_TYPES - 1 do
	local isTainted = playerType >= PlayerType.PLAYER_ISAAC_B
	local name = isTainted and "Tainted " .. nameMap.TaintedCharacters[playerType] or
	nameMap.NormalCharacters[playerType]
	local displayName = isTainted and taintedDisplayNames[playerType] and "Tainted " .. taintedDisplayNames[playerType] or
	normalDisplayNames[playerType] or name
	UniqueItemsAPI.RegisteredCharacters[playerType] = {
		Name = name,
		DisplayName = displayName,
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

---Takes a table to fully copy as its own new table, which is then returned.
---Credit to catinsurance
---@generic dataTable
---@param tab dataTable
---@return dataTable
function UniqueItemsAPI.DeepCopy(tab)
	if type(tab) ~= "table" then
		return tab
	end

	local final = setmetatable({}, getmetatable(tab))
	for i, v in pairs(tab) do
		final[UniqueItemsAPI.DeepCopy(i)] = UniqueItemsAPI.DeepCopy(v)
	end

	return final
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
	lastRegisteredMod = modName
	if UniqueItemsAPI.IsModRegistered(modName) then return end
	if modName == nil or type(modName) ~= "string" then
		callArgumentNumberError(funcName, modName, 1, "string")
		return
	end

	table.insert(UniqueItemsAPI.RegisteredMods, modName)
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
		Name = name,
		IsTainted = isTainted,
		DisplayName = displayName or name
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
---@param params UniqueObjectModData
---@param dataType UniqueObjectType
local function shouldDataBeAdded(funcName, params, dataType)
	if params.GlobalMod then
		--Is good :)
	elseif params.PlayerType == nil
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
	if params.SpritePath ~= nil and type(params.SpritePath) ~= "table" then
		callArgumentError(funcName, params.SpritePath, "SpritePath", "table", true)
	elseif  params.Anm2 ~= nil and type(params.Anm2) ~= "string" then
		callArgumentError(funcName, params.Anm2, "Anm2", "string", true)
	end

	if dataType == nil
		or type(dataType) ~= "number"
	then
		callArgumentError(funcName, dataType, "SpritePath", "table", true)
	end

	if (dataType < 1 or dataType > 3) then
		callError("Bad Argument \"dataType\" in " ..
		funcName .. " (ItemType is out of bounds. Must be between range of 1 to 3).")
	end

	if dataType == UniqueItemsAPI.ObjectType.COLLECTIBLE then
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

	return true
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

---@param params UniqueObjectModData
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
		UniqueItemsAPI.ObjectLookupTable[uniqueItemTable][objectData.Name] = {
			ObjectData = objectData
		}
	end
	
	if not params.PlayerType and params.GlobalMod then
		for playerType, _ in pairs(UniqueItemsAPI.RegisteredCharacters) do
			params.PlayerType = playerType
			UniqueItemsAPI.AssignUniqueObject(params, objectType)
		end
		return
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
		local objectLookup = UniqueItemsAPI.ObjectLookupTable[uniqueItemTable][objectData.Name]
		if not objectLookup.CharacterLookupTable then
			objectLookup.CharacterLookupTable = {
				Normal = {},
				Tainted = {}
			}
		end
		objectLookup.CharacterLookupTable[charType][playerName] = playerData
	end
	local playerData = UniqueItemsAPI.GetObjectData(params.ObjectID, objectType, params.PlayerType)
	---@cast playerData UniqueObjectPlayerData
	
	local modData = {
		ModName = lastRegisteredMod
	}
	for name, value in pairs(params) do
		modData[name] = value
	end

	table.insert(playerData.ModData, modData)
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
	---@param mods UniqueObjectModifier
	for _, mods in ipairs(UniqueItemsAPI.ObjectModifiers[objectName]) do
		if mods.Condition(params) == true then
			params = mods.Callback(params) or params
		end
	end
	return params
end

---@param objectID integer
---@param playerOrPlayerType Entity | PlayerType
---@param objectType UniqueObjectType
---@param noModifier? boolean
---@param objectEntity? Entity
---@return UniqueObjectParams | nil
function UniqueItemsAPI.GetObjectParams(objectID, playerOrPlayerType, objectType, noModifier, objectEntity)
	local playerType = playerOrPlayerType
	local player
	if type(playerOrPlayerType) ~= "number" then
		---@cast playerOrPlayerType Entity
		player = UniqueItemsAPI.TryGetPlayer(playerOrPlayerType)
		if not player then return end
		playerType = player:GetPlayerType()
	end
	---@cast playerType PlayerType
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData then return end
	local params = {}
	local modData = playerData.ModData[playerData.SelectedModIndex]

	if UniqueItemsAPI.IsObjectRandomized(playerData) and player then
		modData = playerData.ModData[player:GetData().UniqueItemsRandomIndex]
	end

	for varName, value in pairs(modData) do
		params[varName] = value
	end

	if player then
		params.Player = player
	end
	if objectEntity then
		params.ObjectEntity = objectEntity
	end

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
function UniqueItemsAPI.SetIsCharacterObjectDisabled(objectID, playerType, bool, objectType)
	if not bool or type(bool) ~= "boolean" then return end
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData then return end
	playerData.TempDisable = bool
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
	UniqueItemsAPI.AssignObjectName(id, name, UniqueItemsAPI.ObjectType.COLLECTIBLE)
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
	return UniqueItemsAPI.IsObjectIDRegistered(itemID, UniqueItemsAPI.ObjectType.COLLECTIBLE)
end

---@deprecated
---@param familiarVariant FamiliarVariant
function UniqueItemsAPI.IsFamiliarRegistered(familiarVariant)
	return UniqueItemsAPI.IsObjectIDRegistered(familiarVariant, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param knifeVariant KnifeVariant
function UniqueItemsAPI.IsKnifeRegistered(knifeVariant)
	return UniqueItemsAPI.IsObjectIDRegistered(knifeVariant, UniqueItemsAPI.ObjectType.KNIFE)
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
	UniqueItemsAPI.AssignUniqueObject(params, UniqueItemsAPI.ObjectType.COLLECTIBLE)
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
	UniqueItemsAPI.AssignObjectModifier(modifierName, funcCondition, funcCallback, UniqueItemsAPI.ObjectType.COLLECTIBLE)
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
	UniqueItemsAPI.RemoveObjectModifier(modifierName, UniqueItemsAPI.ObjectType.COLLECTIBLE)
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
	local params = UniqueItemsAPI.GetObjectParams(itemID, player, UniqueItemsAPI.ObjectType.COLLECTIBLE, noModifier)
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
	local params = UniqueItemsAPI.GetObjectParams(familiarVariant, familiar, 
	UniqueItemsAPI.ObjectType.FAMILIAR, noModifier)
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
	local params = UniqueItemsAPI.GetObjectParams(knifeVariant, knife, UniqueItemsAPI.ObjectType.KNIFE, noModifier)
	---@cast params OldObjectParams
	if params then
		params.KnifeVariant = params.ObjectID
		params.KnifeSprite = params.SpritePath or params.Anm2
		params.DisabledOnFirstLoad = params.DisableByDefault
		if params.KnifeEntity then
			params.ObjectEntity = params.KnifeEntity
		end
	end
	return params
end

---@deprecated
---@param itemID CollectibleType
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentItemMod(itemID, playerType)
	UniqueItemsAPI.GetCurrentObjectMod(itemID, playerType, UniqueItemsAPI.ObjectType.COLLECTIBLE)
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
	UniqueItemsAPI.SetIsCharacterObjectDisabled(itemID, playerType, not bool, UniqueItemsAPI.ObjectType.COLLECTIBLE)
end

---@deprecated
---@param familiarVariant FamiliarVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterFamiliar(familiarVariant, playerType, bool)
	UniqueItemsAPI.SetIsCharacterObjectDisabled(familiarVariant, playerType, not bool, UniqueItemsAPI.ObjectType.FAMILIAR)
end

---@deprecated
---@param knifeVariant KnifeVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterKnife(knifeVariant, playerType, bool)
	UniqueItemsAPI.SetIsCharacterObjectDisabled(knifeVariant, playerType, not bool, UniqueItemsAPI.ObjectType.FAMILIAR)
end

--#endregion
