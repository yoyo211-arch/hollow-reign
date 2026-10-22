# Hollow Reign

A dark top-down pixel-art roguelite made in Godot 4.3 (GDScript). Art uses the 0x72 DungeonTileset II sprites and Kenney effects, font and sounds (all CC0, see `CREDITS.txt`).

## Play
1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard version, not .NET).
2. Open Godot, click **Import**, select this folder's `project.godot`, then press **F5**.

On the original dev PC, `Play.bat` launches it directly (it points at a local Godot install).

## Controls
| Action | Keys |
|---|---|
| Move | WASD / arrows |
| Aim & fire | Mouse (hold left button) |
| Dash (brief invulnerability) | Space / Shift |
| Switch weapon | 1-5, Q / E, mouse wheel |
| Pause | Esc / P |
| Fullscreen | F11 |

## Progression
- **Gates I-V**: survive the timer, then reach the portal. **Gate VI**: defeat the Hollow King (three phases).
- **Souls** drop from enemies and are kept even if you die. Clearing a gate for the first time gives a bonus.
- **Armory**: forge new weapons (Hellfire Staff, Bone Bow, Executioner's Axe, Wraith Staff) as you clear gates.
- **Wardrobe**: 13 hero skins (knights, elves, dwarves, wizards, lizardfolk, plague doctor, pumpkin head, fallen angel) bought with souls.
- **Skill tree**: three branches (Blood / Wrath / Shade) with 4 tiers each. Skills can be refunded at any time.

## Performance
Settings -> Quality: **Low** turns off shadows, post-processing and halves particles. Uses the Compatibility (OpenGL) renderer so it runs on older GPUs and integrated graphics.

## Files
- `scripts/data.gd` - all tuning: weapons, skills, enemies, skins, levels (sprite names map to `assets/dungeon/`).
- `scripts/art.gd` - loads sprites/effects/font and builds the character animations.
- `scripts/game.gd` - level logic, combat, effects. `player.gd`, `enemy.gd`, `boss.gd` - actors.
- `scripts/menu.gd`, `scripts/hud.gd` - UI. `scripts/sfx.gd` - synthesized audio. `shaders/post.gdshader` - grain/vignette.

## Exporting a standalone .exe
In Godot: Editor -> Manage Export Templates -> Download, then Project -> Export -> Add "Windows Desktop" -> Export Project.
