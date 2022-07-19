local mcm = {}
local modName = "UniqueItemsAPI"
local nameMap = require("uniqueitems_src.nameMap")
local api

local wasLoaded = false

function mcm:GenerateModConfigMenu(a, CurVersion, noItems)
	api = a
	if ModConfigMenu == nil or wasLoaded == true then return end

	wasLoaded = true
	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "Unique Items API")
	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "Version " .. CurVersion)
	ModConfigMenu.AddSpace(modName, "Info")
	ModConfigMenu.AddText(modName, "Info", "by Sanio")

	if noItems then
		ModConfigMenu.AddText(modName, "General", "No other compatible mods are installed!")
		ModConfigMenu.AddText(modName, "General", "Please install a mod that uses this API.")
		return
	end

	ModConfigMenu.AddSetting(modName, "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,
		CurrentSetting = function() return api.isDisabled end,
		Display = function()
			local onOff = "False"
			if api.isDisabled then
				onOff = "True"
			end
			return "Disabled: " .. onOff
		end,
		OnChange = function(currentBool)
			api.isDisabled = currentBool
		end,
		Info = "Enables / Disables all content linked with the API. Overrides the current 'Disabled' settings for all unique items."
	})
	ModConfigMenu.AddSetting(modName, "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,
		CurrentSetting = function() return api.isRandomized end,
		Display = function()
			local onOff = "False"
			if api.isRandomized then
				onOff = "True"
			end
			return "Randomize: "..onOff
		end,
		OnChange = function(currentBool)
			--For now, nothing.
		end,
		Info = "Randomizes settings on what mod is used for every character with every item, if more than one mod is available for that character."
	})

	local tables = {
		api.uniqueItems,
		api.uniqueFamiliars,
		api.uniqueKnives
	}
	for i = 1, #tables do
		---@param ID CollectibleType | FamiliarVariant | KnifeVariant
		for ID, itemData in pairs(tables[i]) do
			---@type GlobalModParams
			itemData = itemData
			local subcategoryName = "?"
			if i == 1 then
				local itemConfig = Isaac.GetItemConfig()
				subcategoryName = (ID < CollectibleType.NUM_COLLECTIBLES and nameMap.Items[ID]) or api.registeredItems[ID] or itemConfig:GetCollectible(ID).Name
				ModConfigMenu.UpdateSubcategory(modName, subcategoryName, {
					Name = subcategoryName,
					Info = "API Settings for item: " .. subcategoryName
				})
			elseif i == 2 then
				subcategoryName = nameMap.Familiars[ID] or api.registeredFamiliars[ID] or "FamiliarVariant"..ID
				ModConfigMenu.UpdateSubcategory(modName, subcategoryName, {
					Name = subcategoryName,
					Info = "API Settings for familiar: " .. subcategoryName
				})
			elseif i == 3 then
				subcategoryName = nameMap.Knives[ID] or api.registeredKnives[ID] or "KnifeVariant"..ID
				ModConfigMenu.UpdateSubcategory(modName, subcategoryName, {
					Name = subcategoryName,
					Info = "API Settings for knife: " .. subcategoryName
				})
			end

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddSetting(modName, subcategoryName, {
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function()
					return itemData.CurrentModGlobal
				end,
				Minimum = itemData.RandomizedAvailable and -1 or 0,
				Maximum = #itemData.AllMods,
				ModifyBy = 1,
				Display = function()
					local display = ""
					if itemData.AllMods[itemData.CurrentModGlobal] then
						display = itemData.AllMods[itemData.CurrentModGlobal]
					elseif itemData.CurrentModGlobal == 0 then
						display = "Disabled"
					elseif itemData.CurrentModGlobal == -1 then
						display = "Randomized"
					end
					display = "All: "..display
					return display
				end,
				OnChange = function(currentNum)
					itemData.CurrentModGlobal = currentNum
					for var, playerData in pairs(itemData) do
						if type(var) == "number" then
							if currentNum == -1 then
								if #playerData.Mods > 1 then
									playerData.Disabled = false
									playerData.Randomized = true
								end
							elseif currentNum == 0 then
								playerData.Randomized = false
								playerData.Disabled = true
							else
								for i, modData in ipairs(playerData.Mods) do
									if itemData.AllMods[itemData.CurrentModGlobal] == modData.ModName then
										playerData.Randomized = false
										playerData.Disabled = false
										playerData.CurrentMod = i
									end
								end
							end
						end
					end
				end,
				Info = "Changes settings for all characters if the setting is available to them."
			})

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddTitle(modName, subcategoryName, "Normal Characters")
			ModConfigMenu.AddSpace(modName, subcategoryName)

			local shouldNA = true
			--Isaac is put at the very end due to their index of 0, but I don't want to change the system more than it has to, so this is forcing Isaac first if he's available
			if itemData[PlayerType.PLAYER_ISAAC] ~= nil then
				if api.registeredCharacters[PlayerType.PLAYER_ISAAC] then
					mcm:GenerateCharacter(subcategoryName, PlayerType.PLAYER_ISAAC, itemData[PlayerType.PLAYER_ISAAC])
					shouldNA = false
				end
			end
			for playerType, playerData in pairs(itemData) do
				if playerType ~= PlayerType.PLAYER_ISAAC and type(playerType) == "number" then
					if api.registeredCharacters[playerType] then
						mcm:GenerateCharacter(subcategoryName, playerType, playerData)
						shouldNA = false
					end
				end
			end
			if shouldNA then
				ModConfigMenu.AddText(modName, subcategoryName, "N/A")
			end

			ModConfigMenu.AddSpace(modName, subcategoryName)
			ModConfigMenu.AddTitle(modName, subcategoryName, "Tainted Characters")
			ModConfigMenu.AddSpace(modName, subcategoryName)

			local shouldNATainted = true
			for playerType, playerData in pairs(itemData) do
				if type(playerType) == "number" then
					if api.registeredTainteds[playerType] then
						mcm:GenerateCharacter(subcategoryName, playerType, playerData)
						shouldNATainted = false
					end
				end
			end
			if shouldNATainted then
				ModConfigMenu.AddText(modName, subcategoryName, "N/A")
			end
		end
	end
end

function mcm:GenerateCharacter(subcategoryName, playerType, playerData)
	ModConfigMenu.AddSetting(modName, subcategoryName, {
		Type = ModConfigMenu.OptionType.NUMBER,
		CurrentSetting = function()
			local num = playerData.CurrentMod
			if playerData.Randomized then
				num = -1
			elseif playerData.Disabled then
				num = 0
			end
			return num
		end,
		Minimum = #playerData.Mods > 1 and -1 or 0,
		Maximum = #playerData.Mods,
		ModifyBy = 1,
		Display = function()
			local display = playerData.Mods[playerData.CurrentMod].ModName
			local char = api.registeredCharacters[playerType] or api.registeredTainteds[playerType]
			if playerData.Disabled then
				display = "Disabled"
			elseif playerData.Randomized then
				display = "Randomized"
			end
			display = char .. ": "..display
			return display
		end,
		OnChange = function(currentNum)
			if currentNum == -1 then
				playerData.Disabled = false
				playerData.Randomized = true
			elseif currentNum == 0 then
				playerData.Disabled = true
				playerData.Randomized = false
			else
				playerData.Randomized = false
				playerData.Disabled = false
				playerData.CurrentMod = currentNum
			end
		end
	})
end

return mcm
