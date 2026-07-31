# Native non-zero path tessellator

This GDExtension implements the same scanbeam `NON_ZERO` winding tessellation
as `scripts/non_zero_path_tessellator_2d.gd`, in C++ through the official
`godot-cpp` bindings.

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

The Snake does this automatically in its native render mode and falls back to
the GDScript implementation if the native class is unavailable.

## Compare the two backends

On a `Snake` node, select either of these `Body Render Mode` values:

- `Processing Vector Fill` uses the pure GDScript backup.
- `Processing Vector Fill Native` uses this GDExtension, with automatic
  fallback if its DLL is missing.

The main scene currently selects the native mode. Both modes build the same
Processing-style outline, apply the same `NON_ZERO` fill rule, and feed the
same explicit triangle format to `RenderingServer`, so they are suitable for
an apples-to-apples profiler comparison.

Run the standalone comparison from the project root with:

```powershell
& 'C:\Godot\4.7\engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
    --headless --path . `
    --script res://tests/non_zero_path_tessellator_benchmark.gd
```

The initial debug-editor measurement on the development machine, using the
included 192-point crossing contour for 30 runs, was approximately 4,257
microseconds per call in GDScript and 52 microseconds per call in the native
extension (about 82x faster). Treat that as a baseline, not a universal result;
the included benchmark is the source of truth for each machine and build.

The parity test can be rerun by replacing the script path above with:

```text
res://tests/non_zero_path_tessellator_native_test.gd
```

For production measurements, compare an exported release build as well as the
editor. Godot loads `template_debug` in the editor and `template_release` for
a release export.

## What Godot needs at runtime

Godot discovers `non_zero_path_tessellator.gdextension` automatically. The
descriptor names the native class entry point and maps debug/release builds to
their DLLs. There is no editor plugin to enable and no autoload to add.

If the C++ source changes, rerun the appropriate build command and restart the
editor if Windows has the DLL locked. If only GDScript changes, no native
rebuild is needed.
