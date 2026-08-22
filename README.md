# asm_assignment

ASM food delivery assignment starter.

This project currently uses 16-bit DOS assembly with MASM syntax. The bundled
`MASM.EXE` and `LINK.EXE` are DOS programs, so they must be run through DOSBox
or DOSBox-X on modern 64-bit Windows.

## Requirements

- DOSBox-X or DOSBox installed
- `MASM.EXE` and `LINK.EXE` in the project root

## Build

The recommended Windows command is:

```powershell
.\build.cmd
```

You can also double-click `build.cmd` in File Explorer. It automatically uses
the standard DOSBox 0.74-3 Start Menu installation, builds `main.exe`, and runs
the program in DOSBox.

This launcher works when Windows PowerShell reports that running scripts is
disabled. Its execution-policy bypass applies only to the build process and
does not change the user or computer policy.

You can also run the PowerShell script directly on systems that allow scripts:

```powershell
.\build.ps1
```

The script assembles `src\main.asm`, automatically links module-style `.asm`
files from `src`, and writes the DOS executable to:

```text
main.exe
```

If DOSBox is installed but not on `PATH`, pass its location:

```powershell
.\build.cmd -DosBox "C:\Program Files\DOSBox-X\dosbox-x.exe"
```

The DOSBox Start Menu folder is also accepted:

```powershell
.\build.cmd -DosBox "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3"
```

## Run

Run the built program inside DOSBox:

```powershell
dosbox-x -c "mount c ." -c "c:" -c "main.exe"
```

Expected output:

```text
Press a key:
```

## Source

The executable starts at:

- `src\main.asm` - application menu and module dispatch

The build script automatically links non-empty module files in `src`. Files that
end with an entry point such as `END MAIN` are treated as standalone programs
and are deliberately not linked into `main.exe`; `src\report.asm` is one of
those standalone programs.

Discovered sources are staged under `build\dos` with short DOS-safe filenames
before MASM runs, so module filenames do not need to follow 8.3 naming.

To replace a built-in fallback screen, add a module that exports the matching
entry point with `PUBLIC`:

```asm
PUBLIC OrderModule
```

The recognized feature entry points are `OrderModule`, `CartModule`, and
`HistoryModule`. If one of those is missing, the build creates a tiny temporary
stub so the app still links while the module is unfinished.

## Manual MASM commands

If you are already inside DOSBox at the project root, assemble the `.asm` file,
then link the `.obj` file:

```dos
MASM src\main.asm,main.obj;
LINK main.obj;
main.exe
```

Do not run `MASM main.exe`. An `.exe` file is the finished program, not source
code, so MASM will report confusing errors like `Line too long` and will not
create `main.obj`.
