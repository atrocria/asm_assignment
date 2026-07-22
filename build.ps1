```powershell
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

# Check that MASM exists.
if (-not (Test-Path $masmPath -PathType Leaf)) {
    throw "MASM.EXE was not found in $projectRoot."
}

# Check that LINK exists.
if (-not (Test-Path $linkPath -PathType Leaf)) {
    throw "LINK.EXE was not found in $projectRoot."
}

# Check the src folder.
if (-not (Test-Path $srcDir -PathType Container)) {
    throw "The src folder was not found at $srcDir."
}

# Check main.asm.
if (-not (Test-Path $sourcePath -PathType Leaf)) {
    throw "main.asm was not found at $sourcePath."
}

# Find DOSBox or DOSBox-X.
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

$programFilesX86 =
    [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")

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

    if (Test-Path $candidate -PathType Leaf) {
        $dosBoxPath = $candidate
        break
    }
}

if (-not $dosBoxPath) {
    throw @"
DOSBox or DOSBox-X was not found.

Install DOSBox or DOSBox-X and add it to PATH, or run:

.\build.ps1 -DosBox "C:\path\to\dosbox.exe"
"@
}

# Create the output directory if necessary.
New-Item `
    -ItemType Directory `
    -Force `
    -Path $outputDir |
    Out-Null

$sourceName = Split-Path -Leaf $sourcePath

$programName =
    [System.IO.Path]::GetFileNameWithoutExtension($sourceName)

# DOS paths are relative to the mounted project root.
$dosSourcePath =
    $sourcePath.Substring($projectRoot.Length).TrimStart("\")

$dosOutput = Join-Path $dosWorkDir "$programName.EXE"
$dosObject = Join-Path $dosWorkDir "$programName.OBJ"
$batchPath = Join-Path $dosWorkDir "BUILD.BAT"

# BUILD.BAT behavior:
#
# Success:
#   EXIT closes DOSBox automatically.
#
# Failure:
#   PAUSE lets you read the error.
#   The batch file then ends without EXIT, leaving DOSBox open.
$buildBatch = @"
@ECHO OFF
CLS

ECHO ========================================
ECHO Building $programName.asm
ECHO ========================================
ECHO.

MASM $dosSourcePath,$programName.OBJ;
IF ERRORLEVEL 1 GOTO ASSEMBLY_FAILED

LINK $programName.OBJ;
IF ERRORLEVEL 1 GOTO LINK_FAILED

ECHO.
ECHO ========================================
ECHO BUILD SUCCESSFUL
ECHO Created $programName.EXE
ECHO ========================================

EXIT


:ASSEMBLY_FAILED
ECHO.
ECHO ========================================
ECHO ASSEMBLY FAILED
ECHO ========================================
ECHO.
ECHO MASM reported an error.
ECHO Review the messages above.
ECHO.
PAUSE
GOTO KEEP_OPEN


:LINK_FAILED
ECHO.
ECHO ========================================
ECHO LINKING FAILED
ECHO ========================================
ECHO.
ECHO LINK reported an error.
ECHO Review the messages above.
ECHO.
PAUSE
GOTO KEEP_OPEN


:KEEP_OPEN
ECHO.
ECHO DOSBox will remain open.
ECHO Type EXIT when you are finished.
ECHO.
"@

$buildBatch |
    Set-Content `
        -Path $batchPath `
        -Encoding ASCII

# Remove previous build files so an old EXE cannot be mistaken
# for a successful new build.
Remove-Item `
    -Force `
    -ErrorAction SilentlyContinue `
    $dosOutput

Remove-Item `
    -Force `
    -ErrorAction SilentlyContinue `
    $dosObject

# Do not add:
#
#   -c "exit"
#
# BUILD.BAT itself exits DOSBox only when the build succeeds.
$dosBoxArgs = @(
    "-c", "mount c `"$dosWorkDir`""
    "-c", "c:"
    "-c", "call BUILD.BAT"
)

$process = Start-Process `
    -FilePath $dosBoxPath `
    -ArgumentList $dosBoxArgs `
    -Wait `
    -PassThru

# On an error, this line is reached only after you manually close
# DOSBox because PowerShell is waiting for the DOSBox process.
if (-not (Test-Path $dosOutput -PathType Leaf)) {
    throw "Build failed. No executable was created."
}

if ($dosOutput -ne $outputPath) {
    Copy-Item `
        -Force `
        -Path $dosOutput `
        -Destination $outputPath
}

Write-Host "Built $Output"

# Open a new DOSBox window in the output directory after a
# successful build.
$runDosBoxArgs = @(
    "-c", "mount c `"$outputDir`""
    "-c", "c:"
)

Start-Process `
    -FilePath $dosBoxPath `
    -ArgumentList $runDosBoxArgs |
    Out-Null
```
