---@class Settings
---This class stores settings for the Upgrade Your Factory mod
Settings = {}
local Settings_mt = Class(Settings)
local MOD_NAME = g_currentModName or "FS25_UpgradeYourFactory"
---Creates a new settings instance
---@return table @The new instance
function Settings.new()
    local self = setmetatable({}, Settings_mt)

    -- set via in-game menu
    self.maxLevel = SettingsManager.defaultConfig.maxLevel
    self.sortByLevel = SettingsManager.defaultConfig.sortByLevel

    self:initializeListeners()

    -- Logging.info(MOD_NAME .. ":SETTINGS :: initialized")
    return self
end

---Stores the setting into the local object
---@param settingName string @The name of the setting, in dot notation for nested settings
---@param settingParent string|nil @The name of the parent of the setting, in dot notation for nested settings
function Settings:onSettingsChange(settingName, settingParent)
    local name = self:cleanSettingName(settingName, settingParent)
    local newValue = self:getSetting(settingName, settingParent)

    self:publishNewSettings()
end

---Retrieves the stored setting by name
---@param settingName string @The name of the setting
---@param settingParent string|nil @The name of the parent of the setting
---@return number|boolean @The current value of the requested setting
function Settings:getSetting(settingName, settingParent)
    local name = self:cleanSettingName(settingName, settingParent)
    local newValue

    if settingParent then
        newValue = self[settingParent][name]
    else
        newValue = self[name]
    end

    return newValue
end

---Retrieves all settings at once
---@return table @The current index
function Settings:getSettings()
    return self
end

---Cleans the setting name. Kept in the same structure as the original Settings.lua.
---@param settingName string @The name of the setting
---@param settingParent string|nil @The name of the parent of the setting
---@return string @The cleaned setting name
function Settings:cleanSettingName(settingName, settingParent)
    local name = settingName

    return name
end

---Publishes new settings in case of multiplayer
function Settings:publishNewSettings()
    if g_server ~= nil then
        -- Broadcast to other clients, if any are connected
        g_server:broadcastEvent(SyncMaxLevelEvent.new(self.maxLevel), true)
        g_server:broadcastEvent(SyncSortByLevelEvent.new(self.sortByLevel), true)
    else
        -- Ask the server to broadcast the event
        g_client:getServerConnection():sendEvent(SyncMaxLevelEvent.new(self.maxLevel))
        g_client:getServerConnection():sendEvent(SyncSortByLevelEvent.new(self.sortByLevel))
    end
end

---Receives the initial settings from the server when joining a multiplayer game
---@param streamId any @The ID of the stream to read from
---@param connection any @Unused
function Settings:onReadStream(streamId, connection)
    -- set via in-game menu
    self.maxLevel = streamReadInt16(streamId)
    self.sortByLevel = streamReadBool(streamId)

    if g_currentMission ~= nil and g_currentMission.uyf ~= nil then
        g_currentMission.uyf.maxLevel = self.maxLevel
        g_currentMission.uyf.sortByLevel = self.sortByLevel
    end

    -- Logging.info(MOD_NAME .. ":SETTINGS :: Completed receiving new settings", streamId)
end

---Sends the current settings to a client which is connecting to a multiplayer game
---@param streamId any @The ID of the stream to write to
---@param connection any @Unused
function Settings:onWriteStream(streamId, connection)
    if g_currentMission ~= nil and g_currentMission.uyf ~= nil then
        self.maxLevel = g_currentMission.uyf.maxLevel
        self.sortByLevel = g_currentMission.uyf.sortByLevel
    end

    -- set via in-game menu
    streamWriteInt16(streamId, self.maxLevel)
    streamWriteBool(streamId, self.sortByLevel)

    -- Logging.info(MOD_NAME .. ":SETTINGS :: Completed sending new settings", streamId)
end

---Registers read/write listeners
function Settings:initializeListeners()
    local settings = self

    Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        settings:onReadStream(streamId, connection)
    end)

    Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        settings:onWriteStream(streamId, connection)
    end)
end
