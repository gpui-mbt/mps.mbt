///|
/// Outcome of advancing the simulation by one step.
pub(all) enum StepStatus {
  /// The step completed; the next step may proceed.
  Ok
  /// The CFL condition demanded a time step below `dt_min`.
  TimestepTooSmall
  /// A non-finite coordinate or velocity appeared.
  Diverged
}

///|
/// Result of one [`Simulation::step`] call.
pub(all) struct StepResult {
  status : StepStatus
  /// Time step actually used, in seconds.
  dt : Double
  /// Largest CG iteration count over the pressure solves of this step.
  cg_iterations : Int32
}

///|
/// A dam-break simulation: scene, parameters, neighbour cache and the scratch
/// buffers of the pressure solve.
pub(all) struct Simulation {
  params : Params
  domain : Domain
  scene : Scene
  list : @core.NeighborList
  /// Scratch: number density of the predicted configuration `n*`.
  density_scratch : Array[Double]
  /// Scratch: solution of the pressure Poisson equation.
  pressure_next : Array[Double]
  /// Scratch: predicted velocities.
  vx_star : Array[Double]
  vy_star : Array[Double]
  /// Scratch: the previous pressure, the `p_hat` of the gradient.
  pressure_hat : Array[Double]
  /// Scratch: the constant part p0_i implied by the density constraint.
  pressure_old : Array[Double]
  /// Scratch: relaxed positions.
  relaxed_x : Array[Double]
  relaxed_y : Array[Double]
}

///|
/// Builds a simulation for the dam-break scene inside `domain`.
pub fn Simulation::new(
  params : Params,
  domain : Domain,
  water_w : Double,
  water_h : Double,
) -> Simulation {
  let scene = Scene::build(params, domain, water_w, water_h)
  let n = scene.state.x.length()
  let list = @core.NeighborList::build(
    positions_of(scene.state),
    params.radius,
    params.skin * params.spacing,
  )
  let sim = Simulation::{
    params,
    domain,
    scene,
    list,
    density_scratch: Array::make(n, 0.0),
    pressure_next: Array::make(n, 0.0),
    vx_star: Array::make(n, 0.0),
    vy_star: Array::make(n, 0.0),
    pressure_hat: Array::make(n, 0.0),
    pressure_old: Array::make(n, 0.0),
    relaxed_x: Array::make(n, 0.0),
    relaxed_y: Array::make(n, 0.0),
  }
  // The initial density is exact by construction: it was measured on this
  // configuration.
  let n0 = scene.n0
  for i = 0; i < n; i = i + 1 {
    scene.state.n_density[i] = n0
  }
  sim
}

///|
/// Particle positions as vectors, for the spatial index.
pub fn positions_of(state : State) -> Array[@core.Vec2] {
  let out : Array[@core.Vec2] = []
  for i = 0; i < state.x.length(); i = i + 1 {
    out.push(@core.Vec2::new(state.x[i], state.y[i]))
  }
  out
}

///|
/// Largest component-wise displacement of a fluid particle beyond the wall
/// surface, in metres; zero when every fluid particle is inside the domain.
pub fn overflow(state : State, domain : Domain, spacing : Double) -> Double {
  let margin = spacing
  let mut worst = 0.0
  for i = 0; i < state.x.length(); i = i + 1 {
    if state.kind[i] is Fluid {
      let dx = (domain.min_x + margin - state.x[i]).max(
        state.x[i] - (domain.max_x - margin),
      )
      let dy = (domain.min_y + margin - state.y[i]).max(
        state.y[i] - (domain.max_y - margin),
      )
      worst = worst.max(dx).max(dy)
    }
  }
  worst
}

///|
/// Time step for the next step from the CFL condition, clamped to
/// `[dt_min, dt_max]`.
fn cfl_dt(params : Params, max_speed : Double) -> Double {
  // The free-fall increment keeps the bound finite while the fluid is at rest
  // and tight enough that a released column resolves its acceleration.
  let v = max_speed + params.gravity * params.dt_max
  let dt = params.cfl * params.spacing / v
  dt.max(params.dt_min).min(params.dt_max)
}

///|
/// Advances the simulation by one step.
///
/// 1. Refresh the neighbour cache.
/// 2. Viscosity on the current velocity (explicit).
/// 3. Gravity.
/// 4. Advect to the predicted positions, keeping the predicted velocities.
/// 5. Number density `n*` of the predicted configuration.
/// 6. Solve the pressure Poisson equation (ICP, non-negative pressure).
/// 7. Velocity and position correction from the pressure gradient.
///
/// Fluid particles are re-clamped to the domain at the end of the step; the
/// clamp is reported by [`overflow`] so the caller can see when it engages.
pub fn Simulation::step(self : Simulation) -> StepResult {
  let params = self.params
  let state = self.scene.state
  let n = state.x.length()
  let predicted_positions = positions_of(state)
  let list = @core.NeighborList::build(
    predicted_positions,
    params.radius,
    params.skin * params.spacing,
  )
  let mut max_speed = 0.0
  for i = 0; i < n; i = i + 1 {
    max_speed = max_speed.max(state.vx[i].abs().max(state.vy[i].abs()))
  }
  let dt = cfl_dt(params, max_speed)
  if dt <= params.dt_min && max_speed > 0.0 {
    return { status: StepStatus::TimestepTooSmall, dt, cg_iterations: 0, }
  }
  apply_viscosity(state, list, params, dt, self.vx_star, self.vy_star)
  for i = 0; i < n; i = i + 1 {
    self.vy_star[i] = self.vy_star[i] - params.gravity * dt
    state.x[i] = state.x[i] + self.vx_star[i] * dt
    state.y[i] = state.y[i] + self.vy_star[i] * dt
  }
  // Every interaction model of this step reads the same predicted-velocity
  // neighbourhood; `list` is rebuilt from scratch, so the step is a pure
  // function of the state and the result is identical on every backend.
  update_density(state, list, params.re2(), self.density_scratch)
  for i = 0; i < n; i = i + 1 {
    self.pressure_hat[i] = state.pressure[i]
  }
  let solve = self.solve_pressure(dt, list)
  self.apply_pressure_gradient(dt, list)
  for k = 0; k < params.relaxation_iterations; k = k + 1 {
    update_density(state, list, params.re2(), self.density_scratch)
    relax_density(
      state,
      list,
      params,
      self.scene.n0,
      self.density_scratch,
      self.relaxed_x,
      self.relaxed_y,
    )
    for i = 0; i < n; i = i + 1 {
      if state.kind[i] is Fluid {
        state.x[i] = self.relaxed_x[i]
        state.y[i] = self.relaxed_y[i]
      }
    }
  }
  clamp_to_domain(state, self.domain, params.spacing)
  state.time = state.time + dt
  state.step = state.step + 1
  if has_non_finite(state) {
    return {
      status: StepStatus::Diverged,
      dt,
      cg_iterations: solve.cg_iterations,
    }
  }
  { status: StepStatus::Ok, dt, cg_iterations: solve.cg_iterations, }
}

///|
/// Keeps fluid particles inside the wall surface.
pub fn clamp_to_domain(
  state : State,
  domain : Domain,
  spacing : Double,
) -> Unit {
  let lo_x = domain.min_x + spacing * 0.5
  let hi_x = domain.max_x - spacing * 0.5
  let lo_y = domain.min_y + spacing * 0.5
  let hi_y = domain.max_y - spacing * 0.5
  for i = 0; i < state.x.length(); i = i + 1 {
    if state.kind[i] is Fluid {
      if state.x[i] < lo_x {
        state.x[i] = lo_x
      } else if state.x[i] > hi_x {
        state.x[i] = hi_x
      }
      if state.y[i] < lo_y {
        state.y[i] = lo_y
      } else if state.y[i] > hi_y {
        state.y[i] = hi_y
      }
    }
  }
}

///|
fn has_non_finite(state : State) -> Bool {
  for i = 0; i < state.x.length(); i = i + 1 {
    if !finite(state.x[i]) || !finite(state.y[i]) {
      return true
    }
  }
  false
}
