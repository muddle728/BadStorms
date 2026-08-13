local BadStorms = _G.BadStorms
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local _syncFields = {"exportData", "pendingTrades", "plusOnes", "softReserves", "softReservesCsv"}
local _lastPushedByKey = {}

local function Encode(data)
    return LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(AceSerializer:Serialize(data)))
end

local function Decode(str)
    return AceSerializer:Deserialize(LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(str)))
end

function BadStorms.GetLatestHistoryEntry(key)
    local history = BadStormsSettings.syncHistory or {}
    local best
    for _, entry in ipairs(history) do
        if entry.key == key and entry.version then
            if not best or entry.version > best.version then
                best = entry
            end
        end
    end
    if best then
        local ok, decoded = Decode(best.compressed)
        if ok and decoded then
            return decoded
        end
    end
    return nil
end

function BadStorms.PushToHistory(payload)
    local parts = {}
    for _, name in ipairs(_syncFields) do
        local v = payload[name]
        parts[#parts + 1] = v ~= nil and AceSerializer:Serialize(v) or ""
    end
    local serialized = table.concat(parts, "|")
    local key = payload.key or ""
    if _lastPushedByKey[key] == serialized then
        return false
    end
    _lastPushedByKey[key] = serialized
    if payload.version == nil then
        local current = BadStorms.GetLatestHistoryEntry(key) or {}
        payload.version = (current.version or -1) + 1
    end

    local history = BadStormsSettings.syncHistory or {}
    table.insert(history, 1, {
        compressed = Encode(payload),
        timestamp = time(),
        key = payload.key,
        version = payload.version
    })
    for i = 51, #history do
        history[i] = nil
    end
    BadStormsSettings.syncHistory = history
    local frame = BadStorms.configFrame
    if frame and frame.PopulateSyncHistoryList and frame.syncHistoryPanel and frame.syncHistoryPanel:IsVisible() then
        frame.PopulateSyncHistoryList()
    end
    return true
end

function BadStorms.RestoreFromHistory(entry)
    local ok, payload = Decode(entry.compressed)
    if not ok or not payload then
        print("|cff00ff00BadStorms:|r Failed to decode history entry.")
        return
    end
    BadStorms.RefreshUIAfterSync(payload)
    BadStorms.SyncToAll()
    print("|cff00ff00BadStorms:|r Restored from version " .. (payload.version or "?") .. " (" .. (payload.key or "unknown") .. ")")
end

function BadStorms.DecodeHistoryEntry(entry)
    if not entry or not entry.compressed then return nil end
    local ok, decoded = Decode(entry.compressed)
    if not ok then return nil end
    return decoded
end

function BadStorms.GetHistoryList()
    return BadStormsSettings.syncHistory or {}
end

function BadStorms.RefreshUIAfterSync(payload)
    local frame = BadStorms.configFrame
    if not frame then
        return
    end
    for _, name in pairs(_syncFields) do
        if payload[name] ~= nil then
            if name == "exportData" then
                BadStormsSettings.exportData = BadStormsSettings.exportData or {}
                for exportDate, entries in pairs(payload[name]) do
                    BadStormsSettings.exportData[exportDate] = entries
                end
            else
                BadStormsSettings[name] = payload[name]
            end
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

    local myKey = UnitName("player") .. "_" .. date("%Y%m%d")
    local currentPayload = BadStorms.GetLatestHistoryEntry(myKey) or {}
    local today = date("%Y-%m-%d")

    local payload = {
        action = "sync",
        key = myKey,
        plusOnes = BadStormsSettings.plusOnes or {},
        pendingTrades = BadStormsSettings.pendingTrades or {},
        softReserves = BadStormsSettings.softReserves or {},
        softReservesCsv = BadStormsSettings.softReservesCsv or "",
        exportData = { [today] = (BadStormsSettings.exportData or {})[today] or {} }
    }

    BadStorms.PushToHistory(payload)
    
    if payload.version == nil then
        payload.version = currentPayload.version or 0
    end

    local encoded = Encode(payload)
    if encoded then
        AceComm:SendCommMessage("BadStorms", encoded, BadStorms.GetChannel(), nil, "BULK")
    end

end

function BadStorms.SyncPlusOnes()
    if not BadStormsSettings.enabled then
        return
    end
    if not BadStorms.IsMasterLooter() then
        return
    end
    local payload = {
        action = "sync",
        plusOnes = BadStormsSettings.plusOnes
    }
    AceComm:SendCommMessage("BadStorms", Encode(payload), BadStorms.GetChannel(), nil, "ALERT")
end

function BadStorms.SyncSoftReserves()
    if not BadStormsSettings.enabled then
        return
    end
    if not BadStorms.IsMasterLooter() then
        return
    end
    local payload = {
        action = "sync",
        softReserves = BadStormsSettings.softReserves or {},
        softReservesCsv = BadStormsSettings.softReservesCsv or ""
    }
    AceComm:SendCommMessage("BadStorms", Encode(payload), BadStorms.GetChannel(), nil, "ALERT")
end

AceComm:RegisterComm("BadStorms", function(prefix, payload, distribution, sender)
    if sender == UnitName("player") then
        return
    end

    if UnitAffectingCombat("player") then
        return
    end

    local ok, _, rp = pcall(Decode, payload)
    if not ok or type(rp) ~= "table" then
        return
    end

    local currentPayload = BadStorms.GetLatestHistoryEntry(rp.key) or {}

    if rp.action == "sync" then
        if rp.version and currentPayload.key == rp.key and currentPayload.version and currentPayload.version > rp.version then
            local restorePayload = {
                action = "restore",
                key = currentPayload.key,
                version = currentPayload.version
            }
            for _, name in ipairs(_syncFields) do
                if BadStormsSettings[name] ~= nil then
                    if name == "exportData" then
                        local today = date("%Y-%m-%d")
                        local bucket = (BadStormsSettings.exportData or {})[today]
                        if bucket then
                            restorePayload[name] = { [today] = bucket }
                        end
                    else
                        restorePayload[name] = BadStormsSettings[name]
                    end
                end
            end
            AceComm:SendCommMessage("BadStorms", Encode(restorePayload), "WHISPER", sender)
            return
        end
        if rp.version and currentPayload.key == rp.key and currentPayload.version and rp.version <= currentPayload.version then
            return
        end
        BadStorms.RefreshUIAfterSync(rp)
        if rp.version then
            BadStorms.PushToHistory(rp)
        end
    elseif rp.action == "restore" then
        if rp.key == currentPayload.key and rp.version > (currentPayload.version or 0) then
            print("|cff00ff00BadStorms:|r Restoring data from " .. sender)
            BadStorms.RefreshUIAfterSync(rp)
            BadStorms.PushToHistory(rp)
        end
    end
end)

C_Timer.NewTicker(60, BadStorms.SyncToAll)
