# 2.5D World Presentation & Asset Subsystem (`src/world`)

## Overview
Coordinates the 2.5D illustrated isometric representation of the simulation world (`EvoWorldRenderer`), locked-yaw 2.5D pitch/pan/zoom camera transformations (`EvoCameraController`), GPU shaders (`./shaders`), and high-DPI procedural illustrated PNG generation and mipmapped `ImageTexture` caching (`EvoPixelArtGen`). Delegates specialized rendering passes to `./render` and procedural sprite drawing routines to `./sprites`.

## Interface
- `[camera_controller.gd:EvoCameraController]` — `Node2D` locked-yaw 2.5D pitch, pan, and zoom camera controller.
  - Constants: `[camera_controller.gd:MIN_PITCH_DEG]`, `[camera_controller.gd:MAX_PITCH_DEG]`, `[camera_controller.gd:DEFAULT_PITCH_DEG]`, `[camera_controller.gd:DEFAULT_YAW_DEG]`, `[camera_controller.gd:MIN_ZOOM]`, `[camera_controller.gd:MAX_ZOOM]`, `[camera_controller.gd:DEFAULT_ZOOM]`, `[camera_controller.gd:DEFAULT_PAN]`, `[camera_controller.gd:MAX_PAN_RADIUS]`, `[camera_controller.gd:MAX_COLUMN_HEIGHT_PX]`
  - Properties: `[camera_controller.gd:yaw_deg]`, `[camera_controller.gd:pitch_deg]`, `[camera_controller.gd:zoom_level]`, `[camera_controller.gd:pan_offset]`, `[camera_controller.gd:active_tool]`
  - Methods: `[camera_controller.gd:ground_transform]`, `[camera_controller.gd:height_scale]`, `[camera_controller.gd:get_depth]`, `[camera_controller.gd:rotate_by]`, `[camera_controller.gd:tilt_by]`, `[camera_controller.gd:set_pitch_preset]`, `[camera_controller.gd:zoom_by]`, `[camera_controller.gd:reset_camera]`, `[camera_controller.gd:focus_on_hex]`
- `[pixel_art_gen.gd:EvoPixelArtGen]` — High-DPI procedural illustrated asset registry, disk serializer, and mipmapped `Image`/`ImageTexture` cache extending `EvoPixelCanvas`.
  - Constants: `[pixel_art_gen.gd:ASSET_SCHEMA_VERSION]`, `[pixel_art_gen.gd:HEX_TILE_SPRITES]`, `[pixel_art_gen.gd:TERRAIN_SPRITES]`, `[pixel_art_gen.gd:VILLAGE_SPRITES]`, `[pixel_art_gen.gd:UI_SPRITES]`
  - Static Methods: `[pixel_art_gen.gd:ensure_all_assets]`, `[pixel_art_gen.gd:get_texture]`, `[pixel_art_gen.gd:get_image]`, `[pixel_art_gen.gd:get_villager_texture]`
- `[world_renderer.gd:EvoWorldRenderer]` — Multi-layer `Node2D` 2.5D hex column, rural land-use overlay, road/perimeter-wall network, animated prop, and screen-space overlay renderer configured with `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`.
  - Signals: `[world_renderer.gd:hex_clicked]`, `[world_renderer.gd:hex_dragged]`, `[world_renderer.gd:deme_clicked]`
  - Constants: `[world_renderer.gd:PixelArtGen]`, `[world_renderer.gd:CameraController]`, `[world_renderer.gd:OceanWavesShader]`, `[world_renderer.gd:HexTerrainShader]`, `[world_renderer.gd:PropSwayGlowShader]`, `[world_renderer.gd:Prop]`, `[world_renderer.gd:MAX_COLUMN_HEIGHT_PX]`, `[world_renderer.gd:BIOME_PALETTE]`, `[world_renderer.gd:C_ROCK_CRACK]`, `[world_renderer.gd:C_CLIFF_OUTLINE]`, `[world_renderer.gd:C_SAND]`, `[world_renderer.gd:C_SURF]`, `[world_renderer.gd:C_RIPPLE]`, `[world_renderer.gd:C_SELECTION]`
  - Properties: `[world_renderer.gd:world_state]`, `[world_renderer.gd:camera]`, `[world_renderer.gd:lang]`, `[world_renderer.gd:active_lens]`, `[world_renderer.gd:active_tool]`, `[world_renderer.gd:selected_hex_id]`, `[world_renderer.gd:selected_deme_id]`, `[world_renderer.gd:highlighted_lineage_id]`, `[world_renderer.gd:hovered_hex_id]`, `[world_renderer.gd:hovered_deme_id]`, `[world_renderer.gd:brush_radius]`
  - Methods: `[world_renderer.gd:set_world_state]`, `[world_renderer.gd:set_camera]`, `[world_renderer.gd:refresh]`, `[world_renderer.gd:refresh_village_decisions]`
- Subdirectories:
  - [Render Pass Helpers](./render/README.md) — Full-hex 4-tier settlement props, rural hinterlands (`crops`, `pasture`, `has_ruins`), hex-edge perimeter walls & multi-hex walled unions, road networks, and screen-space billboards.
  - [Procedural Illustrated Sprites](./sprites/README.md) — Base canvas (`#23150c` ink outlines) and high-DPI procedural terrain (`256x224` tiles, `128x128`–`160x160` flora), village (`128x128`–`160x160` buildings, `48x48` villagers), and `64x64` UI sprite generators.
  - `shaders/` — GPU `canvas_item` shaders (`ocean_waves.gdshader`, `hex_terrain.gdshader`, `prop_sway_glow.gdshader`).

## Invariants
- `[camera_controller.gd:_clamp_targets]` locks `yaw_deg` and `_target_yaw_deg` to `0.0` (so 2.5D illustrated facades and shadows remain oriented toward the viewer), clamps `_target_pitch_deg` to `[MIN_PITCH_DEG, MAX_PITCH_DEG]` (`[32.0, 68.0]`), `_target_zoom` to `[MIN_ZOOM, MAX_ZOOM]` (`[0.18, 2.80]`), and `_target_pan` length within `MAX_PAN_RADIUS` (`2800.0`, scaled by zoom) across the `169`-hex (`map_radius = 7`, `HEX_SIZE = 240.0`) world.
- `[camera_controller.gd:_process]` and `[camera_controller.gd:_unhandled_input]` ignore keyboard and mouse camera inputs when a `LineEdit` or `TextEdit` holds focus or any HUD modal (`lab_modal`, `notebook_modal`, `tree_modal`, `_settings_popup`, `_missing_models_modal`) is visible.
- `[pixel_art_gen.gd:_generate_and_register]` validates `ASSET_SCHEMA_VERSION` (`v3_illustrated_hdpi`), generates mipmaps on every `Image` before calling `ImageTexture.create_from_image()`, and produces `256x224` hex tiles, `128x128`–`160x160` terrain/settlement sprites, `48x48` villager sprites, and `64x64` UI icons.
- `[world_renderer.gd:_get_cell_top_z]` quantizes land column heights into 10 discrete tiers (`ceil(altitude * 10.0) / 10.0 * MAX_COLUMN_HEIGHT_PX`), draws `#23150c` ink-outlined 2.5D cliff skirts when `altitude - sea_level > 0.015`, and clamps water elevation to `clamp(sea_level, 0.0, 0.5) * MAX_COLUMN_HEIGHT_PX`.
- `[world_renderer.gd:_layout_columns]` depth-sorts `_sorted_hex_ids` back-to-front via `camera.get_depth`, reorders `_terrain_layer` child column nodes, and invalidates column caches whenever `cell.land_use`, `cell.owner_deme_id`, or `cell.has_ruins` changes.

## Side Effects
- `[pixel_art_gen.gd:ensure_all_assets]` and `[pixel_art_gen.gd:_generate_and_register]` create directories and read/write PNG files and `schema_version.txt` under `res://assets/sprites/terrain/`, `res://assets/sprites/villages/`, and `res://assets/sprites/ui/`, and mutate static caches (`_texture_cache`, `_image_cache`, `_villager_colored_cache`, `_initialized`).
- `[world_renderer.gd:_init]` and `[world_renderer.gd:_create_columns]` allocate `_backdrop_rect` (bound to `OceanWavesShader`), `Node2D` child layers (`_world_layer`, `_terrain_layer`, `_network_layer`, `_anim_layer`, `_overlay_layer`), and per-hex column/water-FX `Node2D` instances, and store projection keys in `HexCell` metadata (`_proj_key`).
- `[world_renderer.gd:_unhandled_input]` emits `hex_clicked`, `hex_dragged`, and `deme_clicked` signals on mouse interaction.
- `[camera_controller.gd:_unhandled_input]` marks viewport input as handled on mouse wheel zoom events.

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
