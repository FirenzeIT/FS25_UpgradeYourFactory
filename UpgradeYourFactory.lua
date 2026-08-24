local modDirectory = g_currentModDirectory
local modName = g_currentModName
local xmlFilename = nil

UpgradeYourFactory = UpgradeYourFactory or {}
UpgradeYourFactory.MAX_LEVEL = UpgradeYourFactory.MAX_LEVEL or 15
UpgradeYourFactory.SORT_BY_LEVEL = UpgradeYourFactory.SORT_BY_LEVEL or true

source(modDirectory .. "SyncMaxLevelEvent.lua")
source(modDirectory .. "SyncSortByLevelEvent.lua")
source(modDirectory .. "UpgradeProductionEvent.lua")
source(modDirectory .. "InGameMenuUpgradeYourFactory.lua")
source(modDirectory .. "Settings.lua")
source(modDirectory .. "SettingsUI.lua")
source(modDirectory .. "lib/UIHelper.lua")
addModEventListener(UpgradeYourFactory)

function UYFInfo(infoMessage, ...)
	print(string.format("  UpgradeYourFactory: " .. infoMessage, ...))
end

---Hooks into the ModEventListener:loadMap() function
function UpgradeYourFactory:loadMap()
	self.newSavegame = not g_currentMission.missionInfo.savegameDirectory or nil
	self.loadedProductions = {}

	g_currentMission.uyf = g_currentMission.uyf or {}
	g_currentMission.uyf.maxLevel = self.MAX_LEVEL
	g_currentMission.uyf.sortByLevel = self.SORT_BY_LEVEL

	self.settingsUI = SettingsUI.new()
	self.settingsUI:injectUiSettings(g_currentMission.uyf)

	InGameMenuUpgradeYourFactory:initialize()

	if not self.newSavegame then
		xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/UpgradeYourFactory.xml"
	end
	self:loadXML()
	
	if g_server ~= nil then
        addConsoleCommand("uyfMaxLevel", "Update UpgradeYourFactory max level", "updateMaxLevel", self)
		addConsoleCommand("uyfToggleSortByLevel", "Toggle UpgradeYourFactory sort by level setting", "updateSortByLevel", self)
    end
	g_messageCenter:subscribe(MessageType.SAVEGAME_LOADED, self.onSavegameLoaded, self)
end

---Hooks into the ModEventListener:delete() function
function UpgradeYourFactory:delete()
	g_messageCenter:unsubscribeAll(self)
end

---Hooks into the ModEventListener:onSavegameLoaded() function
function UpgradeYourFactory:onSavegameLoaded()
	UpgradeYourFactory.onFinalizePlacement()
    self:initializeLoadedProductions()
	-- UYFInfo("Global MaxLevel currently set to: "..self.MAX_LEVEL)
end

---Local helper function to get the production point based on it's placeable position on the map
local function getProductionPointFromPosition(pos)
	if g_currentMission.productionChainManager.farmIds == nil then
		return nil
	end
	
	for _, farmData in pairs(g_currentMission.productionChainManager.farmIds) do
		for _,prod in ipairs(farmData.productionPoints) do
			local x, y, z = getWorldTranslation(prod.owningPlaceable.rootNode)
			if MathUtil.getPointPointDistanceSquared(pos.x, pos.z, x, z) < 0.0001 then
				return prod
			end
		end
	end
	return nil
end

---Strorage capacity increase by it's base value each level
local function getCapacityAtLvl(capacity, lvl)
	return math.floor(capacity * lvl)
end

---Production speed increase by it's base value each level.
---A bonus of 15% of the base speed is applied per level starting at the level 2
local function getCycleAtLvl(cycle, lvl)
	lvl = tonumber(lvl)
	local adj = cycle * lvl + cycle * 0.15 * (lvl - 1)
	if adj < 1 then
		return adj
	else
		return math.floor(adj)
	end
end

---Running cost increase by it's base value each level
---A reduction of 10% of the base cost is applied par level starting at the level 2
local function getActiveCostAtLvl(cost, lvl)
	lvl = tonumber(lvl)
	local adj = cost * lvl - cost * 0.1 * (lvl - 1)
	if adj < 1 then
		return adj
	else
		return math.floor(adj)
	end
end

---Discharge speed to match each level
---A reduction of 10% of the base discharge speed is applied par level starting at the level 2
local function getDischargeSpeedAtLvl(speed, lvl)
	lvl = tonumber(lvl)
	local newSpeed = speed * lvl - speed * 0.1 * (lvl - 1)
	return newSpeed
end

---Upgrade price increase by 10% each level
local function getUpgradePriceAtLvl(basePrice, lvl)
	return math.floor(basePrice + basePrice * 0.1 * lvl)
end

---Base price + all upgrade prices
local function getOverallProductionValue(basePrice, lvl)
	local value = 0
	for l=2, lvl do
		value = value + getUpgradePriceAtLvl(basePrice, l-1)
	end
	return basePrice + value
end

---Format the poduction point with the current level ie: 3 - Bakery or Bakery [Lv:3]
local function prodPointNameWithLevel(basename, level, prodpoint, sortByLevel)
    if prodpoint == nil or prodpoint.owningPlaceable == nil then
        return basename
    end

    local farmId = prodpoint.owningPlaceable:getOwnerFarmId() or 0

    if g_server ~= nil or (farmId > 0 and farmId ~= FarmManager.SPECTATOR_FARM_ID) then
		if sortByLevel then
			return string.format("%d - %s", level, basename)
		else
			return string.format("%s [Lv:%d]", basename, level)
		end
    end

    return basename
end

---Update the production point based on the chosen level
function UpgradeYourFactory:adjProdPoint2lvl(prodpoint, lvl)
	-- UYFInfo("Adjust Production Point '%s' to level %d.", prodpoint.name, lvl)

	-- update the name with the level
	prodpoint.name = prodPointNameWithLevel(prodpoint.baseName, lvl, prodpoint, self.SORT_BY_LEVEL)

	-- update cycles based on the level
    for _,prod in ipairs(prodpoint.productions) do
        prod.cyclesPerMinute = getCycleAtLvl(prod.baseCyclesPerMinute, lvl)
        prod.cyclesPerHour = getCycleAtLvl(prod.baseCyclesPerHour, lvl)
        prod.cyclesPerMonth = getCycleAtLvl(prod.baseCyclesPerMonth, lvl)

        prod.costsPerActiveMinute = getActiveCostAtLvl(prod.baseCostsPerActiveMinute, lvl)
        prod.costsPerActiveHour = getActiveCostAtLvl(prod.baseCostsPerActiveHour, lvl)
        prod.costsPerActiveMonth = getActiveCostAtLvl(prod.baseCostsPerActiveMonth, lvl)
    end

	-- update the storage capacities based on the level
	for ft,baseCapacity in pairs(prodpoint.storage.baseCapacities) do
		prodpoint.storage.capacities[ft] = getCapacityAtLvl(baseCapacity, lvl)
	end

	-- update the storage capacities based on the level
	if prodpoint.loadingStation ~= nil then
		for lt,loadingTrigger in pairs(prodpoint.loadingStation.loadTriggers) do
			local oldFillLitersPerMS
			if not loadingTrigger.oldFillLitersPerMS then
				oldFillLitersPerMS = loadingTrigger.fillLitersPerMS
				prodpoint.loadingStation.loadTriggers[lt].oldFillLitersPerMS = oldFillLitersPerMS
			else
				oldFillLitersPerMS = loadingTrigger.oldFillLitersPerMS
			end

			local newFillLitersPerMS = getDischargeSpeedAtLvl(oldFillLitersPerMS, lvl)
			prodpoint.loadingStation.loadTriggers[lt].fillLitersPerMS = newFillLitersPerMS
			-- if oldFillLitersPerMS ~= newFillLitersPerMS then
				-- UYFInfo("Updated loadingStation discharge speed for '%s' to %d liters/second.",prodpoint.name, (newFillLitersPerMS*1000) )
			-- end
		end
	end

	-- update the prices to match the upgraded level
    prodpoint.owningPlaceable.totalValue = getOverallProductionValue(prodpoint.owningPlaceable.price, lvl)
    prodpoint.owningPlaceable.upgradePrice = getUpgradePriceAtLvl(prodpoint.owningPlaceable.price, lvl)
    prodpoint.owningPlaceable.getSellPrice = function ()
        local priceMultiplier = 0.75
        local maxAge = prodpoint.owningPlaceable.storeItem.lifetime
        if maxAge ~= nil and maxAge ~= 0 then
            priceMultiplier = priceMultiplier * math.exp(-3.5 * math.min(prodpoint.owningPlaceable.age / maxAge, 1))
        end
        return math.floor(prodpoint.owningPlaceable.totalValue * math.max(priceMultiplier, 0.05))
    end
end

---Initialize all the loaded productions, gets called during the loadMap() phase
function UpgradeYourFactory:initializeLoadedProductions()
	-- UYFInfo("initializeLoadedProductions %d", #self.loadedProductions)
	if self.newSavegame or #self.loadedProductions < 1 then
		return
	end

	local isMP = g_currentMission.missionDynamicInfo.isMultiplayer
	local forcedFarmId = 1

	for _, loadedProd in ipairs(self.loadedProductions) do
		local prodpoint = getProductionPointFromPosition(loadedProd.position)
		if prodpoint ~= nil then
			local placeable = prodpoint.owningPlaceable
			local currentFarmId = placeable:getOwnerFarmId()

			if not isMP and currentFarmId ~= 1 then
				placeable:setOwnerFarmId(forcedFarmId)
				currentFarmId = forcedFarmId
			end

			if (isMP and currentFarmId == loadedProd.farmId) or (not isMP and currentFarmId == 1) then
				if prodpoint.isUpgradable then
					prodpoint.productionLevel = loadedProd.level
					-- adjust the prodction point to the latest level
					self:adjProdPoint2lvl(prodpoint, loadedProd.level)

					-- alwawys use this function to set the fillLevels - the new loadedProd.fillLevels CANNOT be set into the prodpoint directly.
					self:setFillLevelsFromConfig(prodpoint, loadedProd.fillLevels)
				end
			end
		end
	end
end

function UpgradeYourFactory:initializeProduction(prodpoint)
	if not prodpoint.isUpgradable then
		if (prodpoint.owningPlaceable.price or 0) <= 1 and prodpoint.owningPlaceable.storeItem ~= nil and prodpoint.owningPlaceable.storeItem.price > 1 then
			prodpoint.owningPlaceable.price = prodpoint.owningPlaceable.storeItem.price
		end

		if (prodpoint.owningPlaceable.price or 0) <= 1 then
			prodpoint.isUpgradable = false
			-- UYFInfo("Production Point '%s' has no valid price and cannot be upgraded.", prodpoint:getName())
			return
		end
		
		prodpoint.isUpgradable = true
		prodpoint.productionLevel = 1

		prodpoint.baseName = prodpoint:getName()
		prodpoint.name = prodPointNameWithLevel(prodpoint.baseName, 1, prodpoint, self.SORT_BY_LEVEL)
		prodpoint.owningPlaceable.upgradePrice = getUpgradePriceAtLvl(prodpoint.owningPlaceable.price, 1)
		prodpoint.owningPlaceable.totalValue = prodpoint.owningPlaceable.price

		for _,prod in ipairs(prodpoint.productions) do
			prod.baseCyclesPerMinute = prod.cyclesPerMinute
			prod.baseCyclesPerHour = prod.cyclesPerHour
			prod.baseCyclesPerMonth = prod.cyclesPerMonth
			prod.baseCostsPerActiveMinute = prod.costsPerActiveMinute
			prod.baseCostsPerActiveHour = prod.costsPerActiveHour
			prod.baseCostsPerActiveMonth = prod.costsPerActiveMonth
		end

		-- store the baseCapacities for later
		prodpoint.storage.baseCapacities = {}
		for ft,val in pairs(prodpoint.storage.capacities) do
			prodpoint.storage.baseCapacities[ft] = val
		end

		local farmId = prodpoint.owningPlaceable:getOwnerFarmId() or 0
		if farmId > 0 and farmId ~= FarmManager.SPECTATOR_FARM_ID then
			UpgradeYourFactory:adjProdPoint2lvl(prodpoint, 1)
		else
			prodpoint.name = prodpoint.baseName
		end
	end
end

---Initialize a specific production, called in a loop
function UpgradeYourFactory:setFillLevelsFromConfig(prodpoint, fillLevels)
	if prodpoint.isUpgradable then
		prodpoint.storage.fillLevels = {}
		for ft,capacity in pairs(prodpoint.storage.capacities) do
			local fillTypeName = g_fillTypeManager:getFillTypeByIndex(ft).name
			prodpoint.storage.fillLevels[ft] = fillLevels[fillTypeName] or 0
		end
	end
end

---Hook into the finalize placement, which is called when the player places a new production
function UpgradeYourFactory.onFinalizePlacement()
	for _, prodpoint in ipairs(g_currentMission.productionChainManager.productionPoints) do
		if prodpoint.isUpgradable == nil or prodpoint.productionLevel == nil or prodpoint.productionLevel < 1 then
			UpgradeYourFactory:initializeProduction(prodpoint)
		end
	end
end

---Hooks into a player purchasing an existing production, adjusting the production to work with the new system
function UpgradeYourFactory.setOwnerFarmId(prodpoint, farmId)
    if prodpoint == nil or prodpoint.productions == nil then
        return
    end

    if farmId == 0 then
        if prodpoint.productions[1].baseCyclesPerMinute then
            prodpoint.productionLevel = 1
            UpgradeYourFactory:adjProdPoint2lvl(prodpoint, 1)
        end
        return
    end

    if farmId > 0 and prodpoint.isUpgradable then
        local lvl = prodpoint.productionLevel or 1
        prodpoint.name = string.format("%d - %s", lvl, prodpoint.baseName)
    end
end

---Console command to set the max level
function UpgradeYourFactory:updateMaxLevel(arg)
	if not arg then
		print("uyfMaxLevel <max_level>")
		return
	end
	
	local newLevel = tonumber(arg)
	if not newLevel then
		print("uyfMaxLevel <max_level>")
		print("<max_level> must be a number")
		return
	elseif newLevel < 1 or newLevel > 99 then
		print("uyfMaxLevel <max_level>")
		print("<max_level> must be between 1 and 99")
		return
	end
	
	-- set the max level into local var
	self.MAX_LEVEL = newLevel
	if g_currentMission and g_currentMission.uyf then
		g_currentMission.uyf.maxLevel = newLevel
	end

	-- re-initialize the loaded productions based on the current max level
	-- self:forceMaxLevel()
	
	UYFInfo("Global MaxLevel updated to: %d", newLevel)
	
	if g_server ~= nil then
		g_server:broadcastEvent(SyncMaxLevelEvent.new(newLevel), true)
	end	
end

---Console command to set the max level
function UpgradeYourFactory:updateSortByLevel(arg)
	local newValue = type(arg) == "boolean" and arg or not self.SORT_BY_LEVEL
	
	-- set the max level into local var
	self.SORT_BY_LEVEL = newValue

	if g_currentMission and g_currentMission.uyf then
		g_currentMission.uyf.sortByLevel = newValue
	end

	-- re-initialize the loaded productions based on the current max level
	for _, prodpoint in ipairs(g_currentMission.productionChainManager.productionPoints) do
		if prodpoint.isUpgradable ~= nil and prodpoint.productionLevel ~= nil then
			prodpoint.name = prodPointNameWithLevel(prodpoint.baseName, prodpoint.productionLevel, prodpoint, newValue)
		end
	end

	UYFInfo("Sorting by level has been turned %s", newValue and "on" or "off")

	if g_server ~= nil then
		g_server:broadcastEvent(SyncSortByLevelEvent.new(newValue), true)
	end	
end

function UpgradeYourFactory.saveToXML()
	-- on a new save, create xmlFile path
	if g_currentMission.missionInfo.savegameDirectory then
		xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/UpgradeYourFactory.xml"
	end

	local xmlFile = XMLFile.create("UpgradeYourFactoryXML", xmlFilename, "UpgradeYourFactory")
	xmlFile:setInt("UpgradeYourFactory#maxLevel", UpgradeYourFactory.MAX_LEVEL)
	xmlFile:setBool("UpgradeYourFactory#sortByLevel", UpgradeYourFactory.SORT_BY_LEVEL)

	-- check if player has owned production installed
	if g_currentMission.productionChainManager.farmIds ~= nil then
		local pCounter = 0
		local skipped = 0

		for farmId, farmData in pairs(g_currentMission.productionChainManager.farmIds) do
			local farm = g_farmManager:getFarmById(farmId)
			if farm == nil then
				skipped = skipped + 1
			else
				for _, prodpoint in ipairs(farmData.productionPoints) do
					if prodpoint.isUpgradable then
						local key = string.format("UpgradeYourFactory.production(%d)", pCounter)
						xmlFile:setInt(key .. "#farmId", prodpoint.owningPlaceable:getOwnerFarmId() or 0)
						xmlFile:setInt(key .. "#level", prodpoint.productionLevel)

						local key2 = key .. ".position"

						local x, y, z = getWorldTranslation(prodpoint.owningPlaceable.rootNode)
						xmlFile:setFloat(key2 .. "#x", x)
						xmlFile:setFloat(key2 .. "#y", y)
						xmlFile:setFloat(key2 .. "#z", z)

						local fCounter = 0
						key2 = ""
						for fillTypeIndex,fillLevel in pairs(prodpoint.storage.fillLevels) do
							local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
							if ft ~= nil then
								key2 = key .. string.format(".fillLevels.fillLevel(%d)", fCounter)
								xmlFile:setString(key2 .. "#fillType", string.upper(ft.name))
								xmlFile:setInt(key2 .. "#storage", fillLevel)
								fCounter = fCounter + 1
							end	
						end
						pCounter = pCounter + 1
					end
				end
			end
		end
	end
	xmlFile:save()
end

function UpgradeYourFactory:loadXML()
	if self.newSavegame then
		-- UYFInfo('loadXML :: exit due to newSavegame')
		return
	end

	local xmlFile = XMLFile.loadIfExists("UpgradeYourFactoryXML", xmlFilename)
	
	if not xmlFile then
		return
	end
	-- if not xmlFile then
		-- UYFInfo('loadXML :: no xmlFile to load')
		-- SyncMaxLevelEvent.new()
		-- SyncSortByLevelEvent.new()
		-- return
	-- end

	local productionCounter = 0
	while true do
		local key = string.format("UpgradeYourFactory.production(%d)", productionCounter)
		local level = getXMLInt(xmlFile.handle,key .. "#level")
		if level == nil then
			break
		end

		local loadedFillLevels = {}
		local fillLevelCounter = 0
		while true do
			-- old values
			local oldKey = key .. string.format(".fillLevels.fillType(%d)", fillLevelCounter)
			local oldFillTypeName = getXMLString(xmlFile.handle, oldKey .. "#fillType")
			local oldFillTypeId = getXMLInt(xmlFile.handle, oldKey .. "#id")
			local oldFillLevel = getXMLInt(xmlFile.handle, oldKey .. "#fillLevel", 0)

			-- new values
			local newKey = key .. string.format(".fillLevels.fillLevel(%d)", fillLevelCounter)
			local newFillTypeName = getXMLString(xmlFile.handle, newKey .. "#fillType")
			local newStorage = getXMLInt(xmlFile.handle, newKey .. "#storage", 0)

			local fillLevel
			local fillTypeName
			if newFillTypeName == nil and oldFillTypeId == nil then
				break
			elseif newFillTypeName ~= nil then
				-- new file save structure
				fillTypeName = newFillTypeName
				fillLevel = newStorage
			elseif oldFillTypeId ~= nil then
				fillTypeName = oldFillTypeName
				fillLevel = oldFillLevel
			end

			if fillTypeName ~= nil then
				loadedFillLevels[fillTypeName] = fillLevel
			end

			-- counter loop for fillLevels
			fillLevelCounter = fillLevelCounter + 1
		end

		-- insert once we have all the related data
		table.insert(
			self.loadedProductions,
			{
				level = level,
				farmId = getXMLInt(xmlFile.handle, key .. "#farmId") or 0,
				position = {
					x = getXMLFloat(xmlFile.handle, key .. ".position#x"),
					y = getXMLFloat(xmlFile.handle, key .. ".position#y"),
					z = getXMLFloat(xmlFile.handle, key .. ".position#z")
				},
				fillLevels = loadedFillLevels
			}
		)

		-- counter loop for productions
		productionCounter = productionCounter + 1
	end

	local maxLevel = getXMLInt(xmlFile.handle, "UpgradeYourFactory#maxLevel")
	if maxLevel and maxLevel > 0 and maxLevel < 100 then
		self.MAX_LEVEL = maxLevel
		g_currentMission.uyf.maxLevel = maxLevel
	end

	local sortByLevel = getXMLBool(xmlFile.handle, "UpgradeYourFactory#sortByLevel")
	if sortByLevel ~= nil then
		self.SORT_BY_LEVEL = sortByLevel
		g_currentMission.uyf.sortByLevel = sortByLevel
	end

	if g_server ~= nil then
		g_server:broadcastEvent(SyncMaxLevelEvent.new(g_currentMission.uyf.maxLevel), true)
		g_server:broadcastEvent(SyncSortByLevelEvent.new(g_currentMission.uyf.sortByLevel), true)
	end

	-- UYFInfo('loadXML :: maxLevel: %d', g_currentMission.uyf.maxLevel)
	-- UYFInfo('loadXML :: sortByLevel: %s', g_currentMission.uyf.sortByLevel and "on" or "off")
	-- UYFInfo('loadXML :: loadedProductions: %d', #self.loadedProductions)
end

function UpgradeYourFactory:upgradeProduction(prodpoint)
    if prodpoint == nil or prodpoint.owningPlaceable == nil then
        return
    end

    local newLevel = prodpoint.productionLevel + 1
    local event = UpgradeProductionEvent.new(prodpoint, newLevel)

    if g_server ~= nil then
        g_server:broadcastEvent(event, true)
    else
        g_client:getServerConnection():sendEvent(event)
    end
end

function UpgradeYourFactory:downgradeProduction(prodpoint)
    if prodpoint == nil or prodpoint.owningPlaceable == nil then
        return
    end

    if prodpoint.productionLevel <= 1 then
        return
    end

    local newLevel = prodpoint.productionLevel - 1
    local event = UpgradeProductionEvent.new(prodpoint, newLevel, true)

    if g_server ~= nil then
        g_server:broadcastEvent(event, true)
    else
        g_client:getServerConnection():sendEvent(event)
    end
end

---Creates a settings object which can be accessed from the UI and the rest of the code
---@param   mission     table   @The object which is later available as g_currentMission
local function createModSettings(mission)
    -- Register the settings object globally so we can access it from the event class and others later
    mission.uyfSettings = Settings.new()
    addModEventListener(mission.uyfSettings)
end
Mission00.load = Utils.prependedFunction(Mission00.load, createModSettings)

PlaceableProductionPoint.onFinalizePlacement = Utils.appendedFunction(PlaceableProductionPoint.onFinalizePlacement, UpgradeYourFactory.onFinalizePlacement)
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, UpgradeYourFactory.saveToXML)
ProductionPoint.setOwnerFarmId = Utils.appendedFunction(ProductionPoint.setOwnerFarmId, UpgradeYourFactory.setOwnerFarmId)

