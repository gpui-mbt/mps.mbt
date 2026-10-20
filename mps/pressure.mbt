///|
/// Spatial dimension of the simulation.
pub const DIMENSION : Int32 = 2

///|
/// Result of one pressure solve.
pub(all) struct PressureSolve {
  /// Largest CG iteration count over the ICP solves.
  cg_iterations : Int32
  /// Number of ICP iterations performed.
  icp_iterations : Int32
  /// Whether the last CG solve converged within its iteration cap.
  converged : Bool
}

///|
/// Solves the pressure Poisson equation on the predicted configuration.
///
/// The discrete operators follow Koshizuka & Oka (1996) with `d = 2`,
/// `w_ij = re/r - 1`, `lambda_i = sum_j r_ij² w_ij` and the reference density
/// `n0`:
///
/// - Laplacian of `i`: `2d (sum_j w_ij - lambda_i) / (n0 lambda_i)`
/// - Laplacian of `j != i`: `2d w_ij / (n0 lambda_i)`
/// - right-hand side: `(rho0 / dt²) (n*_i - n0) / n0` for the negated system
///   `L = -[grad²]`
///
/// Walls and dummy walls take part in `sum_w` and `lambda` but are not
/// unknowns; their contribution to the diagonal is what gives a fluid
/// particle next to a wall or a free surface a pressure that is pulled towards
/// zero, the physical boundary condition.
///
/// Non-negative pressure is enforced by ICP: a particle whose pressure came
/// out negative is fixed at zero and removed from the unknowns, and the system
/// is solved again, at most `icp_iterations` times.
pub fn Simulation::solve_pressure(
  self : Simulation,
  dt : Double,
  list : @core.NeighborList,
) -> PressureSolve {
  let params = self.params
  let state = self.scene.state
  let n = state.x.length()
  let n0 = self.scene.n0
  let d = DIMENSION.to_double()
  let re = params.radius
  let re2 = params.re2()
  let scale = params.density / (dt * dt * n0)
  let diag = Array::make(n, 0.0)
  let rows = Array::make(n, [])
  let rhs = Array::make(n, 0.0)
  let active = Array::make(n, false)
  for i = 0; i < n; i = i + 1 {
    if state.kind[i] is Fluid {
      let neighbors = list.neighbors_of(i)
      let mut sum_w = 0.0
      let mut lambda = 0.0
      for j in neighbors {
        let dx = state.x[j] - state.x[i]
        let dy = state.y[j] - state.y[i]
        let r2 = dx * dx + dy * dy
        if r2 > 0.0 && r2 < re2 {
          let w = re / r2.sqrt() - 1.0
          sum_w = sum_w + w
          lambda = lambda + r2 * w
        }
      }
      if lambda > 0.0 {
        let coeff = 2.0 * d / (n0 * lambda)
        let keep : Array[(Int32, Double)] = []
        for j in neighbors {
          if state.kind[j] is Fluid {
            let dx = state.x[j] - state.x[i]
            let dy = state.y[j] - state.y[i]
            let r2 = dx * dx + dy * dy
            if r2 > 0.0 && r2 < re2 {
              // Negated off-diagonal coefficient of the positive definite
              // operator L = -[grad²].
              keep.push((j, -coeff * (re / r2.sqrt() - 1.0)))
            }
          }
        }
        rows[i] = keep
        diag[i] = coeff * (lambda - sum_w)
        rhs[i] = (self.density_scratch[i] - n0) * scale
        active[i] = true
      }
    }
  }
  for i = 0; i < n; i = i + 1 {
    self.pressure_next[i] = 0.0
  }
  let a = SparseMatrix::from_rows(rows, diag)
  let mut cg_max = 0
  let mut converged = true
  for it = 0; it < params.icp_iterations; it = it + 1 {
    let cg = conjugate_gradient_masked(
      a,
      rhs,
      self.pressure_next,
      active,
      params.cg_iterations,
      params.cg_tolerance,
    )
    cg_max = cg_max.max(cg)
    converged = cg < params.cg_iterations
    let mut pinned = false
    for i = 0; i < n; i = i + 1 {
      if active[i] && self.pressure_next[i] < 0.0 {
        self.pressure_next[i] = 0.0
        active[i] = false
        pinned = true
      }
    }
    if !pinned {
      break
    }
  }
  for i = 0; i < n; i = i + 1 {
    if state.kind[i] is Fluid {
      let p = self.pressure_next[i]
      state.pressure[i] = if p > 0.0 { p } else { 0.0 }
    }
  }
  { cg_iterations: cg_max, icp_iterations: params.icp_iterations, converged, }
}

///|
/// Applies the pressure gradient correction and moves the fluid particles.
///
/// `grad p_i = (d / (n0 lambda_i)) sum_{j != i} (p_j - p_hat_i) (x_j - x_i) w_ij / r_ij²`
///
/// with `p_hat_i` the pressure of the previous step. A neighbour that is not a
/// fluid particle contributes `p_j = 0`, the wall and free-surface condition.
/// The correction is `v = v* - dt / rho0 * grad p`.
pub fn Simulation::apply_pressure_gradient(
  self : Simulation,
  dt : Double,
  list : @core.NeighborList,
) -> Unit {
  let params = self.params
  let state = self.scene.state
  let n = state.x.length()
  let n0 = self.scene.n0
  let pressure = self.pressure_next
  let d = DIMENSION.to_double()
  let re = params.radius
  let re2 = params.re2()
  for i = 0; i < n; i = i + 1 {
    if state.kind[i] is Fluid {
      let mut lambda = 0.0
      let mut gx = 0.0
      let mut gy = 0.0
      for j in list.neighbors_of(i) {
        let dx = state.x[j] - state.x[i]
        let dy = state.y[j] - state.y[i]
        let r2 = dx * dx + dy * dy
        if r2 > 0.0 && r2 < re2 {
          let w = re / r2.sqrt() - 1.0
          lambda = lambda + r2 * w
          // Wall and dummy-wall neighbours carry no pressure, and the free
          // surface is a missing neighbour, so both contribute nothing here.
          if state.kind[j] is Fluid && pressure[j] > 0.0 {
            let factor = pressure[j] * w / r2
            gx = gx + factor * dx
            gy = gy + factor * dy
          }
        }
      }
      let mut vx = self.vx_star[i]
      let mut vy = self.vy_star[i]
      if lambda > 0.0 {
        let k = d / (n0 * lambda)
        vx = vx - dt / params.density * k * gx
        vy = vy - dt / params.density * k * gy
      }
      state.vx[i] = vx
      state.vy[i] = vy
      state.x[i] = state.x[i] + vx * dt
      state.y[i] = state.y[i] + vy * dt
    }
  }
  for i = 0; i < n; i = i + 1 {
    if state.kind[i] is Fluid {
      state.pressure[i] = pressure[i]
    }
  }
}
