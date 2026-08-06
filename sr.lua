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

function BadStorms.ItemHasReservation(itemId)
    if not itemId or not BadStormsSettings.softReserves then return false end
    for _, r in ipairs(BadStormsSettings.softReserves) do
        if r.itemId == itemId and not r.received then return true end
    end
    return false
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

local function ParseCSVLine(line)
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

    for i, f in ipairs(fields) do
        fields[i] = f:match("^%s*(.-)%s*$")
    end
    return fields
end

local function ApplySRPlusFromNotes()
    local reservations = BadStormsSettings.softReserves or {}
    local playerOrder = {}
    local byPlayer = {}
    for _, r in ipairs(reservations) do
        local key = (r.name or ""):lower()
        if not byPlayer[key] then
            byPlayer[key] = {}
            table.insert(playerOrder, key)
        end
        table.insert(byPlayer[key], r)
    end

    for _, key in ipairs(playerOrder) do
        local entries = byPlayer[key]

        local seq = {}
        local seenNotes = {}
        for _, r in ipairs(entries) do
            local note = r.note or ""
            if note ~= "" and not seenNotes[note] then
                seenNotes[note] = true
                for num in note:gmatch("%d+") do
                    table.insert(seq, tonumber(num))
                end
            end
        end

        local seen = {}
        local items = {}
        for _, r in ipairs(entries) do
            local itemKey = tostring(r.itemId)
            if not seen[itemKey] then
                seen[itemKey] = true
                table.insert(items, itemKey)
            end
        end

        local indexOf = {}
        for i, itemKey in ipairs(items) do
            indexOf[itemKey] = i
        end

        for _, r in ipairs(entries) do
            if (tonumber(r.plus) or 0) == 0 then
                local seqIdx = indexOf[tostring(r.itemId)]
                if seqIdx and seq[seqIdx] then
                    r.plus = tostring(seq[seqIdx])
                else
                    r.plus = "0"
                end
            end
        end
    end
end

local function ParseSRCSV(csvText)
    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        if line ~= "" then table.insert(lines, line) end
    end

    local format = "legacy"
    local raidres = false
    if #lines > 0 then
        local header = ParseCSVLine(lines[1])
        local h1 = (header[1] or ""):lower()
        local h4 = (header[4] or ""):lower()
        if h1 == "id" and h4 == "attendee" then
            raidres = true
            table.remove(lines, 1)
        elseif tonumber(header[2]) == nil then
            table.remove(lines, 1)
            local extraHeader = (header[8] or ""):lower()
            if extraHeader == "extra reserves" then
                format = "new"
            end
        end
    end

    BadStormsSettings.softReserves = {}
    local count = 0

    for _, line in ipairs(lines) do
        local fields = ParseCSVLine(line)

        if #fields >= 4 then
            if raidres then
                table.insert(BadStormsSettings.softReserves, {
                    item = fields[2] or "",
                    itemId = tonumber(fields[1]) or 0,
                    from = fields[3] or "",
                    name = fields[4] or "",
                    class = fields[5] or "",
                    spec = fields[6] or "",
                    note = fields[7] or "",
                    plus = string.format("%g", (tonumber(fields[9]) or 0) / 10),
                    extraReserves = "",
                    date = fields[8] or ""
                })
            else
                table.insert(BadStormsSettings.softReserves, {
                    item = fields[1] or "",
                    itemId = tonumber(fields[2]) or 0,
                    from = fields[3] or "",
                    name = fields[4] or "",
                    class = fields[5] or "",
                    spec = fields[6] or "",
                    note = fields[7] or "",
                    plus = format == "new" and "" or (fields[8] or ""),
                    extraReserves = format == "new" and (fields[8] or "") or "",
                    date = fields[9] or ""
                })
            end
            count = count + 1
        end
    end

    if not raidres then
        ApplySRPlusFromNotes()
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
        instr:SetText("Paste CSV data from softres.it or raidres.top below (Ctrl+V):")
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
                        pendingPlayers[playerName] = (pendingPlayers[playerName] or 0) + 1
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
    for playerName, count in pairs(pendingPlayers) do
        if count and count > 1 then
            GameTooltip:AddLine("  Pending Trade: " .. playerName .. " (x" .. count .. ")", 1, 1, 0)
        else
            GameTooltip:AddLine("  Pending Trade: " .. playerName, 1, 1, 0)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("  |cff66ccffALT+CLICK|r to roll", 0.82, 0.82, 0.82)
    GameTooltip:AddLine("  |cff66ccffALT+SHIFT+CLICK|r to award", 0.82, 0.82, 0.82)
    GameTooltip:AddLine(" ")
    GameTooltip:Show()
end
