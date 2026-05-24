local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID
local GetChannel = BadStorms.GetChannel
local SendToChannel = BadStorms.SendToChannel
local PlayerHasReservation = BadStorms.PlayerHasReservation

local function UpdateRollDisplay(frame)
    local currentItemId = frame.data and GetItemID(frame.data.link)

    table.sort(BadStorms.currentRolls, function(a, b)
        local aSR = currentItemId and PlayerHasReservation(currentItemId, a.name) or 0
        local bSR = currentItemId and PlayerHasReservation(currentItemId, b.name) or 0
        if aSR > 0 and bSR == 0 then return true end
        if bSR > 0 and aSR == 0 then return false end
        if aSR > 0 and bSR > 0 then
            return a.roll > b.roll
        end
        local aPO = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[a.name] or 0) or 0
        local bPO = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[b.name] or 0) or 0
        local aIsMS = a.max == 100
        local bIsMS = b.max == 100
        local aHasPO = aPO > 0
        local bHasPO = bPO > 0
        local function cat(isMS, hasPO)
            if isMS and not hasPO then return 0 end
            if isMS and hasPO then return 1 end
            return 2
        end
        local ca, cb = cat(aIsMS, aHasPO), cat(bIsMS, bHasPO)
        if ca ~= cb then
            return ca < cb
        end
        if ca == 2 then
            return a.roll > b.roll
        end
        if aPO ~= bPO then
            return aPO < bPO
        end
        return a.roll > b.roll
    end)

    for i, btn in ipairs(frame.rollButtons) do
        local data = BadStorms.currentRolls[i]
        if data then
            local spec = data.max == 100 and "MS" or "OS"
            local r, g, b = BadStorms.GetClassColor(data.class)

            local hasSR = currentItemId and PlayerHasReservation(currentItemId, data.name) or 0
            local plusOnes = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[data.name] or 0) or 0
            btn.nameText:SetText(data.name)
            btn.nameText:SetTextColor(r, g, b)

            btn.rollText:SetText(tostring(data.roll))
            btn.rollText:SetTextColor(r, g, b)
            btn.specText:SetText(hasSR > 0 and spec .. " SR" or spec)
            btn.specText:SetTextColor(r, g, b)

            if hasSR > 0 then
                btn.srText:SetText(hasSR > 1 and "SR x" .. hasSR or "SR")
                btn.srText:SetTextColor(1, 0.82, 0)
            else
                btn.srText:SetText("")
            end

            if data.max == 100 and plusOnes > 0 then
                btn.plusText:SetText("+" .. plusOnes)
                btn.plusText:SetTextColor(0, 1, 0)
            else
                btn.plusText:SetText("")
            end

            btn.rollData = data
            btn:Show()
        else
            btn.rollData = nil
            if btn.srText then btn.srText:SetText("") end
            if btn.plusText then btn.plusText:SetText("") end
            btn:Hide()
        end
    end
end
BadStorms.UpdateRollDisplay = UpdateRollDisplay

local function EndRoll(frame)
    if not BadStorms.isRolling then
        return
    end
    BadStorms.isRolling = false
    if BadStorms.rollTimerActive then
        BadStorms.rollTimerActive:Cancel()
        BadStorms.rollTimerActive = nil
    end

    UpdateRollDisplay(frame)
    
    if #BadStorms.currentRolls > 0 then
        local winner = BadStorms.currentRolls[1]
        frame.selectedRoll = winner
        frame.selectedRollLabel:SetText("Player: " .. winner.name)
        frame.rollAssignButton:Enable()
        for _, btn in ipairs(frame.rollButtons) do
            if btn.rollData and btn.rollData.name == winner.name then
                btn.selectedTexture:Show()
            else
                btn.selectedTexture:Hide()
            end
        end
        local currentItemId = frame.data and GetItemID(frame.data.link)
        local winnerHasSR = currentItemId and PlayerHasReservation(currentItemId, winner.name) or 0
        local winMsg
        if winnerHasSR > 0 then
            winMsg = string.format("Winner: %s [%d] (SR)", winner.name, winner.roll)
        elseif winner.max == 100 then
            local plusParts = {}
            local anyNonZero = false
            for _, entry in ipairs(BadStorms.currentRolls) do
                if entry.max == 100 then
                    local po = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[entry.name] or 0) or 0
                    if po > 0 then anyNonZero = true end
                    table.insert(plusParts, entry.name .. "(" .. po .. ")")
                end
            end
            if anyNonZero then
                local plusStr = table.concat(plusParts, " ")
                if #plusStr > 250 then
                    plusStr = plusStr:sub(1, 150) .. "..."
                end
                winMsg = string.format("Winner: %s [%d] (MS) - +1s: %s", winner.name, winner.roll, plusStr)
            else
                winMsg = string.format("Winner: %s [%d] (MS)", winner.name, winner.roll)
            end
        else
            winMsg = string.format("Winner: %s [%d] (OS)", winner.name, winner.roll)
        end
        SendToChannel(string.format("ROLLS CLOSED! %s", winMsg))
    else 
        SendToChannel("ROLLS CLOSED!")
    end

    frame.rollTimerText:SetText("Roll ended")
    if frame.data and frame.data.link then
        frame.startRollButton:Enable()
    end
    frame.endRollButton:Disable()
end
BadStorms.EndRoll = EndRoll

local function StartRoll(frame)
    if BadStorms.isRolling then
        return
    end

    BadStorms.currentRolls = {}
    BadStorms.isRolling = true
    BadStorms.rollRemaining = BadStormsSettings.rollTimer or 10

    UpdateRollDisplay(frame)

    local link = frame.data and frame.data.link or "an item"
    local rollTimer = BadStormsSettings.rollTimer or 10
    local rollMsg = "Roll for " .. link .. " (/roll for MS or /roll 99 for OS) [RollTimer:" .. rollTimer .. "]"
    if BadStorms.CanRaidWarning() then
        SendChatMessage(rollMsg, "RAID_WARNING")
    else
        SendToChannel(rollMsg)
    end

    local currentItemId = frame.data and GetItemID(frame.data.link)
    if currentItemId and BadStormsSettings.softReserves then
        local srPlayers = {}
        for _, r in ipairs(BadStormsSettings.softReserves) do
            if r.itemId == currentItemId then
                local count = (tonumber(r.plus) or 0) + 1
                srPlayers[r.name] = (srPlayers[r.name] or 0) + count
            end
        end
        local names = {}
        for name, count in pairs(srPlayers) do
            table.insert(names, name .. (count > 1 and " x" .. count or ""))
        end
        if #names > 0 then
            table.sort(names)
            SendToChannel("SR: " .. table.concat(names, ", "))
        end
    end

    frame.rollTimerText:SetText("Rolling... " .. BadStorms.rollRemaining)
    frame.startRollButton:Disable()
    frame.endRollButton:Enable()

    if BadStorms.rollTimerActive then
        BadStorms.rollTimerActive:Cancel()
    end
    BadStorms.rollTimerActive = C_Timer.NewTicker(1, function()
        BadStorms.rollRemaining = BadStorms.rollRemaining - 1
        frame.rollTimerText:SetText("Rolling... " .. BadStorms.rollRemaining)
        local roller = BadStorms.lootRoller
        if roller and roller.statusText and roller:IsShown() then
            local rem = BadStorms.rollRemaining
            if rem > 0 then
                roller.statusText:SetText("Rolling... (" .. rem .. "s)")
            else
                roller.statusText:SetText("Roll ended")
            end
        end

        if BadStorms.rollRemaining > 0 and BadStorms.rollRemaining <= 10 then
            local remaining = BadStorms.rollRemaining
            local sec = remaining == 1 and "second" or "seconds"
            local msg = "Roll ends in " .. tostring(remaining) .. " " .. sec .. "..."
            local chan = GetChannel()
            if chan ~= "PRINT" then
                SendChatMessage(msg, chan)
            end
        end

        if BadStorms.rollRemaining <= 0 then
            EndRoll(frame)
        end
    end)
end
BadStorms.StartRoll = StartRoll

local rollListener = CreateFrame("Frame")
rollListener:RegisterEvent("CHAT_MSG_SYSTEM")
rollListener:SetScript("OnEvent", function(self, event, msg)
    if not BadStorms.isRolling then
        return
    end

    local name, roll, min, max = msg:match("(.+) rolls (%d+) %((%d+)%-(%d+)%)")
    if not name then
        return
    end

    roll = tonumber(roll)
    min = tonumber(min)
    max = tonumber(max)

    if min ~= 1 then
        return
    end
    if max ~= 100 and max ~= 99 then
        return
    end

    local _, class = UnitClass(name)
    local unit = BadStorms.GetPlayerUnit(name)
    local frame = BadStorms.configFrame
    local lootRoller = BadStorms.lootRoller
    local currentItemId = frame and frame.data and GetItemID(frame.data.link)
    if not currentItemId and lootRoller and lootRoller.data then
        currentItemId = GetItemID(lootRoller.data.link)
    end
    if currentItemId then
        local srCount = PlayerHasReservation(currentItemId, name)
        local maxRolls = srCount > 0 and srCount or 1
        local rollCount = 0
        for _, v in ipairs(BadStorms.currentRolls) do
            if v.name == name then
                rollCount = rollCount + 1

            end
        end
        if rollCount >= maxRolls then
            return
        end
    end
    if currentItemId then
        local srCount = PlayerHasReservation(currentItemId, name)
        local maxRolls = srCount > 0 and srCount or 1
        local rollCount = 0
        for _, v in ipairs(BadStorms.currentRolls) do
            if v.name == name then
                rollCount = rollCount + 1
            end
        end
        if rollCount >= maxRolls then
            return
        end
    end

    table.insert(BadStorms.currentRolls, {
        name = name,
        unit = unit,
        roll = roll,
        max = max,
        class = class
    })
    if frame and frame.rollButtons then
        UpdateRollDisplay(frame)
    end
    if lootRoller and lootRoller.rollButtons then
        UpdateRollDisplay(lootRoller)
    end
end)
