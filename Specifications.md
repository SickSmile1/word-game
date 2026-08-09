# Scrabble Project — Code Specifications

A German-language Scrabble game built in Godot 4.6 (GDScript). Single-player vs AI, mobile-first layout (1080×1920 portrait base, expands to landscape). This document traces execution from engine boot through a complete AI game turn.

---

## 1. Engine Boot & Autoloads

Godot initialises autoloads in `project.godot` order **before** any scene is loaded:

```
Settings   → scripts/autoload/SettingsManager.gd
Audio      → scripts/autoload/AudioManager.gd
WordDict   → scripts/autoload/WordDictionary.gd
SaveManager→ scripts/autoload/SaveManager.gd
```

### 1.1 SettingsManager (`Settings`)

`_ready()` calls `load_settings()`, which reads `user://settings.cfg` via Godot's `ConfigFile`. If the file does not exist, defaults are used:

| Property | Default | Effect on write |
|---|---|---|
| `music_volume` | 0.8 | emits `music_volume_changed` |
| `effects_volume` | 0.8 | emits `effects_volume_changed` |
| `overall_volume` | 1.0 | emits `overall_volume_changed` |
| `target_fps` | 60 | sets `Engine.max_fps` |
| `dark_mode` | true | emits `theme_changed` |

Every property uses a GDScript setter. Setting any property (except during a bulk load) immediately calls `save()`, which writes `user://settings.cfg`. The `_loading` flag batches writes during `load_settings()` and `reset_to_defaults()` so only one disk write occurs.

### 1.2 AudioManager (`Audio`)

`_ready()` connects to the three volume signals from `Settings`. Provides:
- `play_sfx(stream)` — creates a temporary `AudioStreamPlayer2D`, plays it, then frees itself on `finished`.
- `play_music(stream, loop)` — creates a persistent `_music_player`, optionally reconnects the looping signal.
- `fade_out_music(duration)` — tweens the Music bus volume to 0 via `Tween`.

Audio bus indices are the Godot default layout: Master=0, Music=1, Effects=2.

### 1.3 WordDictionary (`WordDict`)

`_ready()` creates an empty `Trie`, then starts a background `Thread`:

```
_ready()
  └─ Thread.start(_load_on_thread)
       └─ [background thread]
            FileAccess.open(german_scrabble.txt)   ← 1.2 MB, 112 450 words
            loop: file.get_line() → trie.insert(word)
            call_deferred("_finish_load", thread)
       └─ [main thread, deferred]
            thread.wait_to_finish()
            is_ready = true
            dictionary_ready.emit()
```

The game scene awaits `dictionary_ready` before starting if the thread has not finished yet. This keeps the first frame rendering immediately while the 112 k-word trie builds in the background.

**Trie structure** — `Trie` wraps a tree of `TrieNode` objects. Each `TrieNode` holds:
- `children: Dictionary` — maps a single-character String key to another TrieNode
- `is_end: bool` — marks a complete word

`insert(word)` walks/creates nodes character by character.  
`search(word)` walks nodes and checks `is_end` at the terminal node.  
`starts_with(prefix)` checks whether the traversal reaches a node (not necessarily a word end).

### 1.4 SaveManager

`_ready()` creates `user://saves/` if it does not exist. Provides:
- `save_data(slot, data)` — JSON-stringifies the Dictionary and writes `slot_N.sav`.
- `load_data(slot)` — reads and `JSON.parse_string`s a slot file.
- `get_save_list()` — loads all slots, returns metadata Dictionaries sorted by timestamp.
- `pending_load_slot` — an integer set by MainMenu when the player picks a save; Game reads and clears it in `_ready()`.

---

## 2. Main Menu Scene

**Scene file:** `scenes/main_menu/MainMenu.tscn`  
**Script:** `scripts/ui/MainMenu.gd`

### 2.1 States

`MainMenu` uses a simple enum-driven panel-swap pattern:

```
MenuState.MAIN      → menu_container visible  (Start / Continue / Settings / Quit)
MenuState.START     → start_panel visible     (Online / Vs AI / Back)
MenuState.SETTINGS  → settings_panel visible  (sliders, FPS, theme toggles)
MenuState.CONTINUE  → continue_panel visible  (list of save slots)
```

Setting `_state` triggers the setter which calls `_update_ui_state()`, swapping panel visibility.

### 2.2 `_ready()` sequence

```
_ready()
  ├─ _setup_buttons()        — connect all button.pressed signals
  ├─ _setup_sliders()        — connect slider.value_changed signals
  ├─ _setup_fps_buttons()
  ├─ _setup_theme_buttons()
  ├─ _populate_slider_values()   — read current values from Settings
  ├─ _populate_fps_value()
  ├─ _populate_theme_value()
  ├─ _apply_background(Settings.dark_mode)
  ├─ Settings.theme_changed.connect(_on_theme_changed)
  ├─ _update_ui_state()       — show MAIN panel
  └─ _populate_slot_list()    — read saves from SaveManager
```

### 2.3 Settings flow

When the player moves a slider:
```
slider.value_changed → _on_music_slider_changed(value)
  └─ Settings.music_volume = value      ← setter fires
       ├─ clamps to [0, 1]
       ├─ music_volume_changed.emit()   → Audio._on_music_volume_changed()
       │    └─ AudioServer.set_bus_volume_db(MUSIC, ...)
       └─ _save_unless_loading()        → SettingsManager.save()
```

FPS and theme buttons write to `Settings.target_fps` / `Settings.dark_mode` in the same pattern; `dark_mode`'s setter emits `theme_changed` which is also connected in MainMenu to `_on_theme_changed()` → `_apply_background()` + restyle.

### 2.4 Starting a new game

```
Start button → _on_start_pressed() → _state = START
Vs AI button → _on_vs_ai_pressed()
  └─ get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
```

### 2.5 Loading a saved game

```
Continue button → _on_continue_pressed()
  └─ _populate_slot_list()        — builds Button list from SaveManager.get_save_list()
     _state = CONTINUE

Slot button clicked → _on_slot_selected(slot)
  ├─ SaveManager.pending_load_slot = slot
  └─ get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
```

---

## 3. Game Scene Initialisation

**Scene file:** `scenes/game/Game.tscn`  
**Script:** `scripts/ui/Game.gd`

### 3.1 Node references (`@onready`)

| Variable | Node | Role |
|---|---|---|
| `difficulty_panel` | `%DifficultyPanel` | difficulty picker, shown before game starts |
| `game_ui` | `%GameUI` | entire in-game HUD |
| `board_display` | `%BoardDisplay` | 15×15 drawn grid |
| `rack_display` | `%RackDisplay` | player's 7-tile rack |
| `player_score_label` | `%PlayerScore` | score labels |
| `ai_score_label` | `%AIScore` | |
| `status_label` | `%StatusLabel` | status messages |
| `game_overlay` | `%GameOverOverlay` | end-of-game overlay |
| `background` | `$Background` | full-screen ColorRect |

### 3.2 `_ready()` sequence

```
_ready()
  ├─ _setup_signals()         — connect board_display, rack_display, buttons, Settings
  ├─ _apply_background(dark_mode)
  ├─ _update_theme_button()
  ├─ _style_scene_theme()     — programmatic StyleBoxFlat on all buttons/panels
  ├─ get_viewport().size_changed.connect(_relayout)
  ├─ _relayout()              — compute board/HUD positions for current viewport
  │
  └─ [if SaveManager.pending_load_slot >= 0]
       slot = pending_load_slot ; pending_load_slot = -1
       data = SaveManager.load_data(slot)
       await _apply_save_data(slot, data)   ← restores full game state
       return
  │
  └─ [else]
       difficulty_panel.visible = true
       game_ui.visible = false
```

### 3.3 Layout system

`_relayout()` is called on resize and at startup. It reads `get_viewport_rect().size` and branches on aspect ratio:

- **Portrait** (`width ≤ height`): stacks HUD → status → board → action-buttons → rack vertically.
- **Landscape** (`width > height`): board on the left, panel (HUD + status + buttons + rack) on the right.

All positions are set manually via `_set_rect(node, x, y, w, h)` which zeros the anchors and sets offsets directly, giving pixel-perfect control without the container layout system.

---

## 4. Difficulty Selection & Game Start

```
Easy/Medium/Hard button pressed
  → _on_difficulty_selected(diff)
       ├─ _difficulty = diff
       ├─ difficulty_panel.visible = false
       ├─ game_ui.visible = true
       ├─ await _resize_board()          ← waits one frame then calls _relayout()
       ├─ [if not WordDict.is_ready]
       │    _set_status("Loading dictionary...")
       │    await WordDict.dictionary_ready
       └─ _start_game()
            ├─ _board = Board.new()          ← 15×15 grid, all null
            ├─ _bag = TileBag.new()          ← shuffled pool of 101 German tiles
            ├─ _human_rack = TileRack.new(_bag.draw_balanced_tiles(7))
            ├─ _ai_rack   = TileRack.new(_bag.draw_balanced_tiles(7))
            ├─ scores / passes reset to 0
            ├─ _reset_turn_state()           ← clears pending placements
            ├─ guard: WordDict.trie must not be null
            ├─ _ai_player = AIPlayer.new(_difficulty, MoveGenerator.new(), WordDict.trie)
            ├─ _update_display()
            └─ _start_human_turn()
```

### 4.1 TileBag & drawing balanced tiles

`TileBag._init()` fills `_pool` using the German tile distribution (101 tiles total: 15 E's, 9 N's, …) and shuffles. `draw_balanced_tiles(7)` draws 7 tiles, checks that there is at least one vowel and one consonant; if not it returns the tiles and redraws once.

### 4.2 Save-restore path

`_apply_save_data(slot, data)` mirrors `_start_game()` but reads state from the JSON dictionary:
- Reconstructs `_board` by iterating a 15×15 cell array.
- Restores `_bag._pool` directly.
- Rebuilds both racks from stored strings.
- Awaits `WordDict.dictionary_ready` if needed.
- Skips `difficulty_panel`, goes straight to `game_ui`.

---

## 5. The Board Data Model

**Script:** `scripts/game/Board.gd` — `class_name Board extends RefCounted`

The board is a pure data object (no Node). It is not part of the scene tree.

```
_cells: Array       — 15×15 nested Array, each cell is null or an uppercase letter String
_occupied_count: int — live count of non-null cells
```

Key methods:

| Method | Detail |
|---|---|
| `place_tile(r, c, letter)` | Writes `letter.to_upper()`, increments `_occupied_count` if cell was null |
| `remove_tile(r, c)` | Sets cell to null, decrements `_occupied_count` |
| `is_first_move()` | Returns `_occupied_count == 0` — O(1) |
| `get_anchors()` | First move: returns centre `(7,7)`. Otherwise: every empty cell that has at least one occupied neighbour |
| `is_move_connected(…, tiles_placed)` | First move: checks any tile covers centre. Otherwise: checks any placed tile has an occupied neighbour |
| `duplicate()` | Shallow cell copy + copies `_occupied_count` — used for preview/validation without mutating real board |
| `get_bonus_at(r, c)` | Static lookup into `_BONUS_LAYOUT` 2D array — returns BONUS_NONE/DL/TL/DW/TW |

`_BONUS_LAYOUT` is a compile-time constant encoding the standard Scrabble bonus pattern (4=TW, 3=DW, 2=TL, 1=DL, 0=none).

---

## 6. Human Turn Flow

### 6.1 State machine

`Game._state` is one of:
```
DIFFICULTY_SELECT  — before any game starts
HUMAN_TURN         — player is placing tiles
AI_THINKING        — AI coroutine is running
GAME_OVER          — game ended
```

### 6.2 Tile placement — step by step

**Step 1: Select a rack tile**
```
RackDisplay slot clicked
  → _on_slot_clicked(index) [in RackDisplay]
       └─ tile_selected.emit(index)
  → Game._on_rack_tile_selected(index)
       _selected_rack_index = index
```

**Step 2: Click a board cell**
```
BoardDisplay cell clicked
  → cell_clicked.emit(row, col)
  → Game._on_board_cell_clicked(row, col)
       [guard: state must be HUMAN_TURN, cell must be empty]
       _pending_placements.append({pos, letter, rack_index})
       _placed_rack_indices.append(_selected_rack_index)
       _selected_rack_index = -1
       _preview_dirty = true
       rack_display.clear_selection()
       _update_display()
```

**Clicking a board cell that already has a pending tile removes it:**
```
_get_pending_idx(row, col) finds the placement
_pending_placements.remove_at(idx)
_placed_rack_indices.erase(rack_index)
_preview_dirty = true
_update_display()
```

### 6.3 `_update_display()`

Called after every interactive action. Builds a preview board and drives both display nodes:

```
_update_display()
  ├─ preview_board = _board.duplicate()
  ├─ for each pending placement: preview_board.place_tile(...)
  │
  ├─ [cache check]
  │    if _pending_placements is empty → _preview_valid_cache = false
  │    elif _preview_dirty:
  │         _preview_valid_cache = _validate_move().valid   ← only when placements changed
  │         _preview_dirty = false
  │
  ├─ board_display.display(preview_board, pending_positions, _preview_valid_cache)
  ├─ rack_display.display(rack_tiles, selected_idx, placed_indices)
  ├─ update score labels
  └─ enable/disable Submit / Pass / Exchange buttons based on state
```

### 6.4 BoardDisplay rendering

`BoardDisplay` (`scripts/ui/BoardDisplay.gd`) builds 225 `Control` nodes (one per cell) lazily in `_ensure_built()`. Each cell contains:
- `ColorRect` BG — shows bonus colour when empty, tile colour when occupied, preview colour when pending
- `ColorRect` Marker — red tint over pending tiles
- `Label` Letter — the tile letter, centred
- `Label` Value — small point value, bottom-right
- `Label` Bonus — "DL"/"TL"/"DW"/"TW" text, shown on empty bonus cells

`display(board, preview_placements, preview_valid)` iterates all 225 cells and updates visibility/colour/text in one pass. On resize, `_apply_cell_metrics(s)` repositions every child node.

### 6.5 Move validation (`_validate_move()`)

```
_validate_move()
  ├─ guard: at least one pending tile
  ├─ compute row/col sets → determine horizontal vs vertical
  ├─ guard: all tiles in one row or one column
  ├─ sort tiles, check no empty gaps between them (board cells may fill gaps)
  ├─ _board.is_move_connected(...)        ← ensures connection to existing tiles
  ├─ temp = _board.duplicate()
  │   apply pending tiles to temp
  ├─ find main word (walk from word start to end on temp board)
  ├─ WordDict.is_valid_word(main_word)    ← Trie lookup
  ├─ for each placed tile: check cross-word if length > 1
  │    WordDict.is_valid_word(cross_word)
  └─ Scoring.calculate(temp, word, row, col, horizontal, tiles_placed)
       → returns {valid, word, row, col, horizontal, score, tiles_placed}
```

### 6.6 Scoring (`Scoring.calculate`)

```
calculate(board, word, row, col, horizontal, tiles_placed)
  ├─ build placed_set: Dictionary from tiles_placed (for O(1) lookup)
  ├─ walk the main word letter by letter:
  │    is_new = placed_set.has(position)
  │    apply DL/TL to letter value if is_new and bonus cell
  │    accumulate DW/TW multipliers
  ├─ total = letter_sum × word_multiplier
  ├─ for each new tile: _calculate_cross(board, pos, horizontal)
  │    walks perpendicular direction to collect full cross-word
  │    applies letter bonuses (cross-word bonuses are NOT applied — they burned when placed)
  │    returns cross-word score
  ├─ total += cross_score
  └─ if tiles_placed.size() == 7: total += 50   (bingo bonus)
```

### 6.7 Submit

```
Submit pressed → _on_submit()
  ├─ _validate_move() — full validation
  └─ _apply_human_move(result)
       ├─ place all pending tiles on _board permanently
       ├─ remove placed letters from _human_rack
       ├─ _human_score += score
       ├─ _pending_placements = []  (via _reset_turn_state-equivalent inline)
       ├─ _draw_human_tiles()       ← refill rack from _bag up to 7
       ├─ _update_display()
       ├─ _auto_save()
       ├─ await 0.8s timer
       ├─ await _check_end_game()   ← check win conditions
       └─ _start_ai_turn()
```

### 6.8 Pass & Exchange

**Pass:**
```
_on_pass()
  _consecutive_passes += 1
  await _check_end_game()
  _start_ai_turn()
```

**Exchange:**
First press enters exchange mode (tiles highlighted in blue in RackDisplay). Second press:
```
_on_exchange() [second press]
  ├─ collect exchange_indices from rack_display
  ├─ remove those letters from _human_rack
  ├─ _bag.exchange(letters)  ← returns letters to pool, shuffles, draws same count
  ├─ add new tiles to _human_rack
  ├─ _auto_save()
  └─ _start_ai_turn()
```

---

## 7. AI Turn Flow

```
_start_ai_turn()
  ├─ _state = AI_THINKING
  ├─ disable all action buttons
  ├─ await 0.3s  (gives UI one frame to show "AI thinking…")
  ├─ move = _ai_player.choose_move(_board, _ai_rack.get_tiles())
  │    [synchronous — runs on main thread]
  └─ [apply move or pass, then _start_human_turn()]
```

### 7.1 AIPlayer.choose_move

```
choose_move(board, rack)
  ├─ thinking_started.emit()
  ├─ moves = move_generator.generate_moves(board, rack, trie)
  ├─ if moves empty → return pass move
  ├─ chosen = _select_move(moves)
  │    HARD:   _select_hard   — pick highest eval_score (5% random from top 50%)
  │    MEDIUM: _select_medium — pick randomly from top 30%
  │    EASY:   _select_easy   — pick randomly from bottom 40% (10% chance to pass)
  ├─ thinking_finished.emit()
  └─ move_chosen.emit(chosen)
```

### 7.2 Move evaluation

`_evaluate_moves(moves)` scores every candidate move with a weighted formula:

```
eval_score = (move.score × 1.0)          ← raw point value
           + (_evaluate_rack_leave × 0.3) ← quality of remaining tiles
           + (_evaluate_defensive × 0.15) ← penalty for opening bonus squares
```

**Rack leave** scoring rewards common letters (E, R, S, N…), penalises awkward letters (Q, X, J…), and gives a bonus for vowel/consonant balance.

**Defensive** scoring applies a penalty for each placed tile that is diagonally adjacent to an uncovered TW or DW square, scaled by the letter being placed (vowels adjacent to TW penalised more) and by the raw score magnitude.

### 7.3 MoveGenerator.generate_moves

This is the engine of the AI. It uses an anchor-based backtracking search over the Trie:

```
generate_moves(board, rack, trie)
  ├─ _move_keys = {}       ← dedup dictionary
  ├─ _cross_cache = {}     ← per-call cross-check cache
  ├─ anchors = board.get_anchors()
  ├─ for each anchor:
  │    _gen_direction(board, anchor, rack, trie, moves, horizontal=true)
  │    _gen_direction(board, anchor, rack, trie, moves, horizontal=false)
  └─ _scoring_sort(moves)  ← descending by score
```

**`_gen_direction`** calculates how many empty cells exist behind the anchor (up to rack length) and calls `_go_direction` for each possible start position.

**`_go_direction`** is a recursive Trie-guided depth-first search:

```
_go_direction(board, row, col, anchor, rack, trie_node, word, tiles_placed, placed_any, moves, horizontal)

  [base case — off board edge]
    if placed_any and node.is_end and board.is_move_connected(...):
      _register_move(...)
    return

  [cell occupied on board]
    follow the existing letter through the Trie (no rack tile consumed)
    recurse to next position

  [cell empty]
    if placed_any and node.is_end and connected: _register_move(...)
    
    for each letter in rack:
      if Trie child exists for letter AND cross_check passes:
        recurse with letter consumed from rack, tile added to tiles_placed

    [before anchor — allow skipping empty cell without placing]
    if not placed_any and cur_pos < anchor_pos:
      recurse without placing any tile
```

**`_cross_check(board, row, col, letter, is_horizontal, trie)`** verifies that placing `letter` at `(row, col)` does not create an invalid word in the perpendicular direction:

```
_cross_check(...)
  ├─ cache_key = Vector2i(row*15+col, letter.unicode_at(0)*2 + int(is_horizontal))
  ├─ if _cross_cache.has(key): return cached result  ← board is static during generation
  ├─ collect tiles above/below (or left/right) the position
  ├─ form cross_word = prefix + letter + suffix
  ├─ if no perpendicular neighbours: result = true
  ├─ elif cross_word length == 1: result = true
  ├─ else: result = trie.search(cross_word)
  └─ _cross_cache[key] = result ; return result
```

**`_register_move`** reconstructs the actual word from board tiles and placed tiles, deduplicates via `_move_keys`, and calls `Scoring.calculate` to assign a score.

### 7.4 Applying the AI move

```
[after choose_move returns]

if move.passed:
  _consecutive_passes += 1
  await 0.8s

else:
  for each tile_placed:
    _board.place_tile(pos.x, pos.y, letter)
    _ai_rack.remove_letter(letter)
  _ai_score += move.score
  _draw_ai_tiles()
  await 1.2s

_update_display()
_auto_save()
await _check_end_game()
_start_human_turn()
```

---

## 8. End Game Conditions

`_check_end_game()` is called after every human move and every AI move:

| Condition | Outcome |
|---|---|
| `_consecutive_passes >= 6` (both players passed 3× each) | Game over, no bonus |
| Human rack empty | AI rack value added to human score as bonus |
| AI rack empty | Human rack value added to AI score as bonus |

`Tiles.get_rack_value(rack_string)` sums point values of all letters remaining in the loser's rack.

```
_end_game(reason)
  ├─ _state = GAME_OVER
  ├─ SaveManager.delete_save(_save_slot)  ← clears the in-progress save
  ├─ disable all action buttons
  ├─ await 0.5s
  └─ game_overlay.show_scores(human_score, ai_score)
       └─ GameOverOverlay shows winner label + score, emits play_again_pressed or main_menu_pressed
```

**Play again** → `_on_play_again()` hides overlay, calls `_start_game()`.  
**Main menu** → `get_tree().change_scene_to_file("…/MainMenu.tscn")`.

---

## 9. Auto-Save

`_auto_save()` is called after every human move, AI move, pass, and exchange:

```
_auto_save()
  └─ SaveManager.save_data(_save_slot, _collect_save_data())

_collect_save_data() → Dictionary:
  - version: 1
  - timestamp: ISO string
  - difficulty / difficulty_name
  - board: 15×15 Array of letter|null
  - bag_pool: Array of remaining tile strings
  - human_rack / ai_rack: strings
  - human_score / ai_score / consecutive_passes
```

Slot assignment uses the first empty slot; if all 5 are full, the oldest save (by timestamp) is overwritten.

---

## 10. Theme System

All visual theming flows through `Settings.dark_mode`:

1. `Settings.dark_mode = value` triggers setter → `theme_changed.emit(dark_mode)`.
2. Every connected scene re-styles itself:
   - `MainMenu._on_theme_changed()` → `_apply_background()` → `_style_menu_theme()`
   - `Game._on_theme_changed()` → `_apply_background()` + `_style_scene_theme()`
   - `BoardDisplay.apply_theme()` — updates all colour constants and redraws all 225 cells
   - `RackDisplay.apply_theme()` — updates tile/empty/placed colour constants and redraws

Styling is entirely programmatic: `StyleBoxFlat` objects are created and applied via `add_theme_stylebox_override` and `add_theme_color_override`. No `.theme` resource files are used.

---

## 11. Signal Map

```
Settings.theme_changed         → MainMenu._on_theme_changed
                               → Game._on_theme_changed
                               → BoardDisplay.apply_theme
                               → RackDisplay.apply_theme

Settings.music_volume_changed  → Audio._on_music_volume_changed
Settings.effects_volume_changed→ Audio._on_effects_volume_changed
Settings.overall_volume_changed→ Audio._on_overall_volume_changed

WordDict.dictionary_ready      → (awaited in Game._on_difficulty_selected,
                                   Game._apply_save_data)

BoardDisplay.cell_clicked      → Game._on_board_cell_clicked
RackDisplay.tile_selected      → Game._on_rack_tile_selected
RackDisplay.tile_deselected    → Game._on_rack_tile_deselected
RackDisplay.placed_tile_clicked→ Game._on_placed_tile_clicked

GameOverOverlay.play_again_pressed → Game._on_play_again
GameOverOverlay.main_menu_pressed  → Game._on_main_menu

AIPlayer.thinking_started      → (not connected in current UI — available for spinners)
AIPlayer.thinking_finished     → (not connected in current UI)
AIPlayer.move_chosen           → (not connected in current UI — move returned synchronously)
```

---

## 12. File & Class Reference

```
project.godot                         — autoload declarations, viewport config
scenes/main_menu/MainMenu.tscn        — main menu scene
scenes/game/Game.tscn                 — game scene
scripts/
  autoload/
    SettingsManager.gd  (Settings)    — persistent settings, signals to Audio/UI
    AudioManager.gd     (Audio)       — SFX/music playback, volume control
    WordDictionary.gd   (WordDict)    — async trie loader, is_valid_word()
    SaveManager.gd                    — JSON slot saves, pending_load_slot handshake
  game/
    Board.gd                          — 15×15 data grid, anchor/bonus logic
    Trie.gd                           — prefix-tree word lookup structure
    TrieNode.gd                       — single node: children Dict + is_end bool
    Tiles.gd                          — letter values, tile distribution constants
    TileBag.gd                        — shuffled tile pool, draw/exchange
    TileRack.gd                       — player's hand as a String, add/remove helpers
    Scoring.gd                        — static calculate(): main word + cross-words + bingo
  ai/
    AIPlayer.gd                       — difficulty selector, move evaluator
    MoveGenerator.gd                  — anchor-based Trie backtracking search
  ui/
    MainMenu.gd                       — panel-swap menu, settings wiring
    Game.gd                           — game state machine, human/AI turn loop
    BoardDisplay.gd                   — 225-cell procedural grid renderer
    RackDisplay.gd                    — 7-slot tile rack renderer, selection/exchange UI
    GameOverOverlay.gd                — end-of-game scores panel
```
