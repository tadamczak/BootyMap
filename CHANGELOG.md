# Changelog

## 0.1.0-dev.11 - 2026-10-08

- Accept native eight-bit alpha readback during hover fades while retaining refused-write and foreign-owner checks.

## 0.1.0-dev.10 - 2026-10-08

- Geometry, shape reporting and pfQuest clipping yield after another addon replaces the native mask setter.

## 0.1.0-dev.9 - 2026-10-08

- Preserve foreign launcher ownership across repeated collection refreshes, including explicit additional names.

## 0.1.0-dev.8 - 2026-10-08

- Prevent cut-corner clicks from sending pings outside custom map shapes.
- Use valid native mouse scripts for explicitly included plain-frame launchers.
- Update in-game help for custom shapes and extra launchers.

## 0.1.0-dev.7 - 2026-10-08

- Add rounded-square and octagonal masks with matching boundaries; explicit extra launcher names preserve callbacks and exclude continuous workers. Native rendering/input acceptance pending.

## 0.1.0-dev.6 - 2026-10-08

- Add landscape3:2 and portrait2:3 minimaps with consistent edges, pings, zone text, information and panel layout.
- Add reversible GetMinimapShape compatibility and explicit viewport geometry/containment APIs.
- Add optional pfQuest viewport clipping without replacing its renderer; unchanged render caches skip pin loops.
- Allow the known pfQuest launcher in the icon panel while preserving quest pins and foreign owners.
- Full pfQuest corner discovery and native rendering/input/performance acceptance remain pending.

## 0.1.0-dev.5 - 2026-10-08

- Add independent hover visibility for zone, information, addon panel, native controls and borders.
- Add idle opacity, hide delay and fade duration; Edit keeps selected elements visible.
- Preserve native tooltip/click/status behavior and restore original callbacks/opacity when disabled.
- Stop transition timers at rest and suspend clock/coordinate updates when fully faded out.
- Native rendering/input/performance acceptance remains pending.

## 0.1.0-dev.4 - 2026-10-08

- Fix false cluster ownership failures when settings refresh during native dragging.
- Add digital local/server time in12/24-hour format and throttled player coordinates.
- Add information position/font/color settings and profile support, with edge placement and panel spacing.
- Preserve an open world map's selected zone; disable information handlers when hidden or off.
- Native game-client acceptance remains pending.

## 0.1.0-dev.3 - 2026-10-08

- Allow the visible minimap to touch screen edges in Edit; restore native clamp flags when disabled.
- Add an optional addon-button panel with size, spacing, columns, side, custom order and exceptions.
- Preserve launcher clicks/tooltips, restore original layouts and yield to MinimapButtonFrame.
- Add event-driven discovery and /bm refresh and /bm buttons commands; native acceptance remains pending.

## 0.1.0-dev.2 - 2026-10-08

- Accept native layout float precision during size/position writes and restoration.
- Keep genuine write failures diagnostic, including the requested and read sizes.

## 0.1.0-dev.1 - 2026-10-08

- First BootyMap development build: native map layout, shape, border, opacity,
  zone text, zoom and native-indicator customization.
- Add standalone and Booty Suite settings, shared profiles, edit mode, presets
  and layout rescue; restore captured native state when disabled.
- Preserve existing addon-button owners and report compatibility limits.
- Native game-client acceptance remains pending.
