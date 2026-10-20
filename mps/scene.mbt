///|
/// Rectangular simulation domain with solid walls on all four sides.
pub(all) struct Domain {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
/// Particles created by [`Scene::build`], plus the initial reference density.
pub(all) struct Scene {
  state : State
  n0 : Double
  fluid : Int32
  wall : Int32
}

///|
/// Builds the classic dam-break scene inside `domain`.
///
/// A still body of water of `water_w` × `water_h` metres occupies the lower
/// left corner and is released at `t = 0`. Walls are filled with `layers` rows
/// of particles outside the domain on every side; the ones in the two outer
/// layers stay `DummyWall` so they receive pressure but never move.
///
/// Positions are deterministic: no random jitter is applied, so the native and
/// `wasm-gc` builds produce identical trajectories.
pub fn Scene::build(
  params : Params,
  domain : Domain,
  water_w : Double,
  water_h : Double,
) -> Scene {
  let h = params.spacing
  let state = State::{
    x: [],
    y: [],
    vx: [],
    vy: [],
    pressure: [],
    n_density: [],
    kind: [],
    time: 0.0,
    step: 0,
  }
  // Fluid block: rows from the bottom wall upwards.
  let nx = fluid_count(water_w, h)
  let ny = fluid_count(water_h, h)
  for j = 0; j < ny; j = j + 1 {
    for i = 0; i < nx; i = i + 1 {
      state.push(cell_centre(i, h), cell_centre(j, h), ParticleKind::Fluid)
    }
  }
  let fluid = state.x.length()
  // Wall particles: one ring outside the fluid domain, `layers` deep.
  let cols = fluid_count(domain.max_x - domain.min_x, h)
  let rows = fluid_count(domain.max_y - domain.min_y, h)
  for layer = 1; layer <= params.wall_layers; layer = layer + 1 {
    let d = layer.to_double() * h
    let kind = if layer == 1 {
      ParticleKind::Wall
    } else {
      ParticleKind::DummyWall
    }
    for i = 0; i < cols; i = i + 1 {
      let x = cell_centre(i, h)
      state.push(x, -d, kind)
      state.push(x, domain.max_y + d - h, kind)
    }
    for j = 0; j < rows; j = j + 1 {
      let y = cell_centre(j, h)
      state.push(-d, y, kind)
      state.push(domain.max_x + d - h, y, kind)
    }
  }
  let wall = state.x.length() - fluid
  let n0 = initial_density(state, params)
  if n0 <= 0.0 || n0.is_nan() {
    abort(
      "mps: reference density must be positive, got " + @core.fmt_fixed(n0, 6),
    )
  }
  { state, n0, fluid, wall, }
}

///|
/// Number of particle columns that fit in `length`.
fn fluid_count(length : Double, spacing : Double) -> Int32 {
  let n = (length / spacing).floor().to_int()
  if n < 1 {
    1
  } else {
    n
  }
}

///|
/// Centre of particle `i` on its axis.
fn cell_centre(i : Int32, spacing : Double) -> Double {
  (i.to_double() + 0.5) * spacing
}

///|
fn State::push(
  self : State,
  x : Double,
  y : Double,
  kind : ParticleKind,
) -> Unit {
  self.x.push(x)
  self.y.push(y)
  self.vx.push(0.0)
  self.vy.push(0.0)
  self.pressure.push(0.0)
  self.n_density.push(0.0)
  self.kind.push(kind)
}

///|
/// Reference number density `n0` measured on the initial fluid particles.
///
/// Using the measured value makes the initial configuration exactly
/// "incompressible" and keeps the pressure equation well posed.
pub fn initial_density(state : State, params : Params) -> Double {
  let re2 = params.re2()
  let mut total = 0.0
  let mut count = 0
  for i = 0; i < state.x.length(); i = i + 1 {
    if state.kind[i] is Fluid {
      let mut n = 0.0
      for j = 0; j < state.x.length(); j = j + 1 {
        let dx = state.x[j] - state.x[i]
        let dy = state.y[j] - state.y[i]
        n = n + weight(dx * dx + dy * dy, re2)
      }
      total = total + n
      count = count + 1
    }
  }
  total / count.to_double()
}
