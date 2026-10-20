///|
/// What the integration of one step should model.
pub(all) enum Mode {
  /// Full MPS semi-implicit step: viscosity, gravity, pressure Poisson solve,
  /// gradient correction and the density relaxation safety net.
  Mps
  /// Gravity, advection and wall clamping only, without the pressure solve.
  ///
  /// This is the deterministic free-fall demo mode the native and browser
  /// hosts use while the pressure model is still under development; the motion
  /// it produces is what the renderers are checked against.
  Kinematic
}

///|
/// Physical and numerical parameters of the simulation.
///
/// Lengths are metres, times seconds, density kilograms per cubic metre. The MPS
/// parameter set follows the dam-break literature (Koshizuka & Oka 1996): an
/// interaction radius of four particle spacings and the `re/r - 1` kernel.
pub(all) struct Params {
  /// Particle spacing `l0`.
  spacing : Double
  /// Interaction radius `re`; must be a multiple of `spacing`.
  radius : Double
  /// Reference density `rho0`.
  density : Double
  /// Kinematic viscosity `nu`.
  viscosity : Double
  /// Gravitational acceleration magnitude.
  gravity : Double
  /// Courant number for the time step.
  cfl : Double
  /// Upper bound on the time step.
  dt_max : Double
  /// Lower bound on the time step; falling below it stops the simulation.
  dt_min : Double
  /// Maximum iterations of the pressure Poisson CG per step.
  cg_iterations : Int32
  /// Relative CG residual that counts as converged.
  cg_tolerance : Double
  /// Maximum ICP iterations for the non-negative pressure constraint.
  icp_iterations : Int32
  /// Verlet-list padding in units of `spacing`.
  skin : Double
  /// Number of wall particle rings placed outside the domain.
  wall_layers : Int32
  /// Step model.
  mode : Mode
}

///|
/// Default parameters for a dam break with `l0 = 1e-2 m` in kinematic mode.
pub fn Params::default() -> Params {
  Params::kinematic()
}

///|
/// Parameters for the deterministic kinematic demo.
pub fn Params::kinematic() -> Params {
  {
    spacing: 0.01,
    radius: 0.04,
    density: 1000.0,
    viscosity: 0.000001,
    gravity: 9.8,
    cfl: 0.2,
    dt_max: 0.002,
    dt_min: 0.00001,
    cg_iterations: 200,
    cg_tolerance: 1.0e-6,
    icp_iterations: 3,
    skin: 0.3,
    wall_layers: 2,
    mode: Mode::Kinematic,
  }
}

///|
/// Parameters for the full MPS step; the pressure model is still experimental,
/// see `docs/physics-status.md`.
pub fn Params::mps() -> Params {
  let base = Params::kinematic()
  {
    spacing: base.spacing,
    radius: base.radius,
    density: base.density,
    viscosity: base.viscosity,
    gravity: base.gravity,
    cfl: base.cfl,
    dt_max: base.dt_max,
    dt_min: base.dt_min,
    cg_iterations: base.cg_iterations,
    cg_tolerance: base.cg_tolerance,
    icp_iterations: base.icp_iterations,
    skin: base.skin,
    wall_layers: base.wall_layers,
    mode: Mode::Mps,
  }
}

///|
/// Interaction radius including the Verlet padding.
pub fn Params::padded_radius(self : Params) -> Double {
  self.radius + self.skin * self.spacing
}

///|
pub fn Params::re2(self : Params) -> Double {
  self.radius * self.radius
}
