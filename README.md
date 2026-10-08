<p align="center"><img src="https://raw.githubusercontent.com/tadamczak/MuklaOfficerSuite/master/Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyMap

BootyMap customizes the native World of Warcraft 1.12 minimap. Move and resize
the map, choose its shape and appearance, and arrange its native indicators.
Use it on its own with BootyLib or inside Booty Suite.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Compatibility](#compatibility)

## Features

- Map size from 80 to 400, saved placement, position locking and edge snapping.
- Circle or square shape, native border, Booty project border or no border.
- Map opacity and configurable zone-name visibility, position, font and color.
- Optional mouse-wheel zoom and preferred zoom level.
- Visibility and corner placement for native zoom, clock, tracking, mail and
  battleground controls, when those controls are available in the client.
- Classic, Booty and Compact presets, layout rescue and full preference reset.
- Shared settings profiles that include the map's saved placement.
- Digital local/server clock with 12/24-hour format and player coordinates.
- Information font, size, color and above/below placement, with edge adjustment.
- Optional addon-button panel: size, spacing, columns, side, custom order and
  exceptions that keep selected buttons on the minimap. Panel placement flips
  to the opposite side when needed near a screen edge.
- Disabling BootyMap restores the native state captured when it was enabled.

This development build awaits verification in the game client. An
hover visibility and further compatible shapes are planned additions.

## Installation

Place `BootyLib` and `BootyMap` directly inside `Interface/AddOns`. The folders
must have those exact names. Enable both in the character-selection addon list.
Booty Suite is optional. Restart the client after the first installation so the
new addon appears in the character-selection list.

## Usage

Use `/bm` or `/bootymap` to open Map and `/bm settings` to open settings.
Changes apply immediately. Use the shared Profile page to save or restore your
map settings and position; the same preferences are available in Booty Suite.

Use `/bm edit` to toggle temporary drag editing. Finish editing or use `/bm lock`
to lock the map. The permanent Lock position setting also allows ordinary
dragging when unlocked. Edge snapping applies when a drag finishes.

Use `/bm reset` or **Reset layout** if the minimap is outside the screen or
transparent. This ends editing and restores native placement, size 140, full
opacity, position locking and disabled edge snapping. Other appearance settings
stay as chosen. **Reset all** restores all minimap preferences. Both resets keep
your saved profiles.

Use `/bm disable` to restore the captured native layout and `/bm enable` to
apply BootyMap again. Disable also ends editing. Reset commands remain available
when BootyMap customizations are disabled; corrected preferences apply when you
enable them again.

In **Map > Addon buttons**, enable collection and choose panel layout. Custom
order and exceptions use comma-separated button frame names; `/bm buttons`
lists collected names. Unlisted buttons sort alphabetically. Hidden buttons
keep their slots and native visibility. `/bm refresh` discovers buttons created
late; normal discovery also runs when addons load or you enter the world.
Disabling collection restores the buttons' original layouts.

In **Map > Information**, enable the digital clock or player coordinates. Choose
local or server time, 12/24-hour format and information appearance. Coordinates
refresh up to four times per second; while the world map is open or position is
unavailable they show `--, --`, preserving the zone you are browsing. Close the
world map to resume coordinates. Both displays default off and use no update
handler when disabled or hidden. Information settings are included in profiles.

## Compatibility

Choose one owner for minimap customization. Disable ShaguTweaks MiniMap Tweaks,
MiniMap Clock and MiniMap Square when using the corresponding BootyMap features,
then reload the UI. Other addons can change the same minimap controls, fonts,
mask or mouse handlers. BootyMap reports detected conflicts; it cannot guarantee
compatibility with every minimap replacement.

Collection is off by default. Disable MinimapButtonFrame and reload before using
BootyMap's panel; if it is active, collection pauses with a status message.
Native controls, quest pins, unnamed buttons and buttons with continuous update
handlers keep their owners. Unusual launchers may require a separate integration.
Native mail,
tracking and battleground actions keep their existing click behavior and
tooltips; choosing visibility does not invent a status the client has not shown.

The square option changes the minimap shape. pfQuest may still keep quest markers
inside the native circle; support for quest markers in square corners is not
included in this first build. Map clicks, pings, client extensions and the
combination with pfQuest require verification in the game client.
