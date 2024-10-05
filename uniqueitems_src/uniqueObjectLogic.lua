--#region Replace sprite of Collectibles, Familiars, Knives

local entTypeToItemType = {
	[EntityType.ENTITY_PICKUP] = UniqueItemsAPI.ObjectType.COLLECTIBLE,
	[EntityType.ENTITY_FAMILIAR] = UniqueItemsAPI.ObjectType.FAMILIAR,
	[EntityType.ENTITY_KNIFE] = UniqueItemsAPI.ObjectType.KNIFE
}

---@param ent Entity
function UniqueItemsAPI:OnObjectInit(ent)
	if ent.Type == EntityType.ENTITY_PICKUP then
		local level = UniqueItemsAPI.Game:GetLevel()
		if level:GetCurses() == LevelCurse.CURSE_OF_BLIND or ent.SubType == CollectibleType.COLLECTIBLE_NULL then return end
	end
	local player = UniqueItemsAPI.TryGetPlayer(ent)
	if not player then return end
	local playerType = player:GetPlayerType()
	local objectID = ent.Type == EntityType.ENTITY_PICKUP and ent.SubType or ent.Variant
	local objectType = entTypeToItemType[ent.Type]
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData or UniqueItemsAPI.IsObjectDisabled(playerData) then return end
	local data = player:GetData()
	if UniqueItemsAPI.IsObjectRandomized(playerData) then
		local rng = RNG()
		rng:SetSeed(ent.InitSeed, 35)
		data.UniqueItemsRandomIndex = rng:RandomInt(#playerData.ModData) + 1
	end
	local params = UniqueItemsAPI.GetObjectParams(objectID, player, objectType, false, ent)
	if not params then return end
	local sprite = ent:GetSprite()
	local originalAnm2 = sprite:GetFilename()

	if params.Anm2 then
		local animToPlay = sprite:GetAnimation() or sprite:GetDefaultAnimation()
		local frame = sprite:GetFrame()
		local isPlaying = sprite:IsPlaying(animToPlay)

		sprite:Load(params.Anm2, true)

		if not isPlaying then
			sprite:SetFrame(animToPlay, frame)
		else
			sprite:SetAnimation(animToPlay, true)
		end
	end

	if params.SpritePath then
		for layerID, spritePath in pairs(params.SpritePath) do
			sprite:ReplaceSpritesheet(layerID, spritePath)
		end
		sprite:LoadGraphics()
	end

	local entData = ent:GetData()
	entData.UniqueItemsAPISprite = {
		SelectedModIndex = playerData.SelectedModIndex,
		PlayerType = playerType,
		DefaultAnm2 = originalAnm2
	}
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, UniqueItemsAPI.OnObjectInit,
	PickupVariant.PICKUP_COLLECTIBLE)
UniqueItemsAPI:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, UniqueItemsAPI.OnObjectInit)
UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, UniqueItemsAPI.OnObjectInit)

---@param ent Entity
local function tryResetObjectSprite(ent)
	local data = ent:GetData()
	if data.UniqueItemsAPISprite then
		if ent.Type == EntityType.ENTITY_KNIFE then
			if (ent.Variant ~= 0 and ent.Variant ~= 5 and ent.Variant ~= 10 and ent.Variant ~= 11)
				and ent:GetEntityFlags() == 67108864
				and not UniqueItemsAPI.Game:IsPaused()
			then
				ent.Visible = false
				return
			end
		end
		local sprite = ent:GetSprite()
		local animToPlay = sprite:GetAnimation() or sprite:GetDefaultAnimation()
		local frame = sprite:GetFrame()
		local isPlaying = sprite:IsPlaying(animToPlay)

		sprite:Load(data.UniqueItemsAPISprite.DefaultAnm2, true)

		if not isPlaying then
			sprite:SetFrame(animToPlay, frame)
		else
			sprite:SetAnimation(animToPlay, true)
		end
	end
end

---@param ent Entity
function UniqueItemsAPI:UpdateObjectSprite(ent)
	if ent.Type == EntityType.ENTITY_PICKUP then
		local level = UniqueItemsAPI.Game:GetLevel()
		if level:GetCurses() == LevelCurse.CURSE_OF_BLIND or ent.SubType == CollectibleType.COLLECTIBLE_NULL then return end
	end
	
	local player = ent.Type == EntityType.ENTITY_PICKUP and UniqueItemsAPI.GetFirstAlivePlayer() or
	UniqueItemsAPI.TryGetPlayer(ent)
	if not player then return end
	local playerType = player:GetPlayerType()
	local data = ent:GetData()
	local objectID = ent.Type == EntityType.ENTITY_PICKUP and ent.SubType or ent.Variant
	local objectType = entTypeToItemType[ent.Type]
	local playerData = UniqueItemsAPI.GetObjectData(objectID, objectType, playerType)
	if not playerData or UniqueItemsAPI.IsObjectDisabled(playerData) then
		tryResetObjectSprite(ent)
		return
	end

	if data.UniqueItemsAPISprite
		and data.UniqueItemsAPISprite.PlayerType == playerType
		and data.UniqueItemsAPISprite.SelectedModIndex == playerData.SelectedModIndex
		and UniqueItemsAPI.Game:GetFrameCount() % 30 ~= 0
	then
		return
	end
	local params = UniqueItemsAPI.GetObjectParams(objectID, player, objectType, false, ent)
	if not params then
		tryResetObjectSprite(ent)
		return
	end

	tryResetObjectSprite(ent)
	UniqueItemsAPI:OnObjectInit(ent)
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, UniqueItemsAPI.UpdateObjectSprite,
	PickupVariant.PICKUP_COLLECTIBLE)
UniqueItemsAPI:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, UniqueItemsAPI.UpdateObjectSprite)
UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, UniqueItemsAPI.UpdateObjectSprite)

--#endregion
--#region Costumes

local itemConfig = UniqueItemsAPI.ItemConfig

---@param player EntityPlayer
---@param itemID CollectibleType
local function tryResetCostume(player, itemID)
	local data = player:GetData()
	local itemConfigItem = itemConfig:GetCollectible(itemID)
	if data.UniqueCostumeSprites and data.UniqueCostumeSprites[itemID] then
		player:AddCostume(itemConfigItem)
		data.UniqueCostumeSprites[itemID] = nil
	end
end

function UniqueItemsAPI:ReplaceItemCostume(player)
	for itemID, objectData in pairs(UniqueItemsAPI.ObjectData.Collectibles) do
		local playerType = player:GetPlayerType()
		local data = player:GetData()

		if not objectData.AllPlayers[playerType]
			or not player:HasCollectible(itemID)
			or (data.UniqueCostumeSprites
				and data.UniqueCostumeSprites[itemID] ~= nil
				and data.UniqueCostumeSprites[itemID].CollectibleNum == player:GetCollectibleNum(itemID)
				and data.UniqueCostumeSprites[itemID].PlayerType == playerType
			)
		then
			goto continue
		end

		local playerData = UniqueItemsAPI.GetObjectData(itemID, UniqueItemsAPI.ObjectType.COLLECTIBLE, playerType)
		if not playerData or UniqueItemsAPI.IsObjectDisabled(playerData) then
			tryResetCostume(player, itemID)
			goto continue
		end
		local params = UniqueItemsAPI.GetObjectParams(itemID, player, UniqueItemsAPI.ObjectType.COLLECTIBLE, false, player)
		if not params then
			tryResetCostume(player, itemID)
			goto continue
		end

		if params.CostumeSpritePath or params.NullCostume then
			if not data.UniqueCostumeSprites then
				data.UniqueCostumeSprites = {}
			end
			data.UniqueCostumeSprites[itemID] = {
				SelectedModIndex = playerData.SelectedModIndex,
				PlayerType = playerType,
				CollectibleNum = player:GetCollectibleNum(itemID)
			}
		else
			tryResetCostume(player, itemID)
			goto continue
		end

		if params.CostumeSpritePath ~= nil then
			local itemConfigItem = itemConfig:GetCollectible(itemID)
			local shouldAddCostume = itemConfigItem.Costume.ID ~= -1 and itemConfigItem.Type == ItemType.ITEM_ACTIVE and
				player:GetEffects():HasCollectibleEffect(itemID) or
				ItemConfig.Config.ShouldAddCostumeOnPickup(itemConfigItem)

			if shouldAddCostume then
				--We don't need to worry about other layers because...this function is bugged to replace all layers! Woo...
				player:ReplaceCostumeSprite(itemConfigItem, params.CostumeSpritePath, 0)
			end
		end
		if params.NullCostume ~= nil and player.FrameCount > 0 then
			player:AddNullCostume(params.NullCostume)
			data.UniqueCostumeSprites[itemID].NullCostume = params.NullCostume
		end
		::continue::
	end
end

---@param player EntityPlayer
function UniqueItemsAPI:ReplaceCollectibleOnItemQueue(player)
	local data = player:GetData()

	if player.QueuedItem.Item ~= nil then
		for itemID, _ in pairs(UniqueItemsAPI.ObjectData.Collectibles) do
			if player.QueuedItem.Item.ID ~= itemID
				or data.UniqueItemSpriteHeld
			then
				goto continue
			end
			local playerType = player:GetPlayerType()
			local playerData = UniqueItemsAPI.GetObjectData(itemID, UniqueItemsAPI.ObjectType.COLLECTIBLE, playerType)
			if not playerData then goto continue end
			local params = UniqueItemsAPI.GetObjectParams(itemID, player, UniqueItemsAPI.ObjectType.COLLECTIBLE, false, player)
			if params == nil then goto continue end
			local sprite = Sprite()

			sprite:Load("gfx/005.100_collectible.anm2", true)
			sprite:Play("PlayerPickupSparkle", true)

			for layerID, spritePath in pairs(params.SpritePath) do
				sprite:ReplaceSpritesheet(layerID, spritePath)
			end

			sprite:LoadGraphics()
			player:AnimatePickup(sprite, false, "Pickup")
			data.UniqueItemSpriteHeld = true
		end
		::continue::
	elseif player:IsItemQueueEmpty() and data.UniqueItemSpriteHeld then
		data.UniqueItemSpriteHeld = nil
	end
end

---@param player EntityPlayer
function UniqueItemsAPI:OnPeffectUpdate(player)
	UniqueItemsAPI:ReplaceItemCostume(player)
	UniqueItemsAPI:ReplaceCollectibleOnItemQueue(player)
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, UniqueItemsAPI.OnPeffectUpdate)

--#endregion
--#region Spirit Sword

---@param tear EntityTear
function UniqueItemsAPI:ReplaceSpiritSwordProjectileOnInit(tear)
	local parent = tear.SpawnerEntity and (tear.SpawnerEntity:ToPlayer() or tear.SpawnerEntity:ToFamiliar())
	if not parent then return end
	local knifeVariant = tear.Variant == TearVariant.SWORD_BEAM and 10 or 11
	local player = UniqueItemsAPI.TryGetPlayer(tear)
	if not player then return end
	local playerType = player:GetPlayerType()
	local playerData = UniqueItemsAPI.GetObjectData(knifeVariant, UniqueItemsAPI.ObjectType.KNIFE, playerType)
	if not playerData then return end
	local params = UniqueItemsAPI.GetObjectParams(knifeVariant, player, UniqueItemsAPI.ObjectType.KNIFE, false, tear)
	if not params then return end

	---@type Sprite
	local sprite = tear:GetSprite()
	if params.SwordProjectile and params.SwordProjectile.Beam then
		if string.find(params.SwordProjectile.Beam, ".anm2") then
			sprite:Load(params.SwordProjectile.Beam, true)
			sprite:Play(sprite:GetDefaultAnimation(), true)
		elseif string.find(params.SwordProjectile.Beam, ".png") then
			sprite:ReplaceSpritesheet(0, params.SwordProjectile.Beam)
			sprite:LoadGraphics()
		end
	end
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, UniqueItemsAPI.ReplaceSpiritSwordProjectileOnInit,
	TearVariant.SWORD_BEAM)
UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, UniqueItemsAPI.ReplaceSpiritSwordProjectileOnInit,
	TearVariant.TECH_SWORD_BEAM)

---@param tear EntityTear
function UniqueItemsAPI:ReplaceSwordSplashOnTearDeath(tear)
	if tear.Variant ~= TearVariant.SWORD_BEAM
		and tear.Variant ~= TearVariant.TECH_SWORD_BEAM
	then
		return
	end

	local function tryReplaceSplash(effect)
		local player = UniqueItemsAPI.TryGetPlayer(tear)
		if not player then return end
		local knifeVariant = tear.Variant == TearVariant.SWORD_BEAM and 10 or 11
		local playerType = player:GetPlayerType()
		local playerData = UniqueItemsAPI.GetObjectData(knifeVariant, UniqueItemsAPI.ObjectType.KNIFE, playerType)
		if not playerData then return end
		local params = UniqueItemsAPI.GetObjectParams(knifeVariant, player, UniqueItemsAPI.ObjectType.KNIFE, false, effect)
		if not params then return end
		local sprite = effect:GetSprite()

		if params.SwordProjectile and params.SwordProjectile.Splash then
			if string.sub(params.SwordProjectile.Splash, -5, -1) == ".anm2" then
				sprite:Load(params.SwordProjectile.Splash, true)
				sprite:Play(sprite:GetDefaultAnimation(), true)
			elseif string.sub(params.SwordProjectile.Splash, -4, -1) == ".png" then
				sprite:ReplaceSpritesheet(0, params.SwordProjectile.Splash)
				sprite:LoadGraphics()
			end
		end
	end

	local splashVariants = {
		EffectVariant.TEAR_POOF_A,
		EffectVariant.TEAR_POOF_B,
		EffectVariant.TEAR_POOF_SMALL,
		EffectVariant.TEAR_POOF_VERYSMALL,
		EffectVariant.BULLET_POOF --I can't believe this is actually used
	}
	for _, variant in pairs(splashVariants) do
		for _, effect in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, variant)) do
			if tear.Position:Distance(effect.Position) == 0 then
				tryReplaceSplash(effect)
			end
		end
	end
end

UniqueItemsAPI:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, UniqueItemsAPI.ReplaceSwordSplashOnTearDeath,
	EntityType.ENTITY_TEAR)

--#endregion
