local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID
local SendToChannel = BadStorms.SendToChannel
local ShowSRImportDialog = BadStorms.ShowSRImportDialog
local AppendSRTooltip = BadStorms.AppendSRTooltip
local UpdateRollDisplay = BadStorms.UpdateRollDisplay
local UpdateItemSelection = BadStorms.UpdateItemSelection
local PopulatePlayerList = BadStorms.PopulatePlayerList
local CreateItemTooltip = BadStorms.CreateItemTooltip
local BossIDs = BadStorms.BossIDs

local function CheckAutoMasterLoot()
    if not BadStormsSettings.autoMasterLoot then
        return
    end
    if not UnitExists("target") then
        return
    end
    local guid = UnitGUID("target")
    if not guid then
        return
    end

    local isBoss
    if guid:find("-") then
        local _, _, _, _, _, mobID = strsplit("-", guid)
        mobID = tonumber(mobID)
        isBoss = mobID and BossIDs[mobID]
    else
        local hex = guid:sub(3)
        if #hex == 16 then
            local mobID = tonumber(hex:sub(7, 10), 16)
            isBoss = mobID and BossIDs[mobID]
        end
        if not isBoss then
            isBoss = UnitClassification("target") == "worldboss" or UnitLevel("target") == -1
        end
    end

    if not isBoss then
        return
    end
    if not BadStorms.InGroup() then
        return
    end
    if not IsPartyLeader() and not IsRaidLeader() and not IsRaidOfficer() then
        return
    end
    if GetLootMethod() == "master" then
        return
    end
    SetLootMethod("master", "player")
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "BadStormsMinimapButton", UIParent)
    btn:SetSize(28, 28)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(100)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_StormReach")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")

    local dragging = false

    local function GetRadius()
        return Minimap:GetWidth() / 2 * 0.85
    end

    local function UpdatePosition(angleDeg)
        local r = GetRadius()
        local angle = math.rad(angleDeg)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
    end
    UpdatePosition(BadStormsSettings.minimapPos)

    btn:SetScript("OnDragStart", function()
        dragging = true
    end)
    btn:SetScript("OnDragStop", function()
        dragging = false
        local cx, cy = Minimap:GetCenter()
        local bx, by = btn:GetCenter()
        BadStormsSettings.minimapPos = math.deg(math.atan2(by - cy, bx - cx))
        UpdatePosition(BadStormsSettings.minimapPos)
    end)
    btn:SetScript("OnUpdate", function()
        if not dragging then
            return
        end
        local cx, cy = Minimap:GetCenter()
        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local dx = mx / scale - cx
        local dy = my / scale - cy
        BadStormsSettings.minimapPos = math.deg(math.atan2(dy, dx))
        UpdatePosition(BadStormsSettings.minimapPos)
    end)

    btn:SetScript("OnClick", function()
        BadStorms:ToggleConfigFrame()
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Bad Storms Loot Assistant")
        GameTooltip:AddLine("Click to open menu", 0.82, 0.82, 0.82)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    BadStorms.minimapButton = btn
end

local function CreateConfigFrame()
    if BadStorms.configFrame then
        return
    end

    local frame = CreateFrame("Frame", "BadStormsDialogFrame", UIParent)
    frame:SetSize(640, 440)
    local pos = BadStormsSettings.framePos
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = {
            left = 1,
            right = 1,
            top = 1,
            bottom = 1
        }
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local a, b, c, x, y = self:GetPoint(1)
        if a then
            BadStormsSettings.framePos = {
                point = a,
                relativeTo = b,
                relativePoint = c,
                xOfs = x,
                yOfs = y
            }
        end
    end)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnReceiveDrag", function(self)
        local cursorType, link = GetCursorInfo()
        if cursorType == "item" and link then
            ClearCursor()
            UpdateItemSelection(frame, link)
            frame:SelectTab("award")
            PopulatePlayerList(frame)
            frame:Show()
        end
    end)

    frame.titleIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.titleIcon:SetTexture("Interface\\Icons\\Spell_Nature_StormReach")
    frame.titleIcon:SetSize(24, 24)
    frame.titleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -13)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.title:SetPoint("LEFT", frame.titleIcon, "RIGHT", 6, 0)
    frame.title:SetText("Bad Storms Loot Assistant")
    frame.title:SetWidth(320)
    frame.title:SetJustifyH("LEFT")

    local settingsTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    settingsTab:SetSize(100, 24)
    settingsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -50)
    settingsTab:SetText("General")

    local awardTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    awardTab:SetSize(100, 24)
    awardTab:SetPoint("LEFT", settingsTab, "RIGHT", 4, 0)
    awardTab:SetText("Award Item")

    local rollTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    rollTab:SetSize(100, 24)
    rollTab:SetPoint("LEFT", awardTab, "RIGHT", 4, 0)
    rollTab:SetText("Roll Item")

    local plusOneTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    plusOneTab:SetSize(90, 24)
    plusOneTab:SetPoint("LEFT", rollTab, "RIGHT", 4, 0)
    plusOneTab:SetText("Plus Ones")

    local srTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    srTab:SetSize(120, 24)
    srTab:SetPoint("LEFT", plusOneTab, "RIGHT", 4, 0)
    srTab:SetText("Soft-Reserves")

    local exportTab = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    exportTab:SetSize(80, 24)
    exportTab:SetPoint("LEFT", srTab, "RIGHT", 4, 0)
    exportTab:SetText("Export")

    local settingsPanel = CreateFrame("Frame", nil, frame)
    settingsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    settingsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)

    local awardPanel = CreateFrame("Frame", nil, frame)
    awardPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    awardPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    awardPanel:EnableMouse(true)
    awardPanel:RegisterForDrag("LeftButton")
    awardPanel:SetScript("OnReceiveDrag", function(self)
        local cursorType, link = GetCursorInfo()
        if cursorType == "item" and link then
            ClearCursor()
            UpdateItemSelection(frame, link)
            frame:SelectTab("award")
            PopulatePlayerList(frame)
            frame:Show()
        end
    end)

    local rollPanel = CreateFrame("Frame", nil, frame)
    rollPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    rollPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    rollPanel:EnableMouse(true)
    rollPanel:RegisterForDrag("LeftButton")
    rollPanel:SetScript("OnReceiveDrag", function(self)
        local cursorType, link = GetCursorInfo()
        if cursorType == "item" and link then
            ClearCursor()
            if BadStorms.isRolling then
                print("|cff00ff00BadStorms:|r Cannot change item during an active roll.")
                return
            end
            UpdateItemSelection(frame, link)
            BadStorms.currentRolls = {}
            frame.selectedRollLabel:SetText("Player: None")
            for _, btn in ipairs(frame.rollButtons) do
                btn.selectedTexture:Hide()
                btn.rollData = nil
                btn:Hide()
            end
            frame.rollAssignButton:Disable()
            frame.startRollButton:Disable()
            frame:SelectTab("roll")
            frame:Show()
        end
    end)

    -- SR panel
    local srPanel = CreateFrame("Frame", nil, frame)
    srPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    srPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    srPanel:EnableMouseWheel(true)

    local srImportBtn = CreateFrame("Button", nil, srPanel, "GameMenuButtonTemplate")
    srImportBtn:SetSize(80, 24)
    srImportBtn:SetPoint("BOTTOMLEFT", srPanel, "BOTTOMLEFT", 0, 10)
    srImportBtn:SetText("Import")
    srImportBtn:SetScript("OnClick", function()
        ShowSRImportDialog()
    end)

    local srCountText = srPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    srCountText:SetPoint("RIGHT", srPanel, "TOPRIGHT", 0, 0)
    srCountText:SetText("")

    local srRefreshBtn = CreateFrame("Button", nil, srPanel, "GameMenuButtonTemplate")
    srRefreshBtn:SetSize(80, 24)
    srRefreshBtn:SetPoint("RIGHT", srCountText, "LEFT", -8, 0)
    srRefreshBtn:SetText("Refresh")
    srRefreshBtn:SetScript("OnClick", function()
        frame.PopulateSRList()
    end)

    local srAnnounceBtn = CreateFrame("Button", nil, srPanel, "GameMenuButtonTemplate")
    srAnnounceBtn:SetSize(130, 24)
    srAnnounceBtn:SetText("Announce Missing")
    srAnnounceBtn:SetPoint("RIGHT", srRefreshBtn, "LEFT", -4, 0)
    srAnnounceBtn:SetScript("OnClick", function()
        local reservations = BadStormsSettings.srReservations or {}
        local srNames = {}
        for _, r in ipairs(reservations) do
            srNames[r.name:lower()] = true
        end
        local missing = {}
        local raidCount = GetNumRaidMembers()
        local partyCount = GetNumPartyMembers()
        if raidCount > 0 then
            for i = 1, raidCount do
                local name = GetRaidRosterInfo(i)
                if name and not srNames[name:lower()] then
                    table.insert(missing, name)
                end
            end
        elseif partyCount > 0 then
            local myName = UnitName("player")
            if myName and not srNames[myName:lower()] then
                table.insert(missing, myName)
            end
            for i = 1, partyCount do
                local name = UnitName("party" .. i)
                if name and not srNames[name:lower()] then
                    table.insert(missing, name)
                end
            end
        end
        if #missing == 0 then
            local msg = "All players have soft reserves."
            if BadStorms.CanRaidWarning() then
                SendChatMessage(msg, "RAID_WARNING")
            elseif GetNumRaidMembers() > 0 then
                SendChatMessage(msg, "RAID")
            elseif GetNumPartyMembers() > 0 then
                SendChatMessage(msg, "PARTY")
            else
                print("|cff00ff00BadStorms:|r " .. msg)
            end
            return
        end
        table.sort(missing)
        local msg = "Missing SR: " .. table.concat(missing, ", ")
        if BadStorms.CanRaidWarning() then
            SendChatMessage(msg, "RAID_WARNING")
        elseif GetNumRaidMembers() > 0 then
            SendChatMessage(msg, "RAID")
        elseif GetNumPartyMembers() > 0 then
            SendChatMessage(msg, "PARTY")
        else
            print("|cff00ff00BadStorms:|r " .. msg)
        end
    end)

    local srScrollIdx = 0
    local SR_VISIBLE = 10
    local ROW_GAP = 24
    local ROW_HEIGHT = 22

    srPanel:SetScript("OnMouseWheel", function(self, delta)
        local items = frame.srItemList or {}
        srScrollIdx = math.max(0, math.min(srScrollIdx - delta, #items - SR_VISIBLE))
        frame.PopulateSRList()
    end)

    frame.srButtons = {}
    for i = 1, SR_VISIBLE do
        local btn = CreateFrame("Button", nil, srPanel)
        btn:SetPoint("TOPLEFT", srPanel, "TOPLEFT", 4, -20 - (i - 1) * ROW_GAP)
        btn:SetPoint("TOPRIGHT", srPanel, "TOPRIGHT", -4, -20 - (i - 1) * ROW_GAP)
        btn:SetHeight(ROW_HEIGHT)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.2)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        hl:SetAllPoints()
        hl:Hide()
        btn.highlight = hl

        btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.nameText:SetPoint("LEFT", btn, "LEFT", 4, 0)
        btn.nameText:SetWidth(200)
        btn.nameText:SetJustifyH("LEFT")

        btn.itemButtons = {}
        for j = 1, 1 do
            local itemBtn = CreateFrame("Button", nil, btn)
            itemBtn:SetHeight(22)
            itemBtn:Hide()

            local hl2 = itemBtn:CreateTexture(nil, "HIGHLIGHT")
            hl2:SetTexture("Interface\\Buttons\\WHITE8X8")
            hl2:SetVertexColor(1, 1, 1, 0.15)
            hl2:SetAllPoints()
            itemBtn.highlight = hl2

            itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemBtn.text:SetPoint("LEFT", itemBtn, "LEFT", 2, 0)
            itemBtn.text:SetJustifyH("LEFT")

            itemBtn:SetScript("OnEnter", function(self)
                local parent = self:GetParent()
                parent.highlight:Show()
                self.highlight:Show()
                if self.itemId then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. self.itemId)
                    GameTooltip:Show()
                end
            end)
            itemBtn:SetScript("OnLeave", function(self)
                self:GetParent().highlight:Hide()
                self.highlight:Hide()
                GameTooltip_Hide()
            end)

            btn.itemButtons[j] = itemBtn
        end

        btn:Hide()
        frame.srButtons[i] = btn
    end

    local function PopulateSRList()
        local reservations = BadStormsSettings.srReservations or {}
        local playerMap = {}
        for _, r in ipairs(reservations) do
            if not playerMap[r.name] then
                playerMap[r.name] = {}
            end
            local count = (tonumber(r.plus) or 0) + 1
            local key = tostring(r.itemId)
            if not playerMap[r.name][key] then
                playerMap[r.name][key] = {
                    item = r.item,
                    itemId = r.itemId,
                    count = 0,
                    received = 0
                }
            end
            playerMap[r.name][key].count = playerMap[r.name][key].count + count
            if r.received then
                playerMap[r.name][key].received = playerMap[r.name][key].received + count
            end
        end

        local playerList = {}
        local nameOrder = {}
        for name in pairs(playerMap) do
            table.insert(nameOrder, name)
        end
        table.sort(nameOrder)
        for _, name in ipairs(nameOrder) do
            local itemMap = playerMap[name]
            local itemList = {}
            for _, data in pairs(itemMap) do
                table.insert(itemList, data)
            end
            table.sort(itemList, function(a, b) return (a.item or "") < (b.item or "") end)
            for _, data in ipairs(itemList) do
                table.insert(playerList, { name = name, item = data })
            end
        end

        local srNames = {}
        for _, entry in ipairs(playerList) do
            srNames[entry.name:lower()] = true
        end
        local raidCount = GetNumRaidMembers()
        local partyCount = GetNumPartyMembers()
        if raidCount > 0 then
            for i = 1, raidCount do
                local name = GetRaidRosterInfo(i)
                if name and not srNames[name:lower()] then
                    table.insert(playerList, { name = name, noSR = true })
                    srNames[name:lower()] = true
                end
            end
        elseif partyCount > 0 then
            local myName = UnitName("player")
            if myName and not srNames[myName:lower()] then
                table.insert(playerList, { name = myName, noSR = true })
                srNames[myName:lower()] = true
            end
            for i = 1, partyCount do
                local name = UnitName("party" .. i)
                if name and not srNames[name:lower()] then
                    table.insert(playerList, { name = name, noSR = true })
                    srNames[name:lower()] = true
                end
            end
        end

        frame.srItemList = playerList

        local srCount = 0
        for _ in pairs(playerMap) do
            srCount = srCount + 1
        end
        srCountText:SetText(srCount .. " player(s) with SR")

        local hasAnyReservation = next(playerMap) ~= nil
        if not hasAnyReservation then
            ShowSRImportDialog()
        end

        local prevName = ""
        for i, btn in ipairs(frame.srButtons) do
            local entry = playerList[srScrollIdx + i]
            if entry then
                if entry.name == prevName then
                    btn.nameText:SetText("")
                elseif entry.noSR then
                    btn.nameText:SetText("|cffff4444" .. entry.name .. "|r")
                else
                    local unit = BadStorms.GetPlayerUnit(entry.name)
                    local _, class
                    if unit then
                        _, class = UnitClass(unit)
                    end
                    if class then
                        local r, g, b = BadStorms.GetClassColor(class)
                        local hex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                        btn.nameText:SetText(hex .. entry.name .. "|r")
                    else
                        btn.nameText:SetText(entry.name)
                    end
                end
                prevName = entry.name

                local data = entry.item
                if data then
                    local itemBtn = btn.itemButtons[1]

                    local itemName = data.item or ("Item " .. data.itemId)
                    local itemLink = GetItemInfo(data.itemId)
                    if not itemLink then
                        itemLink = "|cffffffff|Hitem:" .. data.itemId .. ":::::::::::::::::|h[" .. itemName .. "]|h|r"
                    end

                    local displayName = itemName
                    if data.count > 1 then
                        displayName = displayName .. " x" .. data.count
                    end
                    if data.received > 0 and data.received >= data.count then
                        displayName = "|cff888888" .. displayName .. " (Received)|r"
                    else
                        local _, _, quality = GetItemInfo(data.itemId)
                        if quality then
                            local qColor = ITEM_QUALITY_COLORS[quality]
                            local hex = string.format("|cff%02x%02x%02x", qColor.r * 255, qColor.g * 255, qColor.b * 255)
                            displayName = hex .. displayName .. "|r"
                        end
                        if data.received > 0 then
                            displayName = displayName .. " (" .. (data.count - data.received) .. "/" .. data.count .. ")"
                        end
                    end

                    itemBtn.text:SetText(displayName)
                    itemBtn.text:SetWidth(0)
                    local textWidth = itemBtn.text:GetStringWidth() or 10
                    local maxWidth = btn:GetWidth() - 216
                    local btnWidth = math.min(textWidth + 8, math.max(maxWidth, 20))
                    itemBtn:SetSize(btnWidth, 22)
                    itemBtn.text:SetWidth(btnWidth - 4)
                    itemBtn:ClearAllPoints()
                    itemBtn:SetPoint("LEFT", btn, "LEFT", 208, 0)
                    itemBtn.itemLink = itemLink
                    itemBtn.itemId = data.itemId
                    itemBtn:Show()
                else
                    btn.itemButtons[1]:Hide()
                end

                btn:Show()
            else
                btn:Hide()
            end
        end
    end
    frame.PopulateSRList = PopulateSRList

    -- Export panel
    local exportPanel = CreateFrame("Frame", nil, frame)
    exportPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    exportPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)

    local plusOnesPanel = CreateFrame("Frame", nil, frame)
    plusOnesPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -94)
    plusOnesPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)

    -- Settings panel
    local autoLootCheckbox
    local enableCheckbox = CreateFrame("CheckButton", "BadStormsEnableCheckbox", settingsPanel,
        "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 0, 0)
    _G["BadStormsEnableCheckboxText"]:SetText("Enable Loot Assistant Automation (Requires Master Looter)")
    enableCheckbox:SetChecked(BadStormsSettings.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.enabled = self:GetChecked()
        if BadStormsSettings.enabled then
            autoLootCheckbox:Enable()
        else
            autoLootCheckbox:Disable()
        end
    end)

    local enableHelp = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enableHelp:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 24, -2)
    enableHelp:SetWidth(440)
    enableHelp:SetJustifyH("LEFT")
    enableHelp:SetText(
        "Enables ALT+CLICK to roll items, ALT+SHIFT+CLICK to award items, drag & drop, and auto-looting all items to the Master Looter.")

    autoLootCheckbox = CreateFrame("CheckButton", "BadStormsAutoLootCheckbox", settingsPanel,
        "InterfaceOptionsCheckButtonTemplate")
    autoLootCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -36)
    _G["BadStormsAutoLootCheckboxText"]:SetText("Enable Auto-Loot (Hold SHIFT to Bypass)")
    autoLootCheckbox:SetChecked(BadStormsSettings.autoloot)
    if BadStormsSettings.enabled then
        autoLootCheckbox:Enable()
    else
        autoLootCheckbox:Disable()
    end
    autoLootCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.autoloot = self:GetChecked()
    end)

    local autoLootWarning = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoLootWarning:SetPoint("TOPLEFT", autoLootCheckbox, "BOTTOMLEFT", 24, 0)
    autoLootWarning:SetWidth(440)
    autoLootWarning:SetJustifyH("LEFT")
    autoLootWarning:SetTextColor(1, 0.5, 0.5)
    autoLootWarning:SetText("WARNING: This will loot ALL items to you.")

    local autoMLCheckbox = CreateFrame("CheckButton", "BadStormsAutoMLCheckbox", settingsPanel,
        "InterfaceOptionsCheckButtonTemplate")
    autoMLCheckbox:SetPoint("TOPLEFT", autoLootCheckbox, "BOTTOMLEFT", 0, -20)
    _G["BadStormsAutoMLCheckboxText"]:SetText("Enable Auto-Switch to Master Looter (Requires Group Leader)")
    autoMLCheckbox:SetChecked(BadStormsSettings.autoMasterLoot)
    autoMLCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.autoMasterLoot = self:GetChecked()
        if BadStormsSettings.autoMasterLoot then
            CheckAutoMasterLoot()
        end
    end)

    local autoMLHelp = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoMLHelp:SetPoint("TOPLEFT", autoMLCheckbox, "BOTTOMLEFT", 24, 0)
    autoMLHelp:SetWidth(440)
    autoMLHelp:SetJustifyH("LEFT")
    autoMLHelp:SetText("Attempts set Master Looter when targeting a boss.")
    autoMLHelp:SetTextColor(1, 0.82, 0)

    local disenchanterCheckbox
    local disenchanterText
    disenchanterCheckbox = CreateFrame("CheckButton", "BadStormsDisenchanterCheckbox", settingsPanel,
        "InterfaceOptionsCheckButtonTemplate")
    disenchanterCheckbox:SetPoint("TOPLEFT", autoMLCheckbox, "BOTTOMLEFT", 0, -18)
    _G["BadStormsDisenchanterCheckboxText"]:SetText("Enable Disenchanter (Requires Master Looter)")
    disenchanterCheckbox:SetChecked(BadStormsSettings.disenchanterEnabled)
    disenchanterCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.disenchanterEnabled = self:GetChecked()
        if frame.disenchantRollButton then
            if BadStormsSettings.disenchanterEnabled and BadStormsSettings.disenchanter ~= "" and frame.data and frame.data.link then
                frame.disenchantRollButton:Enable()
            else
                frame.disenchantRollButton:Disable()
            end
        end
        if frame.awardDisenchantButton then
            if BadStormsSettings.disenchanterEnabled and BadStormsSettings.disenchanter ~= "" and frame.data and frame.data.link then
                frame.awardDisenchantButton:Enable()
            else
                frame.awardDisenchantButton:Disable()
            end
        end
    end)

    local disenchanterHelp = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    disenchanterHelp:SetPoint("TOPLEFT", disenchanterCheckbox, "BOTTOMLEFT", 24, -2)
    disenchanterHelp:SetWidth(440)
    disenchanterHelp:SetJustifyH("LEFT")
    disenchanterHelp:SetText("Sends items to be disenchanted to the selected player.")
    disenchanterHelp:SetTextColor(1, 0.82, 0)

    local disenchanterLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    disenchanterLabel:SetPoint("LEFT", disenchanterCheckbox, "RIGHT", 285, 0)
    disenchanterLabel:SetText("Player:")

    local disenchanterText = CreateFrame("EditBox", "BadStormsDisenchanterText", settingsPanel, "InputBoxTemplate")
    disenchanterText:SetPoint("LEFT", disenchanterLabel, "RIGHT", 8, 0)
    disenchanterText:SetWidth(140)
    disenchanterText:SetHeight(20)
    disenchanterText:SetText(BadStormsSettings.disenchanter or "")
    disenchanterText:SetAutoFocus(false)
    disenchanterText:SetTextInsets(2, 0, 0, 0)
    disenchanterText:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        CloseDropDownMenus()
    end)
    disenchanterText:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        CloseDropDownMenus()
    end)
    disenchanterText:SetScript("OnTabPressed", function(self)
        self:ClearFocus()
        CloseDropDownMenus()
    end)
    disenchanterText:SetScript("OnTextChanged", function(self)
        BadStormsSettings.disenchanter = self:GetText()
    end)
    disenchanterText:SetBackdropBorderColor(0.6, 0.6, 0.6)

    local disenchanterMenu = CreateFrame("Frame", "BadStormsDisenchanterMenu", UIParent, "UIDropDownMenuTemplate")

    local function InitDisenchanterMenu(self, level, menuList)
        if not BadStormsSettings.disenchanterEnabled then
            return
        end
        local seen = {}
        local function AddPlayer(name)
            if name and not seen[name] then
                seen[name] = true
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    disenchanterText:SetText(name)
                    BadStormsSettings.disenchanter = name
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end

        AddPlayer(UnitName("player"))
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                AddPlayer(GetRaidRosterInfo(i))
            end
        else
            for i = 1, GetNumPartyMembers() do
                AddPlayer(UnitName("party" .. i))
            end
        end
    end

    UIDropDownMenu_Initialize(disenchanterMenu, InitDisenchanterMenu)

    disenchanterText:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        if not BadStormsSettings.disenchanterEnabled then
            return
        end
        self:ClearFocus()
        CloseDropDownMenus()
        ToggleDropDownMenu(1, nil, disenchanterMenu, self:GetName(), 0, 0)
    end)

    local hideMinimapCheckbox = CreateFrame("CheckButton", "BadStormsHideMinimapCheckbox", settingsPanel,
        "InterfaceOptionsCheckButtonTemplate")
    hideMinimapCheckbox:SetPoint("TOPLEFT", disenchanterCheckbox, "BOTTOMLEFT", 0, -20)
    _G["BadStormsHideMinimapCheckboxText"]:SetText("Show Minimap Button")
    hideMinimapCheckbox:SetChecked(not BadStormsSettings.hideMinimap)
    hideMinimapCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.hideMinimap = not self:GetChecked()
        if BadStormsSettings.hideMinimap then
            if BadStorms.minimapButton then
                BadStorms.minimapButton:Hide()
            end
        elseif not BadStorms.minimapButton then
            CreateMinimapButton()
        else
            BadStorms.minimapButton:Show()
        end
    end)

    local notesTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesTitle:SetPoint("TOPLEFT", hideMinimapCheckbox, "BOTTOMLEFT", 0, -16)
    notesTitle:SetText("Usage:")

    local notes = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    notes:SetPoint("TOPLEFT", notesTitle, "BOTTOMLEFT", 0, 5)
    notes:SetWidth(520)
    notes:SetJustifyH("LEFT")
    notes:SetText(
        "\n|cff66ccffALT+CLICK |r an item in your bags, loot window, or chat to open the Roll tab.\n|cff66ccffALT+SHIFT+CLICK|r an item in your bags, loot window, or chat to open the Award tab.\n|cff66ccffCTRL+SCROLL|r on the frame to adjust the UI scale.\n|cff66ccffCTRL+RIGHT CLICK|r on the frame to reset the UI scale to 1.")

    -- Award panel
    frame.itemIcon = CreateFrame("Button", nil, awardPanel)
    frame.itemIcon:SetSize(36, 36)
    frame.itemIcon:SetPoint("TOPLEFT", awardPanel, "TOPLEFT", 0, 0)
    frame.itemIcon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame.itemIcon:SetBackdropBorderColor(0.5, 0.5, 0.5)
    frame.itemIcon.texture = frame.itemIcon:CreateTexture(nil, "BACKGROUND")
    frame.itemIcon.texture:SetAllPoints()
    frame.itemIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.itemIcon:EnableMouse(true)
    frame.itemIcon:RegisterForDrag("LeftButton")
    frame.itemIcon:SetScript("OnReceiveDrag", function(self)
        local cursorType, link = GetCursorInfo()
        if cursorType == "item" and link then
            ClearCursor()
            UpdateItemSelection(frame, link)
            frame:SelectTab("award")
        end
    end)
    CreateItemTooltip(frame, frame.itemIcon)

    frame.linkText = CreateFrame("Button", nil, awardPanel)
    frame.linkText:SetPoint("TOPLEFT", frame.itemIcon, "TOPRIGHT", 8, 0)
    frame.linkText:SetSize(260, 30)
    frame.linkText.text = frame.linkText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.linkText.text:SetPoint("LEFT", frame.linkText, "LEFT", 0, 0)
    frame.linkText.text:SetJustifyH("LEFT")
    frame.linkText.text:SetText("ALT+SHIFT+CLICK or Drag & Drop an Item")
    CreateItemTooltip(frame, frame.linkText)
    frame.linkText:SetScript("OnReceiveDrag", function(self)
        local cursorType, link = GetCursorInfo()
        if cursorType == "item" and link then
            ClearCursor()
            UpdateItemSelection(frame, link)
            frame:SelectTab("award")
        end
    end)

    frame.srText = awardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.srText:SetPoint("TOPLEFT", frame.linkText, "BOTTOMLEFT", 0, -2)
    frame.srText:SetWidth(420)
    frame.srText:SetJustifyH("LEFT")

    frame.selectedLabel = awardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.selectedLabel:SetPoint("TOPLEFT", frame.srText, "BOTTOMLEFT", 0, -12)
    frame.selectedLabel:SetText("Player: None")

    local awardScroll = CreateFrame("ScrollFrame", nil, awardPanel)
    awardScroll:EnableMouseWheel(true)
    awardScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local val = self:GetVerticalScroll() - delta * 20
        self:SetVerticalScroll(math.max(0, math.min(val, range)))
    end)
    awardScroll:SetPoint("TOPLEFT", awardPanel, "TOPLEFT", 8, -75)
    awardScroll:SetPoint("TOPRIGHT", awardPanel, "TOPRIGHT", -8, -75)
    awardScroll:SetHeight(220)

    --[[ -- Red Border
    awardScroll:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    
    awardScroll:SetBackdropBorderColor(1, 0, 0, 1)
    --]]

    local awardScrollChild = CreateFrame("Frame", nil, awardScroll)
    awardScrollChild:SetSize(620, 960)
    awardScroll:SetScrollChild(awardScrollChild)

    frame.playerButtons = {}
    for i = 1, 40 do
        local btn = CreateFrame("Button", nil, awardScrollChild)
        btn:SetPoint("TOPLEFT", awardScrollChild, "TOPLEFT", 4, -(i - 1) * 24)
        btn:SetPoint("TOPRIGHT", awardScrollChild, "TOPRIGHT", -4, -(i - 1) * 24)
        btn:SetHeight(22)

        btn.background = btn:CreateTexture(nil, "BACKGROUND")
        btn.background:SetAllPoints()
        btn.background:SetTexture(0, 0, 0, 0.2)

        btn.selectedTexture = btn:CreateTexture(nil, "BACKGROUND")
        btn.selectedTexture:SetAllPoints()
        btn.selectedTexture:SetTexture(1, 0.82, 0, 0.25)
        btn.selectedTexture:Hide()

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        hl:SetAllPoints()
        btn:SetHighlightTexture(hl)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.text:SetWidth(220)
        btn.text:SetTextColor(1, 1, 1)

        btn.srText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.srText:SetPoint("LEFT", btn, "LEFT", 260, 0)
        btn.srText:SetWidth(50)

        btn:SetScript("OnClick", function(self)
            frame.selected = self.player
            frame.selectedLabel:SetText("Player: " .. self.player.name)
            for _, other in ipairs(frame.playerButtons) do
                if other == self then
                    other.selectedTexture:Show()
                else
                    other.selectedTexture:Hide()
                end
            end
            frame.awardButton:Enable()
        end)

        btn:Hide()
        frame.playerButtons[i] = btn
    end

    frame.awardButton = CreateFrame("Button", nil, awardPanel, "GameMenuButtonTemplate")
    frame.awardButton:SetSize(76, 24)
    frame.awardButton:SetPoint("LEFT", frame.selectedLabel, "RIGHT", 8, 0)
    frame.awardButton:SetFrameLevel(awardPanel:GetFrameLevel() + 10)
    frame.awardButton:SetText("Award")
    frame.awardButton:Disable()
    frame.awardButton:SetScript("OnClick", function()
        local inGroup = BadStorms.InGroup()
        if inGroup and not BadStorms.CanManageLoot() then
            print("|cff00ff00BadStorms:|r You do not have permission to award items.")
            return
        end
        local selected = frame.selected
        if not selected then
            print("|cff00ff00BadStorms:|r Select a player first.")
            return
        end
        local data = frame.data
        if not data or not data.link then
            return
        end
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end
        StaticPopup_Show("BadStormsConfirmAssign", data.link, selected.name, {
            name = selected.name,
            unit = selected.unit,
            link = data.link,
            bag = data.bag,
            slot = data.slot,
            lootSlot = data.lootSlot,
            note = "Award"
        })
    end)

    frame.awardClearButton = CreateFrame("Button", nil, awardPanel, "GameMenuButtonTemplate")
    frame.awardClearButton:SetSize(76, 24)
    frame.awardClearButton:SetPoint("LEFT", frame.awardButton, "RIGHT", 4, 0)
    frame.awardClearButton:SetFrameLevel(awardPanel:GetFrameLevel() + 10)
    frame.awardClearButton:SetText("Clear")
    frame.awardClearButton:SetScript("OnClick", function()
        frame.data = nil
        frame.selected = nil
        frame.linkText.text:SetText("ALT+SHIFT+CLICK or Drag & Drop an Item")
        frame.itemIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        frame.itemIcon:SetBackdropBorderColor(0.5, 0.5, 0.5)
        frame.selectedLabel:SetText("Player: None")
        for _, btn in ipairs(frame.playerButtons) do
            btn.selectedTexture:Hide()
        end
        frame.awardButton:Disable()
        if frame.awardDisenchantButton then
            frame.awardDisenchantButton:Disable()
        end
    end)

    frame.awardDisenchantButton = CreateFrame("Button", nil, awardPanel, "GameMenuButtonTemplate")
    frame.awardDisenchantButton:SetSize(82, 24)
    frame.awardDisenchantButton:SetPoint("LEFT", frame.awardClearButton, "RIGHT", 4, 0)
    frame.awardDisenchantButton:SetFrameLevel(awardPanel:GetFrameLevel() + 10)
    frame.awardDisenchantButton:SetText("Disenchant")
    frame.awardDisenchantButton:SetScript("OnClick", function()
        if not BadStormsSettings.disenchanterEnabled or BadStormsSettings.disenchanter == "" then
            return
        end
        local data = frame.data
        if not data or not data.link then
            return
        end
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end
        if not BadStorms.IsItemEquippable(data.link) then
            print("|cff00ff00BadStorms:|r Item must be equippable to disenchant.")
            return
        end
        StaticPopup_Show("BadStormsDisenchantConfirm", data.link, BadStormsSettings.disenchanter, {
            link = data.link,
            lootSlot = data.lootSlot,
            bag = data.bag,
            slot = data.slot,
            disenchanter = BadStormsSettings.disenchanter,
        })
    end)
    frame.awardDisenchantButton:SetScript("OnEnter", function(self)
        if not BadStormsSettings.disenchanterEnabled or BadStormsSettings.disenchanter == "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Disenchanter must be enabled and set for this feature.", 1, 0.82, 0, 1)
            GameTooltip:Show()
        end
    end)
    frame.awardDisenchantButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.itemIconRoll = CreateFrame("Button", nil, rollPanel)
    frame.itemIconRoll:SetSize(36, 36)
    frame.itemIconRoll:SetPoint("TOPLEFT", rollPanel, "TOPLEFT", 0, 0)
    frame.itemIconRoll:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame.itemIconRoll:SetBackdropBorderColor(0.5, 0.5, 0.5)
    frame.itemIconRoll.texture = frame.itemIconRoll:CreateTexture(nil, "BACKGROUND")
    frame.itemIconRoll.texture:SetAllPoints()
    frame.itemIconRoll.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    CreateItemTooltip(frame, frame.itemIconRoll)

    frame.linkTextRoll = CreateFrame("Button", nil, rollPanel)
    frame.linkTextRoll:SetPoint("TOPLEFT", frame.itemIconRoll, "TOPRIGHT", 8, 0)
    frame.linkTextRoll:SetSize(200, 30)
    frame.linkTextRoll.text = frame.linkTextRoll:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.linkTextRoll.text:SetPoint("LEFT", frame.linkTextRoll, "LEFT", 0, 0)
    frame.linkTextRoll.text:SetJustifyH("LEFT")
    frame.linkTextRoll.text:SetText("ALT+CLICK or Drag & Drop an Item")
    CreateItemTooltip(frame, frame.linkTextRoll)

    frame.rollTimerText = rollPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.rollTimerText:SetPoint("TOPRIGHT", rollPanel, "TOPRIGHT", 0, 0)
    frame.rollTimerText:SetText("Ready")

    frame.srTextRoll = rollPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.srTextRoll:SetPoint("TOPLEFT", frame.linkTextRoll, "BOTTOMLEFT", 0, -2)
    frame.srTextRoll:SetWidth(420)
    frame.srTextRoll:SetJustifyH("LEFT")

    frame.rollMSButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.rollMSButton:SetSize(80, 24)
    frame.rollMSButton:SetPoint("BOTTOM", rollPanel, "BOTTOM", -42, 0)
    frame.rollMSButton:SetText("Roll MS")
    frame.rollMSButton:SetScript("OnClick", function()
        RandomRoll(1, 100)
    end)

    frame.rollOSButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.rollOSButton:SetSize(80, 24)
    frame.rollOSButton:SetPoint("LEFT", frame.rollMSButton, "RIGHT", 4, 0)
    frame.rollOSButton:SetText("Roll OS")
    frame.rollOSButton:SetScript("OnClick", function()
        RandomRoll(1, 99)
    end)

    local rollScroll = CreateFrame("ScrollFrame", nil, rollPanel)
    rollScroll:EnableMouseWheel(true)
    rollScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local val = self:GetVerticalScroll() - delta * 20
        self:SetVerticalScroll(math.max(0, math.min(val, range)))
    end)
    rollScroll:SetPoint("TOPLEFT", rollPanel, "TOPLEFT", 8, -75)
    rollScroll:SetPoint("TOPRIGHT", rollPanel, "TOPRIGHT", -8, -75)
    rollScroll:SetHeight(220)

    --[[ -- Red Border
    rollScroll:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    
    rollScroll:SetBackdropBorderColor(1, 0, 0, 1)
    --]]

    local rollScrollChild = CreateFrame("Frame", nil, rollScroll)
    rollScrollChild:SetSize(620, 960)
    rollScroll:SetScrollChild(rollScrollChild)

    frame.rollButtons = {}
    for i = 1, 40 do
        local btn = CreateFrame("Button", nil, rollScrollChild)
        btn:SetPoint("TOPLEFT", rollScrollChild, "TOPLEFT", 4, -(i - 1) * 24)
        btn:SetPoint("TOPRIGHT", rollScrollChild, "TOPRIGHT", -4, -(i - 1) * 24)
        btn:SetHeight(22)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.2)

        btn.selectedTexture = btn:CreateTexture(nil, "BACKGROUND")
        btn.selectedTexture:SetAllPoints()
        btn.selectedTexture:SetTexture(1, 0.82, 0, 0.25)
        btn.selectedTexture:Hide()

        btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.nameText:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.nameText:SetWidth(210)

        btn.rollText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.rollText:SetPoint("LEFT", btn, "LEFT", 225, 0)
        btn.rollText:SetWidth(40)

        btn.specText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.specText:SetPoint("LEFT", btn, "LEFT", 290, 0)
        btn.specText:SetWidth(40)

        btn.srText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.srText:SetPoint("LEFT", btn, "LEFT", 340, 0)
        btn.srText:SetWidth(40)

        btn.plusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.plusText:SetPoint("LEFT", btn, "LEFT", 385, 0)
        btn.plusText:SetWidth(30)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        hl:SetAllPoints()
        btn:SetHighlightTexture(hl)

        btn:SetScript("OnClick", function(self)
            if not self.rollData then
                return
            end
            frame.selectedRoll = self.rollData
            frame.selectedRollLabel:SetText("Player: " .. self.rollData.name)
            for _, other in ipairs(frame.rollButtons) do
                if other == self then
                    other.selectedTexture:Show()
                else
                    other.selectedTexture:Hide()
                end
            end
            frame.rollAssignButton:Enable()
        end)

        btn:Hide()
        frame.rollButtons[i] = btn
    end

    frame.selectedRollLabel = rollPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.selectedRollLabel:SetPoint("TOPLEFT", frame.srTextRoll, "BOTTOMLEFT", 0, -12)
    frame.selectedRollLabel:SetText("Player: None")

    frame.rollAssignButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.rollAssignButton:SetSize(76, 24)
    frame.rollAssignButton:SetPoint("LEFT", frame.selectedRollLabel, "RIGHT", 8, 0)
    frame.rollAssignButton:SetFrameLevel(rollPanel:GetFrameLevel() + 10)
    frame.rollAssignButton:SetText("Award")
    frame.rollAssignButton:Disable()
    frame.rollAssignButton:SetScript("OnClick", function()
        local inGroup = BadStorms.InGroup()
        if inGroup and not BadStorms.CanManageLoot() then
            print("|cff00ff00BadStorms:|r You do not have permission to award items.")
            return
        end
        local selected = frame.selectedRoll
        if not selected then
            print("|cff00ff00BadStorms:|r Select a player from the roll list.")
            return
        end
        local data = frame.data
        if not data or not data.link then
            print("|cff00ff00BadStorms:|r No item selected.")
            return
        end
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end
        local rollNote = "Roll - " .. (selected.max == 100 and "MS" or "OS") .. " " .. selected.roll
        StaticPopup_Show("BadStormsConfirmAssign", data.link, selected.name, {
            name = selected.name,
            unit = selected.unit,
            link = data.link,
            bag = data.bag,
            slot = data.slot,
            lootSlot = data.lootSlot,
            note = rollNote
        })
    end)

    frame.rollClearButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.rollClearButton:SetSize(76, 24)
    frame.rollClearButton:SetPoint("LEFT", frame.rollAssignButton, "RIGHT", 4, 0)
    frame.rollClearButton:SetFrameLevel(rollPanel:GetFrameLevel() + 10)
    frame.rollClearButton:SetText("Clear")
    frame.rollClearButton:SetScript("OnClick", function()
        if BadStorms.isRolling then
            print("|cff00ff00BadStorms:|r Cannot clear during an active roll.")
            return
        end
        frame.data = nil
        frame.selectedRoll = nil
        BadStorms.currentRolls = {}
        frame.linkTextRoll.text:SetText("ALT+CLICK or Drag & Drop an Item")
        frame.itemIconRoll.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        frame.itemIconRoll:SetBackdropBorderColor(0.5, 0.5, 0.5)
        frame.selectedRollLabel:SetText("Player: None")
        for _, btn in ipairs(frame.rollButtons) do
            btn.selectedTexture:Hide()
            btn.rollData = nil
            btn:Hide()
        end
        frame.rollAssignButton:Disable()
        frame.startRollButton:Disable()
    end)

    frame.timerEdit = CreateFrame("EditBox", nil, rollPanel, "InputBoxTemplate")
    frame.timerEdit:SetSize(36, 18)
    frame.timerEdit:SetPoint("LEFT", frame.rollClearButton, "RIGHT", 4, 0)
    frame.timerEdit:SetAutoFocus(false)
    frame.timerEdit:SetNumeric(true)
    frame.timerEdit:SetMaxLetters(2)
    frame.timerEdit:SetJustifyH("CENTER")
    frame.timerEdit:SetText(tostring(BadStormsSettings.rollTimer))

    local function SetRollTimer(val)
        val = tonumber(val) or BadStormsSettings.rollTimer
        if val < 5 then
            val = 5
        end
        if val > 60 then
            val = 60
        end
        BadStormsSettings.rollTimer = val
        frame.timerEdit:SetText(tostring(val))
    end

    frame.timerEdit:SetScript("OnEnterPressed", function(self)
        SetRollTimer(tonumber(self:GetText()))
        self:ClearFocus()
    end)
    frame.timerEdit:SetScript("OnEditFocusLost", function(self)
        SetRollTimer(tonumber(self:GetText()))
    end)
    frame.timerEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("5-60, Time in Seconds")
        GameTooltip:Show()
    end)
    frame.timerEdit:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    frame.startRollButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.startRollButton:SetSize(76, 24)
    frame.startRollButton:SetPoint("LEFT", frame.timerEdit, "RIGHT", 4, 0)
    frame.startRollButton:SetText("Start")
    frame.startRollButton:Disable()
    frame.startRollButton:SetScript("OnClick", function()
        BadStorms.StartRoll(frame)
    end)

    frame.endRollButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.endRollButton:SetSize(76, 24)
    frame.endRollButton:SetPoint("LEFT", frame.startRollButton, "RIGHT", 4, 0)
    frame.endRollButton:SetText("End")
    frame.endRollButton:Disable()
    frame.endRollButton:SetScript("OnClick", function()
        BadStorms.EndRoll(frame)
    end)

    frame.disenchantRollButton = CreateFrame("Button", nil, rollPanel, "GameMenuButtonTemplate")
    frame.disenchantRollButton:SetSize(82, 24)
    frame.disenchantRollButton:SetPoint("LEFT", frame.endRollButton, "RIGHT", 4, 0)
    frame.disenchantRollButton:SetText("Disenchant")
    frame.disenchantRollButton:Disable()
    frame.disenchantRollButton:SetScript("OnClick", function()
        if not BadStormsSettings.disenchanterEnabled or BadStormsSettings.disenchanter == "" then
            return
        end
        local link = frame.data and frame.data.link
        if not link then
            return
        end
        local data = frame.data
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end
        if not BadStorms.IsItemEquippable(data.link) then
            print("|cff00ff00BadStorms:|r Item must be equippable to disenchant.")
            return
        end
        StaticPopup_Show("BadStormsDisenchantConfirm", link, BadStormsSettings.disenchanter, {
            link = link,
            lootSlot = frame.data.lootSlot,
            bag = frame.data.bag,
            slot = frame.data.slot,
            disenchanter = BadStormsSettings.disenchanter,
        })
    end)
    frame.disenchantRollButton:SetScript("OnEnter", function(self)
        if not BadStormsSettings.disenchanterEnabled or BadStormsSettings.disenchanter == "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Disenchanter must be enabled and set for this feature.", 1, 0.82, 0, 1)
            GameTooltip:Show()
        end
    end)
    frame.disenchantRollButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if BadStormsSettings.disenchanterEnabled and BadStormsSettings.disenchanter ~= "" and frame.data and frame.data.link and BadStorms.IsItemEquippable(frame.data.link) then
        frame.disenchantRollButton:Enable()
    end

    -- Export panel content
    local exportDateButtons = {}
    local csvEditBox

    local function PopulateExportList()
        local data = BadStormsSettings.exportData or {}
        local dates = {}
        for date in pairs(data) do
            table.insert(dates, date)
        end
        table.sort(dates, function(a, b)
            return a > b
        end)

        if #dates > 0 then
            if not frame.selectedExportDate or not data[frame.selectedExportDate] then
                frame.selectedExportDate = dates[1]
            end
        else
            frame.selectedExportDate = nil
        end

        for i, btn in ipairs(exportDateButtons) do
            local date = dates[i]
            if date then
                local count = #data[date]
                btn.date = date
                btn.text:SetText(date .. " (" .. count .. ")")
                if date == frame.selectedExportDate then
                    btn.selectedTexture:Show()
                else
                    btn.selectedTexture:Hide()
                end
                btn:Show()
            else
                btn.date = nil
                btn:Hide()
            end
        end

        local csv = ""
        if frame.selectedExportDate and BadStormsSettings.exportData[frame.selectedExportDate] then
            csv = "character,item_id,item_name,date_time,public_note,officer_note\n"
            for _, entry in ipairs(BadStormsSettings.exportData[frame.selectedExportDate]) do
                csv =
                    csv .. entry.character .. "," .. entry.item_id .. "," .. entry.item_name .. "," .. entry.date_time ..
                        "," .. entry.public_note .. "," .. entry.officer_note .. "\n"
            end
        end
        csvEditBox:SetText(csv)
        csvEditBox:SetCursorPosition(0)
    end
    frame.PopulateExportList = PopulateExportList

    local dateTitle = exportPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateTitle:SetPoint("TOPLEFT", exportPanel, "TOPLEFT", 10, -10)
    dateTitle:SetText("Export Dates")

    local dateScroll = CreateFrame("ScrollFrame", nil, exportPanel)
    dateScroll:EnableMouseWheel(true)
    dateScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local val = self:GetVerticalScroll() - delta * 20
        self:SetVerticalScroll(math.max(0, math.min(val, range)))
    end)
    dateScroll:SetPoint("TOPLEFT", exportPanel, "TOPLEFT", 10, -35)
    dateScroll:SetPoint("BOTTOMLEFT", exportPanel, "BOTTOMLEFT", 10, 45)
    dateScroll:SetWidth(130)

    local dateScrollChild = CreateFrame("Frame", nil, dateScroll)
    dateScrollChild:SetSize(120, 1600)
    dateScroll:SetScrollChild(dateScrollChild)

    for i = 1, 50 do
        local btn = CreateFrame("Button", nil, dateScrollChild)
        btn:SetPoint("TOPLEFT", dateScrollChild, "TOPLEFT", 0, -(i - 1) * 24)
        btn:SetPoint("TOPRIGHT", dateScrollChild, "TOPRIGHT", 0, -(i - 1) * 24)
        btn:SetHeight(22)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.2)

        btn.selectedTexture = btn:CreateTexture(nil, "BACKGROUND")
        btn.selectedTexture:SetAllPoints()
        btn.selectedTexture:SetTexture(1, 0.82, 0, 0.25)
        btn.selectedTexture:Hide()

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn, "LEFT", 4, 0)
        btn.text:SetWidth(110)
        btn.text:SetJustifyH("LEFT")

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        hl:SetAllPoints()
        btn:SetHighlightTexture(hl)

        btn:SetScript("OnClick", function(self)
            if self.date then
                frame.selectedExportDate = self.date
                PopulateExportList()
            end
        end)

        btn:Hide()
        exportDateButtons[i] = btn
    end

    local clearDateBtn = CreateFrame("Button", nil, exportPanel, "GameMenuButtonTemplate")
    clearDateBtn:SetSize(90, 24)
    clearDateBtn:SetPoint("BOTTOMLEFT", exportPanel, "BOTTOMLEFT", 10, 10)
    clearDateBtn:SetText("Clear Date")
    clearDateBtn:SetScript("OnClick", function()
        if not frame.selectedExportDate then
            return
        end
        StaticPopup_Show("BadStormsConfirmClearExportDate", frame.selectedExportDate, nil, frame.selectedExportDate)
    end)

    local clearAllBtn = CreateFrame("Button", nil, exportPanel, "GameMenuButtonTemplate")
    clearAllBtn:SetSize(90, 24)
    clearAllBtn:SetPoint("LEFT", clearDateBtn, "RIGHT", 4, 0)
    clearAllBtn:SetText("Clear All")
    clearAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("BadStormsConfirmClearExportAll")
    end)

    local csvTitle = exportPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    csvTitle:SetPoint("TOPLEFT", exportPanel, "TOPLEFT", 155, -10)
    csvTitle:SetText("CSV Data")

    local csvHelp = exportPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    csvHelp:SetPoint("TOPLEFT", csvTitle, "BOTTOMLEFT", 0, -2)
    csvHelp:SetText("Click inside the box (CTRL+A to select all, CTRL+C to copy)")

    local csvScroll = CreateFrame("ScrollFrame", nil, exportPanel)
    csvScroll:SetPoint("TOPLEFT", exportPanel, "TOPLEFT", 155, -50)
    csvScroll:SetPoint("BOTTOMRIGHT", exportPanel, "BOTTOMRIGHT", -10, 45)
    csvScroll:EnableMouseWheel(true)
    csvScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local val = self:GetVerticalScroll() - delta * 20
        self:SetVerticalScroll(math.max(0, math.min(val, range)))
    end)

    csvEditBox = CreateFrame("EditBox", nil, csvScroll)
    csvEditBox:SetSize(440, 1600)
    csvEditBox:SetMultiLine(true)
    csvEditBox:SetFontObject("GameFontHighlightSmall")
    csvEditBox:SetAutoFocus(false)
    csvEditBox:SetTextInsets(4, 4, 4, 4)
    csvEditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText(0)
    end)
    csvEditBox:SetScript("OnMouseDown", function(self)
        self:HighlightText(0)
    end)
    csvScroll:SetScrollChild(csvEditBox)

    -- Plus Ones
    local plusOneRows = {}

    local plusOneCheckbox = CreateFrame("CheckButton", "BadStormsPlusOneCheckbox", plusOnesPanel,
        "InterfaceOptionsCheckButtonTemplate")
    plusOneCheckbox:SetPoint("TOPLEFT", plusOnesPanel, "TOPLEFT", 0, 0)
    _G["BadStormsPlusOneCheckboxText"]:SetText("Track Plus Ones")
    plusOneCheckbox:SetChecked(BadStormsSettings.trackPlusOnes)
    plusOneCheckbox:SetScript("OnClick", function(self)
        BadStormsSettings.trackPlusOnes = self:GetChecked()
    end)

    local plusOneScroll = CreateFrame("ScrollFrame", nil, plusOnesPanel)
    plusOneScroll:EnableMouseWheel(true)
    plusOneScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local val = self:GetVerticalScroll() - delta * 20
        self:SetVerticalScroll(math.max(0, math.min(val, range)))
    end)
    plusOneScroll:SetPoint("TOPLEFT", plusOnesPanel, "TOPLEFT", 8, -31)
    plusOneScroll:SetPoint("TOPRIGHT", plusOnesPanel, "TOPRIGHT", -5, -31)
    plusOneScroll:SetPoint("BOTTOMRIGHT", plusOnesPanel, "BOTTOMRIGHT", -5, 45)

    --[[ -- Red Border
    plusOneScroll:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    
    plusOneScroll:SetBackdropBorderColor(1, 0, 0, 1)
    --]]

    local plusOneScrollChild = CreateFrame("Frame", nil, plusOneScroll)
    plusOneScrollChild:SetSize(620, 1600)
    plusOneScroll:SetScrollChild(plusOneScrollChild)

    for i = 1, 40 do
        local row = CreateFrame("Button", nil, plusOneScrollChild)
        row:SetPoint("TOPLEFT", plusOneScrollChild, "TOPLEFT", 0, -(i - 1) * 24)
        row:SetPoint("TOPRIGHT", plusOneScrollChild, "TOPRIGHT", 0, -(i - 1) * 24)
        row:SetHeight(22)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(0, 0, 0, 0.2)

        row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
        row.selectedTexture:SetAllPoints()
        row.selectedTexture:SetTexture(1, 0.82, 0, 0.25)
        row.selectedTexture:Hide()

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        hl:SetAllPoints()
        row:SetHighlightTexture(hl)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.name:SetWidth(250)

        row.minusBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.minusBtn:SetSize(18, 18)
        row.minusBtn:SetPoint("LEFT", row, "LEFT", 310, 0)
        row.minusBtn:SetText("-")
        row.minusBtn:SetNormalFontObject("GameFontNormalSmall")
        row.minusBtn:SetHighlightFontObject("GameFontHighlightSmall")

        row.editBox = CreateFrame("EditBox", nil, row)
        row.editBox:SetSize(36, 18)
        row.editBox:SetPoint("LEFT", row.minusBtn, "RIGHT", 2, 0)
        row.editBox:SetAutoFocus(false)
        row.editBox:SetNumeric(true)
        row.editBox:SetMaxLetters(3)
        row.editBox:SetFontObject("GameFontNormalSmall")
        row.editBox:SetJustifyH("CENTER")
        row.editBox:SetTextInsets(0, 0, 0, 0)
        row.editBox:SetText("0")

        row.plusBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.plusBtn:SetSize(18, 18)
        row.plusBtn:SetPoint("LEFT", row.editBox, "RIGHT", 2, 0)
        row.plusBtn:SetText("+")
        row.plusBtn:SetNormalFontObject("GameFontNormalSmall")
        row.plusBtn:SetHighlightFontObject("GameFontHighlightSmall")

        row.minusBtn:SetScript("OnClick", function()
            local val = tonumber(row.editBox:GetText()) or 0
            if val > 0 then
                val = val - 1
                row.editBox:SetText(tostring(val))
                if row.playerName then
                    BadStormsSettings.plusOnes[row.playerName] = val
                end
            end
        end)

        row.plusBtn:SetScript("OnClick", function()
            local val = tonumber(row.editBox:GetText()) or 0
            val = val + 1
            row.editBox:SetText(tostring(val))
            if row.playerName then
                BadStormsSettings.plusOnes[row.playerName] = val
            end
        end)

        row.editBox:SetScript("OnTextChanged", function()
            local text = row.editBox:GetText()
            local cleaned = text:gsub("%D", "")
            if cleaned ~= text then
                row.editBox:SetText(cleaned)
                row.editBox:SetCursorPosition(#cleaned)
            end
            local val = tonumber(cleaned) or 0
            if row.playerName then
                BadStormsSettings.plusOnes[row.playerName] = val
            end
        end)

        row:SetScript("OnClick", function(self)
            if not self.playerName then
                return
            end
            for _, other in ipairs(plusOneRows) do
                if other == self then
                    other.selectedTexture:Show()
                else
                    other.selectedTexture:Hide()
                end
            end
        end)

        row:Hide()
        plusOneRows[i] = row
    end

    local function PopulatePlusOnesList()
        local seen = {}
        local list = {}
        local raid = GetNumRaidMembers() > 0

        local function AddPlayer(name)
            if not name or name == "" or seen[name:lower()] then
                return
            end
            seen[name:lower()] = true
            local _, class = UnitClass(name)
            table.insert(list, {
                name = name,
                count = BadStormsSettings.plusOnes[name] or 0,
                class = class
            })
        end

        AddPlayer(UnitName("player"))

        if raid then
            for i = 1, GetNumRaidMembers() do
                AddPlayer(GetRaidRosterInfo(i))
            end
        else
            for i = 1, GetNumPartyMembers() do
                AddPlayer(UnitName("party" .. i))
            end
        end

        for name in pairs(BadStormsSettings.plusOnes) do
            AddPlayer(name)
        end

        table.sort(list, function(a, b)
            return a.name:lower() < b.name:lower()
        end)

        for i, row in ipairs(plusOneRows) do
            local entry = list[i]
            if entry then
                row.playerName = entry.name
                row.name:SetText(entry.name)
                if entry.class then
                    local r, g, b = BadStorms.GetClassColor(entry.class)
                    row.name:SetTextColor(r, g, b)
                else
                    row.name:SetTextColor(1, 1, 1)
                end
                row.editBox:SetText(tostring(entry.count))
                row:Show()
            else
                row.playerName = nil
                row:Hide()
            end
        end
    end
    frame.PopulatePlusOnesList = PopulatePlusOnesList

    local plusOneClearBtn = CreateFrame("Button", nil, plusOnesPanel, "GameMenuButtonTemplate")
    plusOneClearBtn:SetSize(90, 24)
    plusOneClearBtn:SetPoint("BOTTOMLEFT", plusOnesPanel, "BOTTOMLEFT", 10, 10)
    plusOneClearBtn:SetText("Clear All")
    plusOneClearBtn:SetScript("OnClick", function()
        StaticPopup_Show("BadStormsConfirmClearPlusOnes")
    end)

    frame.closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    frame.closeButton:SetSize(26, 24)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -15)
    frame.closeButton:SetText("X")
    frame.closeButton:SetNormalFontObject("GameFontNormalSmall")
    frame.closeButton:SetHighlightFontObject("GameFontHighlightSmall")
    frame.closeButton:SetScript("OnClick", function()
        frame:Hide()
        local a, b, c, x, y = frame:GetPoint(1)
        if a then
            BadStormsSettings.framePos = {
                point = a,
                relativeTo = b,
                relativePoint = c,
                xOfs = x,
                yOfs = y
            }
        end
    end)

    frame.settingsPanel = settingsPanel
    frame.awardPanel = awardPanel
    frame.rollPanel = rollPanel
    frame.srPanel = srPanel
    frame.exportPanel = exportPanel
    frame.plusOnesPanel = plusOnesPanel
    frame.settingsTab = settingsTab
    frame.awardTab = awardTab
    frame.rollTab = rollTab
    frame.srTab = srTab
    frame.exportTab = exportTab
    frame.plusOneTab = plusOneTab

    function frame:SelectTab(tab)
        self.settingsPanel:Hide()
        self.awardPanel:Hide()
        self.rollPanel:Hide()
        self.srPanel:Hide()
        self.exportPanel:Hide()
        self.plusOnesPanel:Hide()
        self.settingsTab:UnlockHighlight()
        self.awardTab:UnlockHighlight()
        self.rollTab:UnlockHighlight()
        self.srTab:UnlockHighlight()
        self.exportTab:UnlockHighlight()
        self.plusOneTab:UnlockHighlight()

        if tab == "settings" then
            self.settingsPanel:Show()
            self.settingsTab:LockHighlight()
        elseif tab == "roll" then
            self.rollPanel:Show()
            self.rollTab:LockHighlight()
        elseif tab == "sr" then
            self.srPanel:Show()
            self.srTab:LockHighlight()
            self.PopulateSRList()
        elseif tab == "export" then
            self.exportPanel:Show()
            self.exportTab:LockHighlight()
            PopulateExportList()
        elseif tab == "plusones" then
            self.plusOnesPanel:Show()
            self.plusOneTab:LockHighlight()
            self.PopulatePlusOnesList()
        else
            self.awardPanel:Show()
            self.awardTab:LockHighlight()
            PopulatePlayerList(self)
        end
    end

    local function UpdateLootMasterState()
        local isLM = BadStorms.IsLootMaster()
        local inGroup = BadStorms.InGroup()
        local tabsEnabled = not inGroup or isLM
        local text = _G["BadStormsEnableCheckboxText"]
        if tabsEnabled then
            text:SetTextColor(1, 1, 1)
            awardTab:Enable()
            rollTab:Enable()
            enableCheckbox:Enable()
        else
            text:SetTextColor(1, 0, 0)
            awardTab:Disable()
            rollTab:Disable()
            enableCheckbox:Disable()
        end
        srTab:Enable()
        exportTab:Enable()
        plusOneTab:Enable()

        local data = frame.data
        local canDisenchant = BadStormsSettings.disenchanterEnabled and BadStormsSettings.disenchanter ~= "" and data and data.link and BadStorms.IsItemEquippable(data.link)
        if frame.awardDisenchantButton then
            if canDisenchant then
                frame.awardDisenchantButton:Enable()
            else
                frame.awardDisenchantButton:Disable()
            end
        end
        if frame.disenchantRollButton then
            if canDisenchant then
                frame.disenchantRollButton:Enable()
            else
                frame.disenchantRollButton:Disable()
            end
        end
    end
    frame.UpdateLootMasterState = UpdateLootMasterState
    UpdateLootMasterState()

    settingsTab:SetScript("OnClick", function()
        frame:SelectTab("settings")
    end)
    awardTab:SetScript("OnClick", function()
        local inGroup = BadStorms.InGroup()
        if inGroup and not BadStorms.IsLootMaster() then
            print("|cff00ff00BadStorms:|r You must be the Master Looter to award items.")
            return
        end
        frame:SelectTab("award")
    end)
    rollTab:SetScript("OnClick", function()
        local inGroup = BadStorms.InGroup()
        if inGroup and not BadStorms.IsLootMaster() then
            print("|cff00ff00BadStorms:|r You must be the Master Looter to roll items.")
            return
        end
        frame:SelectTab("roll")
    end)
    srTab:SetScript("OnClick", function()
        frame:SelectTab("sr")
    end)
    exportTab:SetScript("OnClick", function()
        frame:SelectTab("export")
    end)
    plusOneTab:SetScript("OnClick", function()
        frame:SelectTab("plusones")
    end)

    frame:SelectTab("settings")
    frame:SetScript("OnShow", UpdateLootMasterState)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.refreshTimer = (self.refreshTimer or 0) + elapsed
        if self.refreshTimer >= 2 then
            self.refreshTimer = 0
            UpdateLootMasterState()
        end
    end)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsControlKeyDown() then
            BadStormsSettings.frameScale = 1.0
            self:SetScale(1.0)
        end
    end)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            local s = (tonumber(BadStormsSettings.frameScale) or 1.0) + delta * 0.05
            s = math.max(0.60, math.min(1.25, s))
            BadStormsSettings.frameScale = s
            self:SetScale(s)
        end
    end)

    BadStorms.configFrame = frame

    local initialScale = tonumber(BadStormsSettings.frameScale) or 1.0
    initialScale = math.max(0.75, math.min(1.25, initialScale))
    BadStormsSettings.frameScale = initialScale
    frame:SetScale(initialScale)
end

BadStorms.CreateConfigFrame = CreateConfigFrame

function BadStorms:ToggleConfigFrame()
    CreateConfigFrame()
    if BadStorms.configFrame:IsShown() then
        BadStorms.configFrame:Hide()
    else
        BadStorms.configFrame:SelectTab("settings")
        BadStorms.configFrame:Show()
    end
end

SLASH_BADSTORMS1 = "/badstorms"
SLASH_BADSTORMS2 = "/bs"
SlashCmdList.BADSTORMS = function(msg)
    BadStorms:ToggleConfigFrame()
end

local function HookGameTooltips()
    local tooltips = {GameTooltip, ItemRefTooltip}
    for _, tt in ipairs(tooltips) do
        if tt then
            tt:HookScript("OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                if link then
                    local itemId = GetItemID(link)
                    if itemId then
                        BadStorms.AppendItemTooltipInfo(itemId)
                    end
                end
            end)
        end
    end
end

local function CheckLootMasterTransition()
    BadStorms.CreateConfigFrame()
    local f = BadStorms.configFrame
    if f and f.UpdateLootMasterState then
        local isLM = BadStorms.IsLootMaster()
        if isLM and BadStorms.IsMasterLooter() and not BadStorms._wasLootMaster and not f:IsShown() then
            f:SelectTab("settings")
            f:Show()
        end
        BadStorms._wasLootMaster = isLM
        f.UpdateLootMasterState()
    end
end

local BadStormsFrame = CreateFrame("Frame")
BadStormsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BadStormsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
BadStormsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
BadStormsFrame:RegisterEvent("LOOT_METHOD_CHANGED")
BadStormsFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        print("|cff00ff00BadStorms:|r Addon loaded.")
        HookGameTooltips()
        BadStorms._wasLootMaster = BadStorms.IsLootMaster()
        CheckAutoMasterLoot()
        if not BadStormsSettings.hideMinimap then
            CreateMinimapButton()
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LOOT_METHOD_CHANGED" then
        CheckLootMasterTransition()
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckAutoMasterLoot()
    end
end)
BadStormsFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 1 then
        return
    end
    self.elapsed = 0
    CheckLootMasterTransition()
end)

local tradeWatchFrame = CreateFrame("Frame")
tradeWatchFrame:RegisterEvent("TRADE_SHOW")
tradeWatchFrame:RegisterEvent("TRADE_CLOSED")
tradeWatchFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SHOW" then
        local name = UnitName("NPC")
        if not name then
            return
        end

        local items = BadStormsSettings.pendingTrades and BadStormsSettings.pendingTrades[name]
        if not items or #items == 0 then
            return
        end

        self.tradingPartner = name
        self.placedItems = {}

        for i, itemData in ipairs(items) do
            if i > 6 then
                break
            end
            local bag, slot = itemData.bag, itemData.slot
            local link = bag and GetContainerItemLink(bag, slot)
            local id = link and tonumber(link:match("Hitem:(%d+)"))
            if not id or id ~= itemData.itemId then
                bag, slot, link = BadStorms.FindItemInBags(itemData.itemId)
            end
            if bag and slot then
                local idx = i
                self.placedItems[idx] = {
                    bag = bag,
                    slot = slot,
                    itemId = itemData.itemId,
                    link = link
                }
                C_Timer.After((idx - 1) * 0.4, function()
                    if TradeFrame:IsVisible() then
                        PickupContainerItem(bag, slot)
                        ClickTradeButton(idx)
                    end
                end)
            end
        end
    elseif event == "TRADE_CLOSED" then
        local partner = self.tradingPartner
        local placed = self.placedItems
        self.tradingPartner = nil
        self.tradingUnit = nil
        self.placedItems = nil
        if not partner then
            return
        end

        local pending = BadStormsSettings.pendingTrades and BadStormsSettings.pendingTrades[partner]
        if not pending or #pending == 0 then
            return
        end

        local remaining = {}
        local tradedCount = 0

        for i, itemData in ipairs(pending) do
            local slotInfo = placed and placed[i]
            if slotInfo then
                local currentLink = GetContainerItemLink(slotInfo.bag, slotInfo.slot)
                local currentId = currentLink and tonumber(currentLink:match("Hitem:(%d+)"))
                if not currentId or currentId ~= slotInfo.itemId then
                    tradedCount = tradedCount + 1
                    local total = BadStormsSettings.tradeTotals and BadStormsSettings.tradeTotals[partner]
                    if total then
                        total.traded = (total.traded or 0) + 1
                        BadStorms.SendToChannel("LOOT: " .. slotInfo.link .. " traded to " .. partner .. " (" ..
                                                    total.traded .. "/" .. total.awarded .. " awarded)")
                    else
                        BadStorms.SendToChannel("LOOT: " .. slotInfo.link .. " traded to " .. partner)
                    end
                else
                    table.insert(remaining, itemData)
                end
            else
                table.insert(remaining, itemData)
            end
        end

        if #remaining == 0 then
            BadStormsSettings.pendingTrades[partner] = nil
            if BadStormsSettings.tradeTotals then
                BadStormsSettings.tradeTotals[partner] = nil
            end
        else
            BadStormsSettings.pendingTrades[partner] = remaining
        end
    end
end)

local BadStormsMenuFrame = CreateFrame("Frame", "BadStormsTradeMenuFrame", UIParent, "UIDropDownMenuTemplate")

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:SetScript("OnEvent", function()
    if not BadStormsSettings.enabled or not BadStorms.IsLootMaster() then
        return
    end
    if not BadStormsSettings.autoloot then
        return
    end
    if IsShiftKeyDown() then
        return
    end
    local playerName = UnitName("player")
    local isML = BadStorms.IsMasterLooter()
    for i = GetNumLootItems(), 1, -1 do
        local texture, name, quantity, quality = GetLootSlotInfo(i)
        local item = GetLootSlotLink(i)
        if quality < 2 and (IsEquippableItem(item) or quantity == 0) then
            LootSlot(i)
        elseif quality > 1 then
            if quality == 2 and IsEquippableItem(item) and BadStormsSettings.disenchanterEnabled and
                BadStormsSettings.disenchanter ~= "" and isML then
                local dePlayer = BadStormsSettings.disenchanter
                local deFound = false
                for ci = 1, 40 do
                    local candidate = GetMasterLootCandidate(ci)
                    if not candidate then
                        break
                    end
                    if candidate == dePlayer then
                        SendToChannel("LOOT: " .. item .. " (disenchant) sent to " .. dePlayer)
                        GiveMasterLoot(i, ci)
                        deFound = true
                        break
                    end
                end
                if not deFound then
                    for ci = 1, 40 do
                        local name = GetMasterLootCandidate(ci)
                        if name == playerName then
                            if IsEquippableItem(item) then 
                                SendToChannel("LOOT: " .. item)
                            end
                            GiveMasterLoot(i, ci)
                            break
                        end
                    end
                end
            elseif isML then
                for ci = 1, 40 do
                    local name = GetMasterLootCandidate(ci)
                    if name == playerName then
                        if IsEquippableItem(item) then 
                            SendToChannel("LOOT: " .. item)
                        end
                        GiveMasterLoot(i, ci)
                        break
                    end
                end
            else
                if item then
                    SendToChannel("LOOT: " .. item)
                end
                LootSlot(i)
            end

        end
    end
    C_Timer.After(0.10, function()
        CloseLoot()
        local elf = _G["ElvLootFrame"]
        if elf and elf:IsVisible() then
            ElvLootFrame:Hide()
        end
    end)
end)

local function AutoAcceptBoP()
    if not BadStormsSettings.enabled or not BadStorms.IsLootMaster() then
        return
    end
    for i = 1, STATICPOPUP_NUMDIALOGS do
        local dialog = _G["StaticPopup" .. i]
        if dialog and dialog:IsShown() and dialog.which == "LOOT_BIND" then
            local btn = _G["StaticPopup" .. i .. "Button1"]
            if btn then
                btn:Click()
            end
            break
        end
    end
end
hooksecurefunc("StaticPopup_Show", function(which)
    if which == "LOOT_BIND" then
        C_Timer.After(0.05, AutoAcceptBoP)
    end
end)

local function HookCustomLootButtons()
    local buttonProvider
    if getglobal("ElvLootSlot1") then
        buttonProvider = "ElvUI"
    elseif getglobal("XLootFrameButton1") then
        buttonProvider = "XLoot1"
    elseif getglobal("XLootButton1") then
        buttonProvider = "XLoot"
    end

    if not buttonProvider then
        return
    end

    for i = 1, LOOTFRAME_NUMBUTTONS do
        local button
        if buttonProvider == "ElvUI" then
            button = getglobal("ElvLootSlot" .. i)
        elseif buttonProvider == "XLoot1" then
            button = getglobal("XLootFrameButton" .. i)
        elseif buttonProvider == "XLoot" then
            button = getglobal("XLootButton" .. i)
        end

        if not button then
            break
        end

        if not button._badStormsHooked then
            local slotIdx = i
            button:SetAttribute("type", nil)
            button:SetAttribute("loot-slot", nil)
            button:SetScript("OnClick", function()
                local slot = tonumber(button.slot) or slotIdx
                if not slot then
                    return
                end

                if IsAltKeyDown() and BadStormsSettings.enabled then
                    local inGroup = BadStorms.InGroup()
                    if inGroup and not BadStorms.CanManageLoot() then
                        local msg = "You do not have permission to manage loot."
                        print("|cff00ff00BadStorms:|r" .. msg)
                        return
                    end

                    local link = GetLootSlotLink(slot)
                    if not link then
                        return
                    end

                    CloseDropDownMenus()
                    if IsShiftKeyDown() then
                        BadStorms.ShowAwardDialogForLoot(slot, link)
                    else
                        BadStorms.CreateConfigFrame()
                        local f = BadStorms.configFrame
                        if BadStorms.isRolling then
                            print("|cff00ff00BadStorms:|r Cannot change item during an active roll.")
                            return
                        end
                        BadStorms.UpdateItemSelection(f, link)
                        f.data.lootSlot = slot
                        BadStorms.currentRolls = {}
                        f.selectedRollLabel:SetText("Player: None")
                        for _, btn in ipairs(f.rollButtons) do
                            btn.selectedTexture:Hide()
                            btn.rollData = nil
                            btn:Hide()
                        end
                        f.rollAssignButton:Disable()
                        f:SelectTab("roll")
                        f:Show()
                    end
                else
                    LootSlot(slot)
                end
            end)
            button._badStormsHooked = true
        end
    end
end

-- this is needed for ALT+CLICK and ALT+SHIFT+CLICK in chat edit box
hooksecurefunc("ChatEdit_InsertLink", function(link)
    if IsAltKeyDown() and BadStormsSettings.enabled and BadStorms.CanManageLoot() then
        if IsShiftKeyDown() then
            BadStorms.ShowAwardDialogForLoot(nil, link)
        end
    end
end)

hooksecurefunc("SetItemRef", function(link, text, button, ...)
    if not link or not string.find(link, "^item:") then
        return
    end
    if not IsAltKeyDown() then
        return
    end
    if not BadStormsSettings.enabled then
        return
    end
    if not BadStorms.CanManageLoot() then
        local inGroup = BadStorms.InGroup()
        if inGroup then
            local msg = "You do not have permission to manage loot."
            print("|cff00ff00BadStorms:|r" .. msg)
            if UIErrorsFrame then
                msg = "BadStorms: " .. msg
                UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                C_Timer.After(1, function()
                    UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                end)
                C_Timer.After(2, function()
                    UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                end)
            end
        end
        return
    end

    local itemLink = BadStorms.NormalizeItemLink(link)
    if not itemLink then
        local itemId = BadStorms.GetItemID(link)
        if not itemId then
            itemId = tonumber(link:match("^item:(%d+)"))
        end
        if not itemId then
            return
        end
        local _, fullLink = GetItemInfo(itemId)
        if not fullLink then
            return
        end
        itemLink = fullLink
    end

    if IsShiftKeyDown() then
        BadStorms.ShowAwardDialogForLoot(nil, itemLink)
    else
        if BadStorms.isRolling then
            print("|cff00ff00BadStorms:|r Cannot change item during an active roll.")
            return
        end
        BadStorms.CreateConfigFrame()
        local f = BadStorms.configFrame
        BadStorms.UpdateItemSelection(f, itemLink)
        BadStorms.currentRolls = {}
        f.selectedRollLabel:SetText("Player: None")
        for _, btn in ipairs(f.rollButtons) do
            btn.selectedTexture:Hide()
            btn.rollData = nil
            btn:Hide()
        end
        f.rollAssignButton:Disable()
        f:SelectTab("roll")
        f:Show()
    end
end)

local customLootFrame = CreateFrame("Frame")
customLootFrame:RegisterEvent("LOOT_OPENED")
customLootFrame:RegisterEvent("LOOT_READY")
customLootFrame:SetScript("OnEvent", function()
    C_Timer.After(0.4, HookCustomLootButtons)
end)

StaticPopupDialogs["BadStormsConfirmAssign"] = {
    text = "Assign %s to %s?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end

        SendToChannel("LOOT: " .. data.link .. " awarded to " .. data.name)

        local itemId = BadStorms.GetItemID(data.link)
        local itemName = data.link:match("%[(.-)%]") or "Unknown"
        local dateKey = date("%Y-%m-%d")
        local dateTime = date("%Y-%m-%d %H:%M:%S")
        if not BadStormsSettings.exportData then
            BadStormsSettings.exportData = {}
        end
        if not BadStormsSettings.exportData[dateKey] then
            BadStormsSettings.exportData[dateKey] = {}
        end
        table.insert(BadStormsSettings.exportData[dateKey], {
            character = data.name,
            item_id = tostring(itemId or ""),
            item_name = itemName,
            date_time = dateTime,
            public_note = data.note or "Award",
            officer_note = ""
        })

        if BadStormsSettings.trackPlusOnes and data.note and data.note:find("^Roll .- MS") then
            local hasSR = itemId and BadStorms.PlayerHasReservation(itemId, data.name) or 0
            if hasSR == 0 then
                BadStormsSettings.plusOnes[data.name] = (BadStormsSettings.plusOnes[data.name] or 0) + 1
            end
        end

        if itemId and BadStormsSettings.srReservations then
            local nameLower = data.name:lower()
            for _, r in ipairs(BadStormsSettings.srReservations) do
                if r.itemId == itemId and r.name:lower() == nameLower and not r.received then
                    r.received = true
                    break
                end
            end
        end

        if data.lootSlot then
            for ci = 1, 40 do
                local candidate = GetMasterLootCandidate(ci)
                if not candidate then
                    break
                end
                if candidate == data.name then
                    GiveMasterLoot(data.lootSlot, ci)
                    break
                end
            end
        else
            BadStormsSettings.pendingTrades = BadStormsSettings.pendingTrades or {}
            if not BadStormsSettings.pendingTrades[data.name] then
                BadStormsSettings.pendingTrades[data.name] = {}
            end
            table.insert(BadStormsSettings.pendingTrades[data.name], {
                itemId = itemId,
                link = data.link,
                itemName = itemName,
                bag = data.bag,
                slot = data.slot,
                date = dateTime
            })

            BadStormsSettings.tradeTotals = BadStormsSettings.tradeTotals or {}
            if not BadStormsSettings.tradeTotals[data.name] then
                BadStormsSettings.tradeTotals[data.name] = {
                    awarded = 0,
                    traded = 0
                }
            end
            BadStormsSettings.tradeTotals[data.name].awarded = BadStormsSettings.tradeTotals[data.name].awarded + 1

            if not UnitIsUnit(data.unit, "player") then
                if not CheckInteractDistance(data.unit, 2) then
                    SendChatMessage(
                        "WARNING: " .. data.name .. " is out of trade range. Please open trade with me for " ..
                            data.link .. "!", "WHISPER", nil, data.name)
                    return
                end
                BadStormsMenuFrame:Hide()
                InitiateTrade(data.unit)
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsDisenchantConfirm"] = {
    text = "Disenchant %s?\n\nWARNING: Award this item to %s for disenchanting.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if not BadStorms.ItemExistsInSlot(data) then
            print("|cff00ff00BadStorms:|r Item is no longer available.")
            return
        end
        SendToChannel("LOOT: " .. data.link .. " sent to " .. data.disenchanter .. " (disenchant)")

        if data.lootSlot then
            for ci = 1, 40 do
                local candidate = GetMasterLootCandidate(ci)
                if not candidate then
                    break
                end
                if candidate == data.disenchanter then
                    GiveMasterLoot(data.lootSlot, ci)
                    break
                end
            end
        else
            BadStormsSettings.pendingTrades = BadStormsSettings.pendingTrades or {}
            if not BadStormsSettings.pendingTrades[data.disenchanter] then
                BadStormsSettings.pendingTrades[data.disenchanter] = {}
            end
            local itemId = BadStorms.GetItemID(data.link)
            local itemName = data.link:match("%[(.-)%]") or "Unknown"
            table.insert(BadStormsSettings.pendingTrades[data.disenchanter], {
                itemId = itemId,
                link = data.link,
                itemName = itemName,
                bag = data.bag,
                slot = data.slot,
                date = date("%Y-%m-%d %H:%M:%S")
            })
            local unit = BadStorms.GetPlayerUnit(data.disenchanter)
            if unit and not UnitIsUnit(unit, "player") then
                if not CheckInteractDistance(unit, 2) then
                    SendChatMessage("WARNING: " .. data.disenchanter .. " is out of trade range. Please open trade with me for " ..
                                        data.link .. "!", "WHISPER", nil, data.disenchanter)
                    return
                end
                BadStormsMenuFrame:Hide()
                InitiateTrade(unit)
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsConfirmClearExportDate"] = {
    text = "Clear all export data for %s?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data and BadStormsSettings.exportData[data] then
            BadStormsSettings.exportData[data] = nil
        end
        local f = BadStorms.configFrame
        if f then
            f.selectedExportDate = nil
            if f.PopulateExportList then
                f.PopulateExportList()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsConfirmClearExportAll"] = {
    text = "Clear ALL export data? This cannot be undone.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        BadStormsSettings.exportData = {}
        local f = BadStorms.configFrame
        if f then
            f.selectedExportDate = nil
            if f.PopulateExportList then
                f.PopulateExportList()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsConfirmClearPlusOnes"] = {
    text = "Clear ALL plus one counts? This cannot be undone.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        BadStormsSettings.plusOnes = {}
        local f = BadStorms.configFrame
        if f then
            if f.PopulatePlusOnesList then
                f.PopulatePlusOnesList()
            end
            BadStorms.UpdateRollDisplay(f)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsConfirmClearPlusOnesOnImport"] = {
    text = "Clear existing plus one counts?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        BadStormsSettings.plusOnes = {}
        local f = BadStorms.configFrame
        if f then
            if f.PopulatePlusOnesList then
                f.PopulatePlusOnesList()
            end
            BadStorms.UpdateRollDisplay(f)
        end
        print("|cff00ff00BadStorms:|r Plus ones cleared after SR import.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

StaticPopupDialogs["BadStormsConfirmEnablePlusOnes"] = {
    text = "Enable plus ones tracking?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        BadStormsSettings.trackPlusOnes = true
        local checkbox = _G["BadStormsPlusOneCheckbox"]
        if checkbox then
            checkbox:SetChecked(true)
        end
        local f = BadStorms.configFrame
        if f then
            if f.PopulatePlusOnesList then
                f.PopulatePlusOnesList()
            end
            BadStorms.UpdateRollDisplay(f)
        end
        print("|cff00ff00BadStorms:|r Plus ones tracking enabled.")
        if next(BadStormsSettings.plusOnes) then
            StaticPopup_Show("BadStormsConfirmClearPlusOnesOnImport")
        end
    end,
    OnCancel = function()
        BadStormsSettings.trackPlusOnes = false
        local checkbox = _G["BadStormsPlusOneCheckbox"]
        if checkbox then
            checkbox:SetChecked(false)
        end
        local f = BadStorms.configFrame
        if f then
            if f.PopulatePlusOnesList then
                f.PopulatePlusOnesList()
            end
            BadStorms.UpdateRollDisplay(f)
        end
        print("|cff00ff00BadStorms:|r Plus ones tracking disabled.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false
}

hooksecurefunc("HandleModifiedItemClick", function(link)
    if not BadStormsSettings.enabled then
        return
    end
    if not IsAltKeyDown() then
        return
    end
    if not BadStorms.CanManageLoot() then
        local inGroup = BadStorms.InGroup()
        if inGroup then
            local msg = "You do not have permission to manage loot."
            print("|cff00ff00BadStorms:|r" .. msg)
            if UIErrorsFrame then
                msg = "BadStorms: " .. msg
                UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                C_Timer.After(1, function()
                    UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                end)
                C_Timer.After(2, function()
                    UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0, 1.0)
                end)
            end
            return
        end
    end
    if not link then
        return
    end

    for i = 1, GetNumLootItems() do
        local slotLink = GetLootSlotLink(i)
        if slotLink and slotLink == link then
            CloseDropDownMenus()
            if IsShiftKeyDown() then
                BadStorms.ShowAwardDialogForLoot(i, link)
            else
                BadStorms.CreateConfigFrame()
                local f = BadStorms.configFrame
                if BadStorms.isRolling then
                    print("|cff00ff00BadStorms:|r Cannot change item during an active roll.")
                    return
                end
                BadStorms.UpdateItemSelection(f, link)
                f.data.lootSlot = i
                BadStorms.currentRolls = {}
                f.selectedRollLabel:SetText("Player: None")
                for _, btn in ipairs(f.rollButtons) do
                    btn.selectedTexture:Hide()
                    btn.rollData = nil
                    btn:Hide()
                end
                f.rollAssignButton:Disable()
                f:SelectTab("roll")
                f:Show()
            end
            break
        end
    end
end)

