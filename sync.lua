local BadStorms = _G.BadStorms
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")

local _previousPlusOnes = AceSerializer:Serialize(BadStormsSettings.plusOnes or {})

function BadStorms.RefreshUIAfterSync()
    local frame = BadStorms.configFrame
    if not frame then
        return
    end
    frame.PopulatePlusOnesList()
end

function BadStorms.SyncRecoverData()
    local data = {
        action = "ping"
    }
    AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(data), BadStorms.GetChannel(), nil, "NORMAL")
end

function BadStorms.SyncToAll()
    if not BadStorms.IsMasterLooter() then
        return
    end
    if not BadStormsSettings.raidSyncEnabled then
        return
    end
    local _plusOnes = AceSerializer:Serialize(BadStormsSettings.plusOnes)
    if _plusOnes ~= _previousPlusOnes then
        local data = {
            action = "plusOnes",
            plusOnes = BadStormsSettings.plusOnes
        }
        AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(data), BadStorms.GetChannel(), nil, "BULK")
        _previousPlusOnes = _plusOnes
    end
end

AceComm:RegisterComm("BadStorms", function(prefix, data, distribution, sender)
    if sender == UnitName("player") then
        return
    end
    local ok, received = AceSerializer:Deserialize(data)
    if not ok then
        return
    end
    if not received then
        return
    end
    -- print("TODO: action = " .. received.action)
    if received.action == "plusOnes" then
        BadStormsSettings.plusOnes = received.plusOnes or {}
        BadStorms.RefreshUIAfterSync()
    elseif received.action == "ping" then
        local data = {
            action = "pong"
        }
        AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(data), "WHISPER", sender)
    elseif received.action == "pong" then
        print("TODO: " .. sender .. " has this addon too!")
    end
end)

C_Timer.NewTicker(15, BadStorms.SyncToAll)
