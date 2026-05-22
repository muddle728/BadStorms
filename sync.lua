local BadStorms = _G.BadStorms
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local _syncFields = {"exportData", "pendingTrades", "plusOnes", "softReserves", "softReservesCsv"}
local _syncInitialized = false
local _syncPrevious = {}

local function Encode(data)
    return LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(AceSerializer:Serialize(data)))
end

local function Decode(str)
    return AceSerializer:Deserialize(LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(str)))
end

function BadStorms.RefreshUIAfterSync(payload)
    local frame = BadStorms.configFrame
    if not frame then
        return
    end
    for _, name in pairs(_syncFields) do
        if payload[name] ~= nil then
            BadStormsSettings[name] = payload[name]
            _syncPrevious[name] = AceSerializer:Serialize(BadStormsSettings[name])
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
    AceComm:SendCommMessage("BadStorms", Encode(payload), BadStorms.GetChannel(), nil, "NORMAL")
end

function BadStorms.SyncToAll()

    if not BadStormsSettings.enabled then
        return
    end

    if not BadStorms.IsMasterLooter() then
        return
    end

    local currentPayload = BadStormsSettings.payload or {}
    local payload = {
        action = "sync",
        key = UnitName("player") .. "_" .. date("%Y%m%d"),
        version = currentPayload.version and (currentPayload.version + 1) or 0
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
    _syncInitialized = true

    if not send then
        return
    end

    BadStormsSettings.payload = payload

    AceComm:SendCommMessage("BadStorms", Encode(payload), BadStorms.GetChannel(), nil, "BULK")

end

AceComm:RegisterComm("BadStorms", function(prefix, payload, distribution, sender)
    if sender == UnitName("player") then
        return
    end

    local ok, rp = Decode(payload)
    if not ok or not rp then
        return
    end

    local currentPayload = BadStormsSettings.payload or {}

    if rp.action == "sync" then
        if currentPayload.key == rp.key and currentPayload.version and currentPayload.version > rp.version then
            local restorePayload = {
                action = "restore",
                key = currentPayload.key,
                version = currentPayload.version
            }
            for _, name in ipairs(_syncFields) do
                if BadStormsSettings[name] ~= nil then
                    restorePayload[name] = BadStormsSettings[name]
                end
            end
            AceComm:SendCommMessage("BadStorms", Encode(restorePayload), "WHISPER", sender)
            return
        end
        BadStorms.RefreshUIAfterSync(rp)
    elseif rp.action == "restore" then
        if currentPayload.key == rp.key and rp.version > (currentPayload.version or 0) then
            print("|cff00ff00BadStorms:|r Restoring data from " .. sender)
            BadStorms.RefreshUIAfterSync(rp)
        end
    end
end)

C_Timer.NewTicker(5, BadStorms.SyncToAll)
