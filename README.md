# asm_assignment

ASM food delivery assignment starter.

This project currently uses 16-bit DOS assembly with MASM syntax. The bundled
`MASM.EXE` and `LINK.EXE` are DOS programs, so they must be run through DOSBox
or DOSBox-X on modern 64-bit Windows.

## Requirements

- DOSBox-X or DOSBox installed
- `MASM.EXE` and `LINK.EXE` in the project root

## Build

```powershell
.\build.ps1
```

The script assembles `src\main.asm` and writes the DOS executable to:

```text
build\main.exe
```

If DOSBox is installed but not on `PATH`, pass its location:

```powershell
.\build.ps1 -DosBox "C:\Program Files\DOSBox-X\dosbox-x.exe"
```

## Run

Run the built program inside DOSBox:

```powershell
dosbox-x -c "mount c .\build" -c "c:" -c "main.exe"
```

Expected output:

```text
Hello, World!
```

## Source

The source is in `src\main.asm`.

## Manual MASM commands

If you are already inside DOSBox in the `SRC` folder, assemble the `.asm` file,
then link the `.obj` file:

```dos
..\MASM main.asm;
..\LINK main.obj;
main.exe
```

Do not run `MASM main.exe`. An `.exe` file is the finished program, not source
code, so MASM will report confusing errors like `Line too long` and will not
create `main.obj`.
