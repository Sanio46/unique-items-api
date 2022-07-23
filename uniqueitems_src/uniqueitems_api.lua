local api = {}
UniqueItemsAPI = {}

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

---@class GlobalModParams
---@field CurrentModGlobal integer
---@field AllMods string[]
---@field RandomizedAvailable boolean

---@class UniqueItemParams
---@field ModName string
---@field PlayerType PlayerType
---@field ItemID CollectibleType
---@field ItemSprite string
---@field NullCostume NullItemID
---@field CostumeSpritePath string
---@field DisabledOnFirstLoad boolean

---@class UniqueFamiliarParams
---@field ModName string
---@field PlayerType PlayerType
---@field FamiliarVariant FamiliarVariant
---@field FamiliarSprite table<integer, string> | string
---@field DisabledOnFirstLoad boolean

---@class UniqueKnifeParams
---@field ModName string
---@field PlayerType PlayerType
---@field KnifeVariant KnifeVariant
---@field KnifeSprite table<integer, string> | string
---@field SwordProjectile {Beam: string, Splash: string}
---@field DisabledOnFirstLoad boolean

---@class UniquePlayerParams
---@field Disabled boolean
---@field TempDisabled boolean
---@field DisabledOnFirstLoad boolean
---@field CurrentMod integer
---@field Mods UniqueItemParams | UniqueFamiliarParams | UniqueKnifeParams

local lastRegisteredMod = ""
local maxCharacters = PlayerType.NUM_PLAYER_TYPES

---@class KnifeVariant : integer

api.isDisabled = false
api.isRandomized = false

---@type string[]
api.registeredMods = {}

---@type table<PlayerType, string>
api.registeredCharacters = {
	[PlayerType.PLAYER_ISAAC] = "Isaac",
	[PlayerType.PLAYER_MAGDALENE] = "Magdalene",
	[PlayerType.PLAYER_CAIN] = "Cain",
	[PlayerType.PLAYER_JUDAS] = "Judas",
	[PlayerType.PLAYER_BLUEBABY] = "Blue Baby",
	[PlayerType.PLAYER_EVE] = "Eve",
	[PlayerType.PLAYER_SAMSON] = "Samson",
	[PlayerType.PLAYER_AZAZEL] = "Azazel",
	[PlayerType.PLAYER_LAZARUS] = "Lazarus",
	[PlayerType.PLAYER_EDEN] = "Eden",
	[PlayerType.PLAYER_THELOST] = "The Lost",
	[PlayerType.PLAYER_LAZARUS2] = "Lazarus II",
	[PlayerType.PLAYER_BLACKJUDAS] = "Dark Judas",
	[PlayerType.PLAYER_LILITH] = "Lilith",
	[PlayerType.PLAYER_KEEPER] = "Keeper",
	[PlayerType.PLAYER_APOLLYON] = "Apollyon",
	[PlayerType.PLAYER_THEFORGOTTEN] = "The Forgotten",
	[PlayerType.PLAYER_THESOUL] = "The Soul",
	[PlayerType.PLAYER_BETHANY] = "Bethany",
	[PlayerType.PLAYER_JACOB] = "Jacob",
	[PlayerType.PLAYER_ESAU] = "Esau"
}
---@type table<PlayerType, string>
api.registeredTainteds = {
	[PlayerType.PLAYER_ISAAC_B] = "Isaac",
	[PlayerType.PLAYER_MAGDALENE_B] = "Magdalene",
	[PlayerType.PLAYER_CAIN_B] = "Cain",
	[PlayerType.PLAYER_JUDAS_B] = "Judas",
	[PlayerType.PLAYER_BLUEBABY_B] = "Blue Baby",
	[PlayerType.PLAYER_EVE_B] = "Eve",
	[PlayerType.PLAYER_SAMSON_B] = "Samson",
	[PlayerType.PLAYER_AZAZEL_B] = "Azazel",
	[PlayerType.PLAYER_LAZARUS_B] = "Alive Lazarus",
	[PlayerType.PLAYER_EDEN_B] = "Eden",
	[PlayerType.PLAYER_THELOST_B] = "The Lost",
	[PlayerType.PLAYER_LILITH_B] = "Lilith",
	[PlayerType.PLAYER_KEEPER_B] = "Keeper",
	[PlayerType.PLAYER_APOLLYON_B] = "Apollyon",
	[PlayerType.PLAYER_THEFORGOTTEN_B] = "The Forgotten",
	[PlayerType.PLAYER_BETHANY_B] = "Bethany",
	[PlayerType.PLAYER_JACOB_B] = "Jacob",
	[PlayerType.PLAYER_LAZARUS2_B] = "Dead Lazarus",
	[PlayerType.PLAYER_JACOB2_B] = "Ghost Jacob",
	[PlayerType.PLAYER_THESOUL_B] = "The Soul",
}

---@type table<CollectibleType, string>
api.registeredItems = {}

---@type table<CollectibleType, table<PlayerType, UniquePlayerParams>>
api.uniqueItems = {}

---@type table<FamiliarVariant, table<PlayerType, UniquePlayerParams>>
api.uniqueFamiliars = {}
---@type table<KnifeVariant, table<PlayerType, UniquePlayerParams>>
api.uniqueKnives = {}
api.uniqueItemModifiers = {}
api.uniqueFamiliarModifiers = {}
api.uniqueKnifeModifiers = {}

---@param name string
function UniqueItemsAPI.IsModRegistered(name)
	if #api.registeredMods == 0 then
		return false
	end
	for _, modName in pairs(api.registeredMods) do
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
	if isTainted then
		return api.registeredTainteds[playerType] ~= nil
	else
		return api.registeredCharacters[playerType] ~= nil
	end
end

---@param modName string
function UniqueItemsAPI.RegisterMod(modName)
	local funcName = "RegisterMod"
	if UniqueItemsAPI.IsModRegistered(modName) then return end
	if modName == nil or type(modName) ~= "string" then
		callArgumentNumberError(funcName, modName, 1, "string")
		return
	end
	table.insert(api.registeredMods, modName)
	lastRegisteredMod = modName
end

---@param name string
---@param isTainted boolean
function UniqueItemsAPI.RegisterCharacter(name, isTainted)
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
	if isTainted then
		if not api.registeredTainteds[playerType] then
			maxCharacters = maxCharacters + 1
			api.registeredTainteds[playerType] = name
		end
	else
		if not api.registeredCharacters[playerType] then
			maxCharacters = maxCharacters + 1
			api.registeredCharacters[playerType] = name
		end
	end
end

---@param itemID CollectibleType
---@param itemName? string
function UniqueItemsAPI.RegisterItem(itemID, itemName)
	local funcName = "RegisterItem"
	if itemID == nil or type(itemID) ~= "number" then
		callArgumentNumberError(funcName, itemID, 1, "number")
		return
	end
	local itemConfigItem = Isaac.GetItemConfig():GetCollectible(itemID)
	api.registeredItems[itemID] = itemName or itemConfigItem.Name
end

---@param funcName string
---@param params UniqueItemParams | UniqueFamiliarParams | UniqueKnifeParams
local function ShouldDataBeAdded(funcName, params, dataType)
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
	if dataType == "Item" then
		if params.ItemID == nil
			or type(params.ItemID) ~= "number"
		then
			callArgumentError(funcName, params.ItemID, "ItemID", "number", true)
			return
		end
		if (params.ItemSprite == nil and params.NullCostume == nil and params.CostumeSpritePath == nil) then
			local err = "Bad Enumerations in " ..
				funcName .. " (All values are nil, at least one value is required to be non-nil)"
			callError(err, true)
			return
		end
		if params.ItemSprite ~= nil then
			if type(params.ItemSprite) ~= "string" then
				callArgumentError(funcName, params.ItemSprite, "ItemSprite", "string", true)
			end
		end
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
	elseif dataType == "Familiar" then
		if params.FamiliarVariant == nil
			or type(params.FamiliarVariant) ~= "number"
		then
			callArgumentError(funcName, params.FamiliarVariant, "FamiliarVariant", "number", true)
		end
		if params.FamiliarSprite == nil
			or (type(params.FamiliarSprite) ~= "table"
				and type(params.FamiliarSprite) ~= "string"
			)
		then
			callArgumentError(funcName, params.FamiliarSprite, "FamiliarSprite", "table or string", true)
		end
	elseif dataType == "Knife" then
		if params.KnifeVariant == nil
			or type(params.KnifeVariant) ~= "number"
		then
			callArgumentError(funcName, params.KnifeVariant, "KnifeVariant", "number", true)
		end
		if params.KnifeSprite == nil
			or (type(params.KnifeSprite) ~= "table"
				and type(params.KnifeSprite) ~= "string"
			)
		then
			callArgumentError(funcName, params.KnifeSprite, "KnifeSprite", "table or string", true)
		end
		if params.SwordProjectile ~= nil then
			if type(params.SwordProjectile) ~= "table" then
				callArgumentError(funcName, params.SwordProjectile, "KnifeSprite", "table")
			end
		end
	end

	return shouldAdd
end

---@param itemID CollectibleType
function UniqueItemsAPI.IsItemRegistered(itemID)
	return api.registeredItems[itemID] == true
end

---@param params UniqueItemParams
function UniqueItemsAPI.AddCharacterItem(params)
	local funcName = "AddUniqueCharacterItem"
	if not ShouldDataBeAdded(funcName, params, "Item") then return end

	if not api.uniqueItems[params.ItemID] then
		api.uniqueItems[params.ItemID] = {}
		api.uniqueItems[params.ItemID].RandomizedAvailable = false
		api.uniqueItems[params.ItemID].CurrentModGlobal = 1
		api.uniqueItems[params.ItemID].AllMods = {}
	end
	---@type GlobalModParams
	local itemParams = api.uniqueItems[params.ItemID]
	local hasMod = false
	for _, modName in ipairs(itemParams.AllMods) do
		if modName == lastRegisteredMod then
			hasMod = true
		end
	end
	if not hasMod then
		table.insert(itemParams.AllMods, lastRegisteredMod)
	end
	if not itemParams[params.PlayerType] then
		itemParams[params.PlayerType] = {}
		itemParams[params.PlayerType].Disabled = params.DisabledOnFirstLoad or false
		itemParams[params.PlayerType].TempDisabled = false
		itemParams[params.PlayerType].Randomized = false
		itemParams[params.PlayerType].CurrentMod = 1
		itemParams[params.PlayerType].Mods = {}
	end
	local playerData = itemParams[params.PlayerType]
	local modStats = {
		ModName = lastRegisteredMod,
		ItemSprite = params.ItemSprite,
		CostumeSpritePath = params.CostumeSpritePath,
		NullCostume = params.NullCostume
	}
	table.insert(playerData.Mods, modStats)
	if #playerData.Mods > 1 then
		itemParams.RandomizedAvailable = true
	end
end

---@param params UniqueFamiliarParams
function UniqueItemsAPI.AddCharacterFamiliar(params)
	local funcName = "AddUniqueCharacterFamiliar"
	if not ShouldDataBeAdded(funcName, params, "Familiar") then return end

	if not api.uniqueFamiliars[params.FamiliarVariant] then
		api.uniqueFamiliars[params.FamiliarVariant] = {}
		api.uniqueFamiliars[params.FamiliarVariant].RandomizedAvailable = false
		api.uniqueFamiliars[params.FamiliarVariant].AllMods = {}
		api.uniqueFamiliars[params.FamiliarVariant].CurrentModGlobal = 1
	end
	---@type GlobalModParams
	local familiarParams = api.uniqueFamiliars[params.FamiliarVariant]
	local hasMod = false
	for _, modName in ipairs(familiarParams.AllMods) do
		if modName == lastRegisteredMod then
			hasMod = true
		end
	end
	if not hasMod then
		table.insert(familiarParams.AllMods, lastRegisteredMod)
	end

	if not familiarParams[params.PlayerType] then
		familiarParams[params.PlayerType] = {}
		familiarParams[params.PlayerType].Disabled = params.DisabledOnFirstLoad or false
		familiarParams[params.PlayerType].TempDisabled = false
		familiarParams[params.PlayerType].Randomized = false
		familiarParams[params.PlayerType].CurrentMod = 1
		familiarParams[params.PlayerType].Mods = {}
	end
	local playerData = familiarParams[params.PlayerType]
	local modStats = {
		ModName = lastRegisteredMod,
	}
	if type(params.FamiliarSprite) == "table" then
		modStats.FamiliarSprite = {}
		for i, v in pairs(params.FamiliarSprite) do
			modStats.FamiliarSprite[i] = v
		end
	else
		modStats.FamiliarSprite = params.FamiliarSprite
	end
	table.insert(playerData.Mods, modStats)
	if #playerData.Mods > 1 then
		familiarParams.RandomizedAvailable = true
	end
end

---@param params UniqueKnifeParams
function UniqueItemsAPI.AddCharacterKnife(params)
	local funcName = "AddUniqueCharacterKnife"
	if not ShouldDataBeAdded(funcName, params, "Knife") then return end

	if not api.uniqueKnives[params.KnifeVariant] then
		api.uniqueKnives[params.KnifeVariant] = {}
		api.uniqueKnives[params.KnifeVariant].RandomizedAvailable = false
		api.uniqueKnives[params.KnifeVariant].AllMods = {}
		api.uniqueKnives[params.KnifeVariant].CurrentModGlobal = 1
	end
	---@type GlobalModParams
	local knifeParams = api.uniqueKnives[params.KnifeVariant]
	local hasMod = false
	for _, modName in ipairs(knifeParams.AllMods) do
		if modName == lastRegisteredMod then
			hasMod = true
		end
	end
	if not hasMod then
		table.insert(knifeParams.AllMods, lastRegisteredMod)
	end

	if not knifeParams[params.PlayerType] then
		knifeParams[params.PlayerType] = {}
		knifeParams[params.PlayerType].Disabled = params.DisabledOnFirstLoad or false
		knifeParams[params.PlayerType].TempDisabled = false
		knifeParams[params.PlayerType].Randomized = false
		knifeParams[params.PlayerType].CurrentMod = 1
		knifeParams[params.PlayerType].Mods = {}
	end
	local playerData = knifeParams[params.PlayerType]
	local modStats = {
		ModName = lastRegisteredMod
	}
	if params.SwordProjectile ~= nil then
		modStats.SwordProjectile = {
			Beam = params.SwordProjectile.Beam,
			Splash = params.SwordProjectile.Splash
		}
	end
	if type(modStats.KnifeSprite) == "table" then
		params.KnifeSprite = {}
		for i, v in pairs(params.KnifeSprite) do
			modStats.KnifeSprite[i] = v
		end
	else
		modStats.KnifeSprite = params.KnifeSprite
	end
	table.insert(playerData.Mods, modStats)
	if #playerData.Mods > 1 then
		knifeParams.RandomizedAvailable = true
	end
end

local function ShouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, table)
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
function UniqueItemsAPI.AddItemModifier(modifierName, funcCondition, funcCallback)
	local funcName = "AddUniqueItemModifier"
	if ShouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, api.uniqueItemModifiers) then
		table.insert(api.uniqueItemModifiers, { Name = modifierName, Condition = funcCondition, Callback = funcCallback })
	end
end

---@param modifierName string
---@param funcCondition function
---@param funcCallback function
function UniqueItemsAPI.AddFamiliarModifier(modifierName, funcCondition, funcCallback)
	local funcName = "AddUniqueItemModifier"
	if ShouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, api.uniqueFamiliarModifiers) then
		table.insert(api.uniqueFamiliarModifiers, { Name = modifierName, Condition = funcCondition, Callback = funcCallback })
	end
end

---@param modifierName string
---@param funcCondition function
---@param funcCallback function
function UniqueItemsAPI.AddKnifeModifier(modifierName, funcCondition, funcCallback)
	local funcName = "AddUniqueItemModifier"
	if ShouldModifierBeAdded(funcName, modifierName, funcCondition, funcCallback, api.uniqueKnifeModifiers) then
		table.insert(api.uniqueKnifeModifiers, { Name = modifierName, Condition = funcCondition, Callback = funcCallback })
	end
end

---@param params UniqueItemParams
function api:AddItemModifiers(params)
	for _, funcs in ipairs(api.uniqueItemModifiers) do
		if funcs.Condition(params) == true then
			params = funcs.Callback(params) or params
		end
	end
	return params
end

---@param params UniqueFamiliarParams
function api:AddFamiliarModifiers(params)
	for _, funcs in ipairs(api.uniqueFamiliarModifiers) do
		if funcs.Condition(params) == true then
			params = funcs.Callback(params) or params
		end
	end
	return params
end

---@param params UniqueKnifeParams
function api:AddKnifeModifiers(params)
	for _, funcs in ipairs(api.uniqueKnifeModifiers) do
		if funcs.Condition(params) == true then
			params = funcs.Callback(params) or params
		end
	end
	return params
end

---@param modifierName string
function UniqueItemsAPI.RemoveItemModifier(modifierName)
	for i, v in ipairs(api.uniqueItemModifiers) do
		if v.Name == modifierName then
			table.remove(api.uniqueItemModifiers, i)
			return
		end
	end
end

---@param modifierName string
function UniqueItemsAPI.RemoveFamiliarModifier(modifierName)
	for i, v in ipairs(api.uniqueFamiliarModifiers) do
		if v.Name == modifierName then
			table.remove(api.uniqueFamiliarModifiers, i)
			return
		end
	end
end

---@param modifierName string
function UniqueItemsAPI.RemoveKnifeModifier(modifierName)
	for i, v in ipairs(api.uniqueKnifeModifiers) do
		if v.Name == modifierName then
			table.remove(api.uniqueKnifeModifiers, i)
			return
		end
	end
end

---@param itemID CollectibleType
---@param player EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueItemParams | nil
function UniqueItemsAPI.GetItemParams(itemID, player, noModifier)
	local playerType = type(player) == "number" and player or player:GetPlayerType()

	if api.uniqueItems[itemID] == nil or
		(api.registeredCharacters[playerType] == nil and api.registeredTainteds[playerType] == nil) then return end

	local playerData = api.uniqueItems[itemID][playerType]
	local params = {}

	for varName, value in pairs(playerData.Mods[playerData.CurrentMod]) do
		params[varName] = value
	end

	if noModifier == true then return params end
	if type(player) == "userdata" then
		params.Player = player
	end
	params.PlayerType = playerType
	params.ItemID = itemID

	params = api:AddItemModifiers(params)

	return params
end

---@param familiarVariant FamiliarVariant
---@param familiar EntityFamiliar | EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueFamiliarParams | nil
function UniqueItemsAPI.GetFamiliarParams(familiarVariant, familiar, noModifier)
	local player = (type(familiar) == "userdata" and familiar:ToPlayer()) or familiar.Player
	local playerType = (type(familiar) == "number" and familiar) or (player ~= nil and player:GetPlayerType())
	if api.uniqueFamiliars[familiarVariant] == nil or
		(api.registeredCharacters[playerType] == nil and api.registeredTainteds[playerType] == nil) then return end

	local playerData = api.uniqueFamiliars[familiarVariant][playerType]
	local params = {}

	for varName, value in pairs(playerData.Mods[playerData.CurrentMod]) do
		params[varName] = value
	end
	if noModifier then return params end
	if type(familiar) == "userdata" then
		if familiar:ToFamiliar() then
			params.Familiar = familiar:ToFamiliar()
		end
		if player then
			params.Player = player
		end
	end
	params.PlayerType = playerType
	params.FamiliarVariant = familiarVariant
	params = api:AddFamiliarModifiers(params)

	return params
end

---@param knifeVariant KnifeVariant
---@param knife EntityKnife | EntityPlayer | PlayerType
---@param noModifier? boolean
---@return UniqueKnifeParams | nil
function UniqueItemsAPI.GetKnifeParams(knifeVariant, knife, noModifier)
	local player = type(knife) == "userdata" and knife:ToPlayer() or
		knife.SpawnerEntity and (knife.SpawnerEntity:ToPlayer() or knife.SpawnerEntity:ToFamiliar().Player) or knife
	local playerType = (type(knife) == "number" and knife or player ~= nil and player:GetPlayerType())

	if api.uniqueKnives[knifeVariant] == nil or
		(api.registeredCharacters[playerType] == nil and api.registeredTainteds[playerType] == nil) then return end

	local playerData = api.uniqueKnives[knifeVariant][playerType]
	local params = {}

	for varName, value in pairs(playerData.Mods[playerData.CurrentMod]) do
		params[varName] = value
	end
	if noModifier then return params end
	if type(knife) == "userdata" then
		if knife:ToKnife() then
			params.Knife = knife:ToKnife()
		end
		if player then
			params.Player = player
		end
	end
	params.PlayerType = playerType
	params.KnifeVariant = knifeVariant
	params = api:AddKnifeModifiers(params)

	return params
end

---@param itemID CollectibleType
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentItemMod(itemID, playerType)
	if not api.uniqueItems[itemID] or not api.uniqueItems[itemID][playerType] then return end
	local playerParams = api.uniqueItems[itemID][playerType]
	return playerParams.Mods[playerParams.CurrentMod]
end

---@param familiarVariant FamiliarVariant
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentFamiliarMod(familiarVariant, playerType)
	if not api.uniqueFamiliars[familiarVariant] or not api.uniqueFamiliars[familiarVariant][playerType] then return end
	local playerParams = api.uniqueFamiliars[familiarVariant][playerType]
	return playerParams.Mods[playerParams.CurrentMod]
end

---@param kniveVariant KnifeVariant
---@param playerType PlayerType
function UniqueItemsAPI.GetCurrentKnifeMod(kniveVariant, playerType)
	if not api.uniqueKnives[kniveVariant] or not api.uniqueKnives[kniveVariant][playerType] then return end
	local playerParams = api.uniqueKnives[kniveVariant][playerType]
	return playerParams.Mods[playerParams.CurrentMod]
end

---@param itemID CollectibleType
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterItem(itemID, playerType, bool)
	if not bool or type(bool) ~= "boolean" or not api.uniqueItems[itemID] or not api.uniqueItems[itemID][playerType] then return end
	local playerParams = api.uniqueItems[itemID][playerType]
	playerParams.TempDisabled = not bool
end

---@param familiarVariant FamiliarVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterFamiliar(familiarVariant, playerType, bool)
	if not bool or type(bool) ~= "boolean" or not api.uniqueFamiliars[familiarVariant] or
		not api.uniqueFamiliars[familiarVariant][playerType] then return end
	local playerParams = api.uniqueFamiliars[familiarVariant][playerType]
	playerParams.TempDisabled = not bool
end

---@param kniveVariant KnifeVariant
---@param playerType PlayerType
---@param bool boolean
function UniqueItemsAPI.ToggleCharacterKnife(kniveVariant, playerType, bool)
	if not bool or type(bool) ~= "boolean" or not api.uniqueKnives[kniveVariant] or
		not api.uniqueKnives[kniveVariant][playerType] then return end
	local playerParams = api.uniqueKnives[kniveVariant][playerType]
	playerParams.TempDisabled = not bool
end

return api
