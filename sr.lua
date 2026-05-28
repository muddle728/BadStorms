local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID

function BadStorms.PlayerHasReservation(itemId, playerName)
    if not itemId or not BadStormsSettings.softReserves then return 0 end
    local playerLower = playerName:lower()
    local total = 0
    for _, r in ipairs(BadStormsSettings.softReserves) do
        if r.itemId == itemId and r.name:lower() == playerLower and not r.received then
            total = total + 1
        end
    end
    return total
end

function BadStorms.GetPlayerSRPlus(itemId, playerName)
    if not itemId or not BadStormsSettings.softReserves then return 0 end
    local playerLower = playerName:lower()
    for _, r in ipairs(BadStormsSettings.softReserves) do
        if r.itemId == itemId and r.name:lower() == playerLower and not r.received then
            return tonumber(r.plus) or 0
        end
    end
    return 0
end

local function ParseSRCSV(csvText)
    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        if line ~= "" then table.insert(lines, line) end
    end

    if #lines > 0 and lines[1]:lower():match("^item,") then
        table.remove(lines, 1)
    end

    BadStormsSettings.softReserves = {}
    local count = 0

    for _, line in ipairs(lines) do
        local fields = {}
        local current = ""
        local inQuotes = false
        for i = 1, #line do
            local c = line:sub(i, i)
            if c == '"' then
                inQuotes = not inQuotes
            elseif c == ',' and not inQuotes then
                table.insert(fields, current)
                current = ""
            else
                current = current .. c
            end
        end
        table.insert(fields, current)

        if #fields >= 4 then
            table.insert(BadStormsSettings.softReserves, {
                item = fields[1] or "",
                itemId = tonumber(fields[2]) or 0,
                from = fields[3] or "",
                name = fields[4] or "",
                class = fields[5] or "",
                spec = fields[6] or "",
                note = fields[7] or "",
                plus = fields[8] or "",
                date = fields[9] or ""
            })
            count = count + 1
        end
    end

    BadStormsSettings.softReservesCsv = csvText
    print("|cff00ff00BadStorms:|r Imported " .. count .. " soft reserve(s).")

    local frame = BadStorms.configFrame
    if frame then
        if frame.rollPanel and frame.rollPanel:IsShown() then
            BadStorms.UpdateRollDisplay(frame)
        elseif frame.awardPanel and frame.awardPanel:IsShown() then
            BadStorms.PopulatePlayerList(frame)
        elseif frame.srPanel and frame.srPanel:IsShown() then
            frame.PopulateSRList()
        end
    end
end
BadStorms.ParseSRCSV = ParseSRCSV

local function ShowSRImportDialog()
    local dialog = BadStorms.srDialogFrame
    if not dialog then
        dialog = CreateFrame("Frame", "BadStormsSRDialog", UIParent)
        dialog:SetSize(460, 400)
        dialog:SetPoint("TOPLEFT", BadStorms.configFrame, "TOPRIGHT", 10, 0)
        dialog:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true,
            tileSize = 32,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        dialog:SetBackdropColor(0, 0, 0, 0.9)
        dialog:SetBackdropBorderColor(0, 0, 0, 1)
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:EnableMouseWheel(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)

        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", dialog, "TOP", 0, -15)
        title:SetText("Import Soft Reserve CSV")

        local instr = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instr:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -40)
        instr:SetText("Paste CSV data from softres.it below (Ctrl+V):")
        instr:SetWidth(420)
        instr:SetJustifyH("LEFT")

        local editBoxBg = dialog:CreateTexture(nil, "BACKGROUND")
        editBoxBg:SetPoint("TOPLEFT", dialog, "TOPLEFT", 25, -60)
        editBoxBg:SetSize(410, 295)
        editBoxBg:SetTexture(0.05, 0.05, 0.05, 0.9)

        local editScroll = CreateFrame("ScrollFrame", nil, dialog)
        editScroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 25, -60)
        editScroll:SetSize(410, 295)
        editScroll:EnableMouse(true)

        local editBox = CreateFrame("EditBox", nil, editScroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(4, 4, 4, 4)
        editBox:SetWidth(410)

        editScroll:SetScrollChild(editBox)
        editScroll:SetScript("OnMouseDown", function()
            editBox:SetFocus()
        end)
        dialog.editBox = editBox

        dialog:SetScript("OnMouseWheel", function(self, delta)
            local val = editScroll:GetVerticalScroll()
            local range = editScroll:GetVerticalScrollRange()
            editScroll:SetVerticalScroll(math.max(0, math.min(val - delta * 40, range)))
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        local function ShowImportPostDialog()
            BadStorms.ShowDialog(
                "|cffff0000Confirmation Needed!|r\n\nEnable plus one tracking?",
                nil,
                function()
                    BadStormsSettings.plusOnesEnabled = true
                    local checkbox = _G["BadStormsPlusOneCheckbox"]
                    if checkbox then checkbox:SetChecked(true) end
                    local f = BadStorms.configFrame
                    if f then
                        if f.PopulatePlusOnesList then f.PopulatePlusOnesList() end
                        BadStorms.UpdateRollDisplay(f)
                    end
                    print("|cff00ff00BadStorms:|r Plus ones tracking enabled.")
                    if next(BadStormsSettings.plusOnes) then
                        BadStorms.ShowDialog(
                            "|cffff0000Confirmation Needed!|r\n\nClear existing plus one counts?",
                            nil,
                            function()
                                BadStormsSettings.plusOnes = {}
                                BadStorms.SyncPlusOnes()
                                local f2 = BadStorms.configFrame
                                if f2 then
                                    if f2.PopulatePlusOnesList then f2.PopulatePlusOnesList() end
                                    BadStorms.UpdateRollDisplay(f2)
                                end
                                print("|cff00ff00BadStorms:|r Plus ones cleared after SR import.")
                            end
                        )
                    end
                end,
                function()
                    BadStormsSettings.plusOnesEnabled = false
                    local checkbox = _G["BadStormsPlusOneCheckbox"]
                    if checkbox then checkbox:SetChecked(false) end
                    local f = BadStorms.configFrame
                    if f then
                        if f.PopulatePlusOnesList then f.PopulatePlusOnesList() end
                        BadStorms.UpdateRollDisplay(f)
                    end
                    print("|cff00ff00BadStorms:|r Plus ones tracking disabled.")
                end
            )
        end

        local importBtn = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
        importBtn:SetSize(80, 24)
        importBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -20, 15)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if text and text ~= "" then
                local existing = BadStormsSettings.softReserves or {}
                if next(existing) then
                    BadStorms.ShowDialog(
                        "|cffff0000WARNING:|r |cffffff00This will overwrite the existing soft reserves.\n\nContinue with import?|r",
                        nil,
                        function()
                            ParseSRCSV(text)
                            ShowImportPostDialog()
                        end
                    )
                else
                    ParseSRCSV(text)
                    ShowImportPostDialog()
                end
            end
        end)

        local cancelBtn = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
        cancelBtn:SetSize(80, 24)
        cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -4, 0)
        cancelBtn:SetText("Close")
        cancelBtn:SetScript("OnClick", function()
            editBox:SetText("")
            dialog:Hide()
        end)

        local clearBtn = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
        clearBtn:SetSize(80, 24)
        clearBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 20, 15)
        clearBtn:SetText("Clear All")
        clearBtn:SetScript("OnClick", function()
            BadStorms.ShowDialog(
                "|cffff0000WARNING:|r Clear existing soft reserves?",
                nil,
                function()
                    BadStormsSettings.softReserves = {}
                    BadStormsSettings.softReservesCsv = ""
                    editBox:SetText("")
                    print("|cff00ff00BadStorms:|r Soft reserves cleared.")
                    local f = BadStorms.configFrame
                    if f then
                        f.PopulateSRList()
                        if f.rollPanel and f.rollPanel:IsShown() then
                            BadStorms.UpdateRollDisplay(f)
                        elseif f.awardPanel and f.awardPanel:IsShown() then
                            BadStorms.PopulatePlayerList(f)
                        end
                    end
                end
        )
    end)

    dialog:Hide()
    BadStorms.srDialogFrame = dialog
    end

    dialog.editBox:SetText(BadStormsSettings.softReservesCsv or "")
    dialog:Show()
end
BadStorms.ShowSRImportDialog = ShowSRImportDialog

local function FormatSRName(name, count, plus)
    --[[ keeping this for later
    local entry = name
    if plus and plus > 0 then
        entry = entry .. " (+" .. plus .. ")"
    end
    if count and count > 1 then
        entry = entry .. " x" .. count
    end
    return entry
    ]]
    return name
end

function BadStorms.GetSRText(itemId)
    if not itemId or not BadStormsSettings.softReserves then return "" end
    local pending = {}
    local received = {}
    local pendingPlus = {}
    local receivedPlus = {}
    for _, r in ipairs(BadStormsSettings.softReserves) do
        if r.itemId == itemId then
            local plus = tonumber(r.plus) or 0
            if r.received then
                received[r.name] = (received[r.name] or 0) + 1
                if not receivedPlus[r.name] then
                    receivedPlus[r.name] = plus
                end
            else
                pending[r.name] = (pending[r.name] or 0) + 1
                if not pendingPlus[r.name] then
                    pendingPlus[r.name] = plus
                end
            end
        end
    end
    local totalPlayers = 0
    for _ in pairs(pending) do totalPlayers = totalPlayers + 1 end
    for _ in pairs(received) do totalPlayers = totalPlayers + 1 end
    if totalPlayers == 0 then return "" end

    local parts = {}
    local sorted = {}
    for name in pairs(pending) do table.insert(sorted, name) end
    table.sort(sorted)
    for _, name in ipairs(sorted) do
        table.insert(parts, FormatSRName(name, pending[name], pendingPlus[name]))
    end
    sorted = {}
    for name in pairs(received) do table.insert(sorted, name) end
    table.sort(sorted)
    for _, name in ipairs(sorted) do
        table.insert(parts, "|cff888888" .. FormatSRName(name, received[name], receivedPlus[name]) .. " (received)|r")
    end

    local lines = {}
    for i = 1, #parts, 3 do
        local chunk = {}
        for j = i, math.min(i + 2, #parts) do
            table.insert(chunk, parts[j])
        end
        table.insert(lines, "SR: " .. table.concat(chunk, ", "))
    end
    return table.concat(lines, "\n")
end

function BadStorms.AppendSRTooltip(itemId)
    local text = BadStorms.GetSRText(itemId)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Bad Storms Loot Assignments", 1, 1, 1)
    if text ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(text, 0.82, 0.82, 0.82)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:Show()
end

function BadStorms.AppendItemTooltipInfo(itemId)
    if not itemId then return end
    local srText = BadStorms.GetSRText(itemId)

    local myName = UnitName("player")
    local pendingPlayers = {}
    if BadStormsSettings.pendingTrades then
        for playerName, items in pairs(BadStormsSettings.pendingTrades) do
            if playerName ~= myName then
                for _, itemData in ipairs(items) do
                    if itemData.itemId == itemId then
                        pendingPlayers[playerName] = true
                        break
                    end
                end
            end
        end
    end

    if srText == "" and not next(pendingPlayers) then return end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Bad Storms Loot Assignments", 1, 1, 1)
    GameTooltip:AddLine(" ")
    if srText ~= "" then
        GameTooltip:AddLine(srText, 0.82, 0.82, 0.82)
    end
    for playerName in pairs(pendingPlayers) do
        GameTooltip:AddLine("  Pending award: " .. playerName, 1, 1, 0)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("  |cff66ccffALT+CLICK|r to roll", 0.82, 0.82, 0.82)
    GameTooltip:AddLine("  |cff66ccffALT+SHIFT+CLICK|r to award", 0.82, 0.82, 0.82)
    GameTooltip:AddLine(" ")
    GameTooltip:Show()
end
