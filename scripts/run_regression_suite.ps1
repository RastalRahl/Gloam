$projectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $projectRoot
try {
    function Assert-CleanGodotLog {
        param(
            [string]$TestName,
            [string]$LogPath
        )

        if (-not (Test-Path -LiteralPath $LogPath)) {
            Write-Error "$TestName did not produce a Godot log."
            exit 1
        }

        $unexpectedLines = @(
            Get-Content -LiteralPath $LogPath |
                Where-Object {
					($_ -match "SCRIPT ERROR|Parse Error|Failed to load|Failed loading|Could not load|Can't load|ERROR:") -and
                    ($_ -notmatch "Failed to read the root certificate store")
                }
        )
        if ($unexpectedLines.Count -gt 0) {
            Write-Error "$TestName emitted an unexpected Godot error; refusing a silent pass.`n$($unexpectedLines | Select-Object -First 20 | Out-String)"
            exit 1
        }
    }

    $logDirectory = Join-Path $projectRoot ".godot\regression_logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

    Write-Host "=== GLOAM SLOW FULL-SCENE SMOKE REGRESSION ==="
    $sceneTests = @(
        "pause_shell_verification.gd",
		"audio_verification.gd",
		"title_checkpoint_navigation_verification.gd",
        "run_checkpoint_verification.gd",
        "architecture_verification.gd",
        "assault_loop_verification.gd",
        "night_wave_verification.gd",
		"ten_night_combat_soak.gd",
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
        Assert-CleanGodotLog $sceneTest $logPath
    }

    Write-Host "=== GLOAM HUD MOUSE-INPUT VERIFICATION ==="
    $hudMouseLogPath = Join-Path $logDirectory "hud_mouse_input_verification.log"
    & godot --headless --path $projectRoot --log-file $hudMouseLogPath --script res://scripts/hud_mouse_input_verification.gd
    $hudMouseProcessExit = $LASTEXITCODE
    if ($hudMouseProcessExit -ne 0) {
        exit $hudMouseProcessExit
    }
    Assert-CleanGodotLog "hud_mouse_input_verification.gd" $hudMouseLogPath

    Write-Host "=== GLOAM PROP ALIGNMENT VERIFICATION ==="
    $alignmentLogPath = Join-Path $logDirectory "prop_alignment_verification.log"
    & godot --headless --path $projectRoot --log-file $alignmentLogPath --scene res://scenes/dev/prop_alignment_verification.tscn
    $alignmentProcessExit = $LASTEXITCODE
    if ($alignmentProcessExit -ne 0) {
        exit $alignmentProcessExit
    }
    Assert-CleanGodotLog "prop_alignment_verification.tscn" $alignmentLogPath

    Write-Host "=== GLOAM UI SPACING CAPTURE VERIFICATION ==="
    $uiLogPath = Join-Path $logDirectory "ui_spacing_capture.log"
    & godot --headless --path $projectRoot --log-file $uiLogPath --script res://scripts/ui_spacing_capture.gd
    $uiProcessExit = $LASTEXITCODE
    if ($uiProcessExit -ne 0) {
        exit $uiProcessExit
    }
    Assert-CleanGodotLog "ui_spacing_capture.gd" $uiLogPath

    Write-Host "=== GLOAM FAST LOGIC REGRESSION ==="
    $fastLogPath = Join-Path $logDirectory "fast_logic.log"
    & godot --headless --path $projectRoot --log-file $fastLogPath --script res://scripts/regression_suite.gd
    $fastProcessExit = $LASTEXITCODE
    if ($fastProcessExit -ne 0) {
        exit $fastProcessExit
    }
    Assert-CleanGodotLog "regression_suite.gd" $fastLogPath

    Write-Host "=== GLOAM REGRESSION SUITE: PASS ==="
    exit 0
}
finally {
    Pop-Location
}
