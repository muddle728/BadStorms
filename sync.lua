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
    _syncPaused = false
end

function BadStorms.SyncRecoverData()
    local payload = {
        action = "ping"
    }
    AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(payload), BadStorms.GetChannel(), nil, "NORMAL")
end

function BadStorms.SyncToAll()

    if BadStormsSettings.enabled then
        return
    end

    if not BadStorms.IsMasterLooter() or not BadStormsSettings.raidSyncEnabled then
        return
    end

    if _syncPaused then
        print("|cff00ff00BadStorms:|r Sync paused to restore data.")
        return
    end

    local send = (not _syncInitialized) or false -- force send the first request

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
        if BadStormsSettings.payload.key == rp.key and BadStormsSettings.payload.version > rp.version then
            local restorePayload = {
                action = "restore",
                key = BadStormsSettings.payload.key,
                version = BadStormsSettings.payload.version
            }
            for _, name in ipairs(_syncFields) do
                if BadStormsSettings[name] ~= nill then
                    restorePayload[name] = BadStormsSettings[name]
                end
            end
            AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(restorePayload), "WHISPER", sender)
            return
        end
        BadStorms.RefreshUIAfterSync(rp)
    elseif rp.action == "restore" then
        if BadStormsSettings.payload.key == rp.key and rp.version > BadStormsSettings.payload.version then
            print("|cff00ff00BadStorms:|r Restoring data from " .. sender)
            _syncPaused = true
            BadStorms.RefreshUIAfterSync(rp)
        end
    end
end)

C_Timer.NewTicker(5, BadStorms.SyncToAll)
