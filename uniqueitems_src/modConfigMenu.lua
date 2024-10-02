local mcm = {}

local modName = UniqueItemsAPI.Name

local displayPlayers = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

---@param noItems boolean
function mcm:GenerateModConfigMenu(noItems)
	if ModConfigMenu == nil then return end
	if type(ModConfigMenu.GetCategoryIDByName(modName)) == "number" then
		ModConfigMenu.RemoveCategory(modName)
	end

	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "Unique Items API")
	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "Version " .. UniqueItemsAPI.Version)
	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "by Sanio")

	if noItems then
		ModConfigMenu.AddText(modName, "General", "No other compatible mods are installed!")
		ModConfigMenu.AddText(modName, "General", "Please install a mod that uses this API.")
		return
	end

	ModConfigMenu.AddSetting(modName, "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,
		CurrentSetting = function() return UniqueItemsAPI.DisableAll end,
		Display = function()
			local onOff = "False"
			if UniqueItemsAPI.DisableAll then
				onOff = "True"
			end
			return "Disabled: " .. onOff
		end,
		OnChange = function(currentBool)
			UniqueItemsAPI.DisableAll = currentBool
		end,
		Info =
		"Disables all content linked with the API. Overrides the current settings for all unique items."
	})
	ModConfigMenu.AddSetting(modName, "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,
		CurrentSetting = function() return UniqueItemsAPI.RandomizeAll end,
		Display = function()
			local onOff = "False"
			if UniqueItemsAPI.RandomizeAll then
				onOff = "True"
			end
			return "Randomize: " .. onOff
		end,
		OnChange = function(currentBool)
			UniqueItemsAPI.RandomizeAll = currentBool
		end,
		Info =
		"Randomizes settings on what mod is used for every character with every item, if more than one mod is available for that character."
	})

	for tableName, objectTable in pairs(UniqueItemsAPI.ObjectData) do
		local subcategoryName = tableName
		ModConfigMenu.UpdateSubcategory(modName, subcategoryName, {
			Name = subcategoryName,
			Info = "API Settings for" .. string.lower(tableName) .. ": " .. subcategoryName
		})
		
		---@param ID integer
		---@param objectData UniqueObjectData
		for ID, objectData in pairs(objectTable) do

			--AFFECT ALL
			ModConfigMenu.AddTitle(modName, subcategoryName, objectData.DisplayName)
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return objectData.SelectedModIndex
				end,
				Minimum = #objectData.AllMods > 1 and -1 or 0,
				Maximum = #objectData.AllMods,
				ModifyBy = 1,
				Display = function()
					local display = ""
					if objectData.SelectedModIndex == 0 then
						display = "Disabled"
					elseif objectData.SelectedModIndex == -1 then
						display = "Randomized"
					else
						local selectedModIndex = objectData.SelectedModIndex
						local settingName = #objectData.AllMods > 1 and objectData.AllMods[selectedModIndex] or "Enabled"
						display = settingName
					end
					return "All: " .. display
				end,
				OnChange = function(currentNum)
					objectData.SelectedModIndex = currentNum
					for _, playerData in pairs(objectData.AllPlayers) do
						for i, modData in ipairs(playerData.ModData) do
							if currentNum == 0 or #playerData.ModData > 1 and currentNum == -1 then
								playerData.SelectedModIndex = currentNum
							elseif objectData.AllMods[objectData.SelectedModIndex] == modData.ModName then
								playerData.SelectedModIndex = i
							end
						end
					end
				end,
				Info = "Changes settings for all characters if the setting is available to them."
			})

			displayPlayers[tableName][ID] = {}
			local playerNames = displayPlayers[tableName][ID]
			for playerType, _ in pairs(objectData.AllPlayers) do
				table.insert(playerNames, playerType)
			end
			table.sort(playerNames)

			--CHARACTER
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return objectData.SelectedPlayerIndex
				end,
				Minimum = 1,
				Maximum = #playerNames,
				ModifyBy = 1,
				Display = function()
					return "Character: " .. UniqueItemsAPI.RegisteredCharacters[objectData.SelectedPlayerIndex - 1].Name .. " (" .. objectData.SelectedPlayerIndex .. "/" .. #playerNames .. ")"
				end,
				OnChange = function(currentNum)
					objectData.SelectedPlayerIndex = currentNum
				end
			})

			--CHOOSE SETTING
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					local playerData = objectData.AllPlayers[objectData.SelectedPlayerIndex - 1]
					return playerData.SelectedModIndex
				end,
				Minimum = #objectData.AllPlayers[objectData.SelectedPlayerIndex - 1].ModData > 1 and -1 or 0,
				Maximum = #objectData.AllPlayers[objectData.SelectedPlayerIndex - 1].ModData,
				ModifyBy = 1,
				Display = function()
					local playerData = objectData.AllPlayers[objectData.SelectedPlayerIndex - 1]
					local selectedModIndex = playerData.SelectedModIndex
					local display = ""
					if selectedModIndex == 0 then
						display = "Disabled"
					elseif selectedModIndex == -1 then
						display = "Randomized"
					else
						local settingName = #playerData.ModData > 1 and playerData.ModData[selectedModIndex].ModName or "Enabled"
						display = settingName
					end
					
					return "Setting: " .. display
				end,
				OnChange = function(currentNum)
					local playerData = objectData.AllPlayers[objectData.SelectedPlayerIndex - 1]
					playerData.SelectedModIndex = currentNum
				end
			})
			ModConfigMenu.AddSpace(modName, subcategoryName)
		end
	end
end

return mcm
