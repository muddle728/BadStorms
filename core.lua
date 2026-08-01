local addonName, ns = ...
_G[addonName] = ns
local BadStorms = ns

BadStorms.version = "1.0"
BadStorms.currentRolls = {}
BadStorms.isRolling = false
BadStorms.rollTimerActive = nil
BadStorms.rollRemaining = 0

BadStormsSettings = BadStormsSettings or {}
BadStormsSettings.autoMasterLoot = BadStormsSettings.autoMasterLoot or false
BadStormsSettings.disenchantEnabled = BadStormsSettings.disenchantEnabled or false
BadStormsSettings.disenchanter = BadStormsSettings.disenchanter or ""
BadStormsSettings.exportData = BadStormsSettings.exportData or {}
BadStormsSettings.frameScale = BadStormsSettings.frameScale or 1.0
BadStormsSettings.lootRollerScale = BadStormsSettings.lootRollerScale or 1.0
BadStormsSettings.tradeTimerScale = BadStormsSettings.tradeTimerScale or 1.0
BadStormsSettings.minimapPos = BadStormsSettings.minimapPos or 0
BadStormsSettings.syncHistory = BadStormsSettings.syncHistory or {}
BadStormsSettings.pendingTrades = BadStormsSettings.pendingTrades or {}
BadStormsSettings.plusOnes = BadStormsSettings.plusOnes or {}
BadStormsSettings.plusOnesEnabled = BadStormsSettings.plusOnesEnabled or true
BadStormsSettings.softReserves = BadStormsSettings.softReserves or {}
BadStormsSettings.softReservesCsv = BadStormsSettings.softReservesCsv or ""
BadStormsSettings.rollTimer = BadStormsSettings.rollTimer or 10
BadStormsSettings.lootRollerCloseTime = BadStormsSettings.lootRollerCloseTime or 15
if BadStormsSettings.lootRollerEnabled == nil then
    BadStormsSettings.lootRollerEnabled = true
end
if BadStormsSettings.tradeTimerEnabled == nil then
    BadStormsSettings.tradeTimerEnabled = true
end

if not C_Timer then
    C_Timer = {}
    function C_Timer.After(delay, callback)
        local timerFrame = CreateFrame("Frame")
        local start = GetTime()
        timerFrame:SetScript("OnUpdate", function()
            if GetTime() - start >= delay then
                callback()
                timerFrame:SetScript("OnUpdate", nil)
            end
        end)
        return {
            Cancel = function()
                timerFrame:SetScript("OnUpdate", nil)
            end
        }
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
        return {
            Cancel = function()
                frame:SetScript("OnUpdate", nil)
            end
        }
    end
end

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

function BadStorms.CountItemsInBags(itemId)
    if not itemId then
        return 0
    end
    local count = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("Hitem:(%d+)"))
                if id == itemId then
                    count = count + 1
                end
            end
        end
    end
    return count
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

function BadStorms.FindAllItemSlots(itemId)
    local slots = {}
    if not itemId then
        return slots
    end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("Hitem:(%d+)"))
                if id == itemId then
                    table.insert(slots, { bag = bag, slot = slot, link = link })
                end
            end
        end
    end
    return slots
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

function BadStorms.GetPlayerCandidateIndex()
    local playerName = UnitName("player")
    for ci = 1, 40 do
        local name = GetMasterLootCandidate(ci)
        if name == playerName then
            return ci
        end
    end
end

function BadStorms.GetMasterLooterName()
    local method, partyIndex, raidIndex = GetLootMethod()
    if method ~= "master" then
        return nil
    end
    if partyIndex == 0 then
        return UnitName("player")
    else
        return UnitName("party" .. partyIndex)
    end
    return UnitName("party" .. raidIndex)
end

function BadStorms.GetDisenchanterCandidateIndex()
    local dePlayer = BadStormsSettings.disenchanter
    if not dePlayer or dePlayer == "" then
        return nil
    end
    for ci = 1, 40 do
        local candidate = GetMasterLootCandidate(ci)
        if not candidate then
            break
        end
        if candidate == dePlayer then
            return ci
        end
    end
end

function BadStorms.ParseDateTime(str)
    if not str or str == "" then
        return nil
    end
    local y, m, d, h, mi, s = str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not y then
        y, m, d, h, mi, s = str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
        s = s or "0"
    end
    if not y then
        return nil
    end
    return time({
        year = y,
        month = m,
        day = d,
        hour = h,
        min = mi,
        sec = s
    })
end

function BadStorms.RemoveAllPendingTrades(itemId)
    if not itemId or not BadStormsSettings.pendingTrades then
        return
    end
    for player, items in pairs(BadStormsSettings.pendingTrades) do
        local remaining = {}
        for _, itemData in ipairs(items) do
            if itemData.itemId ~= itemId then
                table.insert(remaining, itemData)
            end
        end
        if #remaining == 0 then
            BadStormsSettings.pendingTrades[player] = nil
        else
            BadStormsSettings.pendingTrades[player] = remaining
        end
    end
end

function BadStorms.CleanupPendingTrades()
    local pending = BadStormsSettings.pendingTrades
    if not pending then
        return false
    end
    local now = time()
    local changed = false
    for player, items in pairs(pending) do
        local remaining = {}
        for _, item in ipairs(items) do
            local itemTime = BadStorms.ParseDateTime(item.date)
            if not itemTime or (now - itemTime) < 7200 then
                table.insert(remaining, item)
            else
                changed = true
            end
        end
        if #remaining == 0 then
            pending[player] = nil
            changed = true
        else
            pending[player] = remaining
        end
    end
    return changed
end

function BadStorms.Update()
    local updatedKeys = {
        _plusOnesSnapshot = false,
        altClickLooting = false,
        disenchanterEnabled = "disenchantEnabled",
        lastSRImport = "softReservesCsv",
        reserves = false,
        srReservations = "softReserves",
        syncLastPull = false,
        syncLastPush = false,
        trackPlusOnes = "plusOnesEnabled",
        tradeTotals = false,
        users = false

    }
    for oldKey, newKey in pairs(updatedKeys) do
        if BadStormsSettings[oldKey] ~= nil then
            if newKey then
                print("|cff00ff00BadStorms:|r Updating " .. oldKey .. " to " .. newKey)
                BadStormsSettings[newKey] = BadStormsSettings[oldKey]
            else
                print("|cff00ff00BadStorms:|r Deleting old key " .. oldKey)
            end
            BadStormsSettings[oldKey] = nil
        end
    end
end
