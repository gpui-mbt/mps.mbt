///|
/// Physical and numerical parameters of an MPS simulation.
///
/// Lengths are metres, times seconds, density kilograms per cubic metre. The
/// parameter set follows the MPS dam-break literature (Koshizuka & Oka 1996):
/// an interaction radius of 4 particle spacings, a `re/r - 1` kernel, and
/// initial density calibrated on the initial packing.
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
  /// Initial particle speed limit used by the CFL condition.
  cfl : Double
  /// Upper bound on the time step.
  dt_max : Double
  /// Lower bound on the time step; falling below it stops the simulation.
  dt_min : Double
  /// Maximum iterations of the pressure Poisson CG per step.
  cg_iterations : Int32
  /// Iteration cap of the incompressibility relaxation applied after the
  /// pressure correction (0 disables it).
  relaxation_iterations : Int32
  /// Relative CG residual that counts as converged.
  cg_tolerance : Double
  /// Maximum ICP iterations for the non-negative pressure constraint.
  icp_iterations : Int32
  /// Verlet-list padding in units of `spacing`.
  skin : Double
  /// Number of wall particle rings placed outside the domain.
  wall_layers : Int32
}

///|
/// Default parameters for a dam break with `l0 = 1e-2 m`.
pub fn Params::default() -> Params {
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
    relaxation_iterations: 0,
    cg_tolerance: 1.0e-6,
    icp_iterations: 3,
    skin: 0.3,
    wall_layers: 2,
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
