local BadStorms = _G.BadStorms
local GetItemID = BadStorms.GetItemID

function BadStorms.PlayerHasReservation(itemId, playerName)
    if not itemId or not BadStormsSettings.srReservations then return 0 end
    local playerLower = playerName:lower()
    local total = 0
    for _, r in ipairs(BadStormsSettings.srReservations) do
        if r.itemId == itemId and r.name:lower() == playerLower then
            total = total + (tonumber(r.plus) or 0) + 1
        end
    end
    return total
end

local function ParseSRCSV(csvText)
    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        if line ~= "" then table.insert(lines, line) end
    end

    if #lines > 0 and lines[1]:lower():match("^item,") then
        table.remove(lines, 1)
    end

    BadStormsSettings.srReservations = {}
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
            table.insert(BadStormsSettings.srReservations, {
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

    BadStormsSettings.lastSRImport = csvText
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
        editBoxBg:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -60)
        editBoxBg:SetSize(420, 280)
        editBoxBg:SetTexture(0.05, 0.05, 0.05, 0.9)

        local editScroll = CreateFrame("ScrollFrame", nil, dialog)
        editScroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -60)
        editScroll:SetSize(420, 280)

        local editBox = CreateFrame("EditBox", nil, editScroll)
        editBox:SetSize(410, 1600)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(4, 4, 4, 4)
        editScroll:SetScrollChild(editBox)
        dialog.editBox = editBox

        dialog:SetScript("OnMouseWheel", function(self, delta)
            local val = editScroll:GetVerticalScroll()
            local range = editScroll:GetVerticalScrollRange()
            editScroll:SetVerticalScroll(math.max(0, math.min(val - delta * 40, range)))
        end)

        local importBtn = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
        importBtn:SetSize(80, 24)
        importBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -20, 15)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if text and text ~= "" then
                ParseSRCSV(text)
                editBox:SetText("")
                dialog:Hide()
                StaticPopup_Show("BadStormsConfirmEnablePlusOnes")
            else
                editBox:SetText("")
                dialog:Hide()
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
        clearBtn:SetText("Clear")
        clearBtn:SetScript("OnClick", function()
            BadStormsSettings.srReservations = {}
            BadStormsSettings.lastSRImport = ""
            print("|cff00ff00BadStorms:|r Soft reserves cleared.")
            editBox:SetText("")
            dialog:Hide()
            local f = BadStorms.configFrame
            if f then
                f.PopulateSRList()
                if f.rollPanel and f.rollPanel:IsShown() then
                    BadStorms.UpdateRollDisplay(f)
                elseif f.awardPanel and f.awardPanel:IsShown() then
                    BadStorms.PopulatePlayerList(f)
                end
            end
        end)

        dialog:Hide()
        BadStorms.srDialogFrame = dialog
    end

    dialog.editBox:SetText(BadStormsSettings.lastSRImport or "")
    dialog:Show()
end
BadStorms.ShowSRImportDialog = ShowSRImportDialog

function BadStorms.GetSRText(itemId)
    if not itemId or not BadStormsSettings.srReservations then return "" end
    local players = {}
    for _, r in ipairs(BadStormsSettings.srReservations) do
        if r.itemId == itemId then
            local count = (tonumber(r.plus) or 0) + 1
            players[r.name] = (players[r.name] or 0) + count
        end
    end
    local count = 0
    for _ in pairs(players) do count = count + 1 end
    if count == 0 then return "" end

    local sorted = {}
    for name in pairs(players) do table.insert(sorted, name) end
    table.sort(sorted)
    local parts = {}
    for _, name in ipairs(sorted) do
        local total = players[name]
        table.insert(parts, name .. (total > 1 and " x" .. total or ""))
    end
    return "SR: " .. table.concat(parts, ", ")
end

function BadStorms.AppendSRTooltip(itemId)
    local text = BadStorms.GetSRText(itemId)
    if text == "" then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Bad Storms Loot Assignments", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("  " .. text, 0.82, 0.82, 0.82)
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
        GameTooltip:AddLine("  " .. srText, 0.82, 0.82, 0.82)
    end
    for playerName in pairs(pendingPlayers) do
        GameTooltip:AddLine("  Pending award: " .. playerName, 1, 1, 0)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:Show()
end
