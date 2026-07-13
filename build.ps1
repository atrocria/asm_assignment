param(
    [string]$Output = "main.exe",
    [string]$DosBox = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$projectRoot = (Resolve-Path -LiteralPath $scriptDir).Path
$srcDir = Join-Path $projectRoot "src"
$sourcePath = Join-Path $srcDir "main.asm"
$outputPath = Join-Path $projectRoot $Output
$outputDir = Split-Path -Parent $outputPath
$dosWorkDir = $projectRoot

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
    "dosbox"
)

if ($env:ProgramFiles) {
    $dosBoxCandidates += @(
        (Join-Path $env:ProgramFiles "DOSBox-X\dosbox-x.exe"),
        (Join-Path $env:ProgramFiles "DOSBox-0.74-3\DOSBox.exe")
    )
}

$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
if ($programFilesX86) {
    $dosBoxCandidates += @(
        (Join-Path $programFilesX86 "DOSBox-X\dosbox-x.exe"),
        (Join-Path $programFilesX86 "DOSBox-0.74-3\DOSBox.exe")
    )
}

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

if (-not (Test-Path $srcDir -PathType Container)) {
    throw "The src folder was not found at $srcDir."
}

if (-not (Test-Path $sourcePath -PathType Leaf)) {
    throw "main.asm was not found at $sourcePath."
}

New-Item -ItemType Directory -Force $outputDir | Out-Null

$sourceName = Split-Path -Leaf $sourcePath
$programName = [System.IO.Path]::GetFileNameWithoutExtension($sourceName)
$dosSourcePath = $sourcePath.Substring($projectRoot.Length).TrimStart("\")
$dosOutput = Join-Path $dosWorkDir "$programName.EXE"
$dosObject = Join-Path $dosWorkDir "$programName.OBJ"

$batchPath = Join-Path $dosWorkDir "BUILD.BAT"
@"
@echo off
MASM $dosSourcePath,$programName.OBJ;
IF ERRORLEVEL 1 GOTO FAILED
LINK $programName.OBJ;
IF ERRORLEVEL 1 GOTO FAILED
GOTO DONE
:FAILED
ECHO Build failed.
:DONE
"@ | Set-Content -Path $batchPath -Encoding ASCII

Remove-Item -Force $dosOutput -ErrorAction SilentlyContinue
Remove-Item -Force $dosObject -ErrorAction SilentlyContinue

$dosBoxArgs = '-c "mount c \"{0}\"" -c "c:" -c "CALL BUILD.BAT" -c "exit"' -f $dosWorkDir
$process = Start-Process -FilePath $dosBoxPath -ArgumentList $dosBoxArgs -Wait -PassThru -WindowStyle Hidden
if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
    throw "DOSBox exited with code $($process.ExitCode)."
}

if (-not (Test-Path $dosOutput)) {
    throw "Build failed: $dosOutput was not created."
}

if ($dosOutput -ne $outputPath) {
    Copy-Item -Force $dosOutput $outputPath
}

Write-Host "Built $Output"

$buildDosBoxArgs = '-c "mount c \"{0}\"" -c "c:"' -f $outputDir
Start-Process -FilePath $dosBoxPath -ArgumentList $buildDosBoxArgs | Out-Null
