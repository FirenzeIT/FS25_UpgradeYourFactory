SyncSortByLevelEvent = {}
local SyncSortByLevelEvent_mt = Class(SyncSortByLevelEvent, Event)

InitEventClass(SyncSortByLevelEvent, "SyncSortByLevelEvent")

function SyncSortByLevelEvent.emptyNew()
    return Event.new(SyncSortByLevelEvent_mt)
end

function SyncSortByLevelEvent.new(sortByLevel)
    local self = SyncSortByLevelEvent.emptyNew()
    self.sortByLevel = sortByLevel or true

    self:initializeListeners()

    UYFInfo("SyncSortByLevelEvent: new")
    return self
end

function SyncSortByLevelEvent:readStream(streamId, connection)
    self.sortByLevel = streamReadBool(streamId)

    UYFInfo("SyncSortByLevelEvent: readStream %s", self.sortByLevel)

    if g_client ~= nil then
        if g_currentMission ~= nil and g_currentMission.uyf ~= nil then
            UYFInfo("SyncSortByLevelEvent: overwriteSortByLevel %s", self.sortByLevel)
            g_currentMission.uyf.sortByLevel = self.sortByLevel
        end
    end

    if g_server ~= nil then
        UYFInfo("SyncSortByLevelEvent: broadcastEvent %s", self.sortByLevel)
        g_server:broadcastEvent(SyncSortByLevelEvent.new(self.sortByLevel), nil, connection)
    end
end

function SyncSortByLevelEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.sortByLevel)
    UYFInfo("SyncSortByLevelEvent: writeStream %s", self.sortByLevel)
end

function SyncSortByLevelEvent:initializeListeners()
    UYFInfo("SyncSortByLevelEvent :: initializeListeners")
    local sortByLevelEvent = self

    Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        sortByLevelEvent:readStream(streamId, connection)
    end)

    Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        sortByLevelEvent:writeStream(streamId, connection)
    end)
end