# Fireworks

A lightweight SwiftUI demo that renders colorful, animated fireworks using `Canvas`, `TimelineView`, and a compact particle system. Tap the Start/Stop button to launch rockets that burst into glowing particles with additive blending.

> Built with SwiftUI. Tested with Xcode 26 on iOS Simulator. Uses only standard Apple frameworks — no third‑party dependencies.


## How it works

- Frame-driven updates: A `TimelineView(.animation)` ticks the simulation at the display’s refresh rate. Each tick advances the physics using the elapsed time since the last frame.
- Compact particle system: The simulation tracks a small set of value types (rockets and particles) in arrays for efficiency. No per-particle views are created — everything is drawn in one `Canvas` pass.
- Launching rockets: When you tap Start, a timer periodically adds new rockets with randomized launch angles, speeds, and fuse times. Each rocket ascends under gravity and air drag until it bursts.
- Bursting into particles: On burst, dozens to hundreds of particles are emitted in a radial pattern with varied speeds, hues, lifetimes, and sizes. Particles fade out over time while gravity pulls them downward and drag slows them.
- Rendering & blending: The `Canvas` draws soft circles (or radial gradients) for each particle. Additive blending (e.g., `.blendMode(.plusLighter)`) makes overlapping particles bloom into bright colors.
- Controls: The Start/Stop toggle switches the emission timer on and off and can clear existing particles to reset the scene.

### Customization knobs (not yet implemented)
- Colors: Choose from a palette or generate hues procedurally per burst.
- Emission: Particle count per burst, initial speed range, spread, and burst shape (spherical, ring, or directional).
- Physics: Gravity strength, drag coefficient, and particle lifetime/fade curves.
- Visuals: Particle size range, glow/blur radius, and stroke vs. fill styles.

### Performance notes
- Keep the total live particle count bounded (e.g., cap per-burst count and prune fully faded particles).
- Batch all drawing inside a single `Canvas` with additive blending instead of layering many separate views.
- Prefer value semantics for particle data and avoid unnecessary allocations each frame.
- Consider using `.drawingGroup()` on the container view if you want GPU-accelerated compositing.
