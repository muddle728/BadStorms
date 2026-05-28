local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID
local NormalizeItemLink = BadStorms.NormalizeItemLink
local PlayerHasReservation = BadStorms.PlayerHasReservation
local GetPlayerSRPlus = BadStorms.GetPlayerSRPlus
local GetSRText = BadStorms.GetSRText

function BadStorms.UpdateItemSelection(frame, link, bag, slot)
    if not link then
        return
    end

    frame.selected = nil
    frame.selectedRoll = nil

    if frame.selectedLabel then
        frame.selectedLabel:SetText("Player: None")
    end
    if frame.selectedRollLabel then
        frame.selectedRollLabel:SetText("Player: None")
    end
    if frame.playerButtons then
        for _, btn in ipairs(frame.playerButtons) do
            btn.selectedTexture:Hide()
        end
    end
    if frame.awardButton then
        frame.awardButton:Disable()
    end

    local linkStr = type(link) == "number" and tostring(link) or link
    local linkID = GetItemID(link)

    local data = {
        link = linkStr,
        bag = bag,
        slot = slot
    }
    if not bag or not slot then
        for b = 0, 4 do
            local numSlots = GetContainerNumSlots(b)
            for s = 1, numSlots do
                local itemLink = GetContainerItemLink(b, s)
                if itemLink then
                    local match = itemLink == linkStr
                    if not match and linkID then
                        match = linkID == GetItemID(itemLink)
                    end
                    if match then
                        data.bag = b
                        data.slot = s
                        data.link = itemLink
                        break
                    end
                end
            end
            if data.bag then
                break
            end
        end
    end

    if type(data.link) ~= "string" or not data.link:find("^|c") then
        local normalized = NormalizeItemLink(data.link)
        if normalized then
            data.link = normalized
        end
    end

    local itemName, _, quality, _, _, _, _, _, _, texture = GetItemInfo(data.link)
    frame.data = data

    local qColor = quality and ITEM_QUALITY_COLORS[quality]
    if frame.itemIcon and frame.linkText then
        frame.linkText.text:SetText(itemName or data.link)
        frame.linkText.text:SetTextColor(qColor and qColor.r or 0.5, qColor and qColor.g or 0.5, qColor and qColor.b or 0.5)
        frame.itemIcon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.itemIcon:SetBackdropBorderColor(qColor and qColor.r or 0.5, qColor and qColor.g or 0.5, qColor and qColor.b or 0.5)
    end
    if frame.itemIconRoll and frame.linkTextRoll then
        frame.linkTextRoll.text:SetText(itemName or data.link)
        frame.linkTextRoll.text:SetTextColor(qColor and qColor.r or 0.5, qColor and qColor.g or 0.5, qColor and qColor.b or 0.5)
        frame.itemIconRoll.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.itemIconRoll:SetBackdropBorderColor(qColor and qColor.r or 0.5, qColor and qColor.g or 0.5, qColor and qColor.b or 0.5)
    end

    if frame.startRollButton and not BadStorms.isRolling then
        frame.startRollButton:Enable()
    end
    local equippable = BadStorms.IsItemEquippable(data.link)
    if frame.disenchantRollButton then
        if BadStormsSettings.disenchantEnabled and BadStormsSettings.disenchanter ~= "" and equippable then
            frame.disenchantRollButton:Enable()
        else
            frame.disenchantRollButton:Disable()
        end
    end
    if frame.awardDisenchantButton then
        if BadStormsSettings.disenchantEnabled and BadStormsSettings.disenchanter ~= "" and equippable then
            frame.awardDisenchantButton:Enable()
        else
            frame.awardDisenchantButton:Disable()
        end
    end
end

function BadStorms.PopulatePlayerList(frame)
    local players = {}
    local raid = GetNumRaidMembers() > 0
    local count = raid and GetNumRaidMembers() or GetNumPartyMembers()

    if raid then
        for i = 1, count do
            local name = GetRaidRosterInfo(i)
            if name then
                local _, class = UnitClass("raid" .. i)
                table.insert(players, {
                    name = name,
                    unit = "raid" .. i,
                    class = class
                })
            end
        end
    else
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")
        table.insert(players, {
            name = playerName,
            unit = "player",
            class = playerClass
        })
        for i = 1, count do
            local name = UnitName("party" .. i)
            if name then
                local _, class = UnitClass("party" .. i)
                table.insert(players, {
                    name = name,
                    unit = "party" .. i,
                    class = class
                })
            end
        end
    end

    local currentItemId = frame.data and GetItemID(frame.data.link)

    table.sort(players, function(a, b)
        local aSR = currentItemId and PlayerHasReservation(currentItemId, a.name) or 0
        local bSR = currentItemId and PlayerHasReservation(currentItemId, b.name) or 0
        if aSR > 0 and bSR == 0 then return true end
        if bSR > 0 and aSR == 0 then return false end
        return a.name:lower() < b.name:lower()
    end)

    for i, btn in ipairs(frame.playerButtons) do
        local player = players[i]
        if player then
            btn.player = player
            local r, g, b = BadStorms.GetClassColor(player.class)

            local hasSR = currentItemId and PlayerHasReservation(currentItemId, player.name) or 0
            btn.text:SetText(player.name)
            btn.text:SetTextColor(r, g, b)
            if hasSR > 0 then
                local srPlus = currentItemId and GetPlayerSRPlus(currentItemId, player.name) or 0
                if srPlus > 0 then
                    btn.srText:SetText("SR +" .. srPlus)
                else
                    btn.srText:SetText(hasSR > 1 and "SR x" .. hasSR or "SR")
                end
                btn.srText:SetTextColor(1, 0.82, 0)
            else
                btn.srText:SetText("")
            end

            btn.selectedTexture:Hide()
            btn:Show()
        else
            btn.player = nil
            btn:Hide()
        end
    end
end

function BadStorms.CreateItemTooltip(frame, parent)
    parent:SetScript("OnEnter", function(self)
        if frame.data and frame.data.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local success = pcall(GameTooltip.SetHyperlink, GameTooltip, frame.data.link)
            if success then
                local itemId = GetItemID(frame.data.link)
                BadStorms.AppendSRTooltip(itemId)
                GameTooltip:Show()
            end
        end
    end)
    parent:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)
end

function BadStorms.ShowAwardDialog(bag, slot, link)
    BadStorms.CreateConfigFrame()
    local frame = BadStorms.configFrame
    BadStorms.UpdateItemSelection(frame, link, bag, slot)
    frame:SelectTab("award")
    BadStorms.PopulatePlayerList(frame)
    frame:Show()
end

function BadStorms.ShowAwardDialogForLoot(lootSlot, link)
    BadStorms.CreateConfigFrame()
    local frame = BadStorms.configFrame
    BadStorms.UpdateItemSelection(frame, link)
    frame.data.lootSlot = lootSlot
    frame:SelectTab("award")
    BadStorms.PopulatePlayerList(frame)
    frame:Show()
end

BadStorms.PlayersMenu = BadStorms.ShowAwardDialog

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if button ~= "LeftButton" or not IsAltKeyDown() then
        return
    end
    if not BadStormsSettings.enabled then
        local msg = "Addon automation is disabled. Enable it in /badstorms settings."
        print("|cff00ff00BadStorms:|r" .. msg)
        return
    end
    if not BadStorms.CanManageLoot() then
        local inGroup = BadStorms.InGroup()
        if inGroup then
            local msg = "You do not have permission to manage loot."
            print("|cff00ff00BadStorms:|r " .. msg)
            return
        end
    end

    local bag = self:GetParent():GetID()
    local slot = self:GetID()
    local link = GetContainerItemLink(bag, slot)

    if link then
        if IsShiftKeyDown() then
            BadStorms.PlayersMenu(bag, slot, link)
        else
            BadStorms.CreateConfigFrame()
            local f = BadStorms.configFrame
            if BadStorms.isRolling then
                print("|cff00ff00BadStorms:|r Cannot change item during an active roll.")
                return
            end
            BadStorms.UpdateItemSelection(f, link, bag, slot)
            f:SelectTab("roll")
            f:Show()
        end
    end
end)
