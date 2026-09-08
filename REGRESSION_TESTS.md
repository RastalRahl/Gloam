# Gloam regression suite

Run the complete deterministic regression suite from the project root with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_regression_suite.ps1
```

The command runs two deliberately separate stages:

- **Slow full-scene smoke regression** runs the existing verification scenes for
  the day/night assault loop, phase/wave flow, settlement, player down,
  contextual interaction, input, elemental progression, exploration, economy,
  pause, and architecture.
- **Fast logic regression** (`scripts/regression_suite.gd`) advances schedules,
  transactions, derived settlement state, upgrade choices, interaction
  debouncing, and soldier return movement directly. It does not wait for
  arbitrary real-time delays.

The fast stage uses seed `1307` for upgrade-choice reproducibility. Existing
deterministic verification scenes provide their own fixed debug seeds. Any
failed assertion prints the expected and actual values where available and the
process exits nonzero; the wrapper stops before later stages on failure.

Late-night profiling and representative visual captures are diagnostics rather
than machine-dependent pass/fail timing gates. Their commands, fixture shape,
baseline, and latest measurements are recorded in
`combat_readability_performance.md`.

Coverage map:

| Failure-prone system | Coverage |
| --- | --- |
| Day → night → day, zone reachability, and night routing | `day_exploration_verification.gd` |
| Dawn checkpoint round-trip, atomic backup recovery, corrupt/unsupported rejection, and new-run reset | `run_checkpoint_verification.gd` |
| Title navigation (keyboard/controller), valid-dawn Continue gating, checkpoint replacement confirmation, and attribution credits | `title_checkpoint_navigation_verification.gd` |
| Terrain topology, authored passages, cliff rejection, and day/night route collision | `terrain_collision_verification.gd` |
| Scene-authored hierarchy, gate alignment/state, spawn markers, and approach paths | `world_authoring_verification.gd` |
| Authored prop footprints and marker-driven resources | `vegetation_resource_verification.gd` |
| 165-second ten-night days, guarded skip/confirmation, outside-village dusk return, authored edge spawns, route/gate behavior, and cancellation safety | `assault_loop_verification.gd` |
| All ten schedules, exact ordinary-enemy totals, modifier introduction order, deterministic elite slots/family order, recovery windows, build-safe behavior keys, active caps, and final boss wave | `night_wave_verification.gd` |
| Accelerated traversal of all ten nights through production spawners, split lanes, real active caps, required-hostile accounting, and the Night 10 boss | `ten_night_combat_soak.gd` |
| Kill-gated completion, pending-work preservation at capacity, invalid-instance handling, cancellation, and final-boss victory gating | `regression_suite.gd` |
| Boss instance spawns exactly once | `boss_spawn_verification.gd` |
| At-cap formation overlap, foreground-foliage fade, large-hostile health visibility, split-lane warnings, and off-screen count/priority | `assault_progression_capture.gd` |
| Game over cancellation and player down/respawn escalation | `player_down_verification.gd` |
| Soldier return-to-post | `regression_suite.gd` |
| Build/upgrade/destroy/rebuild, bonuses, farm, and population capacity | `settlement_verification.gd` and `regression_suite.gd` |
| Day 1–10 pickup/enemy budgets, Worker/Farm yields, build-strategy affordability, resource deduction, and Night 10 boss exclusivity | `regression_suite.gd` and `economy_balance_verification.gd` |
| Input debouncing and named action behavior | `regression_suite.gd` and `input_actions_verification.gd` |
| Upgrade-choice validity and deterministic rolls | `regression_suite.gd` and `elemental_progression_verification.gd` |
| Pause, modal ownership, and phase timer consistency | `pause_shell_verification.gd` |
| HUD mouse hit testing, passive-control filters, modal blockers, and disabled-state explanations | `hud_mouse_input_verification.gd` |
