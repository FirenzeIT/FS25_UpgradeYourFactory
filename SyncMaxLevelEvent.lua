SyncMaxLevelEvent = {}
local SyncMaxLevelEvent_mt = Class(SyncMaxLevelEvent, Event)

InitEventClass(SyncMaxLevelEvent, "SyncMaxLevelEvent")

function SyncMaxLevelEvent.emptyNew()
    return Event.new(SyncMaxLevelEvent_mt)
end

function SyncMaxLevelEvent.new(maxLevel)
    local self = SyncMaxLevelEvent.emptyNew()
    self.maxLevel = maxLevel or 15
    -- UYFInfo("SyncMaxLevelEvent :: new %s", self.maxLevel)

    -- self:initializeListeners()
    return self
end

function SyncMaxLevelEvent:readStream(streamId, connection)
    self.maxLevel = streamReadInt32(streamId)

    -- UYFInfo("SyncMaxLevelEvent :: readStream %s", self.maxLevel)

    UpgradeYourFactory:updateMaxLevel(self.maxLevel)
end

function SyncMaxLevelEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.maxLevel or 15)
    -- UYFInfo("SyncMaxLevelEvent :: writeStream %s", self.maxLevel)
end

-- function SyncMaxLevelEvent:initializeListeners()
    -- UYFInfo("SyncMaxLevelEvent :: initializeListeners")
    -- local syncMaxLevelEvent = self

    -- Player.readStream = Utils.appendedFunction(Player.readStream, function(player, streamId, connection)
        -- syncMaxLevelEvent:readStream(streamId, connection)
    -- end)

    -- Player.writeStream = Utils.appendedFunction(Player.writeStream, function(player, streamId, connection)
        -- syncMaxLevelEvent:writeStream(streamId, connection)
    -- end)
-- end