# Swoop

A polygonal 3D momentum-flight game, 100% self-contained in one HTML file — no
dependencies, no build step. You are a gannet with a camera on its tail: the
bird flies forward on its own, Flappy-Bird style, but the trick to distance is
Ecco-the-Dolphin physics — flap for height, dive to trade it for speed, pierce
the sea, swoop through the water and launch back out faster, over and over.

## Play

Open `index.html` in any browser (desktop or mobile). Everything —
custom 3D engine, physics, world, audio synth — is inline.

## Controls

| Input | Action |
| --- | --- |
| Hold (tap / click / Space / ↑) | Flap and climb; underwater: kick and pull up |
| Release | Nose down and dive |
| M | Mute |
| R | Restart |

Skim the surface at a shallow angle to stone-skip. Fly through gold rings,
eat fish underwater for a burst of speed, and the sky cycles day → sunset →
night → dawn every 2 600 m. Best distance is saved locally.

## Tech notes

- Custom perspective projection + painter-sorted flat-shaded triangles on a
  2D `<canvas>` — the whole world (faceted sea, islands, clouds, seabed,
  the bird) is polygons.
- Physics is a velocity-vector model: gravity in air, buoyancy + kick + drag
  underwater; holding rotates the velocity vector upward (preserving speed),
  which is what makes the water-swoop slingshot work.
- The world is deterministic — islands, rings, fish schools and clouds are pure
  functions of position slots, so it is endless with no spawner state.
- Sound is synthesized with WebAudio (wind, splashes, chimes) — no assets.
