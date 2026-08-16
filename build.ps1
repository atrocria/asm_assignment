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

function Resolve-DosBoxShortcut {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::GetExtension($Path) -ine ".lnk" -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $targetPath = $shell.CreateShortcut($Path).TargetPath

        if ($targetPath -and
            [System.IO.Path]::GetExtension($targetPath) -ieq ".exe" -and
            (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $targetPath).Path
        }
    } catch {
        return $null
    }

    return $null
}

function Resolve-DosBoxCandidate {
    param(
        [Parameter(Mandatory)]
        [string]$Candidate
    )

    if (-not $Candidate) {
        return $null
    }

    $command = Get-Command $Candidate -ErrorAction SilentlyContinue

    if ($command -and $command.CommandType -eq "Application") {
        return $command.Source
    }

    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        if ([System.IO.Path]::GetExtension($Candidate) -ieq ".lnk") {
            return Resolve-DosBoxShortcut -Path $Candidate
        }

        if ([System.IO.Path]::GetExtension($Candidate) -ieq ".exe") {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }

        return $null
    }

    if (Test-Path -LiteralPath $Candidate -PathType Container) {
        $executable = Get-ChildItem -LiteralPath $Candidate -Filter "DOSBox*.exe" -File -Recurse |
            Select-Object -First 1

        if ($executable) {
            return $executable.FullName
        }

        $shortcuts = Get-ChildItem -LiteralPath $Candidate -Filter "DOSBox*.lnk" -File -Recurse

        foreach ($shortcut in $shortcuts) {
            $shortcutTarget = Resolve-DosBoxShortcut -Path $shortcut.FullName

            if ($shortcutTarget) {
                return $shortcutTarget
            }
        }
    }

    return $null
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

$moduleSourceNames = @(
    "login.asm",
    "tools.asm"
)

$mainSource = Get-Item -LiteralPath $mainSourcePath
$sourceFiles = @($mainSource)

foreach ($moduleSourceName in $moduleSourceNames) {
    $moduleSourcePath = Join-Path $srcDir $moduleSourceName

    if (-not (Test-Path -LiteralPath $moduleSourcePath -PathType Leaf)) {
        throw "Required module was not found at $moduleSourcePath."
    }

    $sourceFiles += Get-Item -LiteralPath $moduleSourcePath
}

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

if ($env:ProgramData) {
    $dosBoxCandidates += (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3")
}

if ($env:APPDATA) {
    $dosBoxCandidates += (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3")
}

$dosBoxPath = $null

foreach ($candidate in $dosBoxCandidates) {
    $dosBoxPath = Resolve-DosBoxCandidate -Candidate $candidate

    if ($dosBoxPath) {
        break
    }
}

if (-not $dosBoxPath) {
    throw @"
DOSBox or DOSBox-X was not found.

Install DOSBox or DOSBox-X and add it to PATH, or run:

.\build.ps1 -DosBox "C:\path\to\dosbox.exe"

The -DosBox value may also be a DOSBox Start Menu folder or .lnk shortcut.
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
    "c:",
    "`"$([System.IO.Path]::GetFileName($outputPath))`""
)

$runDosBoxArgs = New-DosBoxArgumentString -Commands $runDosBoxCommands

Start-Process -FilePath $dosBoxPath -ArgumentList $runDosBoxArgs | Out-Null
