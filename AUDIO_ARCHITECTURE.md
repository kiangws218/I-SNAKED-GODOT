# Audio architecture and regression contract

This document records the testable contract for the audio package. The tests are intentionally headless and do not require a physical sound card or shipped BGM files. They use the engine's `AudioServer` metadata and call the directors through runtime reflection so the test script still parses while the package is being added.

## Stable IDs and routing

- Music IDs are `music.title`, `music.tutorial`, `music.wilderness`, `music.forest`, and `music.cave`.
- `StoryMapCatalog` owns the map-to-cue mapping through the `music_cue` key: `prologue_tutorial`, `wilderness`, `forest`, and `cave` map one-to-one to those IDs.
- Every `MusicCue` and `SfxDefinition` has a non-empty unique stable ID. File names are not IDs.
- The bus graph is `Master`; `Music -> Master`; `SFX -> Master`; `UI -> SFX`; `CG -> SFX`; `Ambience -> Music`.
- Music cues route to `Music`; normal effects route to `SFX`; UI/CG effects may route to their dedicated buses; ambience routes to `Ambience`.

## Director behavior

`MusicDirector` is loaded from `res://game/audio/music/music_director.tscn` and exposes `play_cue(StringName) -> Dictionary`, `stop_music()`, and `current_cue_id`. `SfxDirector` is loaded from `res://game/audio/sfx/sfx_director.tscn` and exposes `play_sfx(StringName, Dictionary) -> Dictionary`.

- Unknown cue/ID and a cue/definition with no stream return a Dictionary failure and do not throw, spam an error, or create a playing node.
- Calling `play_cue` for the already-current cue reuses the active player and does not restart it.
- Cross-fades are generation-safe: after rapid A -> B -> A requests, an old fade/tween cannot stop, retarget, or overwrite the latest request.
- `SfxDirector` enforces per-definition cooldown and `max_instances`; rejected calls are quiet and observable through the returned Dictionary.
- All directors must remain safe in a headless process. A generated/silent stream may be used by future fixture tests; no test should load a real BGM file merely to prove routing or state transitions.

## Running the focused regression

From the project directory, use the absolute Godot binary already configured in `GDA_GODOT` and keep `--json` on the GDA invocation:

```powershell
$project = (Resolve-Path .).Path
gda --project $project script validate tests/audio_architecture_tests.gd --json
gda --project $project script run tests/audio_architecture_tests.gd --strict --json
& $env:GDA_GODOT --headless --audio-driver Dummy --path $project --script res://tests/audio_architecture_tests.gd
```

The first two commands provide structured GDA evidence; the final command is the direct Godot headless smoke run. A checkout before the directors/resources land is expected to report explicit `AUDIO TEST SKIP` lines for those components while still validating buses and map IDs. Once they exist, skips should disappear except for intentionally absent silent fixture streams.

## Evidence, risks, and gaps

- Current evidence: `default_bus_layout.tres` contains all six buses and the intended sends; `StoryMapCatalog` contains all four `music_cue` values; the director scenes and cue/catalog resources now load through the expected paths. The initial audit observed those implementation files arriving during test authoring, which is why all implementation references remain runtime-discovered.
- Result dictionaries use `ok` and `code`; music also reports `reused`, while SFX reports `player_kind` and the selected playback parameters.
- Synthetic in-memory `AudioStreamWAV` catalogs cover positive playback state transitions without shipped audio. A future catalog injection seam would make the fixture setup smaller and keep CI independent of scene defaults.
- Gap: a runtime assertion can verify the latest cue remains current after rapid requests, but generation counters/tween cancellation are stronger evidence. Expose a read-only generation or active-transition counter if that becomes part of the implementation contract.
