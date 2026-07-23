local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID
local GetChannel = BadStorms.GetChannel
local SendToChannel = BadStorms.SendToChannel
local PlayerHasReservation = BadStorms.PlayerHasReservation
local GetPlayerSRPlus = BadStorms.GetPlayerSRPlus

local function UpdateRollDisplay(frame)
    local currentItemId = frame.data and GetItemID(frame.data.link)

    table.sort(BadStorms.currentRolls, function(a, b)
        local aSR = currentItemId and PlayerHasReservation(currentItemId, a.name) or 0
        local bSR = currentItemId and PlayerHasReservation(currentItemId, b.name) or 0
        if aSR > 0 and bSR == 0 then
            return true
        end
        if bSR > 0 and aSR == 0 then
            return false
        end
        if aSR > 0 and bSR > 0 then
            local aEff = a.effectiveRoll or a.roll
            local bEff = b.effectiveRoll or b.roll
            return aEff > bEff
        end
        local aPO = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[a.name] or 0) or 0
        local bPO = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[b.name] or 0) or 0
        local aIsMS = a.max == 100
        local bIsMS = b.max == 100
        local aHasPO = aPO > 0
        local bHasPO = bPO > 0
        local function cat(isMS, hasPO)
            if isMS and not hasPO then
                return 0
            end
            if isMS and hasPO then
                return 1
            end
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
            local srPlus = data.srPlus or 0
            local plusOnes = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[data.name] or 0) or 0
            btn.nameText:SetText(data.name)
            btn.nameText:SetTextColor(r, g, b)

            local effectiveRoll = (data.effectiveRoll or data.roll)
            btn.rollText:SetText(tostring(effectiveRoll))
            btn.rollText:SetTextColor(r, g, b)
            if hasSR > 0 then
                local srCount = hasSR
                if srCount > 1 then
                    if srPlus > 0 then
                        btn.specText:SetText("SRx" .. srCount .. " +" .. srPlus)
                    else
                        btn.specText:SetText("SRx" .. srCount)
                    end
                else
                    if srPlus > 0 then
                        btn.specText:SetText("SR +" .. srPlus)
                    else
                        btn.specText:SetText("SR")
                    end
                end
                btn.srText:SetText(tostring(data.roll))
            else
                btn.specText:SetText(spec)
                btn.srText:SetText("")
            end
            btn.specText:SetTextColor(r, g, b)
            btn.srText:SetTextColor(r, g, b)

            if data.max == 100 and plusOnes > 0 and hasSR == 0 then
                btn.plusText:SetText("+" .. plusOnes)
                btn.plusText:SetTextColor(0, 1, 0)
            else
                btn.plusText:SetText("")
            end

            btn.rollData = data
            btn:Show()
        else
            btn.rollData = nil
            if btn.srText then
                btn.srText:SetText("")
            end
            if btn.plusText then
                btn.plusText:SetText("")
            end
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
    BadStorms._activeRollFrame = nil
    if BadStorms.rollTimerActive then
        BadStorms.rollTimerActive:Cancel()
        BadStorms.rollTimerActive = nil
    end

    UpdateRollDisplay(frame)

    if #BadStorms.currentRolls > 0 then
        local top = BadStorms.currentRolls[1]
        local currentItemId = frame.data and GetItemID(frame.data.link)

        local tieNames = {}
        for _, entry in ipairs(BadStorms.currentRolls) do
            local entryEff = entry.effectiveRoll or entry.roll
            local topEff = top.effectiveRoll or top.roll
            if entryEff ~= topEff then break end
            if entry.max ~= top.max then break end
            local entrySR = currentItemId and PlayerHasReservation(currentItemId, entry.name) or 0
            local topSR = currentItemId and PlayerHasReservation(currentItemId, top.name) or 0
            if entrySR ~= topSR then break end
            table.insert(tieNames, entry.name)
        end

        if #tieNames > 1 then
            local tieMsg = "Re-Roll: " .. table.concat(tieNames, ", ")
            SendToChannel(string.format("ROLLS CLOSED! %s", tieMsg))
            frame.selectedRoll = nil
            frame.selectedRollLabel:SetText("Player: None")
            frame.rollAssignButton:Disable()
            for _, btn in ipairs(frame.rollButtons) do
                btn.selectedTexture:Hide()
            end
            frame.rollTimerText:SetText("Tie - Re-Roll!")
        else
            local winner = top
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
            local winnerHasSR = currentItemId and PlayerHasReservation(currentItemId, winner.name) or 0
            local winMsg
            if winnerHasSR > 0 then
                local winnerSRPlus = currentItemId and GetPlayerSRPlus(currentItemId, winner.name) or 0
                if winnerSRPlus > 0 then
                    winMsg = string.format("Winner: %s [%d] (SR +%d)", winner.name, winner.effectiveRoll or winner.roll, winnerSRPlus)
                else
                    winMsg = string.format("Winner: %s [%d] (SR)", winner.name, winner.effectiveRoll or winner.roll)
                end
            elseif winner.max == 100 then
                local plusParts = {}
                local anyNonZero = false
                for _, entry in ipairs(BadStorms.currentRolls) do
                    if entry.max == 100 then
                        local po = BadStormsSettings.plusOnesEnabled and (BadStormsSettings.plusOnes[entry.name] or 0) or 0
                        if po > 0 then
                            anyNonZero = true
                        end
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
            frame.rollTimerText:SetText("Roll ended")
        end
    else
        SendToChannel("ROLLS CLOSED!")
        frame.rollTimerText:SetText("Roll ended")
    end

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
    BadStorms._activeRollFrame = frame
    BadStorms.rollRemaining = BadStormsSettings.rollTimer or 10

    UpdateRollDisplay(frame)

    local link = frame.data and frame.data.link or "an item"
    local rollTimer = BadStormsSettings.rollTimer or 10
    local rollMsg = "Roll for " .. link .. " (/roll for MS, /roll 99 for OS) [Roll Timer: " .. rollTimer .. " seconds]"
    if BadStorms.CanRaidWarning() then
        SendChatMessage(rollMsg, "RAID_WARNING")
    else
        SendToChannel(rollMsg)
    end

    local currentItemId = frame.data and GetItemID(frame.data.link)
    if currentItemId and BadStormsSettings.softReserves then
        local srPlayers = {}
        local srPlusValues = {}
        for _, r in ipairs(BadStormsSettings.softReserves) do
            if r.itemId == currentItemId then
                local plus = tonumber(r.plus) or 0
                srPlayers[r.name] = (srPlayers[r.name] or 0) + 1
                if not srPlusValues[r.name] then
                    srPlusValues[r.name] = plus
                end
            end
        end
        local names = {}
        for name, count in pairs(srPlayers) do
            local entry = name
            local plus = srPlusValues[name]
            if plus > 0 then
                entry = entry .. " (+" .. plus .. ")"
            end
            if count > 1 then
                entry = entry .. " x" .. count
            end
            table.insert(names, entry)
        end
        if #names > 0 then
            table.sort(names)
            local MAX_LINE = 240
            local line = "SR: "
            for _, entry in ipairs(names) do
                local add = (#line > 4 and ", " or "") .. entry
                if #line + #add > MAX_LINE then
                    SendToChannel(line)
                    line = "SR: " .. entry
                else
                    line = line .. add
                end
            end
            SendToChannel(line)
        end
    end

    frame.rollTimerText:SetText("Rolling... " .. BadStorms.rollRemaining)
    frame.startRollButton:Disable()
    frame.endRollButton:Enable()

    if BadStorms.rollTimerActive then
        BadStorms.rollTimerActive:Cancel()
        BadStorms.rollTimerActive = nil
    end
    BadStorms.rollTimerActive = C_Timer.NewTicker(1, function()
        BadStorms.rollRemaining = BadStorms.rollRemaining - 1
        frame.rollTimerText:SetText("Rolling... " .. BadStorms.rollRemaining)

        if BadStorms.rollRemaining > 0 and BadStorms.rollRemaining <= 5 then
            local remaining = BadStorms.rollRemaining
            local sec = remaining == 1 and "second" or "seconds"
            local msg = "Roll ends in " .. tostring(remaining) .. " " .. sec .. "..."
            local chan = GetChannel()
            if chan ~= "PRINT" then
                SendChatMessage(msg, chan)
            end
        end
        
        frame.rollTimerText:SetTextColor(1, 0, 0)

        if BadStorms.rollRemaining <= 0 then
            BadStorms.rollTimerActive:Cancel()
            BadStorms.rollTimerActive = nil
            C_Timer.After(0.5, function()
                EndRoll(frame)
            end)
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

    local srPlus = currentItemId and GetPlayerSRPlus(currentItemId, name) or 0
    table.insert(BadStorms.currentRolls, {
        name = name,
        unit = unit,
        roll = roll,
        srPlus = srPlus,
        effectiveRoll = roll + srPlus,
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
