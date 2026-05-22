local BadStorms = _G.BadStorms
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate", true)

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
    if _plusOnes == _previousPlusOnes then
        return
    end
    local data = {
        action = "plusOnes",
        plusOnes = BadStormsSettings.plusOnes
    }
    print("TODO: " .. AceSerializer:Serialize(data))
    AceComm:SendCommMessage("BadStorms", AceSerializer:Serialize(data), BadStorms.GetChannel(), nil, "BULK")
    _previousPlusOnes = _plusOnes
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
        table.insert(BadStormsSettings.users, sender)
    end
end)

local rawData = "GuildRankData_Reset_2026"

--[[
-- Compress & Encode for Public Chat Channels
local compressed = LibDeflate:CompressDeflate(rawData)
local chatSafeMessage = LibDeflate:EncodeForWoWChatChannel(compressed)

-- Broadcast to Guild
SendChatMessage(chatSafeMessage, "GUILD")

---------------------------------------------------------
-- RECEIVER SIDE
---------------------------------------------------------
-- Inside CHAT_MSG_GUILD event listener:
local function HandleGuildChatData(textMessage)
    local decoded = LibDeflate:DecodeForWoWChatChannel(textMessage)
    if decoded then
        local originalText = LibDeflate:DecompressDeflate(decoded)
        print("Received: " .. originalText)
    end
end
]]--

C_Timer.NewTicker(15, BadStorms.SyncToAll)
