# Native non-zero path tessellator

This GDExtension implements scanbeam `NON_ZERO` winding tessellation in C++
through the official `godot-cpp` bindings. It supports the self-intersecting
Processing-style path used by the snake.

## One-time requirements on Windows

- Visual Studio 2022 with **Desktop development with C++**
- Python 3
- SCons (`python -m pip install scons`)
- Git

The current development machine already has all four requirements.

## Build

From PowerShell in this directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The execution-policy argument only applies to this PowerShell process; it does
not change the machine's PowerShell policy. The first run clones the pinned
official `godot-cpp` release into this directory. That checkout is ignored by
Git.

The first build downloads the pinned `godot-cpp` dependency. Later builds use
the existing checkout. Build an optimized export library with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
    -Target template_release
```

The `.gdextension` resource loads the correct debug or release DLL from
`bin/`. Godot discovers `.gdextension` resources automatically when the
project opens; there is no plugin checkbox to enable.

## Use from GDScript

```gdscript
var tessellator = ClassDB.instantiate(&"NonZeroPathTessellatorNative")
var triangles: PackedVector2Array = tessellator.tessellate(path, 0.001)
```

The Snake uses this automatically when `Body Render Mode` is set to
`Processing Vector Fill`; Fish and Lizard use it for their curved bodies and
fins. If the native class is unavailable, Godot reports an error and skips
those fills instead of silently selecting another tessellator.

## Test

Run the native correctness tests from the project root with:

```powershell
& 'C:\Godot\4.7\engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
    --headless --path . `
    --script res://tests/non_zero_path_tessellator_native_test.gd
```

## What Godot needs at runtime

Godot discovers `non_zero_path_tessellator.gdextension` automatically. The
descriptor names the native class entry point and maps debug/release builds to
their DLLs. There is no editor plugin to enable and no autoload to add.

If the C++ source changes, rerun the appropriate build command and restart the
editor if Windows has the DLL locked. Scene and GDScript changes do not require
a native rebuild.
