# Procedural Animation

Procedural, chain-driven character animation in Godot 4.7. The project
includes an interactive chain, snake, fish, lizard, and anchored flower that
follow the pointer using distance, angle, and FABRIK constraints.

This is a Godot adaptation and extension of Argonaut's Processing 4
procedural-animation project. See [Credits](#credits) for the original source
and accompanying tutorial.

## Highlights

- Shared `ChainBody` foundation for the snake, fish, lizard, and flower.
- Runtime body switching, tail anchoring, pausing, and fullscreen controls.
- Configurable soft and hard chain boundaries with sliding and squishiness.
- Native non-zero winding tessellation for curved, self-overlapping bodies.
- Native adaptive cubic-stroke tessellation for smooth lizard limbs.
- Pause-menu tools for chain and UI-layout debugging.
- Hardware cursor support with optional runtime cursor swapping.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel down/up | Select the next/previous body |
| Left click | Cycle bodies or pause, as selected in **Debug Options** |
| Right click | Anchor the active body's tail or pause, as selected in **Debug Options** |
| Escape, Space, Enter, or keypad Enter | Pause/unpause |
| F | Enter/exit fullscreen |
| R | Restart the current scene |
| Pause icon | Pause/unpause |
| Body name | Open the body-selection menu |

The click behaviors can be changed while paused. Their active mouse bindings
are reflected automatically in the pause-button tooltip.

## Getting started

1. Clone the repository.
2. Open `project.godot` with Godot 4.7 or newer.
3. Run the main scene.

Prebuilt debug and release GDExtension libraries are included for Windows
x86-64. The native extension is required by the curved Snake, Fish, and Lizard
renderers.

### Rebuilding the native extension on Windows

Requirements:

- Visual Studio 2022 with **Desktop development with C++**
- Python 3
- SCons (`python -m pip install scons`)
- Git

From `native/non_zero_tessellator`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

For an optimized export library:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
	-Target template_release
```

The first build downloads the pinned `godot-cpp` dependency. See
[`native/non_zero_tessellator/README.md`](native/non_zero_tessellator/README.md)
for implementation and troubleshooting details.

## Tests

Run a test from the project root with a Godot console executable:

```powershell
godot --headless --path . --script res://tests/main_input_test.gd
godot --headless --path . --script res://tests/body_initialization_test.gd
godot --headless --path . --script res://tests/non_zero_path_tessellator_native_test.gd
godot --headless --path . --script res://tests/cubic_stroke_tessellator_native_test.gd
```

Replace `godot` with the path to your Godot console executable when it is not
available on `PATH`.

## Credits

The original concept, Processing implementation, animal designs, and
explanation are by **Argonaut**:

- [Procedural Animal Animation tutorial](https://www.youtube.com/watch?v=qlfh_rv6khY)
- [`argonautcode/animal-proc-anim`](https://github.com/argonautcode/animal-proc-anim)

This Godot port was developed with AI assistance:

- [OpenAI Codex](https://openai.com/codex/) assisted with translation,
  implementation, testing, and documentation.
- [`hi-godot/godot-ai`](https://github.com/hi-godot/godot-ai) provided the
  Godot editor and Model Context Protocol integration used during development.

## License

This project is available under the [MIT License](LICENSE). The license retains
the original Argonaut copyright notice alongside the notice for this Godot
adaptation.
