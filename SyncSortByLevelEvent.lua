SyncSortByLevelEvent = {}
local SyncSortByLevelEvent_mt = Class(SyncSortByLevelEvent, Event)

InitEventClass(SyncSortByLevelEvent, "SyncSortByLevelEvent")

function SyncSortByLevelEvent.emptyNew()
    return Event.new(SyncSortByLevelEvent_mt)
end

function SyncSortByLevelEvent.new(sortByLevel)
    local self = SyncSortByLevelEvent.emptyNew()
    if sortByLevel == nil then
        sortByLevel = true
    end
	
	self.sortByLevel = sortByLevel
    -- self:initializeListeners()

    -- UYFInfo("SyncSortByLevelEvent: new")
    return self
end

function SyncSortByLevelEvent:readStream(streamId, connection)
    self.sortByLevel = streamReadBool(streamId)

    -- UYFInfo("SyncSortByLevelEvent: readStream %s", self.sortByLevel)

    UpgradeYourFactory:updateSortByLevel(self.sortByLevel)
end

function SyncSortByLevelEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.sortByLevel)
    -- UYFInfo("SyncSortByLevelEvent: writeStream %s", self.sortByLevel)
end

-- function SyncSortByLevelEvent:initializeListeners()
    -- UYFInfo("SyncSortByLevelEvent :: initializeListeners")
    -- local sortByLevelEvent = self

    -- Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        -- sortByLevelEvent:readStream(streamId, connection)
    -- end)

    -- Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        -- sortByLevelEvent:writeStream(streamId, connection)
    -- end)
-- end