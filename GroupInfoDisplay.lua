-- Addon replacement for FUNKI's Weakaura Group Info Display

local addonName, addon = ...
GroupInfoDisplayDB = GroupInfoDisplayDB or {}
addon.GroupInfoDisplayDB = GroupInfoDisplayDB

GI = addon.GroupInfo

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- DEFAULT_CONFIG
local DEFAULT_CONFIG = {
    showGroupNumber = true,
    showRaidComp = true,
    showRaidDifficulty = true,
    showDungeonDifficulty = true,
    showSpec = true,
    showHero = true,
    showLoadout = true,
    showLootSpec = true,
    hideInCombat = false,
    fontSize = 14,
    point = "CENTER",
    relativePoint = "CENTER",
    offsetX = 0,
    offsetY = 0,
}

local function AddonName(color)
    local color = color or "00FF00"
    return string.format("|cff%s%s|r", color, addonName)
end

-- print() with addon name
local function Msg(msg, ...)
    print(AddonName() .. ": " .. msg, ...)
end
addon.Msg = Msg

-- M+ or Combat
local function IsLockedDown()
    return InCombatLockdown() or C_ChallengeMode.IsChallengeModeActive()
end
addon.IsLockedDown = IsLockedDown

-- login message
local _version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
Msg("Version", _version)

-- Create main frame with backdrop support
local frame = CreateFrame("Frame", "GroupInfoDisplayFrame", UIParent, "BackdropTemplate")
-- frame:SetSize(100, 100)
-- frame:SetPoit(DEFAULT_CONFIG.point, UIParent, DEFAULT_CONFIG.relativePoint, DEFAULT_CONFIG.offsetX,
--     DEFAULT_CONFIG.offsetY)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)

-- Rounded background (tooltip-style)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
frame:SetBackdropColor(0, 0, 0, 0)
frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

local _locked = true
local function SetLocked(lock)
    if lock == nil then
        lock = true
    end
    _locked = lock
    if _locked then
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
        frame:SetMovable(false)
        frame:RegisterForDrag()
    else
        frame:SetBackdropColor(0, 0, 0, 0.7)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
    end
end

-- Text display
local text = frame:CreateFontString(nil, "OVERLAY")
text:SetFont(DEFAULT_FONT, DEFAULT_CONFIG.fontSize, "OUTLINE", "MONOCHROME")
text:SetPoint("BOTTOM", 0, 5)
text:SetSpacing(2)
text:SetJustifyV("BOTTOM")
text:SetJustifyH("CENTER")
text:SetTextColor(1, 1, 1)

local text2 = frame:CreateFontString(nil, "OVERLAY")
text2:SetFont(DEFAULT_FONT, DEFAULT_CONFIG.fontSize, "OUTLINE", "MONOCHROME")
text2:SetPoint("TOP", 0, 0)
text2:SetSpacing(2)
text2:SetJustifyV("BOTTOM")
text2:SetJustifyH("CENTER")
text2:SetTextColor(1, 1, 1)

-- Drag functionality
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relativePoint, offsetX, offsetY = self:GetPoint()
    GroupInfoDisplayDB.point = point
    GroupInfoDisplayDB.relativePoint = relativePoint
    GroupInfoDisplayDB.offsetX = offsetX
    GroupInfoDisplayDB.offsetY = offsetY
end)

-- Update stats
local _elapsed = 0
frame:SetScript("OnUpdate", function(self, delta)
    _elapsed = _elapsed + delta
    if _elapsed < 1 or not GI:HasUpdate() then
        return
    end

    _elapsed = 0
    GI:ClearUpdate()

    local offset = 0
    local raidCompAlpha = 0
    local displayText = ""
    local inInstance, instanceType = IsInInstance()
    text2:SetText("")
    if IsInRaid() then
        if GroupInfoDisplayDB.showGroupNumber then
            offset = GroupInfoDisplayDB.fontSize + 5
            displayText = displayText .. GI.groupNumber .. "\n"
        end
        if GroupInfoDisplayDB.showRaidComp then
            raidCompAlpha = 1
            displayText = displayText .. "\n"
            local s = GI:RaidComposition(14, GroupInfoDisplayDB.fontSize)
            text2:SetText(s)
        end
        if GroupInfoDisplayDB.showRaidDifficulty then
            displayText = displayText .. GI.raidDifficulty .. "\n"
        end
    elseif IsInGroup() then
        if GroupInfoDisplayDB.showDungeonDifficulty then
            displayText = displayText .. GI.dungeonDifficulty .. "\n"
        end
    elseif inInstance then
        if instanceType == "party" then
            if GroupInfoDisplayDB.showDungeonDifficulty then
                displayText = displayText .. GI.dungeonDifficulty .. "\n"
            end
        elseif instanceType == "raid" then
            if GroupInfoDisplayDB.showRaidDifficulty then
                displayText = displayText .. GI.raidDifficulty .. "\n"
            end
        end
    end
    if GroupInfoDisplayDB.showSpec then
        displayText = displayText .. GI.spec .. "\n"
    end
    if GroupInfoDisplayDB.showHero then
        displayText = displayText .. GI.hero .. "\n"
    end
    if GroupInfoDisplayDB.showLoadout then
        displayText = displayText .. GI.loadout .. "\n"
    end
    if GroupInfoDisplayDB.showLootSpec then
        displayText = displayText .. GI.lootSpec .. "\n"
    end

    if displayText == "" then
        displayText = AddonName()
    end
    text:SetText(displayText)

    -- Auto-resize frame based on text width
    local textWidth = math.max(text:GetStringWidth(), text2:GetStringWidth())
    local newWidth = textWidth + 10
    if newWidth < 50 then newWidth = 50 end
    frame:SetWidth(newWidth)

    local textHeight = text:GetStringHeight()
    local newHeight = textHeight + 10
    if newHeight < 20 then newHeight = 20 end
    frame:SetHeight(newHeight)

    text2:SetPoint("TOP", frame, "TOP", -5, -offset)
    text2:SetAlpha(raidCompAlpha)
end)


-- create config menu
local menuFrame = CreateFrame("Frame", "GroupInfoDisplayMenu", UIParent, "UIDropDownMenuTemplate")

local function InitializeMenu(self, level)
    local function AddSeparator()
        local info = UIDropDownMenu_CreateInfo()
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    local function AddItem(text, checked, func, keepShownOnClick)
        local info = UIDropDownMenu_CreateInfo()
        info.text = text
        info.checked = checked
        info.func = func
        info.isNotRadio = true
        info.keepShownOnClick = (keepShownOnClick == nil) and true or keepShownOnClick
        UIDropDownMenu_AddButton(info, level)
    end

    level = level or 1
    if level ~= 1 then
        return
    end

    -- Title
    local info = UIDropDownMenu_CreateInfo()
    info.isTitle = true
    info.text = AddonName() .. " v" .. _version
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    AddSeparator()
    AddItem("Hide in Combat", GroupInfoDisplayDB.hideInCombat, function()
        GroupInfoDisplayDB.hideInCombat = not GroupInfoDisplayDB.hideInCombat
        GI.updatePending = true
    end)

    AddSeparator()
    AddItem("Raid Group Number", GroupInfoDisplayDB.showGroupNumber, function()
        GroupInfoDisplayDB.showGroupNumber = not GroupInfoDisplayDB.showGroupNumber
        GI.updatePending = true
    end)
    AddItem("Raid Composition", GroupInfoDisplayDB.showRaidComp, function()
        GroupInfoDisplayDB.showRaidComp = not GroupInfoDisplayDB.showRaidComp
        GI.updatePending = true
    end)
    AddItem("Raid Difficulty", GroupInfoDisplayDB.showRaidDifficulty, function()
        GroupInfoDisplayDB.showRaidDifficulty = not GroupInfoDisplayDB.showRaidDifficulty
        GI.updatePending = true
    end)
    AddItem("Dungeon Difficulty", GroupInfoDisplayDB.showDungeonDifficulty, function()
        GroupInfoDisplayDB.showDungeonDifficulty = not GroupInfoDisplayDB.showDungeonDifficulty
        GI.updatePending = true
    end)
    AddItem("Specialization", GroupInfoDisplayDB.showSpec, function()
        GroupInfoDisplayDB.showSpec = not GroupInfoDisplayDB.showSpec
        GI.updatePending = true
    end)
    AddItem("Hero Talents", GroupInfoDisplayDB.showHero, function()
        GroupInfoDisplayDB.showHero = not GroupInfoDisplayDB.showHero
        GI.updatePending = true
    end)
    AddItem("Loadout", GroupInfoDisplayDB.showLoadout, function()
        GroupInfoDisplayDB.showLoadout = not GroupInfoDisplayDB.showLoadout
        GI.updatePending = true
    end)
    AddItem("Loot Spec", GroupInfoDisplayDB.showLootSpec, function()
        GroupInfoDisplayDB.showLootSpec = not GroupInfoDisplayDB.showLootSpec
        GI.updatePending = true
    end)

    AddSeparator()
    AddItem("Display Lock", _locked, function()
        _locked = not _locked
        SetLocked(_locked)
        Msg(_locked and "Locked" or "Unlocked")
    end, false)
end

-- right-click to show menu
frame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        UIDropDownMenu_Initialize(menuFrame, InitializeMenu, "MENU")
        ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
    end
end)

-- apply the font size change
local function ApplyFont()
    local fontPath, currentSize, flags = text:GetFont()

    local fontSize = tonumber(GroupInfoDisplayDB.fontSize or DEFAULT_CONFIG.fontSize)
    if fontSize < 8 then
        fontSize = 8
    end
    text:SetFont(fontPath, fontSize, flags)
    text2:SetFont(fontPath, fontSize, flags)
end

-- apply the configuration change
-- reset == true, reinitialize the DEFAULT_CONFIG
local function ApplyConfig(reset)
    if not reset then reset = false end

    for k, v in pairs(DEFAULT_CONFIG) do
        if reset or GroupInfoDisplayDB[k] == nil then
            GroupInfoDisplayDB[k] = v
        end
    end

    -- Restore location
    frame:ClearAllPoints()
    frame:SetPoint(
        GroupInfoDisplayDB.point,
        UIParent,
        GroupInfoDisplayDB.relativePoint,
        GroupInfoDisplayDB.offsetX,
        GroupInfoDisplayDB.offsetY
    )

    -- unlock on reset
    SetLocked(not reset)
    ApplyFont()

    -- force redraw
    GI:ForceUpdate()
end

-- Slash command
SLASH_GROUPINFODISPLAY1 = "/gid"
SlashCmdList["GROUPINFODISPLAY"] = function(msg)
    local arg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if arg == "reset" then
        ApplyConfig(true)
        return
    end

    local name, size = arg:match("^(font)%s+(%d+)$")
    if name and size then
        GroupInfoDisplayDB.fontSize = tonumber(size) or GroupInfoDisplayDB.fontSize
        ApplyFont()
        GI:ForceUpdate()
        return
    end

    Msg("Version", _version)
    print("  /gid font NN - Set font size (currently " .. GroupInfoDisplayDB.fontSize .. ")")
    print("  /gid reset - Reset settings")
    print("")
    print("  Right-click GID display to configure.")
end

-- Event handling
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
loginFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
loginFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if GroupInfoDisplayDB.hideInCombat then
            frame:Hide()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if GroupInfoDisplayDB.hideInCombat then
            frame:Show()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        ApplyConfig()
        loginFrame:UnregisterEvent("PLAYER_LOGIN")
        return
    end
end)
