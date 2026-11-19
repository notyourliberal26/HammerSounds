-- HammerSounds: plays a random silly sound when you hit something with any
-- weapon type you've switched on (all of them by default), and optionally
-- mutes the stock two-handed mace hit sounds.
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

-- Bonk-only mode (/hammer bonk). Switch to everything with /hammer sounds all.
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

local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

-- Weapon types you can switch on and off. key = what you type in /hammer,
-- id = the item weapon subclass. "unarmed" means nothing in your main hand.
local WEAPONS = {
    { key = "2hmace",   name = "Two-handed maces",   id = 5 },
    { key = "1hmace",   name = "One-handed maces",   id = 4 },
    { key = "2hsword",  name = "Two-handed swords",  id = 8 },
    { key = "1hsword",  name = "One-handed swords",  id = 7 },
    { key = "2haxe",    name = "Two-handed axes",    id = 1 },
    { key = "1haxe",    name = "One-handed axes",    id = 0 },
    { key = "polearm",  name = "Polearms",           id = 6 },
    { key = "staff",    name = "Staves",             id = 10 },
    { key = "dagger",   name = "Daggers",            id = 15 },
    { key = "fist",     name = "Fist weapons",       id = 13 },
    { key = "spear",    name = "Spears",             id = 17 },
    { key = "bow",      name = "Bows",               id = 2 },
    { key = "gun",      name = "Guns",               id = 3 },
    { key = "crossbow", name = "Crossbows",          id = 18 },
    { key = "thrown",   name = "Thrown weapons",     id = 16 },
    { key = "wand",     name = "Wands",              id = 19 },
    { key = "unarmed",  name = "Unarmed (no weapon)" },
}
local WEAPON_BY_KEY, WEAPON_BY_ID = {}, {}
for _, w in ipairs(WEAPONS) do
    WEAPON_BY_KEY[w.key] = w
    if w.id then WEAPON_BY_ID[w.id] = w end
end
-- Extra names people might type
local WEAPON_ALIASES = {
    ["1h"] = "1hmace", ["hammer"] = "2hmace", ["mace"] = "2hmace",
    ["sword"] = "1hsword", ["axe"] = "1haxe", ["staves"] = "staff",
    ["fists"] = "fist", ["bows"] = "bow", ["guns"] = "gun",
    ["daggers"] = "dagger", ["wands"] = "wand", ["polearms"] = "polearm",
}

local DEFAULTS = {
    enabled = true,
    mute = true,       -- silence the stock 2H mace hit sounds while a 2H mace is equipped
    channel = "SFX",   -- SFX or Master
    debug = false,
    soundSet = "bonk", -- "bonk" = just the bonks, "all" = every sound
}

local db
local hasHammer = false   -- an enabled weapon type is equipped
local has2HMace = false   -- for muting the stock 2H mace sounds
local hasWand = false     -- wand hits aren't physical, so let them through
local meleeOn = false     -- an enabled weapon in main/off hand (or unarmed)
local rangedOn = false    -- an enabled bow/gun/crossbow/thrown/wand
local equippedNames = ""
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

local function WeaponIn(slot)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID or not getInfo then return nil end
    local _, _, _, _, _, classID, subClassID = getInfo(itemID)
    if classID ~= WEAPON_CLASS then return nil end
    return WEAPON_BY_ID[subClassID]
end

-- Looks at main hand (16), off hand (17) and ranged slot (18).
local function UpdateWeapon()
    local was = hasHammer
    hasHammer, has2HMace, hasWand = false, false, false
    local names = {}
    local main = WeaponIn(16)
    local found = {}
    found[1] = main
    found[2] = WeaponIn(17)
    found[3] = WeaponIn(18)
    if not main then found[4] = WEAPON_BY_KEY.unarmed end
    meleeOn, rangedOn = false, false
    for i = 1, 4 do
        local w = found[i]
        if w then
            names[#names + 1] = w.key
            if db.weapons[w.key] then
                hasHammer = true
                if i == 3 then rangedOn = true else meleeOn = true end
                if w.key == "2hmace" then has2HMace = true end
                if w.key == "wand" then hasWand = true end
            end
        end
    end
    equippedNames = table.concat(names, ", ")
    if db.debug and was ~= hasHammer then
        Print("enabled weapon equipped: " .. tostring(hasHammer) .. " (" .. equippedNames .. ")")
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
    SetMuted(db.enabled and db.mute and has2HMace)
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
    if not hasHammer then
        return Skip("no enabled weapon equipped (" .. equippedNames .. "); see /hammer weapons")
    end
    local meleeSwing = AutoAttacking()
    local recentCast = GetTime() - lastCast < CAST_WINDOW
    if not (meleeSwing or recentCast) then
        return Skip("you weren't auto-attacking or casting")
    end
    -- melee swings need an enabled melee weapon; shots/abilities can use either
    if meleeSwing and not recentCast and not meleeOn then
        return Skip("your melee weapon type is switched off (" .. equippedNames .. ")")
    end

    local act = Readable(action)
    if act and act ~= "WOUND" and act ~= "BLOCK" then return Skip("miss/dodge/parry") end
    local school = Readable(schoolMask)
    if school and school ~= 1 and not hasWand then return Skip("not physical damage") end
    if db.debug then Print("  -> sound played") end
    PlayHammer()
end

-- Classic Era path: the combat log tells us exactly whose swing it was.
local function OnCombatLog()
    if not hasHammer then return end
    local _, subevent, _, sourceGUID = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= UnitGUID("player") then return end
    if subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" then
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
        -- Per-weapon switches; every weapon type starts on.
        db.weapons = db.weapons or {}
        for _, w in ipairs(WEAPONS) do
            if db.weapons[w.key] == nil then db.weapons[w.key] = true end
        end
        db.oneHand = nil -- replaced by db.weapons["1hmace"] in 1.6.0
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

local function CountWeaponsOn()
    local n = 0
    for _, w in ipairs(WEAPONS) do
        if db.weapons[w.key] then n = n + 1 end
    end
    return n
end

local function Status()
    Print(("enabled %s, mute stock 2H mace sounds %s, channel %s, debug %s"):format(
        OnOff(db.enabled), OnOff(db.mute), db.channel, OnOff(db.debug)))
    Print(("weapons on: %d of %d, equipped: %s (%s)"):format(
        CountWeaponsOn(), #WEAPONS, equippedNames ~= "" and equippedNames or "?",
        hasHammer and "plays sounds" or "no sounds"))
    Print(("hit detection: %s, sounds: %s (%d)"):format(
        ns.source or "?", db.soundSet == "bonk" and "bonks only" or "all", #CurrentSounds()))
end

local function ListWeapons()
    Print(("weapon types (%d of %d on):"):format(CountWeaponsOn(), #WEAPONS))
    for _, w in ipairs(WEAPONS) do
        print(("   %-9s %s  %s"):format(w.key, OnOff(db.weapons[w.key]), w.name))
    end
    Print("/hammer <type> on|off to change one, /hammer all on|off for every type")
end

local function SetAllWeapons(value)
    for _, w in ipairs(WEAPONS) do db.weapons[w.key] = value end
    UpdateWeapon()
    UpdateMute()
    Print("every weapon type " .. OnOff(value))
end

-- "/hammer <type>" toggles, "/hammer <type> on|off" sets it.
local function SetWeapon(w, arg)
    local value
    if arg == "on" then value = true
    elseif arg == "off" then value = false
    else value = not db.weapons[w.key] end
    db.weapons[w.key] = value
    UpdateWeapon()
    UpdateMute()
    Print(w.name .. " " .. OnOff(value))
end

local function Help()
    Print("commands (also in README.md):")
    print("   /hammer              play a test sound + show status")
    print("   /hammer on | off     turn the addon on or off")
    print("   /hammer weapons      list weapon types and which are on")
    print("   /hammer all on | off switch every weapon type on or off")
    print("   /hammer <type> [on|off]  e.g. /hammer dagger off, /hammer 2hsword on")
    print("   /hammer bonk         bonk sounds only")
    print("   /hammer sounds all   every sound   (/hammer sounds bonk = bonks)")
    print("   /hammer mute         toggle muting the stock 2H mace sounds")
    print("   /hammer channel sfx | master    /hammer debug    /hammer status")
end

SLASH_HAMMERSOUNDS1 = "/hammer"
SLASH_HAMMERSOUNDS2 = "/hammersounds"
SlashCmdList["HAMMERSOUNDS"] = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
    arg = arg and strtrim(arg) or nil
    local weapon = WEAPON_BY_KEY[cmd] or WEAPON_BY_KEY[WEAPON_ALIASES[cmd] or ""]

    if cmd == "" or cmd == "test" then
        PlayHammer(true)
        Status()
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        UpdateMute()
        Print("now " .. OnOff(db.enabled))
    elseif cmd == "all" then
        if arg == "on" or arg == "off" then
            SetAllWeapons(arg == "on")
        else
            Print("type |cffffff00/hammer all on|r or |cffffff00/hammer all off|r for weapons, " ..
                "or |cffffff00/hammer sounds all|r to play every sound")
        end
    elseif cmd == "weapons" or cmd == "weapon" then
        if arg and arg ~= "" then
            local name, value = strsplit(" ", arg, 2)
            local w = WEAPON_BY_KEY[name] or WEAPON_BY_KEY[WEAPON_ALIASES[name] or ""]
            if w then SetWeapon(w, value) else Print("unknown weapon type '" .. name .. "'"); ListWeapons() end
        else
            ListWeapons()
        end
    elseif weapon then
        SetWeapon(weapon, arg)
    elseif cmd == "bonk" or cmd == "sounds" then
        local set = (cmd == "bonk" or arg == "bonk") and "bonk" or (arg == "all" and "all") or nil
        if not set then
            Print("/hammer sounds bonk  or  /hammer sounds all")
        else
            db.soundSet = set
            lastIndex = 0
            Print(set == "bonk" and "bonks only" or "playing every sound")
            PlayHammer(true)
        end
    elseif cmd == "mute" then
        db.mute = not db.mute
        UpdateMute()
        Print("mute stock 2H mace sounds " .. OnOff(db.mute))
    elseif cmd == "channel" then
        db.channel = (arg == "master") and "Master" or "SFX"
        Print("playing on the " .. db.channel .. " channel")
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("debug " .. OnOff(db.debug) .. " (prints each hit event on your target)")
    elseif cmd == "status" then
        Status()
    else
        Help()
    end
end
