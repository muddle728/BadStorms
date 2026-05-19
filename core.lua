local addonName, ns = ...
_G[addonName] = ns
local BadStorms = ns

BadStorms.version = "1.0"

if not C_Timer then
    C_Timer = {}
    function C_Timer.After(delay, callback)
        local timer = CreateFrame("Frame")
        local start = GetTime()
        timer:SetScript("OnUpdate", function()
            if GetTime() - start >= delay then
                callback()
                timer:SetScript("OnUpdate", nil)
            end
        end)
    end
    function C_Timer.NewTicker(interval, callback)
        local frame = CreateFrame("Frame")
        local accum = 0
        frame:SetScript("OnUpdate", function(self, delta)
            accum = accum + delta
            if accum >= interval then
                accum = accum - interval
                callback()
            end
        end)
        return { Cancel = function() frame:SetScript("OnUpdate", nil) end }
    end
end

if not BadStormsSettings then
    BadStormsSettings = {
        enabled = false,
        rollTimer = 5,
        autoloot = false,
        altClickLooting = true,
        framePos = nil,
        minimapPos = 0,
        hideMinimap = false,
        srReservations = {},
        lastSRImport = "",
        exportData = {},
        trackPlusOnes = true,
        plusOnes = {},
        pendingTrades = {},
        tradeTotals = {},
        autoMasterLoot = false,
        disenchanterEnabled = false,
        disenchanter = "",
        frameScale = 1.0
    }
end
BadStormsSettings.srReservations = BadStormsSettings.srReservations or {}
BadStormsSettings.lastSRImport = BadStormsSettings.lastSRImport or ""
BadStormsSettings.altClickLooting = BadStormsSettings.altClickLooting == nil and true or
                                        BadStormsSettings.altClickLooting
BadStormsSettings.exportData = BadStormsSettings.exportData or {}
BadStormsSettings.trackPlusOnes = BadStormsSettings.trackPlusOnes == nil and true or BadStormsSettings.trackPlusOnes
BadStormsSettings.plusOnes = BadStormsSettings.plusOnes or {}
BadStormsSettings.pendingTrades = BadStormsSettings.pendingTrades or {}
BadStormsSettings.tradeTotals = BadStormsSettings.tradeTotals or {}
BadStormsSettings.autoMasterLoot = BadStormsSettings.autoMasterLoot == nil and false or BadStormsSettings.autoMasterLoot
BadStormsSettings.minimapPos = BadStormsSettings.minimapPos or 0
BadStormsSettings.disenchanterEnabled = BadStormsSettings.disenchanterEnabled == nil and false or BadStormsSettings.disenchanterEnabled
BadStormsSettings.disenchanter = BadStormsSettings.disenchanter or ""
BadStormsSettings.frameScale = BadStormsSettings.frameScale or 1.0

function BadStorms.GetItemID(link)
    if type(link) == "number" then
        return link
    end
    if type(link) == "string" then
        return tonumber(link:match("Hitem:(%d+)")) or tonumber(link)
    end
end

function BadStorms.GetChannel()
    if GetNumRaidMembers() > 0 then
        return "RAID"
    end
    if GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return "PRINT"
end

function BadStorms.SendToChannel(msg)
    local chan = BadStorms.GetChannel()
    if chan == "PRINT" then
        print(msg)
    else
        SendChatMessage(msg, chan)
    end
end

function BadStorms.NormalizeItemLink(link)
    if type(link) == "number" then
        link = tostring(link)
    end
    if type(link) ~= "string" then
        return nil
    end
    if string.find(link, "^|c") and string.find(link, ":%d+") then
        return link
    end
    local _, itemLink = GetItemInfo(link)
    if type(itemLink) == "string" and string.find(itemLink, "^|c") then
        return itemLink
    end
    return nil
end

function BadStorms.GetClassColor(class)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    if colors and class and colors[class] then
        local c = colors[class]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function BadStorms.IsLootMaster()
    local method, partyID, raidID = GetLootMethod()
    if method == "freeforall" then
        return true
    end
    if method ~= "master" then
        return false
    end
    if partyID == 0 then
        return true
    end
    if raidID and UnitIsUnit("player", "raid" .. raidID) then
        return true
    end
    return false
end

function BadStorms.IsMasterLooter()
    local method, partyID, raidID = GetLootMethod()
    if method ~= "master" then
        return false
    end
    if partyID == 0 then
        return true
    end
    if raidID and UnitIsUnit("player", "raid" .. raidID) then
        return true
    end
    return false
end

function BadStorms.CanManageLoot()
    if BadStorms.IsMasterLooter() then
        return true
    end
    local method = GetLootMethod()
    if method == "freeforall" then
        if GetNumRaidMembers() > 0 then
            return IsRaidLeader() or IsRaidOfficer()
        end
        return IsPartyLeader()
    end
    return false
end

function BadStorms.CanRaidWarning()
    if GetNumRaidMembers() > 0 then
        return IsRaidLeader() or IsRaidOfficer()
    end
    return false
end

function BadStorms.InGroup()
    return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

BadStorms.currentRolls = {}
BadStorms.isRolling = false
BadStorms.rollTimerActive = nil
BadStorms.rollRemaining = 0

function BadStorms.GetPlayerUnit(name)
    if not name then
        return nil
    end
    local n = name:lower()
    if UnitName("player"):lower() == n then
        return "player"
    end
    for i = 1, 4 do
        if UnitExists("party" .. i) and UnitName("party" .. i):lower() == n then
            return "party" .. i
        end
    end
    for i = 1, 40 do
        if UnitExists("raid" .. i) and UnitName("raid" .. i):lower() == n then
            return "raid" .. i
        end
    end
    return nil
end

function BadStorms.FindItemInBags(itemId)
    if not itemId then
        return nil, nil, nil
    end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("Hitem:(%d+)"))
                if id == itemId then
                    return bag, slot, link
                end
            end
        end
    end
    return nil, nil, nil
end

function BadStorms.ItemExistsInSlot(data)
    if not data then
        return false
    end
    if data.lootSlot then
        return GetLootSlotLink(data.lootSlot) ~= nil
    end
    if data.bag and data.slot then
        return GetContainerItemLink(data.bag, data.slot) ~= nil
    end
    if data.link then
        return true
    end
    return false
end

function BadStorms.IsItemEquippable(link)
    if not link then
        return false
    end
    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(link)
    return equipSlot ~= nil and equipSlot ~= ""
end
