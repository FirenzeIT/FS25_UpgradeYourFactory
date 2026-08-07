InGameMenuUpgradeYourFactory = {}

InGameMenuProductionFrame.UPDATE_INTERVAL = 1000

InGameMenuProductionFrame.Bypass = { "data/placeables/mapUS/playgroundMaker/playgroundMakerHall.xml", "data/placeables/mapUS/wagonBuilder/wagonBuilder.xml", "data/placeables/mapEU/pianoFactory/pianoFactory.xml" }

function InGameMenuUpgradeYourFactory:initialize()
    self.inGameMenu = g_currentMission.inGameMenu
    self.pageProduction = g_inGameMenu.pageProduction
    self.pageProduction.upgradeButtonInfo = {
        profile = "buttonOK",
        inputAction = InputAction.MENU_EXTRA_1,
        text = g_i18n:getText("uyf_upgrade"),
        callback = InGameMenuUpgradeYourFactory.onButtonUpgrade
    }
	
	self.pageProduction.downgradeButtonInfo = {
        profile = "buttonOK",
        inputAction = InputAction.MENU_EXTRA_2,
        text = g_i18n:getText("uyf_downgrade"),
        callback = InGameMenuUpgradeYourFactory.onButtonDowngrade
    }
	
    InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, InGameMenuUpgradeYourFactory.updateMenuButtons)
    InGameMenuProductionFrame.onListSelectionChanged = Utils.appendedFunction(InGameMenuProductionFrame.onListSelectionChanged, InGameMenuUpgradeYourFactory.onListSelectionChanged)
end

function InGameMenuUpgradeYourFactory:onButtonUpgrade()
    local _, prodpoint = self.pageProduction:getSelectedProduction()
	if prodpoint == nil or prodpoint.isUpgradable ~= true or prodpoint.productionLevel == nil or prodpoint.owningPlaceable == nil or prodpoint.owningPlaceable.upgradePrice == nil then
		return
	end
	local farmId = prodpoint.owningPlaceable:getOwnerFarmId()
    local money = g_farmManager:getFarmById(g_currentMission:getFarmId()):getBalance()

    local hasPermission = false
    if g_server ~= nil then
        hasPermission = true
    else
        local myFarmId = g_currentMission:getFarmId()
        if myFarmId ~= nil and myFarmId == farmId then
            hasPermission = g_currentMission:getHasPlayerPermission("manageProductions", nil, farmId)
        end
    end

    if not hasPermission then
		local dialog = g_gui:showDialog("InfoDialog")
		dialog.target:setText(g_i18n:getText("shop_messageNoPermissionGeneral"))
        return
    end

    if prodpoint.productionLevel >= (g_currentMission.uyf and g_currentMission.uyf.maxLevel or UpgradeYourFactory.MAX_LEVEL) then
        local dialog = g_gui:showDialog("InfoDialog")
		dialog.target:setText(g_i18n:getText("uyf_max_level"))
    elseif money >= prodpoint.owningPlaceable.upgradePrice then
        local text = string.format(
            g_i18n:getText("uyf_upgrade_dialog"),
            prodpoint.owningPlaceable:getName(),
            prodpoint.productionLevel+1,
            g_i18n:formatMoney(prodpoint.owningPlaceable.upgradePrice)
        )
		local args = {
		args = (prodpoint),
		callback = function(yes)
            if not yes then
                return
            end
			
			local farmId = prodpoint.owningPlaceable:getOwnerFarmId()
			
			UpgradeYourFactory:upgradeProduction(prodpoint)
			
			if self.pointsList and self.pointsList.reloadData then
				self.pointsList:reloadData()
			end
        end,
		-- info = g_i18n:getText(shop_messageNotEnoughMoneyToBuy)
		}
        local dialog = g_gui:showDialog("YesNoDialog")
        dialog.target:setText(text)
        dialog.target:setTitle(g_i18n:getText("uyf_upgrade_factory"))
        dialog.target:setCallback(args.callback, args.target, args.args)
    else
        local dialog = g_gui:showDialog("InfoDialog")
		dialog.target:setText(g_i18n:getText("shop_messageNotEnoughMoneyToBuy"))
    end
end

function InGameMenuUpgradeYourFactory:onButtonDowngrade()
    local _, prodpoint = self.pageProduction:getSelectedProduction()
	if prodpoint == nil or prodpoint.isUpgradable ~= true or prodpoint.productionLevel == nil or prodpoint.owningPlaceable == nil then
		return
	end
    local farmId = prodpoint.owningPlaceable:getOwnerFarmId()

    local hasPermission = false
    if g_server ~= nil then
        hasPermission = true
    else
        local myFarmId = g_currentMission:getFarmId()
        if myFarmId ~= nil and myFarmId == farmId then
            hasPermission = g_currentMission:getHasPlayerPermission("manageProductions", nil, farmId)
        end
    end

    if not hasPermission then
        local dialog = g_gui:showDialog("InfoDialog")
        dialog.target:setText(g_i18n:getText("shop_messageNoPermissionGeneral"))
        return
    end

    if prodpoint.productionLevel <= 1 then
        return
    end

    local text = string.format(
        g_i18n:getText("uyf_downgrade_dialog"),
        prodpoint.owningPlaceable:getName(),
        prodpoint.productionLevel - 1
    )

    local args = {
        args = prodpoint,
        callback = function(yes)
            if not yes then
                return
            end

            UpgradeYourFactory:downgradeProduction(prodpoint)

            if self.pointsList and self.pointsList.reloadData then
                self.pointsList:reloadData()
            end
        end
    }

    local dialog = g_gui:showDialog("YesNoDialog")
    dialog.target:setText(text)
    dialog.target:setTitle(g_i18n:getText("uyf_downgrade_factory"))
    dialog.target:setCallback(args.callback, args.target, args.args)
end

function InGameMenuUpgradeYourFactory.onListSelectionChanged(pageProduction, list, section, index)
    local prodpoints = pageProduction:getProductionPoints()
    if #prodpoints > 0 then
        local prodpoint = prodpoints[section]
		if prodpoint ~= nil then
			pageProduction.upgradeButtonInfo.disabled = not prodpoint.isUpgradable
			pageProduction.downgradeButtonInfo.disabled = not prodpoint.isUpgradable or prodpoint.productionLevel <= 1
		else
			pageProduction.upgradeButtonInfo.disabled = true
			pageProduction.downgradeButtonInfo.disabled = true
		end	
        pageProduction:setMenuButtonInfoDirty()
    end
end

function InGameMenuUpgradeYourFactory.updateMenuButtons(pageProduction)
    local _, prodpoint = pageProduction:getSelectedProduction()
    if prodpoint == nil or prodpoint.owningPlaceable == nil then
        return
    end
	
	if prodpoint.isUpgradable ~= true or prodpoint.productionLevel == nil or prodpoint.owningPlaceable.upgradePrice == nil then
		return
	end

    if prodpoint.owningPlaceable.xmlFile ~= nil then
        local xmlName = prodpoint.owningPlaceable.xmlFile.filename
        for _, path in ipairs(InGameMenuProductionFrame.Bypass) do
            if path == xmlName then
                return
            end
        end
    end

    local farmId = prodpoint.owningPlaceable:getOwnerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return
    end

    local hasPermission = false

    if g_server ~= nil then
        hasPermission = true
    else
        local myFarmId = g_currentMission:getFarmId()
        if myFarmId ~= nil and myFarmId == farmId then
            hasPermission = g_currentMission:getHasPlayerPermission("manageProductions", nil, farmId)
		end
    end
	
	if hasPermission and pageProduction.upgradeButtonInfo ~= nil then
		table.insert(pageProduction.menuButtonInfo, pageProduction.upgradeButtonInfo)
	end
	
	if hasPermission and pageProduction.downgradeButtonInfo ~= nil then
		table.insert(pageProduction.menuButtonInfo, pageProduction.downgradeButtonInfo)
	end
end

function InGameMenuUpgradeYourFactory.sortProductions()
    if g_currentMission == nil or g_currentMission.productionChainManager == nil then
        return
    end

    local pcm = g_currentMission.productionChainManager
    if pcm.productionPoints == nil then
        return
    end

    table.sort(pcm.productionPoints, function(a, b)
        local lvlA = a.productionLevel or 0
        local lvlB = b.productionLevel or 0

        if lvlA == lvlB then
            return (a.baseName or "") < (b.baseName or "")
        end
        return lvlA < lvlB
    end)
end

local originalShowPage = InGameMenuProductionFrame.onFrameOpen
function InGameMenuProductionFrame:onFrameOpen(...)
    InGameMenuUpgradeYourFactory.sortProductions()
    if originalShowPage ~= nil then
        originalShowPage(self, ...)
    end
end


