local addonName, addon = ...

local GroupInfo = {}
addon.GroupInfo = GroupInfo

-- tracked information
GroupInfo.combat = false
GroupInfo.updatePending = true
GroupInfo.lootSpec = ""
GroupInfo.spec = ""
GroupInfo.loadout = ""
GroupInfo.dungeonDifficulty = ""
GroupInfo.raidComp = ""
GroupInfo.raidDifficulty = ""
GroupInfo.groupNumber = ""

-- Difficulty Colors
local colorNormal = "0070FF"
local colorHeroic = "A335EE"
local colorMythic = "FF8000"
local colorMythicPlus = "E268A8"
local colorLFR = "E5CC63"
local colorTimewalking = "E5CC63"
local colorNone = "1EFF00"

-- Role Icons
-- Key Parameter Positions
-- To help you fine-tune the placement:
-- Size1 (14): Width
-- Size2 (14): Height
-- X-Offset (0): Horizontal move (positive = right, negative = left)
-- Y-Offset (-7): Vertical move (positive = up, negative = down)
-- local tankIcon = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:-7:64:64:0:19:22:41|t"
-- local healerIcon = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:-7:64:64:20:39:1:20|t"
-- local dpsIcon = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:-7:64:64:20:39:22:41|t"
local ICON_TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:%d:64:64:0:19:22:41|t"
local ICON_HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:%d:64:64:20:39:1:20|t"
local ICON_DAMAGE = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:%d:64:64:20:39:22:41|t"

-- format an information string
local function FormatInfo(label, info, color)
    color = color or colorNone
    return string.format('%s: |cFF%s%s|r', label, color, info)
end

-- get the Raid Composition display string
-- does funky scaling and movement depending on the placement in the frame and/or font size
-- probs something I am missing
function GroupInfo:RaidComposition(size, offset)
    local function FormatIcon(icon)
        addon.Msg("Roles", size, offset)
        return string.format(icon, size, size, -offset)
    end

    local tankCount = GroupInfo.tankCount or 0
    local healerCount = GroupInfo.healerCount or 0
    local damageCount = GroupInfo.damageCount or 0

    return FormatIcon(ICON_TANK) .. tankCount .. " " ..
        FormatIcon(ICON_HEALER) .. healerCount .. " " ..
        FormatIcon(ICON_DAMAGE) .. damageCount
end

function GroupInfo:ForceUpdate()
    self.updatePending = true
end

function GroupInfo:HasUpdate()
    return self.updatePending
end

function GroupInfo:ClearUpdate()
    self.updatePending = false
end

-- Loot Spec
-- PLAYER_LOOT_SPEC_UPDATED
local function UpdateLootSpec()
    local specID = GetLootSpecialization() or 0
    local _, name, _, _, _, _, _ = GetSpecializationInfoForSpecID(specID)
    name = name or "Current Spec"

    GroupInfo.lootSpec = FormatInfo("Loot", name)
end

-- Spec/Hero/Loadouts
-- TRAIT_CONFIG_UPDATED
local function UpdateLoadout()
    local specID = PlayerUtil.GetCurrentSpecID() -- First get the current specialization ID
    local savedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)

    local name = "Default"
    if savedConfigID then
        local configInfo = C_Traits.GetConfigInfo(savedConfigID)
        if configInfo and configInfo.name then
            name = configInfo.name
        end
    end

    local _, specName = GetSpecializationInfoByID(specID)
    specName = specName or "Unknown"

    local hero = "Unknown"
    local heroSubTreeID = C_ClassTalents.GetActiveHeroTalentSpec()
    if heroSubTreeID then
        local subTreeInfo = C_Traits.GetSubTreeInfo(C_ClassTalents.GetActiveConfigID(), heroSubTreeID)
        if subTreeInfo and subTreeInfo.name then
            hero = subTreeInfo.name
        end
    end

    GroupInfo.spec = FormatInfo("Spec", specName)
    GroupInfo.hero = FormatInfo("Hero", hero)
    GroupInfo.loadout = FormatInfo("Loadout", name)
end

-- Dungeon Difficulty
-- PLAYER_DIFFICULTY_CHANGED
local function UpdateDungeonDifficulty()
    local dungeonDiff = GetDungeonDifficultyID()
    local name, _, _, _, _, _, _ = GetDifficultyInfo(dungeonDiff) or ""
    local _, instanceType, _, difficultyName, _, _, _, _, _, _ = GetInstanceInfo()
    local color = colorNone

    --
    difficultyName = difficultyName or ""
    instanceType = instanceType or "none"

    -- addon.Msg("DungeonDifficulty", name, "- instanceType", difficultyName)

    -- Blizz UI Bug
    -- After exiting Story/Follower/Timewalking/Delves (maybe anything other than normal/heroic/mythic),
    -- the API does not always reset the dungeon difficulty to the previously selected difficulty.
    -- In the difficulty menu, no difficulties are selected.
    -- The previous difficulty may NOT be selected by the user, any other can be.

    if instanceType == "none" then
        if dungeonDiff ~= 1 and dungeonDiff ~= 2 and dungeonDiff ~= 23 then
            GroupInfo.dungeonDifficulty = FormatInfo("Dungeon", "Not Set", colorNone)
            return
        end
    end

    if dungeonDiff == 1 then
        color = colorNormal
    elseif dungeonDiff == 2 then
        color = colorHeroic
    elseif dungeonDiff == 8 then -- challenge mode? not Mythic+
        color = colorMythic
    elseif dungeonDiff == 23 then
        color = colorMythic
        if string.find(difficultyName, "Keystone", 1, true) then
            name = "Mythic+"
            color = colorMythicPlus
        end
    elseif dungeonDiff == 24 then
        color = colorTimewalking
    elseif dungeonDiff == 205 then -- Follower
        color = colorLFR
    elseif dungeonDiff == 208 then -- Delve
        color = colorNone
    else
        -- Timewalking/follower/story mode can do funky things to dungeon difficulty on exit
        -- Doesn't always reset or puts it in a funky mode (i.e. Normal Scaling 1-5, id 150)
        -- Additional catch all for above
        name = "Not Set"
    end

    GroupInfo.dungeonDifficulty = FormatInfo("Dungeon", name, color)
end

-- Raid Difficulty
-- PLAYER_DIFFICULTY_CHANGED
local function UpdateRaidDifficulty()
    local raidDiff = GetRaidDifficultyID()
    local name, _, _, _, _, _, _ = GetDifficultyInfo(raidDiff) or "Unknown"
    local color = colorNone

    -- addon.Msg("RaidDifficulty", name)

    if raidDiff == 14 then
        color = colorNormal
    elseif raidDiff == 15 then
        color = colorHeroic
    elseif raidDiff == 16 then
        color = colorMythic
    elseif raidDiff == 17 then
        color = colorLFR
    elseif raidDiff == 33 then
        color = colorTimewalking
    elseif raidDiff == 151 then -- where is this a thing?
        name = "LFR Timewalking"
        color = colorTimewalking
    elseif raidDiff == 220 then -- story mode raid
        color = colorLFR
    end

    GroupInfo.raidDifficulty = FormatInfo("Raid", name, color)
end

-- Raid Composition
-- GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED
local function UpdateRaidComp()
    local tankCount = 0
    local healerCount = 0
    local damageCount = 0

    for i = 1, GetNumGroupMembers() do
        local role = UnitGroupRolesAssigned("raid" .. i)

        if type(role) == "string" then
            if role == "TANK" then
                tankCount = tankCount + 1
            elseif role == "HEALER" then
                healerCount = healerCount + 1
            elseif role == "DAMAGER" then
                damageCount = damageCount + 1
            end
        end
    end

    GroupInfo.tankCount = tankCount
    GroupInfo.healerCount = healerCount
    GroupInfo.damageCount = damageCount
end

-- Group Number
-- GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED
local function UpdateGroupNumber()
    local playerIndex = UnitInRaid("player")
    local groupNum = 0

    if playerIndex then
        local _, _, raidGroupNum = GetRaidRosterInfo(playerIndex)
        groupNum = raidGroupNum or 0
    end

    GroupInfo.groupNumber = FormatInfo("Group", tostring(groupNum))
end


local postCombatUpdate = false -- update after combat finishes, nothing here needs to be updated during combat
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
-- Raid Composition
-- GROUP_ROSTER_UPDATE appears to be ALWAYS followed by PLAYER_ROLES_ASSIGNED
-- No Need to do both
-- eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
-- Talent/Loadout changes
-- eventFrame:RegisterEvent("INSPECT_READY")
-- eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
-- eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
-- Combat monitoring
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
-- eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
-- eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")

eventFrame:SetScript("OnEvent", function(self, event)
    addon.Msg("OnEvent", event, addon.IsLockedDown())

    if event == "PLAYER_REGEN_DISABLED" then
        postCombatUpdate = false
        return
    end

    if InCombatLockdown() then
        postCombatUpdate = true
        return
    end

    -- probs just return and update on end
    if event == "PLAYER_REGEN_ENABLED" then
        -- addon.Msg("Post Combat Update", postCombatUpdate)
        if not postCombatUpdate then
            return
        end
        event = "DO_EVERYTHING"
    end

    GroupInfo.updatePending = true;

    if event == "PLAYER_ENTERING_WORLD" then
        event = "DO_EVERYTHING"
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        event = "DO_EVERYTHING"
    end

    if event == "DO_EVERYTHING" then
        UpdateLootSpec()
        UpdateLoadout()
        UpdateDungeonDifficulty()
        if IsInRaid() then
            UpdateRaidDifficulty()
            UpdateGroupNumber()
            UpdateRaidComp()
        end
        return
    end

    -- This is the only reliable event I have found when loadout changes
    if event == "INSPECT_READY" or event == "TRAIT_CONFIG_UPDATED" then
        UpdateLoadout()
        return
    end

    if event == "PLAYER_DIFFICULTY_CHANGED" or event == "CHALLENGE_MODE_START" then
        UpdateRaidDifficulty()
        UpdateDungeonDifficulty()
        return
    end

    -- Looks like GRU is ALWAYS followed by PRA, could probs eliminate one (GRU)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        UpdateGroupNumber()
        UpdateRaidComp()
        return
    end

    if event == "PLAYER_LOOT_SPEC_UPDATED" then
        UpdateLootSpec()
        return
    end
end)
