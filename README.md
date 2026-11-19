# Hammer Sounds

A World of Warcraft addon that adds silly 90s-cartoon sounds to your hits. Bonk an enemy and hear a bonk, a boink, a frying pan or a clown horn.

Made for **WoW Forever** (interface 16001). It also loads on Classic Era (11508).

## What it does

- Plays a random cartoon sound every time you land a hit, never the same sound twice in a row.
- Works with **every weapon type**, plus unarmed. Each type can be switched on or off, and there's a one-command "all on" / "all off".
- Mutes the game's own hit sound for whatever weapons you have equipped, so only the cartoon sound plays. When you swap weapons, the old type's sounds come back. Enemy NPC hits always sound normal.
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
| `/hammer mute` | Toggle muting the game's own hit sounds for your equipped weapons |
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

### Muting the original hit sounds

`MuteList.lua` holds 1,474 file IDs of the game's player-side weapon **impact** sounds, grouped by weapon type. When you equip a weapon type that's switched on, the addon calls `MuteSoundFile` on that type's list, and `UnmuteSoundFile` when you swap away or turn the addon off.

| Muted lists | Covers |
|---|---|
| `2hmace`, `1hmace` | two- and one-handed maces (wood and metal) |
| `2hsword`, `1hsword` | two- and one-handed swords |
| `2haxe`, `1haxe` | two- and one-handed axes |
| `staff` | staves |
| `dagger` | daggers |
| `unarmed` | unarmed hits, also used for fist weapons |
| `bow`, `gun` | arrow and bullet impacts (bows also cover crossbows) |

Good to know:

- **Polearms, spears, thrown weapons and wands** don't have their own impact sounds in the game files I could identify, so their original sound still plays under the cartoon one.
- Swing whooshes, bow draws and gunshots aren't muted, only the impact.
- Muting is client-wide. While, say, swords are muted for you, other players' sword hits are quiet on your screen too. NPC weapon sounds are separate files and are never muted.

To regenerate the list from a fresh copy of the [wowdev community listfile](https://github.com/wowdev/wow-listfile):

```bash
curl -sL https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv | grep -i ";sound/item/weapons/" > weapon_sounds.txt
python tools/make_mutelist.py weapon_sounds.txt HammerSounds/MuteList.lua
```

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
  MuteList.lua       stock weapon hit sound file IDs to mute, per weapon type
  Sounds/            31 .ogg files + README.txt with credits
tools/make_mutelist.py  regenerates MuteList.lua from the community listfile
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
