param(
    [string]$Source = "src\main.asm",
    [string]$Output = "build\main.exe",
    [string]$DosBox = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = $PSScriptRoot
$sourcePath = (Resolve-Path (Join-Path $projectRoot $Source)).Path
$outputPath = Join-Path $projectRoot $Output
$outputDir = Split-Path -Parent $outputPath
$dosWorkDir = Join-Path $projectRoot "build\dos"

$masmPath = Join-Path $projectRoot "MASM.EXE"
$linkPath = Join-Path $projectRoot "LINK.EXE"

if (-not (Test-Path $masmPath)) {
    throw "MASM.EXE was not found in $projectRoot."
}

if (-not (Test-Path $linkPath)) {
    throw "LINK.EXE was not found in $projectRoot."
}

$dosBoxCandidates = @()
if ($DosBox) {
    $dosBoxCandidates += $DosBox
}

$dosBoxCandidates += @(
    "dosbox-x",
    "dosbox",
    "C:\Program Files\DOSBox-X\dosbox-x.exe",
    "C:\Program Files (x86)\DOSBox-X\dosbox-x.exe",
    "C:\Program Files\DOSBox-0.74-3\DOSBox.exe",
    "C:\Program Files (x86)\DOSBox-0.74-3\DOSBox.exe"
)

$dosBoxPath = $null
foreach ($candidate in $dosBoxCandidates) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) {
        $dosBoxPath = $command.Source
        break
    }

    if (Test-Path $candidate) {
        $dosBoxPath = $candidate
        break
    }
}

if (-not $dosBoxPath) {
    throw "DOSBox or DOSBox-X was not found. Install one and add it to PATH, or pass -DosBox C:\path\to\dosbox.exe."
}

New-Item -ItemType Directory -Force $outputDir | Out-Null
New-Item -ItemType Directory -Force $dosWorkDir | Out-Null

$sourceName = Split-Path -Leaf $sourcePath
$programName = [System.IO.Path]::GetFileNameWithoutExtension($sourceName)
$dosOutput = Join-Path $dosWorkDir "$programName.EXE"

Copy-Item -Force $masmPath (Join-Path $dosWorkDir "MASM.EXE")
Copy-Item -Force $linkPath (Join-Path $dosWorkDir "LINK.EXE")
Copy-Item -Force $sourcePath (Join-Path $dosWorkDir $sourceName)

$batchPath = Join-Path $dosWorkDir "BUILD.BAT"
@"
@echo off
MASM $sourceName;
IF ERRORLEVEL 1 GOTO FAILED
LINK $programName.OBJ;
IF ERRORLEVEL 1 GOTO FAILED
GOTO DONE
:FAILED
ECHO Build failed.
:DONE
"@ | Set-Content -Path $batchPath -Encoding ASCII

Remove-Item -Force $dosOutput -ErrorAction SilentlyContinue

$dosBoxArgs = '-c "mount c \"{0}\"" -c "c:" -c "CALL BUILD.BAT" -c "exit"' -f $dosWorkDir
$process = Start-Process -FilePath $dosBoxPath -ArgumentList $dosBoxArgs -Wait -PassThru -WindowStyle Hidden
if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
    throw "DOSBox exited with code $($process.ExitCode)."
}

if (-not (Test-Path $dosOutput)) {
    throw "Build failed: $dosOutput was not created."
}

Copy-Item -Force $dosOutput $outputPath
Write-Host "Built $Output"
