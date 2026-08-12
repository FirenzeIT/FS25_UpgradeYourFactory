--- SettingsUI
-- @author Timmeey86, GMNGjoy
-- @copyright 12/16/2024
-- @contact https://github.com/GMNGjoy/FS25_ContractBoost
-- @license CC0 1.0 Universal
---This class is responsible for adding UI settings and mapping them to the existing settings variables
---@class SettingsUI
---@field sectionTitle table @The UI control which displays the section title
---@field controls table @A list of UI controls
---@field loadedConfig table @A reference to the loaded configuration object
---@field debugMode boolean @Determined if the component should emit data to the log
---@field maxLevel number @A UI control
---@field sortByLevel boolean @A UI control

SettingsUI = {}

-- Create a meta table to get basic Class-like behavior
local SettingsUI_mt = Class(SettingsUI)
local MOD_NAME = g_currentModName or "FS25_UpgradeYourFactory"

---Creates the settings UI object
---@return SettingsUI @The new object
function SettingsUI.new()
    local self = setmetatable({}, SettingsUI_mt)

    self.controls = {}
    self.loadedConfig = nil
    self.isInitialized = false

    return self
end

---Injects the UI controls into the general settings menu
---@param loadedConfig table @The loaded config
function SettingsUI:injectUiSettings(loadedConfig)
    if g_dedicatedServer then
        return
    end

    -- Remember the settings object
    self.loadedConfig = loadedConfig

    if self.isInitialized then
        return
    end
    self.isInitialized = true

    -- Get a reference to the base game general settings page
    local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings

    -- Define the UI controls. For bool values, supply just the name, for ranges, supply min, max and step, and for choices, supply a values table
    -- For every name, a <prefix>_<name>_long and _short text must exist in the l10n files
    -- The _short text will be the title of the setting, the _long" text will be its tool tip
    -- For each control, a on_<name>_changed callback will be called on change
    local controlProperties = {
        { name = "maxLevel", min = 1, max = 25, step = 1, autoBind = true },
        { name = "sortByLevel", autoBind = true },
    }

    UIHelper.createControlsDynamically(settingsPage, "UpgradeYourFactory", self, controlProperties, "uyf_")
    UIHelper.setupAutoBindControls(self, self.loadedConfig, SettingsUI.onSettingsChange)

    -- Apply initial values
    self:updateUiElements()

    -- Update any additional settings whenever the frame gets opened
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        self:updateUiElements(true) -- We can skip autobind controls here since they are already registered to onFrameOpen
    end)
    -- Logging.info(MOD_NAME .. ':SETTINGSUI UI Injected')
end

function SettingsUI:onSettingsChange(control)
    self:updateUiElements()

    -- UIHelper wcześniej zapisał już poprawną wartość number/boolean.
    local newValue = g_currentMission.uyf[control.name]

    -- Logging.info(
        -- MOD_NAME .. ':SETTINGSUI Update Setting: %s = %s',
        -- control.name,
        -- tostring(newValue)
    -- )

    if control.name == 'maxLevel' then
		if g_server ~= nil then
			UpgradeYourFactory:updateMaxLevel(newValue)
		elseif g_client ~= nil then
			g_client:getServerConnection():sendEvent(SyncMaxLevelEvent.new(newValue))
		end

	elseif control.name == 'sortByLevel' then
		if g_server ~= nil then
			UpgradeYourFactory:updateSortByLevel(newValue)
		elseif g_client ~= nil then
			g_client:getServerConnection():sendEvent(SyncSortByLevelEvent.new(newValue))
		end
	end
end

---Updates the UI elements to reflect the current settings
---@param skipAutoBindControls boolean|nil @True if controls with the autoBind properties shall not be newly populated
function SettingsUI:updateUiElements(skipAutoBindControls)

    -- Note: This method is created dynamically by UIHelper.setupAutoBindControls
    self.populateAutoBindControls()

    -- disable the values if not the admin
    local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
	for _, control in ipairs(self.controls) do
        if not control.disabled then
		    control:setDisabled(not isAdmin)
        end
	end

    -- Update the focus manager
    local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
    settingsPage.generalSettingsLayout:invalidateLayout()
end