///|
/// Moves fluid particles to restore the reference number density.
///
/// The pressure correction removes most of the density error. This relaxation
/// covers the configurations the linearised pressure model cannot treat, such
/// as a particle that lost every contact inside one integration step: each
/// particle is displaced along the local density gradient
///
/// `x_i <- x_i + S * (n0 - n_i) * grad n_i / n0`
///
/// with `grad n_i = sum_j (x_j - x_i) w_ij / r_ij²` and `S` the particle
/// spacing, so an over-dense neighbourhood pushes particles apart and an
/// under-dense one pulls them together. The displacement is capped at a quarter
/// of the spacing and the corrected positions are written to
/// `out_x`/`out_y`.
pub fn relax_density(
  state : State,
  list : @core.NeighborList,
  params : Params,
  n0 : Double,
  density : Array[Double],
  out_x : Array[Double],
  out_y : Array[Double],
) -> Unit {
  let re2 = params.re2()
  let re = params.radius
  let cap = 0.25 * params.spacing
  let n = state.x.length()
  for i = 0; i < n; i = i + 1 {
    let mut x = state.x[i]
    let mut y = state.y[i]
    if state.kind[i] is Fluid {
      let mut gx = 0.0
      let mut gy = 0.0
      for j in list.neighbors_of(i) {
        let dx = state.x[j] - state.x[i]
        let dy = state.y[j] - state.y[i]
        let r2 = dx * dx + dy * dy
        if r2 > 0.0 && r2 < re2 {
          let w = re / r2.sqrt() - 1.0
          gx = gx + w / r2 * dx
          gy = gy + w / r2 * dy
        }
      }
      let error = (n0 - density[i]) / n0
      let mut mx = params.spacing * error * gx
      let mut my = params.spacing * error * gy
      let len = (mx * mx + my * my).sqrt()
      if len > cap {
        mx = mx / len * cap
        my = my / len * cap
      }
      x = x + mx
      y = y + my
    }
    out_x[i] = x
    out_y[i] = y
  }
}
