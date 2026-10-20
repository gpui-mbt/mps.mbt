///|
/// Explicit viscous acceleration from the standard MPS Laplacian of velocity:
///
/// `dv_i/dt = 2 * d * nu / (n0 * lambda) * sum_{j != i} (v_j - v_i) w(|x_ij|)`
///
/// with `d = 2`, `lambda = sum_{j != i} r_ij² w(r_ij) / n0`, evaluated on the
/// current (pre-advection) positions. Only fluid particles receive viscosity;
/// wall particles are inert.
///
/// `out_vx` / `out_vy` receive the predicted velocity after this stage, so the
/// caller copies them back.
pub fn apply_viscosity(
  state : State,
  list : @core.NeighborList,
  params : Params,
  dt : Double,
  out_vx : Array[Double],
  out_vy : Array[Double],
) -> Unit {
  let re2 = params.re2()
  let re = params.radius
  let n = state.x.length()
  for i = 0; i < n; i = i + 1 {
    let mut vx = state.vx[i]
    let mut vy = state.vy[i]
    if state.kind[i] is Fluid {
      let mut lamb = 0.0
      let mut acc_x = 0.0
      let mut acc_y = 0.0
      for j in list.neighbors_of(i) {
        let dx = state.x[j] - state.x[i]
        let dy = state.y[j] - state.y[i]
        let r2 = dx * dx + dy * dy
        if r2 > 0.0 && r2 < re2 {
          let r = r2.sqrt()
          let w = re / r - 1.0
          lamb = lamb + r2 * w
          acc_x = acc_x + (state.vx[j] - vx) * w
          acc_y = acc_y + (state.vy[j] - vy) * w
        }
      }
      if lamb > 0.0 {
        let factor = 4.0 * params.viscosity / lamb
        vx = vx + dt * factor * acc_x
        vy = vy + dt * factor * acc_y
      }
    }
    out_vx[i] = vx
    out_vy[i] = vy
  }
}
