local BadStorms = _G.BadStorms
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate", true)

local _syncFields = {"exportData", "pendingTrades", "plusOnes", "softReserves", "softReservesCsv"}
local _syncInitialized = false
local _syncPaused = false
local _syncPrevious = {}

function BadStorms.RefreshUIAfterSync(payload)
    local frame = BadStorms.configFrame
    if not frame then
        return
    end
    for _, name in pairs(_syncFields) do
        if payload[name] ~= nil then
            BadStormsSettings[name] = payload[name]
        end
    end
    if payload["plusOnes"] ~= nil then
        frame.PopulatePlusOnesList()
    end
    if payload["softReserves"] ~= nil or payload["softReservesCsv"] then
        frame.PopulateSRList()
    end
    if payload["exportData"] ~= nil then
        frame.PopulateExportList()
    end
    BadStormsSettings.payload = payload
end

function BadStorms.SyncRecoverData()
    local payload = {
        action = "ping"
    }
    AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(payload), BadStorms.GetChannel(), nil, "NORMAL")
end

function BadStorms.SyncToAll()
    if not BadStorms.IsMasterLooter() or not BadStormsSettings.raidSyncEnabled then
        return
    end

    if _syncPaused then
        print("|cff00ff00BadStorms:|r Sync currently paused to restore data.")
    end

    if not _syncInitialized then
        for _, name in ipairs(_syncFields) do
            _syncPrevious[name] = AceSerializer:Serialize(BadStormsSettings[name] or {})
        end
        _syncInitialized = true
    end

    local payload = {
        action = "sync",
        key = UnitName("player") .. "_" .. date("%Y%m%d"),
        version = BadStormsSettings.payload.version and (BadStormsSettings.payload.version + 1) or 0
    }

    local send = false

    for _, name in ipairs(_syncFields) do
        local serialized = AceSerializer:Serialize(BadStormsSettings[name] or {})
        if _syncPrevious[name] ~= serialized then
            _syncPrevious[name] = serialized
            payload[name] = BadStormsSettings[name]
            send = true
        end
    end

    if not send then
        return
    end

    BadStormsSettings.payload = payload

    AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(payload), BadStorms.GetChannel(), nil, "BULK")

end

AceComm:RegisterComm("BadStorms", function(prefix, payload, distribution, sender)
    if sender == UnitName("player") then
        return
    end

    local ok, rp = AceSerializer:Deserialize(payload)
    if not ok or not rp then
        return
    end

    if rp.action == "sync" then
        if BadStormsSettings.payload.key == rp.key then
            if BadStormsSettings.payload.version >= rp.version then
                BadStormsSettings.payload.action = "restore"
                AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(BadStormsSettings.payload), "WHISPER",
                    sender)
                BadStormsSettings.payload.action = "sync"
            end
        end
        BadStorms.RefreshUIAfterSync(rp)
    elseif rp.action == "restore" then
        if BadStormsSettings.payload.key == rp.key then
            print("|cff00ff00BadStorms:|r Restoring data from " .. sender)
            BadStorms.RefreshUIAfterSync(rp)
            _syncPaused = false
        end
    end
end)

C_Timer.NewTicker(15, BadStorms.SyncToAll)
