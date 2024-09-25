local mcm = {}

local modName = UniqueItemsAPI.Name

local displayPlayers = {
	Collectibles = {},
	Familiars = {},
	Knives = {}
}

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
		"Enables / Disables all content linked with the API. Overrides the current 'Disabled' settings for all unique items."
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
			return UniqueItemsAPI.RandomizeAll
		end,
		Info =
		"Randomizes settings on what mod is used for every character with every item, if more than one mod is available for that character."
	})

	for tableName, objectTable in pairs(UniqueItemsAPI.ObjectData) do
		---@param ID integer
		---@param objectData UniqueObjectData
		for ID, objectData in pairs(objectTable) do
			local subcategoryName = objectData.DisplayName
			ModConfigMenu.UpdateSubcategory(modName, subcategoryName, {
				Name = subcategoryName,
				Info = "API Settings for" .. string.lower(tableName) .. ": " .. subcategoryName
			})

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return objectData.SelectedModIndex
				end,
				Minimum = #objectTable > 1 and -1 or 0,
				Maximum = #objectData.AllMods,
				ModifyBy = 1,
				Display = function()
					local display = ""
					if objectData.AllMods[objectData.SelectedModIndex] then
						display = objectData.AllMods[objectData.SelectedModIndex]
					elseif objectData.SelectedModIndex == 0 then
						display = "Disabled"
					elseif objectData.SelectedModIndex == -1 then
						display = "Randomized"
					end
					display = "All: " .. display
					return display
				end,
				OnChange = function(currentNum)
					objectData.SelectedModIndex = currentNum
					for _, playerData in pairs(objectData.AllPlayers) do
						for i, modData in ipairs(playerData.ModData) do
							if objectData.AllMods[objectData.SelectedModIndex] == modData.ModName then
								playerData.SelectedModIndex = i
							end
						end
					end
				end,
				Info = "Changes settings for all characters if the setting is available to them."
			})

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddTitle(modName, subcategoryName, "Character")
			ModConfigMenu.AddSpace(modName, subcategoryName)

			displayPlayers[tableName][ID] = {}
			local playerNames = displayPlayers[tableName][ID]
			for playerType, _ in pairs(objectData.AllPlayers) do
				table.insert(playerNames, playerType)
			end
			table.sort(playerNames)

			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return objectData.SelectedPlayerIndex
				end,
				Mimumum = 1,
				Maximum = #playerNames,
				ModifyBy = 1,
				Display = function()
					return UniqueItemsAPI.RegisteredCharacters[objectData.AllPlayers[objectData.SelectedPlayerIndex]]
				end,
				OnChange = function(currentNum)
					objectData.SelectedPlayerIndex = currentNum
				end
			})

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddTitle(modName, subcategoryName, "Available Packs")
			ModConfigMenu.AddSpace(modName, subcategoryName)
			
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return objectData.AllPlayers[objectData.SelectedPlayerIndex].SelectedModIndex
				end,
				Minimum = 1,
				Maximum = #objectData.AllPlayers[objectData.SelectedPlayerIndex].ModData[objectData.AllPlayers[objectData.SelectedPlayerIndex].SelectedModIndex],
				ModifyBy = 1,
				Display = function()
					return objectData.AllPlayers[objectData.SelectedPlayerIndex].ModData[objectData.AllPlayers[objectData.SelectedPlayerIndex]].ModName
				end,
				OnChange = function(currentNum)
					objectData.AllPlayers[objectData.SelectedPlayerIndex].SelectedModIndex = currentNum
				end
			})
		end
	end
end

return mcm
