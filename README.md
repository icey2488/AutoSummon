# AutoSummon

A World of Warcraft addon that automatically accepts summon requests after a configurable countdown. Never miss a summon while tabbed out, and never get yanked into a fight you didn't mean to join.

**Author:** icey2488  
**Interface:** 12.0.5 (Midnight)  
**Version:** 1.2.0

---

## Installation

1. Download and extract the zip.
2. Copy the `AutoSummon` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart the game or type `/reload` if it is already running.

---

## Features

- **Configurable delay** — waits a set number of seconds before accepting, giving you time to cancel if needed.
- **Slider + text input** — set your delay by dragging or typing, whichever you prefer.
- **Summoner and destination info** — prints who is summoning you and to which zone the moment it is detected, so you can confirm it is intentional before the timer fires.
- **Sound alert** — plays the Ready Check sound on summon detection so you hear it even if you are tabbed out.
- **Cancel on combat** — automatically aborts a pending acceptance if you enter combat before the countdown finishes.
- **Cancel on death** — automatically aborts a pending acceptance if you die before the countdown finishes.
- **Summon expiry handling** — if the summon expires or is cancelled on the other end, the countdown is cleaned up immediately.
- **Delay capped to summon time** — if your configured delay is longer than the remaining summon window, it is automatically shortened so the accept always fires in time.
- **Per-character delay override** — set a different delay per character while keeping a global default for the rest of your roster.
- **Minimap button** — small circular icon on the minimap edge; click to open settings, drag to reposition. Can be hidden from the options panel.
- **WoW Options integration** — appears in the AddOns tab of the game's Options panel (ESC → Options → AddOns).
- **Tooltips** — hover over any option in the settings panel for a plain-English explanation of what it does.
- **Slash commands** — full control from the chat box if you prefer.

---

## Options Panel

Open with `/as`, `/as options`, or click the minimap button.

| Option | Description |
|---|---|
| **Delay slider / text box** | Seconds to wait before accepting (0–60). 0 accepts instantly. |
| **Per-character delay override** | When checked, this character uses its own delay value instead of the global one. Useful for alts with different playstyles. |
| **Enable AutoSummon** | Master switch. Uncheck to disable all auto-accepting without changing other settings. |
| **Play sound alert** | Plays the Ready Check sound when a summon is detected. |
| **Show summoner and destination** | Prints the caster's name and target zone in the countdown chat message. |
| **Cancel if you enter combat** | Aborts the countdown when you pull a mob or get attacked. |
| **Cancel if you die** | Aborts the countdown if you die before it finishes. |
| **Show minimap button** | Shows or hides the AutoSummon icon on the minimap edge. |

---

## Slash Commands

Both `/autosummon` and `/as` work.

| Command | Effect |
|---|---|
| `/as` | Toggle the standalone settings window. |
| `/as options` | Open the WoW Options panel directly to the AutoSummon AddOns tab. |
| `/as delay <N>` | Set delay to N seconds (0–60). |
| `/as enable` | Enable the addon. |
| `/as disable` | Disable the addon. |
| `/as cancel` | Cancel a currently running countdown. |
| `/as status` | Print all current settings to chat. |

---

## How It Works

When an `INCOMING_SUMMON_CHANGED` event fires, AutoSummon:

1. Calls `C_SummonInfo.GetSummonConfirmTimeLeft()` to determine if a new summon just arrived (time > 0) or if one expired/was cancelled (time == 0).
2. Caps your configured delay to the remaining summon window so the accept always fires in time.
3. Optionally plays a sound and prints the summoner's name and destination zone.
4. Starts a countdown ticker that prints remaining seconds to chat each second.
5. Calls `C_SummonInfo.ConfirmSummon()` when the timer expires and hides the static popup so it does not linger on screen.

If combat, death, or manual cancellation occurs before the countdown finishes, the timers are cancelled cleanly.

---

## Changelog

### 1.2.0
- Minimap button resized to standard small circular style (20px icon, gold ring border) matching other addons.
- Added "Show minimap button" toggle in the options panel.
- Fixed widget name collision that caused the delay text box to be invisible in the WoW Options panel.
- Replaced deprecated `SUMMON_PENDING_DIALOG` / `CANCEL_SUMMON` events with `INCOMING_SUMMON_CHANGED` for Midnight compatibility.
- Settings now appear in WoW Options > AddOns tab via `Settings.RegisterCanvasLayoutCategory`.

### 1.1.0
- Added summoner and destination info in countdown message.
- Added sound alert on summon detection.
- Added cancel-on-combat and cancel-on-death options.
- Added per-character delay override (`SavedVariablesPerCharacter`).
- Added minimap button (draggable).
- Added tooltips on all settings panel options.
- Delay is now automatically capped to the remaining summon window.
- Static popup is now dismissed after accepting.
- Upgraded `ConfirmSummon()` to `C_SummonInfo.ConfirmSummon()` for Midnight compatibility.
- Expanded `/as status` to show all settings at once.

### 1.0.0
- Initial release: configurable delay, slider + text input, enable/disable toggle.
