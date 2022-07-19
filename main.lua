--VERSION 1.0.0

---@class UniqueItemSprite
---@field CurrentMod integer
---@field PlayerType PlayerType

---@class UniqueFamiliarSprite : UniqueItemSprite
---@field DefaultAnm2 string

---@class UniqueKnifeSprite : UniqueFamiliarSprite

local mod = RegisterMod("Unique Items API", 1)
local game = Game()
local api = include("uniqueitems_src.uniqueitems_api")
local mcm = include("uniqueitems_src.modConfigMenu")
local saveData = include("uniqueitems_src.saveData")
local CurVersion = "1.0"

saveData:initAPI(api)

mod.RandomRNG = RNG()
mod.RunSeededRNG = RNG()
mod.RandomRNG:SetSeed(Random() + 1, 35)
function mod:RandomNum(lower, upper)
	if upper then
		return mod.RandomRNG:RandomInt((upper - lower) + 1) + lower
	elseif lower then
		return mod.RandomRNG:RandomInt(lower) + 1
	else
		return mod.RandomRNG:RandomFloat()
	end
end

local function RunJustContinued()
	local wasContinued = false
	if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
		wasContinued = true
	end
	return wasContinued
end

---@param collectible EntityPickup
function mod:ReplaceCollectibleOnInit(collectible)

	local level = game:GetLevel()
	if level:GetCurses() == LevelCurse.CURSE_OF_BLIND or collectible.SubType == CollectibleType.COLLECTIBLE_NULL then return end

	local player = Isaac.GetPlayer(0) --Only for Player 1
	local playerType = player:GetPlayerType()
	local params = UniqueItemsAPI.GetItemParams(collectible.SubType, player)
	if params == nil then return end
	local ItemSprite = params.ItemSprite
	if ItemSprite == nil then return end

	local sprite = collectible:GetSprite()
	local data = collectible:GetData()

	sprite:ReplaceSpritesheet(1, ItemSprite)
	sprite:LoadGraphics()
	data.UniqueItemSprite = { CurrentMod = api.uniqueItems[collectible.SubType][playerType].CurrentMod,
		PlayerType = playerType }
end

---@param player EntityPlayer
function mod:ReplaceItemCostume(player)
	for itemID, itemData in pairs(api.uniqueItems) do
		local playerType = player:GetPlayerType()
		local data = player:GetData()

		if not itemData[playerType] then return end

		if player:HasCollectible(itemID)
			and (not data.UniqueCostumeSprites or data.UniqueCostumeSprites[itemID] == nil)
		then
			local params = UniqueItemsAPI.GetItemParams(itemID, player)
			if params == nil then return end

			if params.CostumeSpritePath or params.NullCostume then
				if not data.UniqueCostumeSprites then
					data.UniqueCostumeSprites = {}
				end
				data.UniqueCostumeSprites[itemID] = { CurrentMod = api.uniqueItems[itemID][playerType].CurrentMod,
					PlayerType = playerType, CollectibleNum = player:GetCollectibleNum(itemID) }
			else
				return
			end

			local itemConfig = Isaac.GetItemConfig()
			if params.CostumeSpritePath ~= nil then
				local itemConfigItem = itemConfig:GetCollectible(itemID)
				local shouldAddCostume = itemConfigItem.Costume.ID ~= -1 and itemConfigItem.Type == ItemType.ITEM_ACTIVE and
					player:GetEffects():HasCollectibleEffect(itemID) or ItemConfig.Config.ShouldAddCostumeOnPickup(itemConfigItem)

				if shouldAddCostume then
					player:ReplaceCostumeSprite(itemConfigItem, params.CostumeSpritePath, 0) --We don't need to worry about other layers because...this function is bugged to replace all layers! Woo...
				end
			end
			if params.NullCostume ~= nil and not RunJustContinued() then
				player:AddNullCostume(params.NullCostume)
				data.UniqueCostumeSprites[itemID].NullCostume = params.NullCostume
			end
		end
	end
end

---@param player EntityPlayer
function mod:ReplaceCollectibleOnItemQueue(player)
	local data = player:GetData()

	if player.QueuedItem.Item ~= nil then
		for itemID, _ in pairs(api.uniqueItems) do

			if player.QueuedItem.Item.ID == itemID
				and not data.UniqueItemSpriteHeld
			then
				local params = UniqueItemsAPI.GetItemParams(itemID, player)
				local sprite = Sprite()

				sprite:Load("gfx/005.100_collectible.anm2", true)
				sprite:Play("PlayerPickupSparkle", true)

				if params == nil then
					local itemConfigItem = Isaac.GetItemConfig():GetCollectible(itemID)
					sprite:ReplaceSpritesheet(1, itemConfigItem.GfxFileName)
				else
					local ItemSprite = params.ItemSprite
					sprite:ReplaceSpritesheet(1, ItemSprite)
				end

				sprite:LoadGraphics()
				player:AnimatePickup(sprite, false, "Pickup")
				data.UniqueItemSpriteHeld = true
			end
		end
	end
	if player:IsItemQueueEmpty() and data.UniqueItemSpriteHeld then
		data.UniqueItemSpriteHeld = nil
	end
end

---@param familiar EntityFamiliar
function mod:ReplaceFamiliarOnInit(familiar)
	local player = familiar.Player
	if not player then return end
	local playerType = player:GetPlayerType()
	local data = familiar:GetData()
	local sprite = familiar:GetSprite()
	local params = UniqueItemsAPI.GetFamiliarParams(familiar.Variant, familiar)
	local originalAnm2 = sprite:GetFilename()

	if params == nil then return end

	if not data.UniqueFamiliarSprite then
		if type(params.FamiliarSprite) == "table" then
			for i = 0, sprite:GetLayerCount() - 1 do
				local spritePath = params.FamiliarSprite[i]
				if spritePath ~= nil then
					sprite:ReplaceSpritesheet(i, params.FamiliarSprite[i])
				end
			end
			sprite:LoadGraphics()
		elseif type(params.FamiliarSprite) == "string" then
			sprite:Load(params.FamiliarSprite, true)
		end
		---@class UniqueFamiliarSprite
		data.UniqueFamiliarSprite = { CurrentMod = api.uniqueFamiliars[familiar.Variant][playerType].CurrentMod,
			PlayerType = playerType, DefaultAnm2 = originalAnm2 }
	end
end

local function LoadKnife(knife, anm2ToLoad)
	local sprite = knife:GetSprite()
	--Only happens for bone-like weapons
	if (knife.Variant ~= 0 and knife.Variant ~= 5 and knife.Variant ~= 10 and knife.Variant ~= 11)
		and knife:GetEntityFlags() == 67108864
		and not game:IsPaused()
	then
		knife.Visible = false
		return
	end
	local animToPlay = sprite:GetAnimation()
	local frame = sprite:GetFrame()
	local isPlaying = sprite:IsPlaying(animToPlay)

	sprite:Load(anm2ToLoad, true)
	sprite:Play(animToPlay, true)
	sprite:SetFrame(frame)
	if not isPlaying then
		sprite:Stop()
	end
end

---@param knife EntityKnife
function mod:ReplaceKnifeOnInit(knife)
	local parent = knife.SpawnerEntity and (knife.SpawnerEntity:ToPlayer() or knife.SpawnerEntity:ToFamiliar())
	if not parent then return end
	---@type EntityPlayer
	local player = parent:ToPlayer() or parent:ToFamiliar().Player
	if not player then return end
	local playerType = player:GetPlayerType()
	local data = knife:GetData()
	local sprite = knife:GetSprite()
	local params = UniqueItemsAPI.GetKnifeParams(knife.Variant, knife)
	local originalAnm2 = sprite:GetFilename()

	if params == nil then return end

	if not data.UniqueKnifeSprite then
		if type(params.KnifeSprite) == "table" then
			for i = 0, sprite:GetLayerCount() - 1 do
				local spritePath = params.KnifeSprite[i]
				if spritePath ~= nil then
					sprite:ReplaceSpritesheet(i, params.KnifeSprite[i])
				end
			end
			sprite:LoadGraphics()
		elseif type(params.KnifeSprite) == "string" then
			LoadKnife(knife, params.KnifeSprite)
		end
		---@class UniqueKnifeSprite
		data.UniqueKnifeSprite = { CurrentMod = api.uniqueKnives[knife.Variant][playerType].CurrentMod, PlayerType = playerType,
			DefaultAnm2 = originalAnm2 }
	end
end

local lastFrameCheckCollectible = 0

---@param collectible EntityPickup
function mod:UpdateCollectibleSprite(collectible)
	if collectible.SubType == CollectibleType.COLLECTIBLE_NULL then return end
	local player = Isaac.GetPlayer(0)
	local playerType = player:GetPlayerType()
	local data = collectible:GetData()
	local params = UniqueItemsAPI.GetItemParams(collectible.SubType, player, true)
	local playerData = params ~= nil and api.uniqueItems[collectible.SubType][playerType]
	local isDisabled = params ~= nil and playerData.Disabled or false

	if (data.UniqueItemSprite
		and (
		data.UniqueItemSprite.PlayerType ~= playerType
			or (params == nil or isDisabled == true or data.UniqueItemSprite.CurrentMod ~= playerData.CurrentMod)
		)
		)
		or (data.UniqueItemSprite == nil and params ~= nil and isDisabled == false)
		or (params ~= nil and game:GetFrameCount() >= lastFrameCheckCollectible + 15)
	then
		lastFrameCheckCollectible = game:GetFrameCount()
		data.UniqueItemSprite = nil
		if params == nil or isDisabled == true then
			local sprite = collectible:GetSprite()
			local itemConfigItem = Isaac.GetItemConfig():GetCollectible(collectible.SubType)
			sprite:ReplaceSpritesheet(1, itemConfigItem.GfxFileName)
			sprite:LoadGraphics()
		else
			mod:ReplaceCollectibleOnInit(collectible)
		end
	end
end

--gaming
---@param player EntityPlayer
function mod:UpdateItemCostume(player)
	local playerType = player:GetPlayerType()
	local data = player:GetData()

	if not data.UniqueCostumeSprites then data.UniqueCostumeSprites = {} end

	for itemID, costumeData in pairs(data.UniqueCostumeSprites) do
		local params = UniqueItemsAPI.GetItemParams(itemID, player)
		local playerData = params ~= nil and api.uniqueItems[itemID][playerType]
		local isDisabled = params ~= nil and playerData.Disabled or nil

		if (data.UniqueCostumeSprites[itemID] ~= nil
			and (
			costumeData.PlayerType ~= playerType
				or player:GetCollectibleNum(itemID) ~= costumeData.CollectibleNum
				or (params == nil or isDisabled == true or data.UniqueCostumeSprites[itemID].CurrentMod ~= playerData.CurrentMod)
			)
			)
			or (data.UniqueCostumeSprites[itemID] == nil and params ~= nil and isDisabled == false)
		then
			local itemConfigItem = Isaac.GetItemConfig():GetCollectible(itemID)

			player:AddCostume(itemConfigItem, false)
			if costumeData.NullCostume ~= nil then
				player:TryRemoveNullCostume(costumeData.NullCostume)
			end
			data.UniqueCostumeSprites[itemID] = nil
			if params ~= nil and isDisabled == false then
				mod:ReplaceItemCostume(player)
			end
		end
	end
end

local lastFrameCheckFamiliar = 0

---@param familiar EntityFamiliar
function mod:UpdateFamiliarSprite(familiar)
	---@type EntityPlayer
	local player = familiar.Player
	if not player then return end
	local playerType = player:GetPlayerType()
	local data = familiar:GetData()
	local params = UniqueItemsAPI.GetFamiliarParams(familiar.Variant, familiar)
	local playerData = params ~= nil and api.uniqueFamiliars[familiar.Variant][playerType]
	local isDisabled = params ~= nil and playerData.Disabled or false
	---@type UniqueFamiliarSprite
	local spriteData = data.UniqueFamiliarSprite

	if (
		spriteData and
			(
			spriteData.PlayerType ~= playerType or
				(params == nil or isDisabled == true or spriteData.CurrentMod ~= playerData.CurrentMod)))
		or (spriteData == nil and params ~= nil and isDisabled == false)
		or (params ~= nil and game:GetFrameCount() >= lastFrameCheckFamiliar + 15)
	then
		lastFrameCheckFamiliar = game:GetFrameCount()
		local sprite = familiar:GetSprite()
		local animPlaying = sprite:GetAnimation()
		local animToPlay = animPlaying or sprite:GetDefaultAnimation()
		local anm2File = spriteData and spriteData.DefaultAnm2 or sprite:GetFilename()
		data.UniqueFamiliarSprite = nil

		sprite:Load(anm2File, true)
		sprite:SetAnimation(animToPlay, true)
		sprite:Play(animToPlay, true)
		if params ~= nil and isDisabled == false then
			mod:ReplaceFamiliarOnInit(familiar)
		end
	end
end

local lastFrameCheckKnife = 0

---@param knife EntityKnife
function mod:UpdateKnifeSprite(knife)
	local parent = knife.SpawnerEntity and (knife.SpawnerEntity:ToPlayer() or knife.SpawnerEntity:ToFamiliar())
	if not parent then return end
	---@type EntityPlayer
	local player = parent:ToPlayer() or parent:ToFamiliar().Player
	if not player then return end
	local playerType = player:GetPlayerType()
	local data = knife:GetData()
	local params = UniqueItemsAPI.GetKnifeParams(knife.Variant, knife)
	local playerData = params ~= nil and api.uniqueKnives[knife.Variant][playerType]
	local isDisabled = params ~= nil and playerData.Disabled or false
	---@type UniqueKnifeSprite
	local spriteData = data.UniqueKnifeSprite

	if (
		spriteData and
			(
			spriteData.PlayerType ~= playerType or
				(params == nil or isDisabled == true or spriteData.CurrentMod ~= playerData.CurrentMod)))
		or (spriteData == nil and params ~= nil and isDisabled == false)
		or (params ~= nil and game:GetFrameCount() >= lastFrameCheckKnife + 15)
	then
		lastFrameCheckKnife = game:GetFrameCount()
		local sprite = knife:GetSprite()
		local anm2File = spriteData and spriteData.DefaultAnm2 or sprite:GetFilename()
		LoadKnife(knife, anm2File)
		data.UniqueKnifeSprite = nil
		if params ~= nil and isDisabled == false then
			mod:ReplaceKnifeOnInit(knife)
		end
	end
end

---@param player EntityPlayer
function mod:OnPlayerUpdate(player)
	mod:UpdateItemCostume(player)
	mod:ReplaceItemCostume(player)
	mod:ReplaceCollectibleOnItemQueue(player)
end

local tearToKnifeVariant = {
	[TearVariant.SWORD_BEAM] = 10,
	[TearVariant.TECH_SWORD_BEAM] = 11
}

---@param tear EntityTear
function mod:ReplaceSpiritSwordProjectileOnInit(tear)
	local parent = tear.SpawnerEntity and (tear.SpawnerEntity:ToPlayer() or tear.SpawnerEntity:ToFamiliar())
	if not parent then return end
	---@type EntityPlayer
	local player = parent:ToPlayer() or parent:ToFamiliar().Player
	local params = UniqueItemsAPI.GetKnifeParams(tearToKnifeVariant[tear.Variant], player)
	if not params then return end

	---@type Sprite
	local sprite = tear:GetSprite()
	if params.SwordProjectile and params.SwordProjectile.Beam then
		if string.sub(params.SwordProjectile.Beam, -5, -1) == ".anm2" then
			sprite:Load(params.SwordProjectile.Beam, true)
			sprite:Play(sprite:GetDefaultAnimation(), true)
		elseif string.sub(params.SwordProjectile.Beam, -4, -1) == ".png" then
			sprite:ReplaceSpritesheet(0, params.SwordProjectile.Beam)
			sprite:LoadGraphics()
		end
	elseif type(params.KnifeSprite) == "table" then
		local validLayer
		for _, spritePath in pairs(params.KnifeSprite) do
			validLayer = spritePath
			break
		end
		if validLayer ~= nil then
			sprite:ReplaceSpritesheet(0, validLayer)
			sprite:LoadGraphics()
		end
	end
end

---@param tear EntityTear
function mod:ReplaceSwordSplashOnTearDeath(tear)
	if tear.Variant ~= TearVariant.SWORD_BEAM
		and tear.Variant ~= TearVariant.TECH_SWORD_BEAM
	then
		return
	end

	for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.TEAR_POOF_A)) do
		if effect.Position:DistanceSquared(tear.Position) <= 5 ^ 2 then
			local parent = tear.SpawnerEntity and (tear.SpawnerEntity:ToPlayer() or tear.SpawnerEntity:ToFamiliar())
			if not parent then return end
			---@type EntityPlayer
			local player = parent:ToPlayer() or parent:ToFamiliar().Player
			local params = UniqueItemsAPI.GetKnifeParams(tearToKnifeVariant[tear.Variant], player)
			if not params then return end

			---@type Sprite
			local sprite = effect:GetSprite()

			if params.SwordProjectile and params.SwordProjectile.Splash then
				if string.sub(params.SwordProjectile.Splash, -5, -1) == ".anm2" then
					sprite:Load(params.SwordProjectile.Splash, true)
					sprite:Play(sprite:GetDefaultAnimation(), true)
				elseif string.sub(params.SwordProjectile.Splash, -4, -1) == ".png" then
					sprite:ReplaceSpritesheet(0, params.SwordProjectile.Splash)
					sprite:LoadGraphics()
				end
			elseif type(params.KnifeSprite) == "table" then
				local validLayer
				for _, spritePath in pairs(params.KnifeSprite) do
					validLayer = spritePath
					break
				end
				if validLayer ~= nil then
					sprite:ReplaceSpritesheet(0, validLayer)
					sprite:LoadGraphics()
				end
			end
		end
	end
end

local noItems = true

function mod:CheckItemsOnGameStart()
	for itemID, itemData in pairs(api.uniqueItems) do
		noItems = false
	end
	for familiarVariant, familiarData in pairs(api.uniqueFamiliars) do
		noItems = false
	end
	for knifeVariant, knifeData in pairs(api.uniqueKnives) do
		noItems = false
	end
end

function mod:OnPostGameStarted()
	mod:CheckItemsOnGameStart()
	mcm:GenerateModConfigMenu(api, CurVersion, noItems)
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnPostGameStarted)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.OnPlayerUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.ReplaceCollectibleOnInit, PickupVariant.PICKUP_COLLECTIBLE)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, mod.ReplaceFamiliarOnInit)
mod:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, mod.ReplaceKnifeOnInit)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, mod.UpdateCollectibleSprite, PickupVariant.PICKUP_COLLECTIBLE)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.UpdateFamiliarSprite)
mod:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, mod.UpdateKnifeSprite)
mod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, mod.ReplaceSpiritSwordProjectileOnInit, TearVariant.SWORD_BEAM)
mod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, mod.ReplaceSpiritSwordProjectileOnInit, TearVariant.TECH_SWORD_BEAM)
mod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, mod.ReplaceSwordSplashOnTearDeath, EntityType.ENTITY_TEAR)
