# CYBERNOVA

**CYBERNOVA** is a Godot 4.7 game demo: a bilingual cinematic introduction followed by a three-lap neon-city race. This repository is a self-contained slice of the current v1.06 build.

## Playable content

- English and Spanish language selection.
- A cinematic introduction with character art and a looping J-POP track (artist and title on screen).
- A 3D city circuit with a sports car, four AI rivals, a minimap, and a randomly selected J-Rock track.

## Requirements

- [Godot 4.7](https://godotengine.org/) (this project was last checked with 4.7.2)
- Linux, macOS, or Windows

The `godot` executable must be on your `PATH`, at `~/.local/bin/godot`, or pointed to by the `GODOT` environment variable.

## Run

From this directory:

```bash
chmod +x run.sh introduction_v1.06/run.sh level1_v1.06/run.sh
./run.sh
```

After a fresh clone, import the project once so Godot can build its local cache:

```bash
godot --headless --editor --path . --quit
```

To start the introduction or the race directly:

```bash
./introduction_v1.06/run.sh
./level1_v1.06/run.sh
```

Race controls: Up/W accelerate, Down/S brake and reverse, Left/Right or A/D steer, Space handbrake/drift, R restart, Esc quit.

## Layout

- `introduction_v1.06/` — language select and cinematic intro (`intro.gd`, `intro.tscn`)
- `level1_v1.06/` — city circuit, car physics, 3D models, and race audio (`circuit.gd`, `car.gd`)
- `scripts/locale.gd` — English/Spanish strings (Godot autoload `Locale`)
- `assets/` — UI fonts

This folder does not depend on any other local copy of the project.

## License

Code and original documentation are under the MIT License. See `LICENSE`.

Third-party items keep their own terms:

- Press Start 2P: SIL Open Font License (`assets/PressStart2P-OFL.txt`)
- Droid Sans Fallback: Apache License 2.0
- Sports-car, building, and streetlight meshes: Quaternius, CC0
- Bundled music tracks remain under their original artist licenses
