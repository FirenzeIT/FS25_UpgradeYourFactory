SyncMaxLevelEvent = {}
local SyncMaxLevelEvent_mt = Class(SyncMaxLevelEvent, Event)

InitEventClass(SyncMaxLevelEvent, "SyncMaxLevelEvent")

function SyncMaxLevelEvent.emptyNew()
    return Event.new(SyncMaxLevelEvent_mt)
end

function SyncMaxLevelEvent.new(maxLevel)
    local self = SyncMaxLevelEvent.emptyNew()
    self.maxLevel = maxLevel or 15
    UYFInfo("SyncMaxLevelEvent :: new %s", self.maxLevel)

    self:initializeListeners()
    return self
end

function SyncMaxLevelEvent:readStream(streamId, connection)
    self.maxLevel = streamReadInt32(streamId)
    UYFInfo("SyncMaxLevelEvent :: readStream %s", self.maxLevel)

    if g_client ~= nil then
        if g_currentMission ~= nil and g_currentMission.uyf ~= nil then
            UYFInfo("SyncMaxLevelEvent :: overwriteMaxLevel %s", self.maxLevel)
            g_currentMission.uyf.maxLevel = self.maxLevel
        end
    end

    if g_server ~= nil then
        UYFInfo("SyncMaxLevelEvent :: broadcastEvent %s", self.maxLevel)
        g_server:broadcastEvent(SyncMaxLevelEvent.new(self.maxLevel), nil, connection)
    end
end

function SyncMaxLevelEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.maxLevel or 15)
    UYFInfo("SyncMaxLevelEvent :: writeStream %s", self.maxLevel)
end

function SyncMaxLevelEvent:initializeListeners()
    UYFInfo("SyncMaxLevelEvent :: initializeListeners")
    local syncMaxLevelEvent = self

    Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        syncMaxLevelEvent:readStream(streamId, connection)
    end)

    Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        syncMaxLevelEvent:writeStream(streamId, connection)
    end)
end