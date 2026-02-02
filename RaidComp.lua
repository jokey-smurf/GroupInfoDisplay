local addonName, addon = ...

local RaidComp = {}
addon.RaidComp = RaidComp

-- RaidComp.frame
-- RaidComp.size
-- RaidComp.icon
-- RaidComp.tankCount
-- RaidComp.healCount
-- RaidComp.dpsCount

-- Configuration
local ICON_SIZE = 18
local PADDING_SIDES = 8
local TEXT_PADDING = 2

-- Helper to create a segment
local function CreateRoleSegment(raidComp, role, relativeTo)
    local icon = raidComp.frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(raidComp.size, raidComp.size)

    -- Using the specific LFG role icons which are cleaner
    if role == "TANK" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
    elseif role == "HEALER" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
    elseif role == "DAMAGER" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
    end

    -- icon:SetPoint("LEFT", frame, "LEFT", xOffset, -1)
    local relativePoint = relativeTo and "RIGHT" or "LEFT"
    relativeTo = relativeTo or raidComp.frame
    icon:SetPoint("LEFT", relativeTo, relativePoint, PADDING_SIDES, -1)

    -- Count Text - matching the yellow color from your screenshot
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local fontPath, currentSize, flags = text:GetFont()
    text:SetFont(fontPath, raidComp.size, flags)

    text:SetPoint("LEFT", icon, "RIGHT", TEXT_PADDING, 1)
    text:SetTextColor(1, 0.82, 0) -- Classic Blizzard Gold/Yellow

    text.icon = icon
    text:SetText("0")
    return text
end

function RaidComp:UpdateWidth()
    local function GetWidth(n)
        return self.size + PADDING_SIDES + TEXT_PADDING + n:GetStringWidth()
    end

    local width = PADDING_SIDES + GetWidth(self.tankCount) + GetWidth(self.healCount) + GetWidth(self.dpsCount)
    self.frame:SetWidth(width)
end

function RaidComp:new(parent, size)
    local t = {}

    t.size = size

    t.frame = CreateFrame("Frame", "RoleCounterFrame", parent, "BackdropTemplate")
    t.frame:SetSize(200, size)
    t.frame:SetPoint("CENTER", 0, 0)
    t.frame:SetMovable(true)

    -- useful for development
    t.frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 12,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    local backdropHidden = true -- development feature
    t.frame:SetBackdropColor(0, 0, 0, backdropHidden and 0 or 0.8)
    t.frame:SetBackdropBorderColor(0.6, 0.6, 0.6, backdropHidden and 0 or 1)

    -- Create the 3 segments
    t.tankCount = CreateRoleSegment(t, "TANK")
    t.healCount = CreateRoleSegment(t, "HEALER", t.tankCount)
    t.dpsCount = CreateRoleSegment(t, "DAMAGER", t.healCount)

    t = setmetatable(t, { __index = RaidComp })
    t:UpdateWidth()
    return t
end

function RaidComp:ChangeFontSize(size)
    local function UpdateRole(role)
        role.icon:SetSize(size, size)

        local fontPath, currentSize, flags = role:GetFont()
        role:SetFont(fontPath, size, flags)
    end

    self.frame:SetHeight(size)
    self.size = size

    UpdateRole(self.tankCount)
    UpdateRole(self.healCount)
    UpdateRole(self.dpsCount)

    self:UpdateWidth()
end

function RaidComp:UpdateRoleCounts(nTank, nHeal, nDPS)
    self.tankCount:SetText(nTank)
    self.healCount:SetText(nHeal)
    self.dpsCount:SetText(nDPS)
    self:UpdateWidth()
end

function RaidComp:GetWidth()
    return self.frame:GetWidth()
end
