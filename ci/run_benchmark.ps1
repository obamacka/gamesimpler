# One-command voxel benchmark for Windows (plan P0.8 b, d, j, k).
# Downloads and verifies Godot 4.7.2 and Voxel Tools 1.7, imports the project, runs
# spikes/voxel/voxel_benchmark.tscn windowed at 1920x1080 and prints a table row for
# _docs/reports/voxel_spike.md.
#
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File ci\run_benchmark.ps1 -Tier min -Machine "i7-3770 / GTX 1070"
#   -Tier min checks 30 fps (min spec), -Tier rec checks 60 fps (recommended spec)
param(
    [ValidateSet("min", "rec")][string]$Tier = "min",
    [string]$Machine = "unnamed",
    [int]$Duration = 60
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # much faster Invoke-WebRequest

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Cache = Join-Path $Root ".bench"
New-Item -ItemType Directory -Force -Path $Cache | Out-Null

function Get-Verified([string]$Url, [string]$OutFile, [string]$Algorithm, [string]$Expected) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    $actual = (Get-FileHash -Path $OutFile -Algorithm $Algorithm).Hash.ToLower()
    if ($actual -ne $Expected.ToLower()) {
        Remove-Item $OutFile -Force
        throw "Checksum mismatch for $OutFile"
    }
}

# Godot 4.7.2 (console build so output reaches this terminal)
$GodotZip = "Godot_v4.7.2-stable_win64.exe.zip"
$GodotSha512 = "83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993"
$Godot = Join-Path $Cache "Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $Godot)) {
    $zipPath = Join-Path $Cache $GodotZip
    Get-Verified "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/$GodotZip" $zipPath "SHA512" $GodotSha512
    Expand-Archive -Path $zipPath -DestinationPath $Cache -Force
    Remove-Item $zipPath -Force
}
& $Godot --version

# Voxel Tools 1.7 GDExtension (desktop binaries only), same as ci/fetch_voxel.sh
$VoxelDst = Join-Path $Root "addons\zylann.voxel"
$VoxelBin = Join-Path $VoxelDst "bin"
if (-not (Test-Path (Join-Path $VoxelBin "libvoxel.windows.editor.x86_64.dll"))) {
    $vzip = Join-Path $Cache "GodotVoxelExtension.zip"
    Get-Verified "https://github.com/Zylann/godot_voxel/releases/download/v1.7x/GodotVoxelExtension.zip" $vzip "SHA256" "600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8"
    $vtmp = Join-Path $Cache "voxel_x"
    if (Test-Path $vtmp) { Remove-Item $vtmp -Recurse -Force }
    Expand-Archive -Path $vzip -DestinationPath $vtmp -Force
    $src = Join-Path $vtmp "addons\zylann.voxel"
    New-Item -ItemType Directory -Force -Path $VoxelBin | Out-Null
    foreach ($f in @("LICENSE.md", "voxel.gdextension", "voxel.gdextension.uid")) {
        Copy-Item (Join-Path $src $f) $VoxelDst -Force
    }
    Copy-Item (Join-Path $src "editor") $VoxelDst -Recurse -Force
    foreach ($f in @("libvoxel.windows.editor.x86_64.dll", "libvoxel.windows.template_release.x86_64.dll",
                     "libvoxel.linux.editor.x86_64.so", "libvoxel.linux.template_release.x86_64.so")) {
        Copy-Item (Join-Path $src "bin\$f") $VoxelBin -Force
    }
    foreach ($f in @("libvoxel.macos.editor.universal.framework", "libvoxel.macos.template_release.universal.framework")) {
        Copy-Item (Join-Path $src "bin\$f") $VoxelBin -Recurse -Force
    }
    Remove-Item $vtmp -Recurse -Force
    Remove-Item $vzip -Force
}

Write-Host "Importing project"
& $Godot --headless --path $Root --import *> $null

$log = Join-Path $Cache ("benchmark_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Write-Host "Running benchmark for $Duration s (log: $log)"
& $Godot --path $Root --resolution 1920x1080 res://spikes/voxel/voxel_benchmark.tscn -- "--duration=$Duration" "--tier=$Tier" "--machine=$Machine" 2>&1 | Tee-Object -FilePath $log

Write-Host ""
Write-Host "Paste this row into _docs/reports/voxel_spike.md:"
$row = Select-String -Path $log -Pattern '\[voxel_benchmark_row\] (.*)' | Select-Object -Last 1
if (-not $row) { throw "benchmark row not found; see $log" }
Write-Host $row.Matches[0].Groups[1].Value
