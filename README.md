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

The script assembles `src\main.asm` and writes the DOS executable to:

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

The executable is assembled from these modules:

- `src\main.asm` — application menu and module dispatch
- `src\login.asm` — login, registration, credential validation, and logout
- `src\tools.asm` — shared display and exit routines

`src\report.asm` is a separate standalone program and is deliberately not
linked into `main.exe`.

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
