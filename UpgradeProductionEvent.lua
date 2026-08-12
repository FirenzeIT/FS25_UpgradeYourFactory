UpgradeProductionEvent = {}
local UpgradeProductionEvent_mt = Class(UpgradeProductionEvent, Event)

InitEventClass(UpgradeProductionEvent, "UpgradeProductionEvent")

function UpgradeProductionEvent.emptyNew()
    return Event.new(UpgradeProductionEvent_mt)
end

function UpgradeProductionEvent.new(prodpoint, newLevel, isDowngrade)
    local self = UpgradeProductionEvent.emptyNew()
    self.placeable = prodpoint.owningPlaceable
    self.farmId = prodpoint.owningPlaceable:getOwnerFarmId() or 0
    local x, y, z = getWorldTranslation(prodpoint.owningPlaceable.rootNode)
    self.posX = x
    self.posZ = z
    self.baseName = prodpoint.baseName or prodpoint:getName() or ""
    self.newLevel = newLevel
    self.isDowngrade = isDowngrade == true

    -- UYFInfo("UpgradeProductionEvent :: new '%s'", self.baseName)
    -- self:initializeListeners()

    return self
end

function UpgradeProductionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placeable)
    streamWriteInt8(streamId, self.farmId or 0)
    streamWriteFloat32(streamId, self.posX or 0)
    streamWriteFloat32(streamId, self.posZ or 0)
    streamWriteString(streamId, self.baseName or "")
    streamWriteInt8(streamId, self.newLevel or 1)
    streamWriteBool(streamId, self.isDowngrade == true)
    -- UYFInfo("UpgradeProductionEvent :: writeStream '%s'", self.baseName)
end

function UpgradeProductionEvent:readStream(streamId, connection)
    self.placeable = NetworkUtil.readNodeObject(streamId)
    self.farmId = streamReadInt8(streamId)
    self.posX = streamReadFloat32(streamId)
    self.posZ = streamReadFloat32(streamId)
    self.baseName = streamReadString(streamId)
    self.newLevel = streamReadInt8(streamId)
    self.isDowngrade = streamReadBool(streamId)

    -- UYFInfo("UpgradeProductionEvent :: readStream '%s'", self.baseName)
    self:run(connection)
end

function UpgradeProductionEvent:run(connection)
    if self.isDowngrade == true then
        self:runDowngrade(connection)
    else
        self:runUpgrade(connection)
    end
end

function UpgradeProductionEvent:runUpgrade(connection)
    local prodpoint = nil

    if self.placeable ~= nil then
        for _, pp in ipairs(g_currentMission.productionChainManager.productionPoints) do
            if pp.owningPlaceable == self.placeable then
                prodpoint = pp
                break
            end
        end
    end

    if prodpoint == nil then
        local eps2 = 0.5 * 0.5
        for _, pp in ipairs(g_currentMission.productionChainManager.productionPoints) do
            local op = pp.owningPlaceable
            if op ~= nil then
                local okFarm = true
                if self.farmId ~= nil and self.farmId ~= 0 then
                    okFarm = (op:getOwnerFarmId() == self.farmId)
                end

                if okFarm then
                    local wx, wy, wz = getWorldTranslation(op.rootNode)
                    local dx = (self.posX or 0) - wx
                    local dz = (self.posZ or 0) - wz
                    local dist2 = dx * dx + dz * dz
                    local nameMatch = true
                    if self.baseName ~= nil and self.baseName ~= "" and pp.baseName ~= nil then
                        nameMatch = (pp.baseName == self.baseName)
                    end

                    if nameMatch and dist2 <= eps2 then
                        prodpoint = pp
                        break
                    end
                end
            end
        end
    end

    if g_currentMission ~= nil and g_currentMission:getIsServer() then
		 if prodpoint == nil then
			return
		end
		
		local maxLevel = g_currentMission.uyf and g_currentMission.uyf.maxLevel or UpgradeYourFactory.MAX_LEVEL

		if prodpoint.productionLevel >= maxLevel then
			-- UYFInfo("UpgradeProductionEvent :: max level reached (%d/%d)", prodpoint.productionLevel, maxLevel)
			return
		end
		
		self.newLevel = prodpoint.productionLevel + 1
		
        local farmId = prodpoint.owningPlaceable:getOwnerFarmId()
        local price = prodpoint.owningPlaceable.upgradePrice or 0

        if price > 0 then
            g_currentMission:addMoney(-price, farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)
        end
    end

    if prodpoint ~= nil then
        local oldLevel = prodpoint.productionLevel or 0
        prodpoint.productionLevel = self.newLevel
        if UpgradeYourFactory and UpgradeYourFactory.adjProdPoint2lvl then
            UpgradeYourFactory:adjProdPoint2lvl(prodpoint, self.newLevel)
        end

        if g_gui ~= nil and g_inGameMenu ~= nil and g_inGameMenu.pageProduction ~= nil then
            local page = g_inGameMenu.pageProduction
            if page.pointsList ~= nil and page.pointsList.reloadData ~= nil then
                page.pointsList:reloadData()
            end
            page:setMenuButtonInfoDirty()
        end
    end

	if g_server ~= nil then
		g_server:broadcastEvent(self, false)
	end
    -- UYFInfo("UpgradeProductionEvent :: run complete")
end

function UpgradeProductionEvent:runDowngrade(connection)
    local prodpoint = nil

    if self.placeable ~= nil then
        for _, pp in ipairs(g_currentMission.productionChainManager.productionPoints) do
            if pp.owningPlaceable == self.placeable then
                prodpoint = pp
                break
            end
        end
    end

    if prodpoint == nil then
        local eps2 = 0.5 * 0.5
        for _, pp in ipairs(g_currentMission.productionChainManager.productionPoints) do
            local op = pp.owningPlaceable
            if op ~= nil then
                local okFarm = true
                if self.farmId ~= nil and self.farmId ~= 0 then
                    okFarm = (op:getOwnerFarmId() == self.farmId)
                end

                if okFarm then
                    local wx, wy, wz = getWorldTranslation(op.rootNode)
                    local dx = (self.posX or 0) - wx
                    local dz = (self.posZ or 0) - wz
                    local dist2 = dx * dx + dz * dz
                    local nameMatch = true
                    if self.baseName ~= nil and self.baseName ~= "" and pp.baseName ~= nil then
                        nameMatch = (pp.baseName == self.baseName)
                    end

                    if nameMatch and dist2 <= eps2 then
                        prodpoint = pp
                        break
                    end
                end
            end
        end
    end

    if g_currentMission ~= nil and g_currentMission:getIsServer() and prodpoint ~= nil then
		local farmId = prodpoint.owningPlaceable:getOwnerFarmId()
		local oldLevel = prodpoint.productionLevel or 0
		local basePrice = prodpoint.owningPlaceable.price or 0
		local price = math.floor(basePrice + basePrice * 0.1 * (oldLevel - 1))

		if price > 0 then
			g_currentMission:addMoney(price, farmId, MoneyType.SHOP_PROPERTY_BUY, true, true)
		end
	end

    if prodpoint ~= nil then
        local oldLevel = prodpoint.productionLevel or 0
        prodpoint.productionLevel = self.newLevel
        if UpgradeYourFactory and UpgradeYourFactory.adjProdPoint2lvl then
            UpgradeYourFactory:adjProdPoint2lvl(prodpoint, self.newLevel)
        end

        if g_gui ~= nil and g_inGameMenu ~= nil and g_inGameMenu.pageProduction ~= nil then
            local page = g_inGameMenu.pageProduction
            if page.pointsList ~= nil and page.pointsList.reloadData ~= nil then
                page.pointsList:reloadData()
            end
            page:setMenuButtonInfoDirty()
        end
    end

	if g_server ~= nil then
		g_server:broadcastEvent(self, false)
	end
    -- UYFInfo("UpgradeProductionEvent :: run complete")
end

function UpgradeProductionEvent:initializeListeners()
    -- UYFInfo("UpgradeProductionEvent :: initializeListeners")
    local settings = self

    Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        settings:readStream(streamId, connection)
    end)

    Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        settings:writeStream(streamId, connection)
    end)
end


-- Hook into basegame ProductionPoint.writeStream event.
local ProductionPoint_writeStream = ProductionPoint.writeStream
function ProductionPoint:writeStream(streamId, connection)
    ProductionPoint_writeStream(self, streamId, connection)
    streamWriteInt8(streamId, self.productionLevel or 0)
    -- UYFInfo("ProductionPoint :: writeStream '%s'", self.name)
end

-- Hook into basegame ProductionPoint.readStream event.
-- local ProductionPoint_readStream = ProductionPoint.readStream
-- function ProductionPoint:readStream(streamId, connection)
    -- ProductionPoint_readStream(self, streamId, connection)
    -- local lvl = streamReadInt8(streamId)
    -- UYFInfo("ProductionPoint :: readStream '%s' with level %d", self.name, lvl)

    -- -- addon for UpgradeYourFactory to adjust the productionPoint.
    -- if lvl ~= nil and lvl >= 1 then
        -- self.productionLevel = lvl
        -- if UpgradeYourFactory and UpgradeYourFactory.adjProdPoint2lvl then
            -- UpgradeYourFactory:adjProdPoint2lvl(self, lvl)
        -- end
    -- end
-- end

local ProductionPoint_readStream = ProductionPoint.readStream

function ProductionPoint:readStream(streamId, connection)
	ProductionPoint_readStream(self, streamId, connection)

	local lvl = streamReadInt8(streamId)

	-- UYFInfo("ProductionPoint :: readStream '%s' with level %d", tostring(self.name), lvl)

	if lvl ~= nil and lvl >= 1 then
		if self.isUpgradable == nil and UpgradeYourFactory ~= nil and UpgradeYourFactory.initializeProduction ~= nil then
			UpgradeYourFactory:initializeProduction(self)
		end

		if self.isUpgradable == true then
			self.productionLevel = lvl

			if UpgradeYourFactory.adjProdPoint2lvl ~= nil then
				UpgradeYourFactory:adjProdPoint2lvl(self, lvl)
			end
		end
	end
end