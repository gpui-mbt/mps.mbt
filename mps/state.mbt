///|
/// Particle role in the dam-break scene.
pub(all) enum ParticleKind {
  /// Incompressible fluid.
  Fluid
  /// Wall particle: fixed, but contributes to the fluid number density.
  Wall
  /// Wall particle that also receives a pressure from the fluid.
  DummyWall
}

///|
/// Simulation state in structure-of-arrays layout.
///
/// Positions are always indexed identically across all arrays, so the spatial
/// index and neighbour lists built for `x`/`y` stay valid for every stage that
/// only reads velocity or pressure.
pub(all) struct State {
  x : Array[Double]
  y : Array[Double]
  vx : Array[Double]
  vy : Array[Double]
  pressure : Array[Double]
  n_density : Array[Double]
  kind : Array[ParticleKind]
  /// Simulated time in seconds.
  mut time : Double
  /// Number of completed steps.
  mut step : Int32
}
