# High-DPI Illustrated & Procedural Sprites (`src/world/sprites`)

## Overview
Implements the high-definition anti-aliased illustrated drawing primitives (`EvoPixelCanvas`) and procedural isometric sprite generators for biome hex tiles and terrain landmarks (`EvoTerrainSprites`), 4-tier settlement buildings, rural agricultural/pastoral fields, fortifications, ruins, and animated villagers (`EvoVillageUiSprites`), and `64x64` 2D UI and map lens icons (`EvoUiIconSprites`).

## Interface
- `[pixel_canvas.gd:EvoPixelCanvas]` — Base procedural vector/raster illustrated canvas helper extending `RefCounted`.
  - Constants: `[pixel_canvas.gd:C_OUTLINE]` (`#23150c`), `[pixel_canvas.gd:C_SHADOW]`
  - Raster & Outline Methods: `[pixel_canvas.gd:_new_canvas]`, `[pixel_canvas.gd:_px]`, `[pixel_canvas.gd:_rect]`, `[pixel_canvas.gd:_rect_outlined]`
  - High-DPI Anti-Aliased & Isometric Methods: `[pixel_canvas.gd:_blend_px]`, `[pixel_canvas.gd:_drop_shadow]`, `[pixel_canvas.gd:_aa_circle]`, `[pixel_canvas.gd:_aa_circle_outlined]`, `[pixel_canvas.gd:_aa_ellipse]`, `[pixel_canvas.gd:_aa_ellipse_outlined]`, `[pixel_canvas.gd:_aa_line]`, `[pixel_canvas.gd:_poly_filled]`, `[pixel_canvas.gd:_poly_outlined]`, `[pixel_canvas.gd:_draw_isometric_box]`, `[pixel_canvas.gd:_draw_pitched_roof]`
- `[terrain_sprites.gd:EvoTerrainSprites]` — High-DPI illustrated generator for biome hex tiles (`256x224`) and terrain flora/geology sprites (`128x128` to `160x160`) extending `EvoPixelCanvas`.
  - Static Methods: `[terrain_sprites.gd:draw_terrain_sprite]`, `[terrain_sprites.gd:draw_hex_tile]`
- `[village_ui_sprites.gd:EvoVillageUiSprites]` — High-DPI illustrated generator for isometric settlement architecture (`hut_thatch`, `campfire`, `house_clay`, `granary`, `house_stone`, `temple_totem`, `windmill`, `watchtower`, `citadel_keep`, `cathedral`, `palisade_wall`, `stone_wall`, `siege_totem`), rural & ruin props (`crop_field`, `pasture_pen`, `covered_wagon`, `ruins_stone`, `prop_betrayal_ruin`), and villagers (`48x48`), delegating `64x64` UI icons to `EvoUiIconSprites`.
  - Static Methods: `[village_ui_sprites.gd:draw_village_or_ui_sprite]`, `[village_ui_sprites.gd:draw_villager]`
- `[ui_icon_sprites.gd:EvoUiIconSprites]` — High-DPI `64x64` 2D UI and map lens icon generator (`tool_*`, `season_*`, `status_*`, decision glyphs `icon_forage`..`icon_innovate`, geopolitical badges `icon_war`..`icon_siege`, and readability icons `icon_epidemic`, `icon_famine`, `icon_immune`, `icon_vendetta`, `icon_casualties`, `icon_loot`, `icon_migrants`) extending `EvoPixelCanvas`.
  - Static Methods: `[ui_icon_sprites.gd:draw_ui_icon_sprite]`

## Invariants
- `[pixel_canvas.gd:_new_canvas]` creates uncompressed `Image.FORMAT_RGBA8` images filled with transparent black `Color(0, 0, 0, 0)`.
- `[pixel_canvas.gd:_px]` and `[pixel_canvas.gd:_blend_px]` bounds-check coordinates (`0 <= x < img.get_width()`, `0 <= y < img.get_height()`) before writing or alpha-compositing pixels.
- `[terrain_sprites.gd:draw_hex_tile]` returns a `256x224` illustrated `Image` for any biome name (`tropical_forest`, `savanna`, `arid_steppe`, `tundra`, `high_mountain`, `coastal_shallows`, or ocean fallback).
- `[terrain_sprites.gd:draw_terrain_sprite]` returns `128x128` (or `160x160` for `rock_mountain` / `mountain_peak`) illustrated sprites with `#23150c` ink outlines.
- `[village_ui_sprites.gd:draw_village_or_ui_sprite]` returns `128x128`–`160x160` isometric building/rural/ruin sprites and delegates `64x64` UI icons to `[ui_icon_sprites.gd:draw_ui_icon_sprite]`.
- `[village_ui_sprites.gd:draw_villager]` renders `48x48` villager sprites with pose-dependent bobbing and alternating leg stride (`step == 1` vs `step == 2`).

## Side Effects
- None (pure in-memory `Image` allocation and pixel/scanline manipulation; disk caching and mipmap generation are handled by `EvoPixelArtGen`).

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
