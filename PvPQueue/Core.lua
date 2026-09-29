-- PvP Queue

local addonName = "PvPQueue"
local PvPQ = _G.PvPQueueAddon or {}
_G.PvPQueueAddon = PvPQ

PvPQ.VERSION = "1.0.1"

PvPQ.defaults = {
    locked = true,
    hideTitle = false,
    showMenuButton = true,
    hideInArena = false,
    scale = 1.0,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -180,
    },
}

local function fillDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            fillDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function PvPQ:InitializeDB()
    if type(_G.PvPQueueDB) ~= "table" then
        _G.PvPQueueDB = {}
    end

    _G.PvPQueueDB.showStatus = nil

    fillDefaults(_G.PvPQueueDB, self.defaults)

    local scale = tonumber(_G.PvPQueueDB.scale) or 1.0
    if scale < 0.5 then scale = 0.5 end
    if scale > 1.5 then scale = 1.5 end
    _G.PvPQueueDB.scale = scale

    self.db = _G.PvPQueueDB
end

function PvPQ:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ccffPvP Queue:|r " .. tostring(msg))
end

function PvPQ:IsInjected()
    return _G.RatedBGMainFrame
        and _G.RatedBGQueueArena1
        and _G.RatedBGQueueArena2
        and _G.RatedBGQueueSoloArena
end

function PvPQ:IsQueueButtonReady(name)
    local button = _G[name]
    if not button or not button.IsEnabled then return false end
    local enabled = button:IsEnabled()
    return enabled == 1 or enabled == true
end

function PvPQ:IsReady()
    return self:IsInjected()
        and self:IsQueueButtonReady("RatedBGQueueArena1")
        and self:IsQueueButtonReady("RatedBGQueueArena2")
        and self:IsQueueButtonReady("RatedBGQueueSoloArena")
end

function PvPQ:IsInArena()
    if not _G.GetInstanceInfo then return false end
    local _, instanceType = _G.GetInstanceInfo()
    return instanceType == "arena"
end

function PvPQ:IsInCombat()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return true
    end

    return _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") or false
end

function PvPQ:ResetPosition()
    if not self.db then return end

    local position = self.defaults.position
    self.db.position = {
        point = position.point,
        relativePoint = position.relativePoint,
        x = position.x,
        y = position.y,
    }
    if self.Bar then
        self.Bar:ApplyPosition()
    end
end

function PvPQ:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:InitializeDB()
    self.Bar:Create()
    self.Config:Create()

    SLASH_PVPQUEUE1 = "/pvpq"
    SlashCmdList.PVPQUEUE = function(msg)
        msg = string.lower(msg or "")

        if msg == "reset" then
            PvPQ:ResetPosition()
            PvPQ:Print("Position reset.")
            return
        end

        PvPQ.Config:Open()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end

    PvPQ:Initialize()
    self:UnregisterEvent("ADDON_LOADED")
end)
