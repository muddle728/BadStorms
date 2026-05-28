local BadStorms = _G.BadStorms

local frame = CreateFrame("Frame", "BadStormsLootRoller", UIParent)
frame:SetSize(300, 300)
local savedPos = BadStormsSettings.lootRollerPos
if savedPos then
    frame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.xOfs, savedPos.yOfs)
else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
frame:SetFrameStrata("DIALOG")
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
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local a, b, c, x, y = self:GetPoint(1)
    if a then
        BadStormsSettings.lootRollerPos = {
            point = a,
            relativePoint = c,
            xOfs = x,
            yOfs = y
        }
    end
end)
frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function(self, delta)
    if IsControlKeyDown() then
        local s = (tonumber(BadStormsSettings.frameScale) or 1.0) + delta * 0.05
        s = math.max(0.60, math.min(1.25, s))
        BadStormsSettings.frameScale = s
        self:SetScale(s)
        if BadStorms.configFrame then
            BadStorms.configFrame:SetScale(s)
            if BadStorms.configFrame:IsShown() then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", BadStorms.configFrame, "TOPRIGHT", 4, 0)
            end
        end
    end
end)
frame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" and IsControlKeyDown() then
        BadStormsSettings.frameScale = 1.0
        self:SetScale(1.0)
        if BadStorms.configFrame then
            BadStorms.configFrame:SetScale(1.0)
            if BadStorms.configFrame:IsShown() then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", BadStorms.configFrame, "TOPRIGHT", 4, 0)
            end
        end
    end
end)
frame:Hide()

local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleText:SetPoint("TOP", frame, "TOP", 0, -11)
titleText:SetText("Bad Storms Loot Roller")

local itemIcon = CreateFrame("Button", nil, frame)
itemIcon:SetSize(36, 36)
itemIcon:SetPoint("TOP", frame, "TOP", 0, -35)
itemIcon:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1
})
itemIcon:SetBackdropBorderColor(0.5, 0.5, 0.5)
itemIcon.texture = itemIcon:CreateTexture(nil, "BACKGROUND")
itemIcon.texture:SetAllPoints()
itemIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
frame.itemIcon = itemIcon

local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
itemName:SetPoint("TOP", itemIcon, "BOTTOM", 0, -6)
itemName:SetWidth(260)
itemName:SetJustifyH("CENTER")
frame.itemName = itemName

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    local val = self:GetVerticalScroll() - delta * 20
    self:SetVerticalScroll(math.max(0, math.min(val, range)))
end)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -106)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 60)
frame.scrollFrame = scrollFrame

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(284, 960)
scrollFrame:SetScrollChild(scrollChild)

frame.rollButtons = {}
for i = 1, 30 do
    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * 22)
    btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * 22)
    btn:SetHeight(20)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(0, 0, 0, 0.2)

    btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.nameText:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btn.nameText:SetWidth(110)

    btn.rollText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.rollText:SetPoint("LEFT", btn, "LEFT", 118, 0)
    btn.rollText:SetWidth(30)

    btn.specText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.specText:SetPoint("LEFT", btn, "LEFT", 152, 0)
    btn.specText:SetWidth(35)

    btn.srText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.srText:SetPoint("LEFT", btn, "LEFT", 190, 0)
    btn.srText:SetWidth(40)

    btn.plusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.plusText:SetPoint("LEFT", btn, "LEFT", 232, 0)
    btn.plusText:SetWidth(30)

    btn:Hide()
    frame.rollButtons[i] = btn
end

local countdownTicker
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
statusText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
statusText:SetTextColor(1, 0, 0)
statusText:SetText("")
BadStorms.UpdateRollDisplay(frame)
PlaySoundFile("Sound\\Interface\\RaidWarningHorn.ogg")

local rollMSBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
rollMSBtn:SetSize(80, 24)
rollMSBtn:SetPoint("BOTTOM", frame, "BOTTOM", -85, 8)
rollMSBtn:SetText("Roll MS")
rollMSBtn:SetScript("OnClick", function()
    RandomRoll(1, 100)
end)
frame.rollMSBtn = rollMSBtn

local rollOSBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
rollOSBtn:SetSize(80, 24)
rollOSBtn:SetPoint("LEFT", rollMSBtn, "RIGHT", 4, 0)
rollOSBtn:SetText("Roll OS")
rollOSBtn:SetScript("OnClick", function()
    RandomRoll(1, 99)
end)
frame.rollOSBtn = rollOSBtn

local rollGen = 0

local function HideRollTracker(gen)
    if gen and gen ~= rollGen then
        return
    end
    if BadStorms.rollerCloseTimer then
        BadStorms.rollerCloseTimer:Cancel()
        BadStorms.rollerCloseTimer = nil
    end
    if BadStorms.currentRollTimer then
        BadStorms.currentRollTimer:Cancel()
        BadStorms.currentRollTimer = nil
    end
    if not frame:IsShown() then
        return
    end
    if not BadStorms.IsMasterLooter() then
        BadStorms.isRolling = false
        BadStorms.currentRolls = {}
    end
    itemIcon:SetScript("OnEnter", nil)
    itemIcon:SetScript("OnLeave", nil)
    frame:Hide()
end

local passBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
passBtn:SetSize(80, 24)
passBtn:SetPoint("LEFT", rollOSBtn, "RIGHT", 4, 0)
passBtn:SetText("Pass")
passBtn:SetScript("OnClick", function()
    HideRollTracker()
end)
frame.passBtn = passBtn

local function ShowRollTracker(link)
    rollGen = rollGen + 1
    if BadStorms.rollerCloseTimer then
        BadStorms.rollerCloseTimer:Cancel()
        BadStorms.rollerCloseTimer = nil
    end
    if BadStorms.currentRollTimer then
        BadStorms.currentRollTimer:Cancel()
        BadStorms.currentRollTimer = nil
    end

    if BadStorms.configFrame and BadStorms.configFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", BadStorms.configFrame, "TOPRIGHT", 4, 0)
    elseif not BadStormsSettings.lootRollerPos then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    BadStorms.isRolling = true
    frame.data = {
        link = link
    }

    local itemNameStr, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
    if itemNameStr then
        local qColor = quality and ITEM_QUALITY_COLORS[quality]
        if qColor then
            local hex = string.format("|cff%02x%02x%02x", qColor.r * 255, qColor.g * 255, qColor.b * 255)
            itemName:SetText(hex .. itemNameStr .. "|r")
        else
            itemName:SetText(itemNameStr)
        end
        if qColor then
            itemIcon:SetBackdropBorderColor(qColor.r, qColor.g, qColor.b)
        else
            itemIcon:SetBackdropBorderColor(0.5, 0.5, 0.5)
        end
        itemIcon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        local linkName = link:match("%[(.-)%]") or link
        itemName:SetText(linkName)
        itemIcon:SetBackdropBorderColor(0.5, 0.5, 0.5)
        itemIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        C_Timer.After(0.5, function()
            if not BadStorms.isRolling then
                return
            end
            if frame.data and frame.data.link ~= link then
                return
            end
            local n2, _, q2, _, _, _, _, _, _, t2 = GetItemInfo(link)
            if n2 then
                local qc = q2 and ITEM_QUALITY_COLORS[q2]
                if qc then
                    local h2 = string.format("|cff%02x%02x%02x", qc.r * 255, qc.g * 255, qc.b * 255)
                    itemName:SetText(h2 .. n2 .. "|r")
                else
                    itemName:SetText(n2)
                end
                if qc then
                    itemIcon:SetBackdropBorderColor(qc.r, qc.g, qc.b)
                end
                itemIcon.texture:SetTexture(t2 or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end)
    end

    itemIcon:SetScript("OnEnter", function(self)
        if link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    itemIcon:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    statusText:SetText("")
    BadStorms.UpdateRollDisplay(frame)

    PlaySoundFile("Sound\\Interface\\RaidWarningHorn.ogg")

    local closeTime = tonumber(BadStormsSettings.lootRollerCloseTime) or 15
    local captureGen = rollGen
    BadStorms.rollerCloseTimer = C_Timer.After(closeTime, function()
        HideRollTracker(captureGen)
    end)

    frame:Show()
end

local closeBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
closeBtn:SetSize(26, 24)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
closeBtn:SetText("X")
closeBtn:SetNormalFontObject("GameFontNormalSmall")
closeBtn:SetHighlightFontObject("GameFontHighlightSmall")
closeBtn:SetScript("OnClick", function()
    HideRollTracker()
end)
frame.closeBtn = closeBtn

BadStorms.lootRoller = frame

local chatListener = CreateFrame("Frame")
chatListener:RegisterEvent("CHAT_MSG_RAID_WARNING")
chatListener:RegisterEvent("CHAT_MSG_RAID")
chatListener:RegisterEvent("CHAT_MSG_RAID_LEADER")
chatListener:RegisterEvent("CHAT_MSG_PARTY_WARNING")
chatListener:RegisterEvent("CHAT_MSG_PARTY")
chatListener:RegisterEvent("CHAT_MSG_PARTY_LEADER")
chatListener:SetScript("OnEvent", function(self, event, msg)

    if not BadStormsSettings.lootRollerEnabled then
        return
    end
    if not BadStorms.InGroup() then
        return
    end

    if (msg and string.lower(msg):match("^rolls closed")) then
        BadStorms.isRolling = false
        if BadStorms.currentRollTimer then
            BadStorms.currentRollTimer:Cancel()
            BadStorms.currentRollTimer = nil
        end
        local reRollNames = msg:match("Re%-Roll: (.+)")
        if reRollNames then
            statusText:SetText("Re-Roll: " .. reRollNames)
        else
            local winnerName, winnerRoll, winnerSpec = msg:match("Winner: (.+) %[(%d+)%] %((%a+)%)")
            if winnerName then
                statusText:SetText("Winner: " .. winnerName .. " [" .. winnerRoll .. "] (" .. winnerSpec .. ")")
            else
                statusText:SetText("ROLLS CLOSED")
            end
        end
    elseif (msg and string.lower(msg):match("^roll")) then
        local link = msg:match("(|c[%x]+|Hitem:[^|]+|h%[.-%]|h|r)")
        if not link then
            local itemID = msg:match("Hitem:(%d+)")
            if itemID then
                link = "item:" .. itemID
            end
        end
        if link then
            ShowRollTracker(link)
            local seconds = tonumber(string.lower(msg):match("roll timer: (%d+)%s*second[s]?"))
            if seconds and not BadStorms.currentRollTimer then
                local timerStart = time()
                BadStorms.currentRollTimer = C_Timer.NewTicker(0.5, function()
                    local elapsed = time() - timerStart
                    local remaining = math.max(0, seconds - elapsed)
                    local display = math.ceil(remaining)
                    if display > 0 then
                        statusText:SetText(display)
                    else
                        statusText:SetText("ROLLS CLOSED")
                        BadStorms.currentRollTimer:Cancel()
                        BadStorms.currentRollTimer = nil
                    end
                end)
            end
        end
    end
end)
