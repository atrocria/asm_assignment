param(
    [string]$Output = "main.exe",
    [string]$DosBox = "",
    [switch]$KeepOpenOnError,
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function New-DosBoxArgumentString {
    param(
        [Parameter(Mandatory)]
        [string[]]$Commands
    )

    (($Commands | ForEach-Object {
        $escapedCommand = $_.Replace('"', '\"')
        "-c `"$escapedCommand`""
    }) -join " ")
}

$projectRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

$srcDir = Join-Path $projectRoot "src"
$mainSourcePath = Join-Path $srcDir "main.asm"

if ([System.IO.Path]::IsPathRooted($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
} else {
    $outputPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Output))
}

$outputDir = Split-Path -Parent $outputPath

$masmPath = Join-Path $projectRoot "MASM.EXE"
$linkPath = Join-Path $projectRoot "LINK.EXE"

if (-not (Test-Path -LiteralPath $masmPath -PathType Leaf)) {
    throw "MASM.EXE was not found in $projectRoot."
}

if (-not (Test-Path -LiteralPath $linkPath -PathType Leaf)) {
    throw "LINK.EXE was not found in $projectRoot."
}

if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) {
    throw "The src folder was not found at $srcDir."
}

if (-not (Test-Path -LiteralPath $mainSourcePath -PathType Leaf)) {
    throw "main.asm was not found at $mainSourcePath."
}

$mainSource = Get-Item -LiteralPath $mainSourcePath
$otherSources = Get-ChildItem -LiteralPath $srcDir -Filter "*.asm" -File |
    Where-Object { $_.FullName -ne $mainSource.FullName -and $_.Length -gt 0 } |
    Sort-Object Name

$sourceFiles = @($mainSource) + @($otherSources)

if ($sourceFiles.Count -eq 0) {
    throw "No assembly source files were found in $srcDir."
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
    if (-not $candidate) {
        continue
    }

    $command = Get-Command $candidate -ErrorAction SilentlyContinue

    if ($command -and $command.CommandType -eq "Application") {
        $dosBoxPath = $command.Source
        break
    }

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $dosBoxPath = (Resolve-Path -LiteralPath $candidate).Path
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

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$programName = [System.IO.Path]::GetFileNameWithoutExtension($mainSource.Name)
$dosOutput = Join-Path $projectRoot "$programName.EXE"
$batchPath = Join-Path $projectRoot "BUILD.BAT"
$logPath = Join-Path $projectRoot "BUILD.LOG"
$okMarkerPath = Join-Path $projectRoot "BUILD.OK"
$failMarkerPath = Join-Path $projectRoot "BUILD.FAIL"

$assemblyCommands = foreach ($sourceFile in $sourceFiles) {
    $dosSourcePath = $sourceFile.FullName.Substring($projectRoot.Length).TrimStart("\")
    $objectName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile.Name) + ".OBJ"

    "ECHO MASM $dosSourcePath,$objectName; >> BUILD.LOG"
    "MASM $dosSourcePath,$objectName; >> BUILD.LOG"
    "IF ERRORLEVEL 1 GOTO ASSEMBLY_FAILED"
    "ECHO. >> BUILD.LOG"
}

$objectNames = foreach ($sourceFile in $sourceFiles) {
    [System.IO.Path]::GetFileNameWithoutExtension($sourceFile.Name) + ".OBJ"
}

$linkObjects = $objectNames -join "+"
$failureAction = if ($KeepOpenOnError) {
    @"
PAUSE
GOTO KEEP_OPEN
"@
} else {
    "EXIT"
}

$buildBatch = @"
@ECHO OFF
CLS
IF EXIST BUILD.LOG DEL BUILD.LOG
IF EXIST BUILD.OK DEL BUILD.OK
IF EXIST BUILD.FAIL DEL BUILD.FAIL

ECHO ========================================
ECHO Building $programName.asm
ECHO ========================================
ECHO.
ECHO Building $programName.asm > BUILD.LOG
ECHO. >> BUILD.LOG

$($assemblyCommands -join "`r`n")
ECHO LINK $linkObjects,$programName.EXE; >> BUILD.LOG
LINK $linkObjects,$programName.EXE; >> BUILD.LOG
IF ERRORLEVEL 1 GOTO LINK_FAILED

ECHO.
ECHO ========================================
ECHO BUILD SUCCESSFUL
ECHO Created $programName.EXE
ECHO ========================================
ECHO OK> BUILD.OK

EXIT


:ASSEMBLY_FAILED
ECHO ASSEMBLY> BUILD.FAIL
ECHO.
ECHO ========================================
ECHO ASSEMBLY FAILED
ECHO ========================================
ECHO.
ECHO MASM reported an error.
ECHO Review the messages above.
ECHO.
$failureAction


:LINK_FAILED
ECHO LINK> BUILD.FAIL
ECHO.
ECHO ========================================
ECHO LINKING FAILED
ECHO ========================================
ECHO.
ECHO LINK reported an error.
ECHO Review the messages above.
ECHO.
$failureAction


:KEEP_OPEN
ECHO.
ECHO DOSBox will remain open.
ECHO Type EXIT when you are finished.
ECHO.
"@

$buildBatch | Set-Content -Path $batchPath -Encoding ASCII

Remove-Item -LiteralPath $dosOutput, $logPath, $okMarkerPath, $failMarkerPath -Force -ErrorAction SilentlyContinue

foreach ($objectName in $objectNames) {
    $objectPath = Join-Path $projectRoot $objectName
    Remove-Item -LiteralPath $objectPath -Force -ErrorAction SilentlyContinue
}

$dosBoxCommands = @(
    "mount c `"$projectRoot`"",
    "c:",
    "BUILD.BAT"
)

$dosBoxArgs = New-DosBoxArgumentString -Commands $dosBoxCommands

if (-not $KeepOpenOnError) {
    $dosBoxArgs = "$dosBoxArgs -c `"exit`""
}

$process = Start-Process -FilePath $dosBoxPath -ArgumentList $dosBoxArgs -Wait -PassThru

if (Test-Path -LiteralPath $failMarkerPath -PathType Leaf) {
    $failedStep = (Get-Content -LiteralPath $failMarkerPath -Raw).Trim()
    $buildLog = if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        (Get-Content -LiteralPath $logPath -Raw).Trim()
    } else {
        "BUILD.LOG was not created."
    }

    throw "Build failed during $failedStep. See BUILD.LOG.`n$buildLog"
}

if (-not (Test-Path -LiteralPath $okMarkerPath -PathType Leaf) -or -not (Test-Path -LiteralPath $dosOutput -PathType Leaf)) {
    throw "Build failed. No executable was created."
}

if ($dosOutput -ne $outputPath) {
    Copy-Item -Force -Path $dosOutput -Destination $outputPath
}

Write-Host "Built $Output"

if ($NoRun) {
    return
}

$runDosBoxCommands = @(
    "mount c `"$outputDir`"",
    "c:"
)

$runDosBoxArgs = New-DosBoxArgumentString -Commands $runDosBoxCommands

Start-Process -FilePath $dosBoxPath -ArgumentList $runDosBoxArgs | Out-Null
