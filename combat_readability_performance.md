# Late-night combat readability and performance

This pass profiles and exercises the production Night 10 active-enemy cap while preserving the schedule's difficulty, enemy totals, and ten-night structure. Measurements were taken on Windows with Godot 4.7.1 using the deterministic `late_night_combat_profile.gd` fixture: 36 active enemies split evenly between lanes, 15 static depth items, and 20 representative soldier/building/defense target candidates.

## Before changing behavior

| Hot path | Baseline average |
| --- | ---: |
| Per-frame world depth sort (51 canvas items) | 46.002 us |
| Three target-group snapshots | 2.018 us |
| All 36 enemies choosing a target | 22.340 us |
| Off-screen lane overlay update | 49.900 us |

The old late capture also staged 40 enemies against a cap of 36, so it was not a valid at-cap regression fixture. It produced 13 close sprite pairs and made the largest units merge into a continuous silhouette behind foreground trees. The capture harness now uses the production spawner and schedule entries and cannot exceed the real cap.

The group snapshots and full target scans were already small. They remain unchanged: adding a target registry or altering target priority would add lifecycle risk without a measured performance justification and could change difficulty.

## Changes justified by the profile and captures

- Static world props receive their world-depth value on setup and on later insertion. Only moving actors are depth-sorted each frame.
- Each lane assigns deterministic four-slot lateral formations, with a phase offset where the lanes converge. This changes presentation spacing only; family counts, health, speed, damage, authored route progression, and target selection are unchanged.
- Trees and bushes fade to 38% opacity only while their foreground canopy overlaps a hostile. Spatial buckets constrain overlap checks, and the readability controller updates at 10 Hz.
- Large existing troll-family enemies keep their health bar visible at night. Data-driven elites retain the existing outline and receive a small diamond marker.
- Off-screen lane cards now communicate hostile count, urgency, and the highest readable priority present: boss, elite, brute, or mob. Incoming split waves continue to telegraph both gates before spawning.

## After

| Hot path | Final average | Change |
| --- | ---: | ---: |
| Per-frame dynamic depth sort | 31.905 us | -30.6% |
| Three target-group snapshots | 1.360 us | measurement noise; unchanged code |
| All 36 enemies choosing a target | 23.983 us | measurement noise; unchanged code |
| Full readability/overlay refresh | 216.287 us | richer work, run at 10 Hz |
| Readability refresh amortized at 60 FPS | 34.845 us/frame | -30.2% vs old every-frame overlay |

Absolute microsecond timings vary by machine, so the profiler reports measurements rather than enforcing fragile timing thresholds. Deterministic behavior assertions cover the cap, formation overlap budget, foliage fade, persistent large-hostile health, both-lane warnings, and off-screen count/priority.

Representative capture metrics at the production cap:

| Capture | Active/cap | Close sprite pairs | Purpose |
| --- | ---: | ---: | --- |
| Night 1 early | 12/20 | 0 | Basic two-lane readability before elites |
| Night 6 mid | 26/26 | 3 (legacy comparator: 4) | Split Armored Vanguard and Hunting Pack pressure |
| Night 10 late | 36/36 | 4 (legacy comparator: 7) | At-cap combined arms and large-enemy visibility |

The accelerated soak traverses all ten schedule definitions through production spawners, holds each night at its real cap, retires hostiles through the required-hostile ledger, and verifies all 464 spawned entities (463 ordinary enemies plus the Night 10 boss). No enemy totals, active caps, combat statistics, or completion rules were adjusted in this readability/performance pass.

## Reproduction

```powershell
godot --headless --path . --script res://scripts/late_night_combat_profile.gd
godot --headless --path . --script res://scripts/ten_night_combat_soak.gd
godot --path . --script res://scripts/assault_progression_capture.gd
powershell -ExecutionPolicy Bypass -File .\scripts\run_regression_suite.ps1
```

The capture command writes `visual_comparison/assault_night_01_early.png`, `visual_comparison/assault_night_06_mid.png`, and `visual_comparison/assault_night_10_late.png`. The regenerated `visual_comparison/assault_night_05_mid.png` is retained as the pre-change midpoint baseline.
