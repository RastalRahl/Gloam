$projectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $projectRoot
try {
    $logDirectory = Join-Path $projectRoot ".godot\regression_logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

    Write-Host "=== GLOAM SLOW FULL-SCENE SMOKE REGRESSION ==="
    $sceneTests = @(
        "pause_shell_verification.gd",
        "architecture_verification.gd",
        "assault_loop_verification.gd",
        "night_wave_verification.gd",
        "boss_spawn_verification.gd",
        "settlement_verification.gd",
        "player_down_verification.gd",
        "contextual_interaction_verification.gd",
        "input_actions_verification.gd",
        "elemental_progression_verification.gd",
        "day_exploration_verification.gd",
        "terrain_collision_verification.gd",
        "world_authoring_verification.gd",
        "vegetation_resource_verification.gd",
        "task3_gameplay_verification.gd",
        "task3_route_probe.gd",
        "economy_balance_verification.gd"
    )

    foreach ($sceneTest in $sceneTests) {
        Write-Host "--- $sceneTest ---"
        $logName = [System.IO.Path]::GetFileNameWithoutExtension($sceneTest) + ".log"
        $logPath = Join-Path $logDirectory $logName
        & godot --headless --path $projectRoot --log-file $logPath --script ("res://scripts/{0}" -f $sceneTest)
        $processExit = $LASTEXITCODE
        if ($processExit -ne 0) {
            exit $processExit
        }
        if (Test-Path -LiteralPath $logPath) {
            $logText = Get-Content -LiteralPath $logPath -Raw
            if ($logText -match "SCRIPT ERROR|Parse Error|Failed to load script") {
                Write-Error "$sceneTest emitted a script error; refusing a silent pass."
                exit 1
            }
        }
    }

    Write-Host "=== GLOAM FAST LOGIC REGRESSION ==="
    $fastLogPath = Join-Path $logDirectory "fast_logic.log"
    & godot --headless --path $projectRoot --log-file $fastLogPath --script res://scripts/regression_suite.gd
    $fastProcessExit = $LASTEXITCODE
    if ($fastProcessExit -ne 0) {
        exit $fastProcessExit
    }
    if (Test-Path -LiteralPath $fastLogPath) {
        $fastLogText = Get-Content -LiteralPath $fastLogPath -Raw
        if ($fastLogText -match "SCRIPT ERROR|Parse Error|Failed to load script") {
            Write-Error "regression_suite.gd emitted a script error; refusing a silent pass."
            exit 1
        }
    }

    Write-Host "=== GLOAM REGRESSION SUITE: PASS ==="
    exit 0
}
finally {
    Pop-Location
}
