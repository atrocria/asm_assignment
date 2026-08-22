param(
    [string]$Output = "main.exe",
    [string]$DosBox = "",
    [switch]$KeepOpenOnError,
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


# =============================================================
# DOSBOX ARGUMENT HELPER
# =============================================================

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


# =============================================================
# DOSBOX SHORTCUT RESOLUTION
# =============================================================

function Resolve-DosBoxShortcut {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (
        [System.IO.Path]::GetExtension($Path) -ine ".lnk" -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)
    ) {
        return $null
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $targetPath = $shell.CreateShortcut($Path).TargetPath

        if (
            $targetPath -and
            [System.IO.Path]::GetExtension($targetPath) -ieq ".exe" -and
            (Test-Path -LiteralPath $targetPath -PathType Leaf)
        ) {
            return (Resolve-Path -LiteralPath $targetPath).Path
        }
    }
    catch {
        return $null
    }

    return $null
}


# =============================================================
# DOSBOX CANDIDATE RESOLUTION
# =============================================================

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

        $executable = Get-ChildItem `
            -LiteralPath $Candidate `
            -Filter "DOSBox*.exe" `
            -File `
            -Recurse |
            Select-Object -First 1

        if ($executable) {
            return $executable.FullName
        }

        $shortcuts = Get-ChildItem `
            -LiteralPath $Candidate `
            -Filter "DOSBox*.lnk" `
            -File `
            -Recurse

        foreach ($shortcut in $shortcuts) {

            $shortcutTarget = Resolve-DosBoxShortcut `
                -Path $shortcut.FullName

            if ($shortcutTarget) {
                return $shortcutTarget
            }
        }
    }

    return $null
}


# =============================================================
# ASM SOURCE DISCOVERY
# =============================================================

function Get-AssemblySourceInfo {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $rawSource = Get-Content -LiteralPath $File.FullName -Raw

    $logicalLines = @(
        $rawSource -split "\r?\n" |
            ForEach-Object {
                ($_ -replace ";.*$", "").Trim()
            }
    )

    $hasCode = @($logicalLines | Where-Object { $_ }).Count -gt 0
    $isStandaloneProgram = $false
    $publicSymbols = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $logicalLines) {

        if ($line -match "(?i)^END\s+\S+") {
            $isStandaloneProgram = $true
        }

        if ($line -match "(?i)^PUBLIC\s+(.+)$") {

            foreach ($rawSymbol in ($Matches[1] -split ",")) {

                $symbol = $rawSymbol.Trim()

                if ($symbol -match "^[A-Za-z_@$?][A-Za-z0-9_@$?]*") {
                    $publicSymbols.Add($Matches[0])
                }
            }
        }
    }

    [pscustomobject]@{
        File = $File
        HasCode = $hasCode
        IsStandaloneProgram = $isStandaloneProgram
        PublicSymbols = [string[]]$publicSymbols
    }
}


function Get-StubMessageInfo {
    param(
        [Parameter(Mandatory)]
        [string]$EntryPoint
    )

    switch ($EntryPoint) {
        "OrderModule" {
            return [pscustomobject]@{
                Prefix = "order"
                Title = "             PLACE ORDER                "
                Body = "Order module is ready."
            }
        }
        "CartModule" {
            return [pscustomobject]@{
                Prefix = "cart"
                Title = "              VIEW CART                 "
                Body = "Cart module is ready."
            }
        }
        "HistoryModule" {
            return [pscustomobject]@{
                Prefix = "history"
                Title = "            ORDER HISTORY               "
                Body = "Order history module is ready."
            }
        }
        default {
            throw "No stub message is configured for $EntryPoint."
        }
    }
}


function New-FeatureStubSource {
    param(
        [Parameter(Mandatory)]
        [string[]]$EntryPoints
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add(".MODEL SMALL")
    $lines.Add("")
    $lines.Add("EXTRN ClearScreen:NEAR")
    $lines.Add("")

    foreach ($entryPoint in $EntryPoints) {
        $lines.Add("PUBLIC $entryPoint")
    }

    $lines.Add("")
    $lines.Add(".DATA")

    foreach ($entryPoint in $EntryPoints) {

        $messageInfo = Get-StubMessageInfo -EntryPoint $entryPoint
        $prefix = $messageInfo.Prefix

        $lines.Add("    ${prefix}_stub_msg DB 0DH,0AH")
        $lines.Add("                    DB '----------------------------------------',0DH,0AH")
        $lines.Add("                    DB '$($messageInfo.Title)',0DH,0AH")
        $lines.Add("                    DB '$($messageInfo.Body)',0DH,0AH")
        $lines.Add("                    DB 'Press any key to return to Main Menu...$'")
        $lines.Add("")
    }

    $lines.Add(".CODE")
    $lines.Add("")

    foreach ($entryPoint in $EntryPoints) {

        $messageInfo = Get-StubMessageInfo -EntryPoint $entryPoint
        $prefix = $messageInfo.Prefix

        $lines.Add("$entryPoint PROC NEAR")
        $lines.Add("    CALL ClearScreen")
        $lines.Add("    LEA DX, ${prefix}_stub_msg")
        $lines.Add("    MOV AH, 09H")
        $lines.Add("    INT 21H")
        $lines.Add("")
        $lines.Add("    MOV AH, 08H")
        $lines.Add("    INT 21H")
        $lines.Add("    RET")
        $lines.Add("$entryPoint ENDP")
        $lines.Add("")
    }

    $lines.Add("END")

    ($lines -join "`r`n") + "`r`n"
}


# =============================================================
# PROJECT PATHS
# =============================================================

$projectRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

$srcDir = Join-Path $projectRoot "src"
$mainSourcePath = Join-Path $srcDir "main.asm"

$masmPath = Join-Path $projectRoot "MASM.EXE"
$linkPath = Join-Path $projectRoot "LINK.EXE"


# =============================================================
# CHECK REQUIRED FILES
# =============================================================

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


# =============================================================
# OUTPUT PATH
# =============================================================

if ([System.IO.Path]::IsPathRooted($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
}
else {
    $outputPath = [System.IO.Path]::GetFullPath(
        (Join-Path $projectRoot $Output)
    )
}

$outputDir = Split-Path -Parent $outputPath

$programName = [System.IO.Path]::GetFileNameWithoutExtension(
    $mainSourcePath
)

$dosOutput = Join-Path $projectRoot "$programName.EXE"

$batchPath = Join-Path $projectRoot "BUILD.BAT"
$logPath = Join-Path $projectRoot "BUILD.LOG"
$okMarkerPath = Join-Path $projectRoot "BUILD.OK"
$failMarkerPath = Join-Path $projectRoot "BUILD.FAI"
$legacyFailMarkerPath = Join-Path $projectRoot "BUILD.FAIL"
$stubSourcePath = Join-Path $projectRoot "BLDSTUB.ASM"
$dosBuildDir = Join-Path $projectRoot "build\dos"


# =============================================================
# FIND LINKABLE ASM SOURCE FILES
#
# main.asm + non-empty module files in src\
# Standalone files that end with an entry point are skipped.
# =============================================================

$mainSource = Get-Item -LiteralPath $mainSourcePath
$sourceFiles = @($mainSource)

$sourceInfos = @(
    Get-ChildItem `
        -LiteralPath $srcDir `
        -Filter "*.asm" `
        -File |
        Sort-Object Name |
        ForEach-Object {
            Get-AssemblySourceInfo -File $_
        }
)

$moduleSourceInfos = @()

foreach ($sourceInfo in $sourceInfos) {

    if ($sourceInfo.File.FullName -ieq $mainSource.FullName) {
        continue
    }

    if (-not $sourceInfo.HasCode) {
        continue
    }

    if ($sourceInfo.IsStandaloneProgram) {
        continue
    }

    $moduleSourceInfos += $sourceInfo
    $sourceFiles += $sourceInfo.File
}

$publicSymbols = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($sourceInfo in $moduleSourceInfos) {

    foreach ($symbol in $sourceInfo.PublicSymbols) {
        $null = $publicSymbols.Add($symbol)
    }
}

$featureEntryPoints = @(
    "OrderModule",
    "CartModule",
    "HistoryModule"
)

$missingFeatureEntryPoints = @(
    $featureEntryPoints |
        Where-Object {
            -not $publicSymbols.Contains($_)
        }
)

Remove-Item `
    -LiteralPath $stubSourcePath `
    -Force `
    -ErrorAction SilentlyContinue

if ($missingFeatureEntryPoints.Count -gt 0) {

    New-FeatureStubSource -EntryPoints $missingFeatureEntryPoints |
        Set-Content `
            -Path $stubSourcePath `
            -Encoding ASCII

    $sourceFiles += Get-Item -LiteralPath $stubSourcePath
}


# =============================================================
# FIND DOSBOX
# =============================================================

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

$programFilesX86 = `
    [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")

if ($programFilesX86) {

    $dosBoxCandidates += @(
        (Join-Path $programFilesX86 "DOSBox-X\dosbox-x.exe"),
        (Join-Path $programFilesX86 "DOSBox-0.74-3\DOSBox.exe")
    )
}

if ($env:ProgramData) {

    $dosBoxCandidates += (
        Join-Path `
            $env:ProgramData `
            "Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3"
    )
}

if ($env:APPDATA) {

    $dosBoxCandidates += (
        Join-Path `
            $env:APPDATA `
            "Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3"
    )
}

$dosBoxPath = $null

foreach ($candidate in $dosBoxCandidates) {

    $dosBoxPath = Resolve-DosBoxCandidate `
        -Candidate $candidate

    if ($dosBoxPath) {
        break
    }
}

if (-not $dosBoxPath) {

    throw @"
DOSBox or DOSBox-X was not found.

Install DOSBox or DOSBox-X and add it to PATH,
or run:

.\build.ps1 -DosBox "C:\path\to\dosbox.exe"
"@
}


# =============================================================
# PREPARE OUTPUT DIRECTORY
# =============================================================

New-Item `
    -ItemType Directory `
    -Force `
    -Path $outputDir |
    Out-Null


# =============================================================
# STAGE DOS-SAFE SOURCE NAMES
#
# MASM 5.10 runs as a DOS program and cannot reliably open long
# Windows filenames. Every source is copied to an 8.3-safe path.
# =============================================================

New-Item `
    -ItemType Directory `
    -Force `
    -Path $dosBuildDir |
    Out-Null

Get-ChildItem -LiteralPath $dosBuildDir -File |
    Remove-Item -Force

$buildItems = @()

for ($index = 0; $index -lt $sourceFiles.Count; $index++) {

    $sequence = "{0:0000}" -f ($index + 1)
    $sourceFile = $sourceFiles[$index]
    $stagedSourceName = "SRC$sequence.ASM"
    $stagedSourcePath = Join-Path $dosBuildDir $stagedSourceName
    $dosSourcePath = $stagedSourcePath.Substring(
        $projectRoot.Length
    ).TrimStart("\")
    $objectName = "OBJ$sequence.OBJ"

    Copy-Item `
        -LiteralPath $sourceFile.FullName `
        -Destination $stagedSourcePath `
        -Force

    $buildItems += [pscustomobject]@{
        SourceName = $sourceFile.Name
        DosSourcePath = $dosSourcePath
        ObjectName = $objectName
    }
}

$objectNames = @(
    $buildItems |
        ForEach-Object {
            $_.ObjectName
        }
)

$linkObjects = $objectNames -join "+"


# =============================================================
# CLEAN OLD BUILD FILES
# =============================================================

Remove-Item `
    -LiteralPath $dosOutput,
                   $logPath,
                   $okMarkerPath,
                   $failMarkerPath,
                   $legacyFailMarkerPath,
                   $stubSourcePath `
    -Force `
    -ErrorAction SilentlyContinue


foreach ($objectName in $objectNames) {
    $objectPath = Join-Path $projectRoot $objectName

    Remove-Item `
        -LiteralPath $objectPath `
        -Force `
        -ErrorAction SilentlyContinue
}


# =============================================================
# GENERATE BUILD.BAT
#
# IMPORTANT:
# MASM and LINK output is NOT interpreted.
# It is simply written to BUILD.LOG and displayed.
# =============================================================

$assemblyCommands = foreach ($buildItem in $buildItems) {

    $sourceName = $buildItem.SourceName
    $dosSourcePath = $buildItem.DosSourcePath
    $objectName = $buildItem.ObjectName

    @"
ECHO.
ECHO ========================================================
ECHO MASM: $sourceName
ECHO ========================================================
ECHO MASM: $sourceName >> BUILD.LOG
ECHO   $dosSourcePath,$objectName; >> BUILD.LOG
MASM $dosSourcePath,$objectName; >> BUILD.LOG
MASM $dosSourcePath,$objectName;
IF ERRORLEVEL 1 GOTO ASSEMBLY_FAILED
"@
}


# =============================================================
# ERROR BEHAVIOR
# =============================================================

if ($KeepOpenOnError) {

    $failureAction = @"
ECHO.
ECHO DOSBox is being kept open.
ECHO Type EXIT when finished.
PAUSE
GOTO KEEP_OPEN
"@

}
else {

    $failureAction = @"
ECHO.
ECHO Press any key to close DOSBox.
PAUSE
EXIT
"@
}


# =============================================================
# BUILD.BAT CONTENT
# =============================================================

$buildBatch = @"
@ECHO OFF
CLS

IF EXIST BUILD.LOG DEL BUILD.LOG
IF EXIST BUILD.OK DEL BUILD.OK
IF EXIST BUILD.FAI DEL BUILD.FAI

ECHO ========================================================
ECHO                 DELIGO BUILD SYSTEM
ECHO ========================================================
ECHO.
ECHO Project: $programName
ECHO.

ECHO ========================================================
ECHO                 ASSEMBLY
ECHO ========================================================
ECHO.

ECHO ======================================================== >> BUILD.LOG
ECHO DELIGO BUILD LOG >> BUILD.LOG
ECHO ======================================================== >> BUILD.LOG
ECHO. >> BUILD.LOG


$($assemblyCommands -join "`r`n")


ECHO.
ECHO ========================================================
ECHO                 LINKING
ECHO ========================================================
ECHO.

ECHO LINK: $linkObjects
ECHO LINK: $linkObjects >> BUILD.LOG
LINK $linkObjects,$programName.EXE; >> BUILD.LOG
LINK $linkObjects,$programName.EXE;

IF ERRORLEVEL 1 GOTO LINK_FAILED


ECHO.
ECHO ========================================================
ECHO                 BUILD SUCCESSFUL
ECHO ========================================================
ECHO.
ECHO Created: $programName.EXE
ECHO.

ECHO OK> BUILD.OK

EXIT


:ASSEMBLY_FAILED

ECHO.
ECHO ========================================================
ECHO                 MASM FAILED
ECHO ========================================================
ECHO.
ECHO The MASM output above is the actual error.
ECHO.
ECHO The complete MASM output is also in BUILD.LOG.
ECHO.

ECHO ASSEMBLY> BUILD.FAI

$failureAction


:LINK_FAILED

ECHO.
ECHO ========================================================
ECHO                 LINK FAILED
ECHO ========================================================
ECHO.
ECHO The LINK output above is the actual error.
ECHO.
ECHO The complete LINK output is also in BUILD.LOG.
ECHO.

ECHO LINK> BUILD.FAI

$failureAction


:KEEP_OPEN

ECHO.
ECHO DOSBox will remain open.
ECHO Type EXIT when finished.
ECHO.

"@


# =============================================================
# WRITE BUILD.BAT
# =============================================================

$buildBatch |
    Set-Content `
        -Path $batchPath `
        -Encoding ASCII


# =============================================================
# RUN BUILD INSIDE DOSBOX
# =============================================================

$dosBoxCommands = @(
    "mount c `"$projectRoot`"",
    "c:",
    "BUILD.BAT"
)

$dosBoxArgs = `
    New-DosBoxArgumentString `
        -Commands $dosBoxCommands

if (-not $KeepOpenOnError) {
    $dosBoxArgs = "$dosBoxArgs -c `"exit`""
}


$process = Start-Process `
    -FilePath $dosBoxPath `
    -ArgumentList $dosBoxArgs `
    -Wait `
    -PassThru


# =============================================================
# CHECK BUILD RESULT
# =============================================================

if (Test-Path -LiteralPath $failMarkerPath -PathType Leaf) {

    $failedStep = `
        (Get-Content `
            -LiteralPath $failMarkerPath `
            -Raw).Trim()

    $buildLog = ""

    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        $buildLog = `
            (Get-Content `
                -LiteralPath $logPath `
                -Raw).Trim()
    }

    Write-Host ""
    Write-Host "========================================================"
    Write-Host "                    BUILD FAILED"
    Write-Host "========================================================"
    Write-Host ""
    Write-Host "Failed step: $failedStep"
    Write-Host ""
    Write-Host "Actual MASM/LINK output:"
    Write-Host "--------------------------------------------------------"
    Write-Host $buildLog
    Write-Host "--------------------------------------------------------"
    Write-Host ""

    throw "Build failed during $failedStep."
}


if (
    -not (Test-Path -LiteralPath $okMarkerPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $dosOutput -PathType Leaf)
) {

    throw @"
Build failed.

No successful build marker or executable was created.

Check BUILD.LOG for the assembler/linker output.
"@
}


# =============================================================
# COPY OUTPUT
# =============================================================

if ($dosOutput -ne $outputPath) {

    Copy-Item `
        -Force `
        -Path $dosOutput `
        -Destination $outputPath
}

Get-ChildItem -LiteralPath $dosBuildDir -File |
    Remove-Item -Force

Remove-Item `
    -LiteralPath $stubSourcePath `
    -Force `
    -ErrorAction SilentlyContinue


Write-Host ""
Write-Host "========================================================"
Write-Host "                    BUILD SUCCESSFUL"
Write-Host "========================================================"
Write-Host ""
Write-Host "Built: $Output"
Write-Host ""


# =============================================================
# DO NOT RUN IF -NoRun WAS SPECIFIED
# =============================================================

if ($NoRun) {
    return
}


# =============================================================
# RUN PROGRAM
# =============================================================

$runDosBoxCommands = @(
    "mount c `"$outputDir`"",
    "c:",
    "`"$([System.IO.Path]::GetFileName($outputPath))`""
)

$runDosBoxArgs = `
    New-DosBoxArgumentString `
        -Commands $runDosBoxCommands

Start-Process `
    -FilePath $dosBoxPath `
    -ArgumentList $runDosBoxArgs |
    Out-Null
