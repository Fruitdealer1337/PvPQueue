-- Floating queue bar

local PvPQ = _G.PvPQueueAddon
local Bar = {}
PvPQ.Bar = Bar

local TITLE_WIDTH = 70
local GRIP_WIDTH = 14
local GRIP_GAP = 4
local BUTTON_GAP = 4
local BUTTON_HEIGHT = 22
local WARMUP_DELAY = 0.50
local WARMUP_TIMEOUT = 5.00

local queueTargets = {
    "RatedBGQueueArena1",
    "RatedBGQueueArena2",
    "RatedBGQueueSoloArena",
}

local function makeButton(parent, name, text, width)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(BUTTON_HEIGHT)
    button:SetText(text)
    button:Disable()
    return button
end

local function quietCall(func)
    local playSound = _G.PlaySound
    local playSoundFile = _G.PlaySoundFile

    if playSound then _G.PlaySound = function() end end
    if playSoundFile then _G.PlaySoundFile = function() end end

    local ok = pcall(func)

    if playSound then _G.PlaySound = playSound end
    if playSoundFile then _G.PlaySoundFile = playSoundFile end

    return ok
end

local function savePoints(frame)
    local points = {}
    local count = frame.GetNumPoints and frame:GetNumPoints() or 1

    for i = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        if point then
            points[#points + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end

    return points
end

local function restorePoints(frame, points)
    if not points or #points == 0 then return end

    frame:ClearAllPoints()
    for i = 1, #points do
        local p = points[i]
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

local function parkFrame(frame)
    -- Alpha alone does not stop the frame from intercepting mouse input.
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 0)
end

local function clickQueue(name)
    if PvPQ:IsInCombat() or not PvPQ:IsQueueButtonReady(name) then return end

    local button = _G[name]
    if button and button.Click then
        button:Click()
    end
end

function Bar:ApplyScale()
    if not self.frame or not PvPQ.db then return end
    self.frame:SetScale(PvPQ.db.scale or 1)
end

function Bar:UpdateVisibility()
    if not self.frame or not PvPQ.db then return end

    if PvPQ.db.hideInArena and PvPQ:IsInArena() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function Bar:ApplyPosition()
    if not self.frame or not PvPQ.db then return end

    local p = PvPQ.db.position
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        p.point or "CENTER",
        UIParent,
        p.relativePoint or p.point or "CENTER",
        p.x or 0,
        p.y or 0
    )
end

function Bar:SavePosition()
    if not self.frame or not PvPQ.db then return end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local p = PvPQ.db.position

    p.point = point or "CENTER"
    p.relativePoint = relativePoint or point or "CENTER"
    p.x = x or 0
    p.y = y or 0
end

function Bar:Layout()
    local db = PvPQ.db
    local x = 0

    if not db.locked then
        x = x + GRIP_WIDTH + GRIP_GAP
        self.dragGrip:Show()
    else
        self.dragGrip:Hide()
    end

    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", self.frame, "TOPLEFT", x, -11)

    if db.hideTitle then
        self.title:Hide()
    else
        self.title:Show()
        x = x + TITLE_WIDTH
    end

    for i = 1, 3 do
        local button = self.queueButtons[i]
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
        x = x + button:GetWidth() + BUTTON_GAP
    end

    if db.showMenuButton then
        self.buttonMenu:Show()
        self.buttonMenu:ClearAllPoints()
        self.buttonMenu:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
        x = x + self.buttonMenu:GetWidth() + BUTTON_GAP
    else
        self.buttonMenu:Hide()
    end

    self.frame:SetWidth(x - BUTTON_GAP)
    self.frame:SetHeight(BUTTON_HEIGHT)
end

function Bar:ApplySettings()
    if not self.frame or not PvPQ.db then return end

    local unlocked = not PvPQ.db.locked
    self.frame:EnableMouse(unlocked)
    self.dragGrip:EnableMouse(unlocked)

    if unlocked then
        self.unlockHint:Show()
    else
        self.unlockHint:Hide()
    end

    self:ApplyScale()
    self:Layout()
    self:UpdateVisibility()
    self:RefreshState(true)
end

function Bar:RefreshState(force)
    if not self.frame then return end

    local injected = PvPQ:IsInjected() and true or false
    local state = injected and "1" or "0"

    for i = 1, #queueTargets do
        if PvPQ:IsQueueButtonReady(queueTargets[i]) then
            state = state .. "1"
        else
            state = state .. "0"
        end
    end

    if not force and state == self.lastState then return end
    self.lastState = state

    for i = 1, #self.queueButtons do
        if PvPQ:IsQueueButtonReady(queueTargets[i]) then
            self.queueButtons[i]:Enable()
        else
            self.queueButtons[i]:Disable()
        end
    end

    if injected then
        self.buttonMenu:Enable()
    else
        self.buttonMenu:Disable()
    end
end

function Bar:RequestWarmup(delay)
    if not self.bootstrapped or PvPQ:IsInArena() then return end
    if PvPQ:IsReady() then return end

    local now = GetTime()
    self.warmPendingAt = now + (delay or 0)
    self.warmPendingUntil = now + WARMUP_TIMEOUT
end

function Bar:FinishWarmup(keepShown)
    if not self.warming then
        self.warmPendingAt = nil
        self.warmPendingUntil = nil
        return
    end

    local frame = self.warmFrame

    if frame and self.warmOwnsFrame then
        if not keepShown and frame:IsShown() then
            quietCall(function() frame:Hide() end)
        end

        if self.warmPoints then
            restorePoints(frame, self.warmPoints)
        end

        if self.warmAlpha ~= nil then
            frame:SetAlpha(self.warmAlpha)
        end
    end

    self.warming = false
    self.warmFrame = nil
    self.warmOwnsFrame = nil
    self.warmAlpha = nil
    self.warmPoints = nil
    self.warmStartedAt = nil
    self.warmConfirm = 0
    self.warmPendingAt = nil
    self.warmPendingUntil = nil

    self:RefreshState(true)
end

function Bar:StartWarmup()
    if self.warming or not self.bootstrapped or PvPQ:IsInArena() then return end
    if not PvPQ:IsInjected() or PvPQ:IsReady() then return end

    local frame = _G.RatedBGMainFrame
    if not frame then return end

    self.warming = true
    self.warmFrame = frame
    self.warmStartedAt = GetTime()
    self.warmConfirm = 0
    self.warmOwnsFrame = not frame:IsShown()

    self.warmPendingAt = nil
    self.warmPendingUntil = nil

    if self.warmOwnsFrame then
        self.warmAlpha = frame:GetAlpha()
        self.warmPoints = savePoints(frame)
        frame:SetAlpha(0)
        parkFrame(frame)
        quietCall(function() frame:Show() end)
    end
end

function Bar:UpdateWarmup(now)
    if PvPQ:IsInArena() then
        if self.warming then
            self:FinishWarmup(false)
        else
            self.warmPendingAt = nil
            self.warmPendingUntil = nil
        end
        return
    end

    if self.warmPendingAt then
        if now >= (self.warmPendingUntil or now) then
            self.warmPendingAt = nil
            self.warmPendingUntil = nil
        elseif now >= self.warmPendingAt and PvPQ:IsInjected() then
            if PvPQ:IsReady() then
                self.warmPendingAt = nil
                self.warmPendingUntil = nil
            else
                self:StartWarmup()
            end
        end
    end

    if not self.warming then return end

    if PvPQ:IsReady() then
        self.warmConfirm = self.warmConfirm + 1
        if self.warmConfirm >= 2 then
            self:FinishWarmup(false)
            return
        end
    else
        self.warmConfirm = 0
    end

    if now - (self.warmStartedAt or now) >= WARMUP_TIMEOUT then
        self:FinishWarmup(false)
    end
end

function Bar:ObserveInjection()
    local injected = PvPQ:IsInjected() and true or false

    if injected and not self.lastInjected and not self.bootstrapped then
        self.bootstrapped = true
        self:RequestWarmup(0.10)
    end

    self.lastInjected = injected
end

function Bar:OpenMenu()
    if not PvPQ:IsInjected() or PvPQ:IsInCombat() then return end

    local frame = _G.RatedBGMainFrame
    if not frame then return end

    if self.warming and self.warmOwnsFrame then
        self:FinishWarmup(true)
        frame:Show()
        return
    end

    if not frame:IsShown() then
        frame:Show()
    end
end

function Bar:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "PvPQueueBar", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    self.frame = f

    local function startDrag()
        if not PvPQ.db.locked then
            f:StartMoving()
        end
    end

    local function stopDrag()
        f:StopMovingOrSizing()
        Bar:SavePosition()
    end

    f:SetScript("OnDragStart", startDrag)
    f:SetScript("OnDragStop", stopDrag)

    local grip = CreateFrame("Frame", nil, f)
    grip:SetWidth(GRIP_WIDTH)
    grip:SetHeight(BUTTON_HEIGHT)
    grip:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", startDrag)
    grip:SetScript("OnDragStop", stopDrag)
    self.dragGrip = grip

    for i = 0, 2 do
        local line = grip:CreateTexture(nil, "ARTWORK")
        line:SetTexture([[Interface\Buttons\WHITE8X8]])
        line:SetWidth(8)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", grip, "TOPLEFT", 3, -(7 + i * 4))
        line:SetVertexColor(0.48, 0.48, 0.48, 0.9)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetText("PvP Queue")
    self.title = title

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    hint:SetText("Unlocked - drag grip to move")
    hint:SetTextColor(0.65, 0.65, 0.65)

    local font, _, flags = hint:GetFont()
    if font then hint:SetFont(font, 8, flags) end

    hint:Hide()
    self.unlockHint = hint

    self.button2v2 = makeButton(f, "PvPQueueButton2v2", "2v2", 46)
    self.button3v3 = makeButton(f, "PvPQueueButton3v3", "3v3", 46)
    self.buttonSolo = makeButton(f, "PvPQueueButtonSolo", "SoloQ", 58)
    self.buttonMenu = makeButton(f, "PvPQueueButtonMenu", "PvP Menu", 78)

    self.button2v2:SetScript("OnClick", function()
        clickQueue("RatedBGQueueArena1")
    end)

    self.button3v3:SetScript("OnClick", function()
        clickQueue("RatedBGQueueArena2")
    end)

    self.buttonSolo:SetScript("OnClick", function()
        clickQueue("RatedBGQueueSoloArena")
    end)

    self.buttonMenu:SetScript("OnClick", function()
        Bar:OpenMenu()
    end)

    self.queueButtons = {
        self.button2v2,
        self.button3v3,
        self.buttonSolo,
    }

    self.lastInjected = false
    self.bootstrapped = false
    self.warmConfirm = 0

    self:ApplyPosition()
    self:ApplySettings()

    -- Keep readiness polling active even when the bar is hidden.
    local driver = CreateFrame("Frame")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.driver = driver

    driver:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_ENTERING_WORLD" then return end

        Bar:UpdateVisibility()

        if PvPQ:IsInArena() then
            Bar:FinishWarmup(false)
        elseif Bar.bootstrapped then
            Bar:RequestWarmup(WARMUP_DELAY)
        end
    end)

    local timer = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        timer = timer + elapsed

        local interval = (Bar.warming or Bar.warmPendingAt) and 0.10 or 0.25
        if timer < interval then return end
        timer = 0

        Bar:ObserveInjection()
        Bar:UpdateWarmup(GetTime())
        Bar:RefreshState()
    end)

    return f
end
