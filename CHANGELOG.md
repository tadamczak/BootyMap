# Changelog

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
