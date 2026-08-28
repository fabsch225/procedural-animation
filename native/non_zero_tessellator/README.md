# Native Processing-style geometry helpers

This GDExtension implements scanbeam `NON_ZERO` winding tessellation and
adaptive cubic-curve stroke tessellation in C++ through the official
`godot-cpp` bindings. It supports the self-intersecting Processing-style body
paths and the lizard's round-capped cubic limbs.

## One-time requirements on macOS

- Xcode Command Line Tools
- Python 3
- SCons (`python -m pip install scons`)
- Git

The build script uses the macOS `arm64` target by default. Pass `-Arch x86_64`
when building on an Intel Mac.

## Build

From PowerShell (`pwsh`) in this directory:

```powershell
pwsh -NoProfile -File ./build.ps1
```

The first run clones the pinned
official `godot-cpp` release into this directory. That checkout is ignored by
Git.

The first build downloads the pinned `godot-cpp` dependency. Later builds use
the existing checkout. Build an optimized export library with:

```powershell
pwsh -NoProfile -File ./build.ps1 `
	-Target template_release
```

To build the Windows library from PowerShell, pass
`-Platform windows -Arch x86_64`.

The `.gdextension` resource loads the correct debug or release DLL from
`bin/`. Godot discovers `.gdextension` resources automatically when the
project opens; there is no plugin checkbox to enable.

## Build for Web

The Web build uses the Emscripten version from Godot 4.7.1's official build
configuration (`4.0.11`) and produces a non-threaded `wasm32` side module to
match this project's Web export preset:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build_web.ps1
```

On its first run, the script installs the pinned Emscripten SDK under
`%LOCALAPPDATA%\Godot\emsdk`. Set `EMSDK`, or pass `-EmsdkPath`, to use an
existing SDK checkout instead. Build a debug side module with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build_web.ps1 `
	-Target template_debug
```

Web exports must have **Extensions Support** enabled and use Godot's matching
dynamic-link export template. Both are configured on the project's `Web`
export preset. The `.gdextension` resource maps Web debug and release exports
to their corresponding `.nothreads.wasm` side modules.

## Use from GDScript

```gdscript
var tessellator = ClassDB.instantiate(&"NonZeroPathTessellatorNative")
var triangles: PackedVector2Array = tessellator.tessellate(path, 0.001)

var stroker = ClassDB.instantiate(&"CubicStrokeTessellatorNative")
var stroke_triangles: PackedVector2Array = stroker.tessellate(
	start, control_1, control_2, end, width, 0.2, 12, 0
)
```

Snake, Fish, and Lizard use the non-zero tessellator for their curved bodies
and fins. Lizard limbs use the cubic stroker. If either native class is
unavailable, Godot reports an error instead of silently selecting a different
renderer.

## Test

Run the native correctness tests from the project root with:

```powershell
& 'C:\Godot\4.7\engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
	--headless --path . `
	--script res://tests/non_zero_path_tessellator_native_test.gd

& 'C:\Godot\4.7\engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
	--headless --path . `
	--script res://tests/cubic_stroke_tessellator_native_test.gd
```

## What Godot needs at runtime

Godot discovers `non_zero_path_tessellator.gdextension` automatically. The
descriptor names the native class entry point and maps debug/release builds to
their Windows DLLs and WebAssembly side modules. There is no editor plugin to
enable and no autoload to add.

If the C++ source changes, rerun the appropriate build command and restart the
editor if Windows has the DLL locked. Scene and GDScript changes do not require
a native rebuild.
