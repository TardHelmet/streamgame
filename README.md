# Starflappy 64

A polygonal 3D retro arcade flyer, 100% self-contained in one HTML file — no
dependencies, no build step. Star Fox corridor flying meets Flappy Bird
forward motion meets Ecco the Dolphin momentum: you are a gannet chased by
the camera, flapping for height, diving into the sea, and swooping back out
faster — while steering through ring series and dodging crossing boat
traffic.

## Play

Open `index.html` in any browser (desktop or mobile). Everything —
custom 3D engine, physics, world, audio synth — is inline.

## Controls

One button, anywhere — touch, click, or Space:

| Input | Action |
| --- | --- |
| Hold | Dive. In the air you fold and plunge; underwater you dig deeper |
| Release | Rise. The bird flies itself back up; underwater it kicks and swoops out |
| M | Mute |
| R | Restart |

There is no steering — the whole game is vertical timing. The green
reticle streams ahead of the bird showing where holding or releasing is
taking you, so you can plan entries, ring threads, and boat dodges.

## The rules of the sky

- A green Star Fox-style reticle streams ahead of your beak so you can line
  up in 3D.
- **Rings score 100 each.** They come in series of 3–10, their colour
  burning hotter toward the last ring. Clear a whole series and you do a
  **barrel roll**: a waterspout erupts around you, every fish nearby is
  sucked into it, and you auto-collect any ring you pass while it rages.
- **Fish grant speed boost** that stacks — and lasts until you slam the
  seabed, which knocks it off in proportion to how hard you hit.
- Each run starts at **night** (~1 min); the sun rises ahead over ~30 s,
  day lasts ~2 min, then ~30 s of twilight as the sun sets *behind* you —
  you always fly into the dawn.
- **When dawn breaks, the boats come out**: fast jet skis that barely dent
  the water, fishing boats with nets cast visibly beneath them, and
  container ships that wall off the sky. They cross your path from either
  side, timed to meet you — fly over, dive under, or die. **Hitting any of
  them ends the game.**

Best score is saved locally.

## Tech notes

- Custom perspective projection + painter-sorted flat-shaded triangles on a
  2D `<canvas>` — the whole world (faceted sea, islands, clouds, seabed,
  boats, the bird) is polygons.
- Physics is a velocity-vector model: gravity in air, buoyancy + kick + drag
  underwater; holding rotates the velocity vector upward (preserving speed),
  which is what makes the water-swoop slingshot work. Lateral steering is a
  bounded strafe: the camera never moves sideways, Star Fox corridor style.
- The world is deterministic — islands, ring series, fish schools and clouds
  are pure functions of position slots; boats are dynamic crossers timed
  against your ETA so you can read the traffic before it arrives.
- Sound is synthesized with WebAudio (wind, splashes, chimes, fog horns) —
  no assets.
