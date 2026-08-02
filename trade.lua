local BadStorms = _G.BadStorms

local _knownCounts = {}
local _userDismissed = false
local _refreshTicker
local _bagUpdateTimer
local VISIBLE_ROWS = 30
local ROW_HEIGHT = 22

local scanner = CreateFrame("GameTooltip", "BadStorms_TradeScanner", UIParent, "GameTooltipTemplate")

local tradeTimerPrefix
if ITEM_BOP_TRADEABLE then
    tradeTimerPrefix = ITEM_BOP_TRADEABLE:match("(.-)%%[ds]")
end
if not tradeTimerPrefix then
    tradeTimerPrefix = "You may trade this item with players that were also eligible to loot this item for the next "
end
tradeTimerPrefix = tradeTimerPrefix:lower()

local function IsItemPendingTrade(itemId)
    if not itemId or not BadStormsSettings.pendingTrades then
        return false
    end
    for _, items in pairs(BadStormsSettings.pendingTrades) do
        for _, itemData in ipairs(items) do
            if itemData.itemId == itemId then
                return true
            end
        end
    end
    return false
end

local function ParseRemaining(text)
    text = text:gsub("|c%x+", ""):gsub("|r", "")
    local hours = tonumber(text:match("(%d+)%s*h")) or 0
    local minutes = tonumber(text:match("(%d+)%s*min")) or 0
    return hours * 3600 + minutes * 60
end

function BadStorms.FormatTradeTime(remaining)
    if remaining >= 3600 then
        local h = math.floor(remaining / 3600)
        local m = math.floor((remaining % 3600) / 60)
        return string.format("%dh %dm", h, m)
    elseif remaining >= 60 then
        local m = math.floor(remaining / 60)
        local s = math.floor(remaining % 60)
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", math.floor(remaining))
    end
end

function BadStorms.ScanBoPTradeItems()
    local items = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("Hitem:(%d+)"))
                if itemId then
                    scanner:ClearLines()
                    scanner:SetOwner(UIParent, "ANCHOR_NONE")
                    scanner:SetBagItem(bag, slot)

                    local remaining = 0
                    for i = 2, scanner:NumLines() do
                        local text = _G["BadStorms_TradeScannerTextLeft" .. i]
                        if text then
                            local raw = text:GetText()
                            if raw then
                                local stripped = raw:gsub("|c%x+", ""):gsub("|r", "")
                                local _, endPos = stripped:lower():find(tradeTimerPrefix, 1, true)
                                if endPos then
                                    local timeStr = stripped:sub(endPos + 1):gsub("%s*%.?%s*$", "")
                                    remaining = ParseRemaining(timeStr)
                                    break
                                end
                            end
                        end
                    end
                    scanner:Hide()

                    if remaining > 0 then
                        table.insert(items, {
                            link = link,
                            itemId = itemId,
                            bag = bag,
                            slot = slot,
                            remaining = remaining
                        })
                    end
                end
            end
        end
    end
    table.sort(items, function(a, b)
        return a.remaining < b.remaining
    end)
    return items
end

local frame = CreateFrame("Frame", "BadStormsTradeTimer", UIParent)
frame:SetSize(300, 300)
local savedPos = BadStormsSettings.tradeTimerPos
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
        BadStormsSettings.tradeTimerPos = {
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
        local s = (tonumber(BadStormsSettings.tradeTimerScale) or 1.0) + delta * 0.05
        s = math.max(0.60, math.min(1.25, s))
        BadStormsSettings.tradeTimerScale = s
        self:SetScale(s)
    end
end)
frame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" and IsControlKeyDown() then
        BadStormsSettings.tradeTimerScale = 1.0
        self:SetScale(1.0)
    end
end)
frame:Hide()

local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleText:SetPoint("TOP", frame, "TOP", 0, -11)
titleText:SetText("Bad Storms Trade Timer")

local closeBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
closeBtn:SetSize(26, 24)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
closeBtn:SetText("X")
closeBtn:SetNormalFontObject("GameFontNormalSmall")
closeBtn:SetHighlightFontObject("GameFontHighlightSmall")
closeBtn:SetScript("OnClick", function()
    BadStorms.HideTradeTimerPanel()
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    local val = self:GetVerticalScroll() - delta * 20
    self:SetVerticalScroll(math.max(0, math.min(val, range)))
end)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -56)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
frame.scrollFrame = scrollFrame

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(284, VISIBLE_ROWS * ROW_HEIGHT)
scrollFrame:SetScrollChild(scrollChild)
frame.scrollChild = scrollChild

local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emptyText:SetPoint("TOP", scrollChild, "TOP", 0, -20)
emptyText:SetText("No tradeable BoP items found")
emptyText:SetTextColor(0.6, 0.6, 0.6)
frame.emptyText = emptyText

frame.rows = {}
for i = 1, VISIBLE_ROWS do
    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
    btn:SetHeight(ROW_HEIGHT)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(0, 0, 0, 0.2)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(1, 1, 1, 0.1)
    hl:SetAllPoints()
    btn:SetHighlightTexture(hl)

    btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.nameText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.nameText:SetJustifyH("LEFT")

    btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.timeText:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    btn.timeText:SetJustifyH("RIGHT")
    btn.timeText:SetTextColor(1, 1, 1)

    btn.nameText:SetPoint("RIGHT", btn.timeText, "LEFT", -4)

    btn:SetScript("OnClick", function(self)
        if not self.itemBag or not self.itemSlot or not self.itemLink then
            return
        end
        if not BadStorms.IsMasterLooter() then
            print("|cff00ff00BadStorms:|r You must be the Master Looter to manage loot.")
            return
        end
        if IsAltKeyDown() and IsShiftKeyDown() then
            BadStorms.ShowAwardDialog(self.itemBag, self.itemSlot, self.itemLink)
        else
            BadStorms.CreateConfigFrame()
            local f = BadStorms.configFrame
            BadStorms.UpdateItemSelection(f, self.itemLink, self.itemBag, self.itemSlot)
            f:SelectTab("roll")
            f:Show()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    btn:Hide()
    frame.rows[i] = btn
end

function BadStorms.ShowTradeTimerPanel()
    _userDismissed = false
    frame:Show()
end

function BadStorms.HideTradeTimerPanel()
    _userDismissed = true
    frame:Hide()
end

function BadStorms.RefreshTradeTimerList()
    if BadStorms.IsMasterLooter() and frame:IsShown() then
        BadStorms.PopulateTradeTimerList()
    end
end

function BadStorms.PopulateTradeTimerList()
    local items = BadStorms.ScanBoPTradeItems()
    local list = frame.scrollChild
    local scroll = frame.scrollFrame

    local totalHeight = math.max(#items, VISIBLE_ROWS) * ROW_HEIGHT
    list:SetHeight(totalHeight)
    scroll:SetVerticalScroll(0)

    if #items == 0 then
        for _, btn in ipairs(frame.rows) do
            btn:Hide()
        end
        frame.emptyText:Show()
        return
    end

    frame.emptyText:Hide()

    for i, btn in ipairs(frame.rows) do
        local data = items[i]
        if data then
            local name = GetItemInfo(data.link)
            if not name then
                name = data.link:match("%[(.-)%]") or "Item"
            end
            if IsItemPendingTrade(data.itemId) then
                name = "* " .. name
            else 
                name = "  " .. name
            end
            if BadStorms.ItemHasReservation(data.itemId) then
                name = name .. " |cffffd100[SR]|r"
            end
            local _, _, quality = GetItemInfo(data.link)
            if quality then
                local qColor = ITEM_QUALITY_COLORS[quality]
                local hex = string.format("|cff%02x%02x%02x", qColor.r * 255, qColor.g * 255, qColor.b * 255)
                btn.nameText:SetText(hex .. name .. "|r")
            else
                btn.nameText:SetText(name)
            end

            btn.timeText:SetText(BadStorms.FormatTradeTime(data.remaining))

            btn.itemLink = data.link
            btn.itemBag = data.bag
            btn.itemSlot = data.slot
            btn:Show()
        else
            btn.itemLink = nil
            btn.itemBag = nil
            btn.itemSlot = nil
            btn:Hide()
        end
    end
end

local function StartRefreshTicker()
    BadStorms.PopulateTradeTimerList()
    if _refreshTicker then
        _refreshTicker:Cancel()
    end
    _refreshTicker = C_Timer.NewTicker(60, BadStorms.PopulateTradeTimerList)
end

local function StopRefreshTicker()
    if _refreshTicker then
        _refreshTicker:Cancel()
        _refreshTicker = nil
    end
end

frame:SetScript("OnShow", function()
    if BadStorms.IsMasterLooter() then
        StartRefreshTicker()
    else
        for _, btn in ipairs(frame.rows) do
            btn:Hide()
        end
        frame.emptyText:Hide()
    end
end)

frame:SetScript("OnHide", function()
    StopRefreshTicker()
end)

local function AutoShowIfNewItems()
    if not BadStormsSettings.tradeTimerEnabled then
        return
    end
    if not BadStorms.IsMasterLooter() then
        return
    end
    local items = BadStorms.ScanBoPTradeItems()
    local counts = {}
    local hasNew = false
    for _, item in ipairs(items) do
        local id = item.itemId
        counts[id] = (counts[id] or 0) + 1
        if not hasNew and (counts[id] > (_knownCounts[id] or 0)) then
            hasNew = true
        end
    end
    _knownCounts = counts
    if hasNew and #items > 0 then
        _userDismissed = false
        frame:Show()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if not BadStorms.IsMasterLooter() then
            return
        end
        local items = BadStorms.ScanBoPTradeItems()
        local counts = {}
        for _, item in ipairs(items) do
            counts[item.itemId] = (counts[item.itemId] or 0) + 1
        end
        _knownCounts = counts
    elseif event == "LOOT_CLOSED" then
        AutoShowIfNewItems()
    elseif event == "BAG_UPDATE" then
        if not BadStorms.IsMasterLooter() then
            return
        end
        if _bagUpdateTimer then
            _bagUpdateTimer:Cancel()
        end
        _bagUpdateTimer = C_Timer.After(0.5, function()
            AutoShowIfNewItems()
            if frame:IsShown() then
                BadStorms.PopulateTradeTimerList()
            end
        end)
    elseif event == "PARTY_LOOT_METHOD_CHANGED" then
        if frame:IsShown() and not BadStorms.IsMasterLooter() then
            frame:Hide()
        end
    end
end)

SLASH_BADSTORMSTRADE1 = "/bst"
SLASH_BADSTORMSTRADE2 = "/tradetimer"
SlashCmdList.BADSTORMSTRADE = function()
    if not BadStorms.IsMasterLooter() then
        print("|cff00ff00BadStorms:|r You must be the Master Looter to use the Trade Timer.")
        return
    end
    if frame:IsShown() then
        BadStorms.HideTradeTimerPanel()
    else
        BadStorms.ShowTradeTimerPanel()
    end
end
