local saveData = RegisterMod("Unique Items Save Data", 1)
local api
local json = require("json")
local shouldSave = false

function saveData:initAPI(a)
	api = a
	saveData:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, saveData.LoadMyData)
	saveData:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, saveData.OnPreGameExit)
	saveData:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, saveData.SaveMyData)
end

saveData.APIData = {
	uniqueItems = {},
	uniqueFamiliars = {},
	uniqueKnives = {}
	--[[
		[CollectibleType.COLLECTIBLE_SAD_ONION] = {
			CurrentModGlobal = "ThisMod"
			[PlayerType.PLAYER_ISAAC] = {
				CurrentMod = "ThisMod"
			}
			["Eevee"] = {
				CurrentMod = "EeveeMod"
			}
		}
	]]
}

local tablesToCopy = {
	"uniqueItems",
	"uniqueFamiliars",
	"uniqueKnives"
}

function saveData:OnPreGameExit()
	saveData:SaveMyData()
	shouldSave = false
end

function saveData:SaveMyData()
	if shouldSave == false then return end

	saveData.isDisabled = api.isDisabled
	saveData.isRandomized = api.isRandomized

	--uniqueItems/Familiars/Knives
	for _, tableName in ipairs(tablesToCopy) do
		--CollectibleType/FamiliarVariant/KnifeVariant, item data
		for ID, value in pairs(api[tableName]) do
			local stringID = tostring(ID)
			if not saveData.APIData[tableName][stringID] then
				saveData.APIData[tableName][stringID] = {}
			end
			if type(value) == "table" then
				--itemParams
				for key2, value2 in pairs(value) do
					if key2 == "AllMods" then
						saveData.APIData[tableName][stringID].CurrentModGlobal = value2[api[tableName][ID].CurrentModGlobal]
						saveData.APIData[tableName][stringID].RandomizedAvailable = api[tableName][ID].RandomizedAvailable
					elseif type(key2) == "number" and type(value2) == "table" then
						--playerData
						for key3, value3 in pairs(value2) do
							local playerType = key2
							if key3 == "CurrentMod" then
								local itemParams = saveData.APIData[tableName][stringID]
								local playerName = api.registeredCharacters[playerType] or api.registeredTainteds[playerType]
								local playerKey = playerType >= PlayerType.NUM_PLAYER_TYPES and (api.registeredTainteds[playerType] and playerName .. "B" or playerName) or tostring(playerType)
		
								if not itemParams[playerKey] then
									itemParams[playerKey] = {}
								end
								itemParams[playerKey].IsTainted = api.registeredTainteds[playerType] == true and true or false
								itemParams[playerKey].CurrentMod = api[tableName][ID].AllMods[api[tableName][ID][playerType].CurrentMod]
								itemParams[playerKey].Disabled = value2.Disabled
								itemParams[playerKey].Randomized = value2.Randomized
							end
						end
					end
				end
			end
		end
	end

	saveData:SaveData(json.encode(saveData.APIData))
end

function saveData:LoadMyData()
	shouldSave = true
	if saveData:HasData() then
		saveData.APIData = json.decode(saveData:LoadData())

		api.isDisabled = saveData.isDisabled
		api.isRandomized = saveData.isRandomized

		for tableName, table in pairs(saveData.APIData) do
			for stringID, value in pairs(table) do
				if api[tableName][tonumber(stringID)] ~= nil then
					local itemParams = api[tableName][tonumber(stringID)]
					for key2, value2 in pairs(value) do
						if key2 == "CurrentModGlobal" then
							for i, modName in ipairs(itemParams.AllMods) do
								if value2 == modName then
									itemParams.CurrentModGlobal = i
								end
							end
						elseif type(key2) == "string" and type(value2) == "table" then
							for key3, value3 in pairs(value2) do
								if key3 == "CurrentMod" then
									local playerType = tonumber(key2)
									if playerType == nil and type(playerType) == "string" then
										local playerName = value2.IsTainted and string.sub(playerType, 1, -2) or playerType
										playerType = Isaac.GetPlayerTypeByName(playerName, value2.IsTainted)
									end
									if itemParams[playerType] ~= nil then
										itemParams[playerType].Disabled = value2.Disabled
										if value.RandomizedAvailable then
											itemParams[playerType].Randomized = value2.Randomized
										end
										for i, modName in ipairs(itemParams.AllMods) do
											if value3 == modName then
												itemParams[playerType].CurrentMod = i
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

return saveData
