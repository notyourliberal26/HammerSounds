# Hammer Sounds

A World of Warcraft addon that adds silly 90s-cartoon sounds to your hits. Bonk an enemy and hear a bonk, a boink, a frying pan or a clown horn.

Made for **WoW Forever** (interface 16001). It also loads on Classic Era (11508).

## What it does

- Plays a random cartoon sound every time you land a hit, never the same sound twice in a row.
- Works with **every weapon type**, plus unarmed. Each type can be switched on or off, and there's a one-command "all on" / "all off".
- Mutes the stock two-handed mace hit sounds while you have one equipped, so only the cartoon sound plays. Other weapons keep their normal hit sound under the cartoon one. Enemy NPC hits always sound normal.
- Has two sound sets: **bonk mode** (the default, 15 bonks and boinks) and **all mode** (31 sounds, adding slide whistles, frying pans, horns and boings).
- Saves your settings between sessions.

## Install

**From a release zip:** unzip it so the `HammerSounds` folder lands in your AddOns folder:

```
World of Warcraft\_forever_\Interface\AddOns\HammerSounds\
```

**From this repo:** copy the `HammerSounds` folder (the one containing `HammerSounds.toc`) into that same AddOns folder.

Then **fully restart WoW**; `/reload` doesn't pick up new sound files. At the character screen, open **AddOns** and make sure **Hammer Sounds** is ticked.

## Commands

Every command starts with `/hammer` (`/hammersounds` works too). Type `/hammer help` in game for a short list.

### General

| Command | What it does |
|---|---|
| `/hammer` or `/hammer test` | Play a test sound and show status |
| `/hammer status` | Show status without playing a sound |
| `/hammer on` | Turn the addon on |
| `/hammer off` | Turn the addon off |
| `/hammer help` | List the commands in chat |

### Weapons

All weapon types are **on** by default.

| Command | What it does |
|---|---|
| `/hammer weapons` | List every weapon type and whether it's on or off |
| `/hammer all on` | Turn **every** weapon type on |
| `/hammer all off` | Turn **every** weapon type off |
| `/hammer <type> on` | Turn one weapon type on, e.g. `/hammer 2hmace on` |
| `/hammer <type> off` | Turn one weapon type off, e.g. `/hammer dagger off` |
| `/hammer <type>` | Flip one weapon type between on and off |

`/hammer weapon <type> on` / `off` works too, if you prefer that wording.

**Weapon types:**

| Type | Weapon | Also accepts |
|---|---|---|
| `2hmace` | Two-handed maces | `hammer`, `mace` |
| `1hmace` | One-handed maces | `1h` |
| `2hsword` | Two-handed swords | |
| `1hsword` | One-handed swords | `sword` |
| `2haxe` | Two-handed axes | |
| `1haxe` | One-handed axes | `axe` |
| `polearm` | Polearms | `polearms` |
| `staff` | Staves | `staves` |
| `dagger` | Daggers | `daggers` |
| `fist` | Fist weapons | `fists` |
| `spear` | Spears | |
| `bow` | Bows | `bows` |
| `gun` | Guns | `guns` |
| `crossbow` | Crossbows | |
| `thrown` | Thrown weapons | |
| `wand` | Wands | `wands` |
| `unarmed` | Nothing in your main hand | |

The addon checks your main hand, off hand and ranged slot. Melee swings play a sound when the weapon in your hands is switched on. Shots and abilities play a sound when any equipped weapon is switched on.

### Sounds

| Command | What it does |
|---|---|
| `/hammer bonk` | Bonks only (default, 15 sounds) |
| `/hammer sounds bonk` | Same as `/hammer bonk` |
| `/hammer sounds all` | Every sound (31) |
| `/hammer mute` | Toggle muting the stock two-handed mace hit sounds |
| `/hammer channel sfx` | Play through the Sound Effects volume (default) |
| `/hammer channel master` | Play through the Master volume |

### Troubleshooting

| Command | What it does |
|---|---|
| `/hammer debug` | Toggle printing each hit event and why a sound did or didn't play |

> **Changed in 1.6.0:** `/hammer all` now controls weapons (`/hammer all on` / `off`). To play every sound, use `/hammer sounds all`. `/hammer 1h` still works and now flips one-handed maces.

## How it works

WoW Forever runs on the newer engine that blocks addons from reading the combat log, and hides combat numbers as "secret values". So Hammer Sounds:

- listens to `UNIT_COMBAT` on your **target** and plays on physical `WOUND`/`BLOCK` hits (misses, dodges and parries are skipped),
- only counts hits while **you are auto-attacking** (tracked with `PLAYER_ENTER_COMBAT` / `PLAYER_LEAVE_COMBAT`) or just after you cast something,
- reads your weapon types from the main hand, off hand and ranged slots with `C_Item.GetItemInfoInstant`, and checks them against your on/off settings,
- has a short cooldown between sounds so a group hitting the same target doesn't spam it.

On Classic Era, where the combat log is still open, it uses `COMBAT_LOG_EVENT_UNFILTERED` instead (swings, shots and physical abilities), which knows exactly whose hit it was.

Stock sound muting uses `MuteSoundFile` with the 270 player-side two-handed mace hit file IDs in `MuteList.lua` (taken from the wowdev community listfile).

## Adding your own sounds

1. Drop an `.ogg` or `.mp3` into `HammerSounds/Sounds/`.
2. Add its file name to the `SOUNDS` list (or the `BONKS` list for bonk mode) at the top of `HammerSounds.lua`.
3. Fully restart WoW.

Only ship sounds you have the rights to share.

## Files

```
HammerSounds/
  HammerSounds.toc   addon manifest
  HammerSounds.lua   hit detection, weapon toggles, sound playback, slash commands
  MuteList.lua       stock mace sound file IDs to mute
  Sounds/            31 .ogg files + README.txt with credits
package.ps1          builds dist/HammerSounds-<version>.zip for CurseForge
```

## Packaging a release

```powershell
.\package.ps1
```

This reads the version from `HammerSounds.toc` and writes `dist\HammerSounds-<version>.zip`, ready to upload to CurseForge.

## Sound credits

`squeak.ogg` is an original sound made for this addon. Every `fs_*.ogg` is a **CC0 (public domain)** sound from [freesound.org](https://freesound.org), trimmed and volume-matched. Attribution isn't required, but each creator is credited in [`HammerSounds/Sounds/README.txt`](HammerSounds/Sounds/README.txt).

## Author

Logan
