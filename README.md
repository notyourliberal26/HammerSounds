# Hammer Sounds

A World of Warcraft addon that replaces the boring *thunk* of your two-handed mace with silly 90s-cartoon sounds. Bonk an enemy and hear a bonk, a boink, a frying pan or a clown horn.

Made for **WoW Forever** (interface 16001). It also loads on Classic Era (11508).

## What it does

- Plays a random cartoon sound every time you land a hit with a **two-handed mace**, never the same sound twice in a row.
- Mutes the stock two-handed mace hit sounds while you have one equipped, so only the cartoon sound plays. Enemy NPC mace hits still sound normal.
- Has two sound sets: **bonk mode** (the default, 15 bonks and boinks) and **all mode** (31 sounds, adding slide whistles, frying pans, horns and boings).
- Can include one-handed maces too.
- Saves your settings between sessions.

## Install

**From a release zip:** unzip it so the `HammerSounds` folder lands in your AddOns folder:

```
World of Warcraft\_forever_\Interface\AddOns\HammerSounds\
```

**From this repo:** copy the `HammerSounds` folder (the one containing `HammerSounds.toc`) into that same AddOns folder.

Then **fully restart WoW**; `/reload` doesn't pick up new sound files. At the character screen, open **AddOns** and make sure **Hammer Sounds** is ticked.

## Commands

| Command | What it does |
|---|---|
| `/hammer` | Play a test sound and show status |
| `/hammer bonk` | Bonks only (default) |
| `/hammer all` | Every sound |
| `/hammer on` / `/hammer off` | Turn the addon on or off |
| `/hammer mute` | Toggle muting the stock mace hit sounds |
| `/hammer 1h` | Also count one-handed maces |
| `/hammer channel master` / `sfx` | Choose which volume slider controls it |
| `/hammer debug` | Print each hit event and why a sound did or didn't play |

`/hammersounds` works as an alias for `/hammer`.

## How it works

WoW Forever runs on the newer engine that blocks addons from reading the combat log, and hides combat numbers as "secret values". So Hammer Sounds:

- listens to `UNIT_COMBAT` on your **target** and plays on physical `WOUND`/`BLOCK` hits (misses, dodges and parries are skipped),
- only counts hits while **you are auto-attacking** (tracked with `PLAYER_ENTER_COMBAT` / `PLAYER_LEAVE_COMBAT`) or just after you cast something,
- has a short cooldown between sounds so a group hitting the same target doesn't spam it.

On Classic Era, where the combat log is still open, it uses `COMBAT_LOG_EVENT_UNFILTERED` instead, which knows exactly whose swing it was.

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
  HammerSounds.lua   hit detection, sound playback, slash commands
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
