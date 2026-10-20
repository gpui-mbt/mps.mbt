///|
/// One snapshot of the simulation as seen by a host.
///
/// The frame is a plain value: the native terminal renderer and the browser
/// renderer both build it from the same simulation state, and the headless
/// snapshot writes it as one line of text. Nothing in this package reads files,
/// clocks or the environment.
pub(all) struct Frame {
  /// Simulated time in seconds.
  time : Double
  /// Completed step count.
  step : Int32
  /// Simulation width and height in metres.
  width : Double
  height : Double
  /// Fluid particle positions in metres, `(x, y)` pairs.
  fluid_x : Array[Double]
  fluid_y : Array[Double]
  /// Largest pressure over the fluid particles, in pascals.
  max_pressure : Double
  /// Largest speed over the fluid particles, in metres per second.
  max_speed : Double
  /// Status word: `ok`, `stalled`, `diverged` or `finished`.
  status : String
  /// Number of wall particles, which the renderer draws as the tank floor.
  wall_count : Int32
}

///|
/// Builds a frame from the current state of `sim`.
pub fn frame_of(sim : @mps.Simulation, status : String) -> Frame {
  let state = sim.scene.state
  let fluid_x : Array[Double] = []
  let fluid_y : Array[Double] = []
  let mut max_pressure = 0.0
  let mut max_speed = 0.0
  for i = 0; i < state.x.length(); i = i + 1 {
    if state.kind[i] is @mps.ParticleKind::Fluid {
      fluid_x.push(state.x[i])
      fluid_y.push(state.y[i])
      max_pressure = max_pressure.max(state.pressure[i])
      max_speed = max_speed.max(
        (state.vx[i] * state.vx[i] + state.vy[i] * state.vy[i]).sqrt(),
      )
    }
  }
  {
    time: state.time,
    step: state.step,
    width: sim.domain.max_x - sim.domain.min_x,
    height: sim.domain.max_y - sim.domain.min_y,
    fluid_x,
    fluid_y,
    max_pressure,
    max_speed,
    status,
    wall_count: state.x.length() - fluid_x.length(),
  }
}
