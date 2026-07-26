--- XML Config Loader
--- This class is responsible for loading and saving user settings
---@class SettingsManager
---@field loadComplete boolean @Have we loaded the configuration?
---@field defaultConfig table @Default values for all settings
---@field loadedConfig table|nil @Loaded values for all settings
---@field modSettingsConfigFile string @Deprecated user configuration filename previously located in modSettings
---@field savegameConfigFile string @Savegame configuration file
---@field xmlSchema table @The configured XML schema
SettingsManager = {}
local XMLTAG = "upgradeYourFactory"
local MOD_NAME = g_currentModName or "FS25_UpgradeYourFactory"

SettingsManager.defaultConfig = {
    maxLevel = 15,
    sortByLevel = true,
}

-- Create a meta table to get basic Class-like behavior
local SettingsManager_mt = Class(SettingsManager)

---Creates the XML configuration manager object
---@return SettingsManager @The new object
function SettingsManager.new()
    local self = setmetatable({}, SettingsManager_mt)

    -- configuration files and loading states
    self.loadComplete = false
    self.loadedConfig = {}

    -- XML config files
    self.modSettingsConfigFile = "modSettings/UpgradeYourFactory.xml"
    self.savegameConfigFile = MOD_NAME .. ".xml"

    Logging.info(MOD_NAME .. ":MANAGER :: initialized")

    return self
end

---Loads the user's configuration file from either the savegame or modSettings file
function SettingsManager:restoreSettings()
    -- setup the XML schema
    self:initXmlSchema()

    Logging.info(MOD_NAME .. ":LOAD :: read user configurations")

    -- don't load it twice if the config is already loaded
    if self.loadComplete and self.loadedConfig then
        Logging.info(MOD_NAME .. ":LOAD :: exit early!")
        return self.loadedConfig
    end

    -- determine the proper path for the user's settings file
    local modSettingsFile = self:getModSettingsXmlFilePath()
    local savegameSettingsFile = self.getSavegameXmlFilePath()

    -- clients receive these settings from the server through Settings.lua
    if not g_currentMission:getIsServer() then
        Logging.info(MOD_NAME .. ":LOAD :: is client, using server settings")
        return
    end

    local settings = g_currentMission.uyf
    if settings == nil then
        Logging.warning(MOD_NAME .. ":LOAD :: Could not find Upgrade Your Factory settings in g_currentMission.uyf")
        return
    end

    -- Load the dedicated settings file when it exists. If it does not exist yet,
    -- keep the values already stored in g_currentMission.uyf. Those values may have
    -- been loaded from the original UpgradeYourFactory.xml file by loadXML().
    local loadedFromFile = false

    if savegameSettingsFile ~= nil and fileExists(savegameSettingsFile) then
        loadedFromFile = self:importConfig(savegameSettingsFile, settings)
        if loadedFromFile then
            Logging.info(MOD_NAME .. ":LOAD :: SAVEGAME configuration from: %s", savegameSettingsFile)
        end
    elseif modSettingsFile ~= nil and fileExists(modSettingsFile) then
        loadedFromFile = self:importConfig(modSettingsFile, settings)
        if loadedFromFile then
            Logging.info(MOD_NAME .. ":LOAD :: MODSETTINGS configuration from: %s", modSettingsFile)
        end
    end

    if not loadedFromFile then
        self:useDefaultConfig(settings)
        Logging.info(MOD_NAME .. ":LOAD :: existing/default configuration used")
    end

    Logging.info(MOD_NAME .. ":LOAD :: Loaded configuration:")
    SettingsManager.logSettings(settings, 1)

    -- make sure we don't load it twice
    self.loadedConfig = settings
    self.loadComplete = true

    Logging.info(MOD_NAME .. ":LOAD :: complete")

    return settings
end

---Initializes the XML file configuration schema
function SettingsManager:initXmlSchema()
    Logging.info(MOD_NAME .. ":LOAD :: init XML schema")

    self.xmlSchema = XMLSchema.new(XMLTAG)

    self.xmlSchema:register(XMLValueType.INT, XMLTAG .. ".settings.maxLevel", "maximum factory level", SettingsManager.defaultConfig.maxLevel)
    self.xmlSchema:register(XMLValueType.BOOL, XMLTAG .. ".settings.sortByLevel", "sort factories by level", SettingsManager.defaultConfig.sortByLevel)

    Logging.info(MOD_NAME .. ":LOAD :: init XML complete")
end

---Imports a specified XML configuration file
---@param xmlFilename string
---@param settingsObject table
function SettingsManager:importConfig(xmlFilename, settingsObject)
    local xmlFile = XMLFile.load("xmlFile", xmlFilename, self.xmlSchema)

    if xmlFile == nil or xmlFile == 0 then
        Logging.warning(MOD_NAME .. ":LOAD :: could not load file: %s", xmlFilename)
        return false
    end

    Logging.info(MOD_NAME .. ":LOAD :: loaded file: %s", xmlFilename)

    settingsObject.maxLevel = xmlFile:getValue(XMLTAG .. ".settings.maxLevel", SettingsManager.defaultConfig.maxLevel)
    settingsObject.sortByLevel = xmlFile:getValue(XMLTAG .. ".settings.sortByLevel", SettingsManager.defaultConfig.sortByLevel)

    -- maxLevel must match the limits and step used in SettingsUI.lua
    if settingsObject.maxLevel < 1 or settingsObject.maxLevel > 25 then
        Logging.info(MOD_NAME .. ":LOAD :: user configured maxLevel (%s) outside of limits, reset to default.", settingsObject.maxLevel)
        settingsObject.maxLevel = SettingsManager.defaultConfig.maxLevel
    end

    xmlFile:delete()
    return true
end

---Uses the default configuration values
---@param settingsObject table
function SettingsManager:useDefaultConfig(settingsObject)
    if settingsObject.maxLevel == nil then
        settingsObject.maxLevel = SettingsManager.defaultConfig.maxLevel
    end

    if settingsObject.sortByLevel == nil then
        settingsObject.sortByLevel = SettingsManager.defaultConfig.sortByLevel
    end
end

---Writes the settings to the savegame XML file
function SettingsManager:saveSettings()
    local xmlPath = self:getSavegameXmlFilePath()
    if xmlPath == nil then
        Logging.warning(MOD_NAME .. ":SAVE :: Could not save current settings.")
        return
    end

    local settings = g_currentMission.uyf
    if settings == nil then
        Logging.warning(MOD_NAME .. ":SAVE :: Could not find Upgrade Your Factory settings in g_currentMission.uyf")
        return
    end

    -- Create an empty XML file in memory
    local xmlFileId = createXMLFile("UpgradeYourFactory", xmlPath, XMLTAG)

    setXMLInt(xmlFileId, XMLTAG .. ".settings.maxLevel", settings.maxLevel)
    setXMLBool(xmlFileId, XMLTAG .. ".settings.sortByLevel", settings.sortByLevel)

    -- Write the XML file to disk
    saveXMLFile(xmlFileId)

    Logging.info(MOD_NAME .. ":SAVE :: saved config to savegame: %s", xmlPath)
end

---Builds a path to the XML file in modSettings.
---@return string|nil @The path to the XML file
function SettingsManager:getModSettingsXmlFilePath()
    return Utils.getFilename(self.modSettingsConfigFile, getUserProfileAppPath())
end

---Builds a path to the XML file in the current savegame.
---@return string|nil @The path to the XML file
function SettingsManager.getSavegameXmlFilePath()
    if g_currentMission and g_currentMission.missionInfo then
        local savegameDirectory = g_currentMission.missionInfo.savegameDirectory
        if savegameDirectory ~= nil then
            return ("%s/%s.xml"):format(savegameDirectory, MOD_NAME)
        end
        -- savegameDirectory is nil if this is a brand-new save
    else
        Logging.warning(MOD_NAME .. ":LOAD :: Could not get the XML settings path because g_currentMission.missionInfo is nil.")
    end

    return nil
end

---Sorts and prints the current settings to the log.
---@param t table
---@param indent number
function SettingsManager.logSettings(t, indent)
    local tkeys = {}
    for k in pairs(t) do
        table.insert(tkeys, k)
    end
    table.sort(tkeys)

    for _, k in ipairs(tkeys) do
        local value = t[k]
        local key = string.rep("   ", indent) .. tostring(k)

        if type(value) == "table" then
            Logging.info(key .. ":")
            SettingsManager.logSettings(value, indent + 1)
        else
            Logging.info(key .. " :: " .. tostring(value))
        end
    end
end
