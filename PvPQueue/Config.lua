-- Settings window

local PvPQ = _G.PvPQueueAddon
local Config = {}
PvPQ.Config = Config

local CYAN_R, CYAN_G, CYAN_B = 0.33, 0.80, 1.00

local function setBackdrop(frame, r, g, b, a, borderAlpha)
    frame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame:SetBackdropColor(r or 0.03, g or 0.03, b or 0.03, a or 0.96)
    frame:SetBackdropBorderColor(0.23, 0.23, 0.23, borderAlpha or 0.9)
end

local function makeText(parent, text, template, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")

    if size then
        local font, _, flags = fs:GetFont()
        if font then fs:SetFont(font, size, flags) end
    end

    if color == "cyan" then
        fs:SetTextColor(CYAN_R, CYAN_G, CYAN_B)
    elseif color == "muted" then
        fs:SetTextColor(0.62, 0.62, 0.62)
    else
        fs:SetTextColor(0.92, 0.92, 0.92)
    end

    return fs
end

local function makeCheck(parent, name, label, y, getValue, setValue)
    local check = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)

    local text = check.Text or _G[name .. "Text"]
    if text then
        text:SetText(label)
        text:SetTextColor(0.92, 0.92, 0.92)
    end

    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() == 1)
        PvPQ.Bar:ApplySettings()
        Config:Refresh()
    end)

    check.Refresh = function(self)
        self:SetChecked(getValue() and 1 or nil)
    end

    return check
end

function Config:Refresh()
    if not PvPQ.db then return end

    self.refreshing = true

    self.lockCheck:Refresh()
    self.titleCheck:Refresh()
    self.menuCheck:Refresh()
    self.arenaCheck:Refresh()
    self.scaleSlider:SetValue(PvPQ.db.scale or 1)
    self.scaleValue:SetText(string.format("%d%%", math.floor((PvPQ.db.scale or 1) * 100 + 0.5)))

    self.refreshing = false
end

function Config:CreateSettingsWindow()
    if self.window then return self.window end

    local f = CreateFrame("Frame", "PvPQueueSettingsFrame", UIParent)
    f:SetWidth(430)
    f:SetHeight(395)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    setBackdrop(f, 0.03, 0.03, 0.03, 0.98, 1)
    f:Hide()
    self.window = f

    table.insert(UISpecialFrames, "PvPQueueSettingsFrame")

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    header:SetHeight(46)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    setBackdrop(header, 0.055, 0.055, 0.055, 1, 0)

    local title = makeText(header, "|cff55ccffPvP|r Queue Settings", "GameFontNormalLarge", 17)
    title:SetPoint("LEFT", header, "LEFT", 14, 0)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 1)
    close:SetScript("OnClick", function() f:Hide() end)

    local subtitle = makeText(
        f, "Compact Warmane PvP queue controls. Changes apply instantly.",
        "GameFontHighlightSmall", 10, "muted"
    )
    subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -62)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetTexture([[Interface\Buttons\WHITE8X8]])
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -84)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -84)
    divider:SetHeight(1)
    divider:SetVertexColor(0.20, 0.20, 0.20, 1)

    local section = makeText(f, "GENERAL", "GameFontNormal", 11, "cyan")
    section:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -103)

    self.lockCheck = makeCheck(
        f, "PvPQueueLockCheck", "Lock Queue Bar", -123,
        function() return PvPQ.db.locked end,
        function(value) PvPQ.db.locked = value end
    )

    local lockHelp = makeText(
        f, "Unlock to drag the queue bar by its small grip; buttons stay clickable.",
        "GameFontHighlightSmall", 9, "muted"
    )
    lockHelp:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -151)

    self.titleCheck = makeCheck(
        f, "PvPQueueTitleCheck", "Hide PvP Queue Text", -176,
        function() return PvPQ.db.hideTitle end,
        function(value) PvPQ.db.hideTitle = value end
    )

    self.menuCheck = makeCheck(
        f, "PvPQueueMenuCheck", "Show PvP Menu Button", -209,
        function() return PvPQ.db.showMenuButton end,
        function(value) PvPQ.db.showMenuButton = value end
    )

    self.arenaCheck = makeCheck(
        f, "PvPQueueArenaCheck", "Hide in Arena", -242,
        function() return PvPQ.db.hideInArena end,
        function(value) PvPQ.db.hideInArena = value end
    )

    local scaleLabel = makeText(f, "BAR SCALE", "GameFontNormal", 11, "cyan")
    scaleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -286)

    local slider = CreateFrame("Slider", "PvPQueueScaleSlider", f, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -311)
    slider:SetWidth(250)
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    self.scaleSlider = slider

    _G.PvPQueueScaleSliderLow:SetText("50%")
    _G.PvPQueueScaleSliderHigh:SetText("150%")
    _G.PvPQueueScaleSliderText:SetText("")

    self.scaleValue = makeText(f, "100%", "GameFontHighlightSmall", 10)
    self.scaleValue:SetPoint("LEFT", slider, "RIGHT", 20, 0)

    slider:SetScript("OnValueChanged", function(_, value)
        if Config.refreshing then return end

        value = math.floor((value * 20) + 0.5) / 20
        PvPQ.db.scale = value
        Config.scaleValue:SetText(string.format("%d%%", math.floor(value * 100 + 0.5)))
        PvPQ.Bar:ApplyScale()
    end)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetWidth(145)
    reset:SetHeight(23)
    reset:SetPoint("TOPLEFT", f, "TOPLEFT", 244, -344)
    reset:SetText("Reset Position")
    reset:SetScript("OnClick", function()
        PvPQ:ResetPosition()
        PvPQ:Print("Position reset.")
    end)

    local credit = makeText(f, "Made by |cff55ccffFruitdealer1337|r", "GameFontHighlightSmall", 9, "muted")
    credit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 11)

    f:SetScript("OnShow", function()
        Config:Refresh()
    end)

    return f
end

function Config:CreateInterfaceLauncher()
    if self.panel then return self.panel end

    local panel = CreateFrame("Frame", "PvPQueueInterfaceOptionsPanel")
    panel.name = "PvP Queue"
    self.panel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("PvP Queue")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Configure the PvP Queue addon in its standalone settings window.")
    desc:SetTextColor(0.75, 0.75, 0.75)

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetWidth(210)
    open:SetHeight(24)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    open:SetText("Open PvP Queue Settings")
    open:SetScript("OnClick", function() Config:Open() end)

    InterfaceOptions_AddCategory(panel)
    return panel
end

function Config:Create()
    self:CreateSettingsWindow()
    self:CreateInterfaceLauncher()
end

function Config:Open()
    if not self.window then self:Create() end

    self:Refresh()
    self.window:Show()
    self.window:Raise()
end
