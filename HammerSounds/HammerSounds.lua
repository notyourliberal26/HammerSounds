-- HammerSounds: plays a random silly sound when you hit something with a hammer,
-- and (optionally) mutes the stock two-handed mace hit sounds.
--
-- Works on WoW Forever (interface 16001), where the combat log is closed to
-- addons and combat values can be "secret", and on Classic Era, where the
-- combat log is still open.

local addonName, ns = ...

local SOUND_DIR = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\"

-- Files in the Sounds folder. Add your own .ogg/.mp3 here (then restart WoW,
-- /reload does not pick up new sound files).
local SOUNDS = {
    "squeak.ogg",
    -- CC0 sounds from freesound.org (credits in Sounds\README.txt)
    -- bonks and smacks
    "fs_bonk_cookie.ogg",
    "fs_bonk_harrisando.ogg",
    "fs_bonk_facklere.ogg",
    "fs_frying_pan.ogg",
    "fs_frying_pan2.ogg",
    "fs_cartoon_slap.ogg",
    "fs_thud.ogg",
    -- slide whistles
    "fs_dizzy_whistle.ogg",
    "fs_whistle_down.ogg",
    "fs_cartoon_fall.ogg",
    -- honks, boings, squeaks
    "fs_bike_honk.ogg",
    "fs_clown_horn.ogg",
    "fs_cartoon_boing.ogg",
    "fs_boing2.ogg",
    "fs_harp_boing.ogg",
    "fs_funny_boing.ogg",
    "fs_springy_bounce.ogg",
    "fs_squeaky_toy.ogg",
}

-- Bonk-only mode (/hammer bonk). Switch back to everything with /hammer all.
local BONKS = {
    "fs_bonk_cookie.ogg",
    "fs_bonk_harrisando.ogg",
    "fs_bonk_facklere.ogg",
    "fs_bonk_phoenixdk.ogg",
    "fs_bonk_head.ogg",
    "fs_bonk_bottle.ogg",
    "fs_bonk_plop.ogg",
    "fs_thump.ogg",
    "fs_boink.ogg",
    "fs_boink2.ogg",
    "fs_vocal_boink.ogg",
    "fs_wood_tok.ogg",
    "fs_tonk.ogg",
    "fs_kabong.ogg",
    "fs_trashcan.ogg",
}

-- "all" mode plays the bonks too
for _, name in ipairs(BONKS) do
    local found = false
    for _, existing in ipairs(SOUNDS) do
        if existing == name then found = true break end
    end
    if not found then SOUNDS[#SOUNDS + 1] = name end
end

local AUTO_ATTACK = 6603   -- "Auto Attack" spell
local MIN_GAP = 0.20       -- seconds; stops double sounds from one swing
local CAST_WINDOW = 0.6    -- an ability hit counts if it lands this soon after your cast

local MACE_1H = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Mace1H) or 4
local MACE_2H = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Mace2H) or 5
local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

local DEFAULTS = {
    enabled = true,
    mute = true,       -- silence the stock 2H mace hit sounds while a hammer is equipped
    oneHand = false,   -- also count one-handed maces
    channel = "SFX",   -- SFX or Master
    debug = false,
    soundSet = "bonk", -- "bonk" = just the bonks, "all" = every sound
}

local db
local hasHammer = false
local muted = false
local lastIndex, lastPlay, lastCast = 0, 0, 0
local warnedPlay = false

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function Print(msg)
    print("|cffffb000HammerSounds:|r " .. msg)
end

-- On Forever some combat values are "secret": they can be passed around but
-- comparing or printing them throws an error. Treat a secret as "unknown".
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Readable(v)
    if IsSecret(v) then return nil end
    return v
end

local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function UpdateWeapon()
    local was = hasHammer
    hasHammer = false
    local itemID = GetInventoryItemID("player", 16) -- main hand
    if itemID and getInfo then
        local _, _, _, _, _, classID, subClassID = getInfo(itemID)
        if classID == WEAPON_CLASS then
            hasHammer = subClassID == MACE_2H or (db.oneHand and subClassID == MACE_1H)
        end
    end
    if db.debug and was ~= hasHammer then
        Print("hammer equipped: " .. tostring(hasHammer))
    end
end

local function SetMuted(want)
    if want == muted or not MuteSoundFile then return end
    local fn = want and MuteSoundFile or UnmuteSoundFile
    for _, id in ipairs(ns.MUTE_IDS or {}) do
        pcall(fn, id)
    end
    muted = want
end

local function UpdateMute()
    SetMuted(db.enabled and db.mute and hasHammer)
end

local function CurrentSounds()
    if db and db.soundSet == "bonk" then return BONKS end
    return SOUNDS
end

local function PlayHammer(force)
    local list = CurrentSounds()
    if #list == 0 then return end
    local now = GetTime()
    if not force and now - lastPlay < MIN_GAP then return end
    lastPlay = now

    local i = math.random(#list)
    if #list > 1 and i == lastIndex then
        i = (i % #list) + 1 -- never the same sound twice in a row
    end
    lastIndex = i

    local ok, willPlay = pcall(PlaySoundFile, SOUND_DIR .. list[i], db.channel)
    if (not ok or willPlay == false) and not warnedPlay then
        warnedPlay = true
        Print("couldn't play " .. list[i] .. ". Check the file is in the Sounds folder and restart WoW.")
    end
end

-- Auto-attack state. PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT fire when your
-- auto-attack turns on and off; the spell check is a backup. On Forever the old
-- global IsCurrentSpell may be gone (it lives in C_Spell there).
local autoAttack = false
local isCurrentSpell = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell

local function AutoAttacking()
    if autoAttack then return true end
    if isCurrentSpell then
        local ok, on = pcall(isCurrentSpell, AUTO_ATTACK)
        if ok and on == true then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- hit detection
---------------------------------------------------------------------------

-- Forever path: UNIT_COMBAT on your target. It doesn't say who did the
-- damage, so only count it while you're auto-attacking that target or just
-- cast something at it. In a group other people's hits on your target can
-- slip through; the MIN_GAP throttle keeps that from turning into spam.
local function OnUnitCombat(unit, action, flagText, amount, schoolMask)
    if unit ~= "target" then return end
    if db.debug then
        Print(("UNIT_COMBAT %s %s %s"):format(
            tostring(Readable(action) or "<secret>"),
            tostring(Readable(amount) or "<secret>"),
            tostring(Readable(schoolMask) or "<secret>")))
    end
    local function Skip(why)
        if db.debug then Print("  -> no sound: " .. why) end
    end
    if not hasHammer then return Skip("no hammer equipped (try /hammer 1h for one-handers)") end
    if not (AutoAttacking() or GetTime() - lastCast < CAST_WINDOW) then
        return Skip("you weren't auto-attacking or casting")
    end

    local act = Readable(action)
    if act and act ~= "WOUND" and act ~= "BLOCK" then return Skip("miss/dodge/parry") end
    local school = Readable(schoolMask)
    if school and school ~= 1 then return Skip("not physical damage") end
    if db.debug then Print("  -> sound played") end
    PlayHammer()
end

-- Classic Era path: the combat log tells us exactly whose swing it was.
local function OnCombatLog()
    if not hasHammer then return end
    local _, subevent, _, sourceGUID = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= UnitGUID("player") then return end
    if subevent == "SWING_DAMAGE" then
        PlayHammer()
    elseif subevent == "SPELL_DAMAGE" then
        local school = select(14, CombatLogGetCurrentEventInfo())
        if school == 1 then PlayHammer() end
    end
end

local function CombatLogOpen()
    -- Forever exposes secret values and no combat-log reader for addons.
    return CombatLogGetCurrentEventInfo ~= nil and issecretvalue == nil
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")

local function SafeRegister(event, unit)
    local ok
    if unit and f.RegisterUnitEvent then
        ok = pcall(f.RegisterUnitEvent, f, event, unit)
    else
        ok = pcall(f.RegisterEvent, f, event)
    end
    return ok
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        HammerSoundsDB = HammerSoundsDB or {}
        db = HammerSoundsDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        f:UnregisterEvent("ADDON_LOADED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        SafeRegister("PLAYER_ENTER_COMBAT")
        SafeRegister("PLAYER_LEAVE_COMBAT")
        SafeRegister("PLAYER_REGEN_ENABLED")
        if CombatLogOpen() then
            ns.source = "combat log"
            f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else
            ns.source = "target hits"
            SafeRegister("UNIT_COMBAT", "target")
            SafeRegister("UNIT_SPELLCAST_SUCCEEDED", "player")
        end
        return
    end

    if not db or not db.enabled then
        if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            UpdateWeapon()
            UpdateMute()
        end
        return
    end

    if event == "PLAYER_ENTER_COMBAT" then
        autoAttack = true
        if db.debug then Print("auto-attack on") end
    elseif event == "PLAYER_LEAVE_COMBAT" or event == "PLAYER_REGEN_ENABLED" then
        if autoAttack and db.debug then Print("auto-attack off") end
        autoAttack = false
    elseif event == "UNIT_COMBAT" then
        OnUnitCombat(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        lastCast = GetTime()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    else -- PLAYER_ENTERING_WORLD / PLAYER_EQUIPMENT_CHANGED
        UpdateWeapon()
        UpdateMute()
    end
end)

---------------------------------------------------------------------------
-- slash commands
---------------------------------------------------------------------------

local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff4040off|r" end

local function Status()
    Print(("enabled %s, mute stock sounds %s, 1H maces %s, channel %s, debug %s"):format(
        OnOff(db.enabled), OnOff(db.mute), OnOff(db.oneHand), db.channel, OnOff(db.debug)))
    Print(("hammer equipped: %s, hit detection: %s, sounds: %s (%d)"):format(
        tostring(hasHammer), ns.source or "?",
        db.soundSet == "bonk" and "bonks only" or "all", #CurrentSounds()))
end

SLASH_HAMMERSOUNDS1 = "/hammer"
SLASH_HAMMERSOUNDS2 = "/hammersounds"
SlashCmdList["HAMMERSOUNDS"] = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
    if cmd == "" or cmd == "test" then
        PlayHammer(true)
        Status()
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        UpdateMute()
        Print("now " .. OnOff(db.enabled))
    elseif cmd == "mute" then
        db.mute = not db.mute
        UpdateMute()
        Print("mute stock mace sounds " .. OnOff(db.mute))
    elseif cmd == "1h" then
        db.oneHand = not db.oneHand
        UpdateWeapon()
        UpdateMute()
        Print("one-handed maces " .. OnOff(db.oneHand))
    elseif cmd == "channel" then
        db.channel = (arg == "master") and "Master" or "SFX"
        Print("playing on the " .. db.channel .. " channel")
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("debug " .. OnOff(db.debug) .. " (prints each hit event on your target)")
    elseif cmd == "bonk" or cmd == "all" then
        db.soundSet = cmd
        lastIndex = 0
        Print(cmd == "bonk" and "bonks only" or "playing every sound")
        PlayHammer(true)
    elseif cmd == "status" then
        Status()
    else
        Print("/hammer [test]  play a sound + show status")
        Print("/hammer bonk    just the bonks      /hammer all    every sound")
        Print("/hammer on | off    /hammer mute    /hammer 1h")
        Print("/hammer channel sfx | master    /hammer debug")
    end
end
