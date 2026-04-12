local modDirectory = g_currentModDirectory
local modName = g_currentModName
local xmlFilename = nil

UpgradeYourFactory = {
	MAX_LEVEL = 15
}

source(modDirectory .. "InGameMenuUpgradeYourFactory.lua")
addModEventListener(UpgradeYourFactory)

function UFInfo(infoMessage, ...)
	print(string.format("  UpgradeYourFactory: " .. infoMessage, ...))
end

---Hooks into the ModEventListener:loadMap() function
function UpgradeYourFactory:loadMap()
	self.newSavegame = not g_currentMission.missionInfo.savegameDirectory or nil
	self.loadedProductions = {}

	InGameMenuUpgradeYourFactory:initialize()

	if not self.newSavegame then
		xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/UpgradeYourFactory.xml"
	end
	self:loadXML()

	addConsoleCommand('uyfMaxLevel', 'Update UpgradeYourFactory max level', 'updateml', self)
	g_messageCenter:subscribe(MessageType.SAVEGAME_LOADED, self.onSavegameLoaded, self)
end

---Hooks into the ModEventListener:delete() function
function UpgradeYourFactory:delete()
	g_messageCenter:unsubscribeAll(self)
end

---Hooks into the ModEventListener:onSavegameLoaded() function
function UpgradeYourFactory:onSavegameLoaded()
	self:initializeLoadedProductions()
end

---Local helper function to get the production point based on it's placeable position on the map
local function getProductionPointFromPosition(pos)
	if #g_currentMission.productionChainManager.farmIds < 1 then
		return nil
	end

	for _,prod in ipairs(g_currentMission.productionChainManager.farmIds[1].productionPoints) do
		local x, y, z = getWorldTranslation(prod.owningPlaceable.rootNode)
		if MathUtil.getPointPointDistanceSquared(pos.x, pos.z, x, z) < 0.0001 then
			return prod
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

---Format the poduction point with the current level ie: 3 - Bakery
local function prodPointUFName(basename, level)
	return string.format("%d - %s", level, basename)
end

---Update the production point based on the chosen level
function UpgradeYourFactory:adjProdPoint2lvl(prodpoint, lvl)
	-- update the name
	prodpoint.name = prodPointUFName(prodpoint.baseName, lvl)

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
			local oldFillSpeedPerMS = loadingTrigger.fillLitersPerMS
			local newFillSpeedPerMS = getDischargeSpeedAtLvl(loadingTrigger.fillLitersPerMS, lvl)
			prodpoint.loadingStation.loadTriggers[lt].fillLitersPerMS = newFillSpeedPerMS
			printf('-- UpgradeYourFactory :: loadTrigger speed updated from %s to %s', oldFillSpeedPerMS, newFillSpeedPerMS)
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
	if self.newSavegame or #self.loadedProductions < 1 then
		return
	end

	for _,loadedProd in ipairs(self.loadedProductions) do
		local prodpoint = getProductionPointFromPosition(loadedProd.position)
		if prodpoint then
			if prodpoint.isUpgradable then
				prodpoint.productionLevel = loadedProd.level
				-- prodpoint.owningPlaceable.price = loadedProd.basePrice
				prodpoint.owningPlaceable.totalValue = getOverallProductionValue(prodpoint.owningPlaceable.price, loadedProd.level)

				-- adjust the production based on level
				self:adjProdPoint2lvl(prodpoint, loadedProd.level)

				-- overwrite the savegame capacities with our stored capacities
				self:setFillLevelsFromConfig(prodpoint, loadedProd.fillLevels)
			end
		end
	end
end

---Initialize a specific production, called in a loop
function UpgradeYourFactory:initializeProduction(prodpoint)
	if not prodpoint.isUpgradable then
		prodpoint.isUpgradable = true
		prodpoint.productionLevel = 1

		prodpoint.baseName = prodpoint:getName()
		prodpoint.name = prodPointUFName(prodpoint:getName(), 1)

		-- prodpoint.owningPlaceable.basePrice = prodpoint.owningPlaceable.price
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
	end
end

---Initialize a specific production, called in a loop
function UpgradeYourFactory:setFillLevelsFromConfig(prodpoint, fillLevels)
	if prodpoint.isUpgradable then

		-- print('-- UpgradeYourFactory:adjProdPoint2lvl :: prodpoint.storage.fillLevels')
		-- DebugUtil.printTableRecursively(prodpoint.storage.fillLevels, nil, nil, 2)

		-- print('-- UpgradeYourFactory:adjProdPoint2lvl :: fillLevels')
		-- DebugUtil.printTableRecursively(fillLevels, nil, nil, 2)

		prodpoint.storage.fillLevels = {}
		for ft,capacity in pairs(prodpoint.storage.capacities) do
			local fillTypeName = g_fillTypeManager:getFillTypeByIndex(ft).name
			prodpoint.storage.fillLevels[ft] = fillLevels[fillTypeName] or 0
		end
	end
end

---Hook into the finalize placement, which is called when the player places a new production
function UpgradeYourFactory.onFinalizePlacement()
	for _,prodpoint in ipairs(g_currentMission.productionChainManager.productionPoints) do
		if not prodpoint.productionLevel then
			UpgradeYourFactory:initializeProduction(prodpoint)
		end
	end
end

---Hooks into a player purchasing an existing production, adjusting the production to work with the new system
function UpgradeYourFactory.setOwnerFarmId(prodpoint, farmId)
	if farmId == 0 and prodpoint.productions[1].baseCyclesPerMinute then
		prodpoint.productionLevel = 1
		UpgradeYourFactory:adjProdPoint2lvl(prodpoint, 1)
	end
end

---Console command to set the max level
function UpgradeYourFactory:updateml(arg)
	if not arg then
		print("uyfMaxLevel <max_level>")
		return
	end

	local n = tonumber(arg)
	if not n then
		print("uyfMaxLevel <max_level>")
		print("<max_level> must be a number")
		return
	elseif n < 1 or n > 99 then
		print("uyfMaxLevel <max_level>")
		print("<max_level> must be between 1 and 99")
		return
	end

	-- set the max level into local var
	self.MAX_LEVEL = n

	-- re-initialize the loaded productions based on the current max level
	self:forceMaxLevel()

	UFInfo("Production maximum level has been updated to level "..n, "")
end

---Handle if the loaded productions are somehow over the maxLevel
function UpgradeYourFactory:forceMaxLevel()
	if #self.loadedProductions > 0 then
		for _,p in ipairs(self.loadedProductions) do
			if p.level > self.MAX_LEVEL then
				p.level = self.MAX_LEVEL
			end
		end
	end
end

function UpgradeYourFactory.saveToXML()
	-- on a new save, create xmlFile path
	if g_currentMission.missionInfo.savegameDirectory then
		xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/UpgradeYourFactory.xml"
	end

	local xmlFile = XMLFile.create("UpgradeYourFactoryXML", xmlFilename, "UpgradeYourFactory")
	xmlFile:setInt("UpgradeYourFactory#maxLevel", UpgradeYourFactory.MAX_LEVEL)

	-- check if player has owned production installed
	if #g_currentMission.productionChainManager.farmIds > 0 then	
		local prodpoints = g_currentMission.productionChainManager.farmIds[1].productionPoints
		local pCounter = 0
		for _,prodpoint in ipairs(prodpoints) do
			if prodpoint.isUpgradable then
				local key = string.format("UpgradeYourFactory.production(%d)", pCounter)
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

						printf('-- UpgradeYourFactory:saveXML :: name:%s fillType:%s level:%d', prodpoint.name, string.upper(ft.name), fillLevel )

						key2 = key .. string.format(".fillLevels.fillLevel(%d)", fCounter)
						xmlFile:setString(key2 .. "#fillType", string.upper(ft.name))
						xmlFile:setInt(key2 .. "#storage", fillLevel)
						fCounter = fCounter + 1
					end
				end
				pCounter = pCounter+1
			end
		end
	end
	xmlFile:save()
end

function UpgradeYourFactory:loadXML()

	if self.newSavegame then
		print('-- UpgradeYourFactory:loadXML :: self.newSavegame')
		return
	end

	local xmlFile = XMLFile.loadIfExists("UpgradeYourFactoryXML", xmlFilename)
	if not xmlFile then
		print('-- UpgradeYourFactory:loadXML :: not xmlFile')
		return
	end

	local productionCounter = 0
	while true do
		local key = string.format("UpgradeYourFactory.production(%d)", productionCounter)

		local level = getXMLInt(xmlFile.handle, key .. "#level")
		if level == nil then
			break
		end

		-- determine the capacities
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
				-- old file save structure
				fillTypeName = oldFillTypeName
				fillLevel = oldFillLevel
			end

			if fillTypeName ~= nil then
				loadedFillLevels[fillTypeName] = fillLevel
			end

			-- counter loop for fillLevels
			fillLevelCounter = fillLevelCounter +1
		end

		-- insert once we have all the related data
		table.insert(
			self.loadedProductions,
			{
				level = level,
				position = {
					x = getXMLFloat(xmlFile.handle, key .. ".position#x"),
					y = getXMLFloat(xmlFile.handle, key .. ".position#y"),
					z = getXMLFloat(xmlFile.handle, key .. ".position#z")
				},
				fillLevels = loadedFillLevels
			}
		)

		-- counter loop for productions
		productionCounter = productionCounter +1
	end

	local maxLevel = getXMLInt(xmlFile.handle, "UpgradeYourFactory#maxLevel")
	if maxLevel and maxLevel > 0 and maxLevel < 100 then
		self.MAX_LEVEL = maxLevel
	end

	print('-- UpgradeYourFactory:loadXML :: self.loadedProductions')
    DebugUtil.printTableRecursively(self.loadedProductions)
end

PlaceableProductionPoint.onFinalizePlacement = Utils.appendedFunction(PlaceableProductionPoint.onFinalizePlacement, UpgradeYourFactory.onFinalizePlacement)
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, UpgradeYourFactory.saveToXML)
ProductionPoint.setOwnerFarmId = Utils.appendedFunction(ProductionPoint.setOwnerFarmId, UpgradeYourFactory.setOwnerFarmId)