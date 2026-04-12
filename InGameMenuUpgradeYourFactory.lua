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

    InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, InGameMenuUpgradeYourFactory.updateMenuButtons)
    InGameMenuProductionFrame.onListSelectionChanged = Utils.appendedFunction(InGameMenuProductionFrame.onListSelectionChanged, InGameMenuUpgradeYourFactory.onListSelectionChanged)
end

function InGameMenuUpgradeYourFactory:onButtonUpgrade()
    local _, prodpoint = self.pageProduction:getSelectedProduction()
    local money = g_farmManager:getFarmById(g_currentMission:getFarmId()):getBalance()

    if prodpoint.productionLevel >= UpgradeYourFactory.MAX_LEVEL then
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

            g_currentMission:addMoney(-prodpoint.owningPlaceable.upgradePrice, 1, MoneyType.SHOP_PROPERTY_BUY, true, true)
        
			prodpoint.productionLevel = prodpoint.productionLevel + 1
			UpgradeYourFactory:adjProdPoint2lvl(prodpoint, prodpoint.productionLevel)
			
			self.pointsList:reloadData()
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

function InGameMenuUpgradeYourFactory.onListSelectionChanged(pageProduction, list, section, index)
    local prodpoints = pageProduction:getProductionPoints()
    if #prodpoints > 0 then
        local prodpoint = prodpoints[section]
		if prodpoint ~= nil then
			pageProduction.upgradeButtonInfo.disabled = not prodpoint.isUpgradable
		else
			pageProduction.upgradeButtonInfo.disabled = true
		end	
        pageProduction:setMenuButtonInfoDirty()
    end
end

function InGameMenuUpgradeYourFactory.updateMenuButtons(pageProduction)
    local _, prodpoint = pageProduction:getSelectedProduction()

    local isBypass = false
    if prodpoint ~= nil and prodpoint.owningPlaceable ~= nil and prodpoint.owningPlaceable.xmlFile ~= nil then
        local xmlName = prodpoint.owningPlaceable.xmlFile.filename
        for _, path in ipairs(InGameMenuProductionFrame.Bypass) do
            if path == xmlName then
                isBypass = true
                break
            end
        end
    end

    if isBypass or prodpoint == nil or prodpoint.owningPlaceable == nil then
        return
    end

    if prodpoint.owningPlaceable.getOwnerFarmId ~= nil then
        if g_currentMission:getFarmId() ~= prodpoint.owningPlaceable:getOwnerFarmId() then
            return
        end
    else
        return
    end

    if pageProduction.upgradeButtonInfo ~= nil then
        table.insert(pageProduction.menuButtonInfo, pageProduction.upgradeButtonInfo)
    end
end