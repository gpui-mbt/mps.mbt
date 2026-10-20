///|
/// Sparse symmetric matrix in compressed sparse row form with a dense
/// diagonal.
///
/// The diagonal is stored separately because the MPS pressure system has one
/// unknown per fluid particle and its off-diagonal couplings are the
/// interaction neighbours; only assembled pairs need column indices.
pub(all) struct SparseMatrix {
  /// Column index of each stored entry.
  cols : Array[Int32]
  /// Value of each stored entry; the same index as `cols`.
  values : Array[Double]
  /// Start offset of each row in `cols`/`values`.
  start : Array[Int32]
  /// Diagonal entries; `diag[i] >= 0`.
  diag : Array[Double]
}

///|
/// Empty matrix with `n` rows.
pub fn SparseMatrix::new(n : Int32) -> SparseMatrix {
  {
    cols: [],
    values: [],
    start: Array::make(n + 1, 0),
    diag: Array::make(n, 0.0),
  }
}

///|
/// Replaces the matrix content with the given row lists.
///
/// `rows[i]` holds the off-diagonal `(column, value)` pairs of row `i`, and
/// `diag` its diagonal. Rows are copied as given.
pub fn SparseMatrix::from_rows(
  rows : Array[Array[(Int32, Double)]],
  diag : Array[Double],
) -> SparseMatrix {
  let n = rows.length()
  let cols : Array[Int32] = []
  let values : Array[Double] = []
  let start = Array::make(n + 1, 0)
  for i = 0; i < n; i = i + 1 {
    start[i] = cols.length()
    for (c, v) in rows[i] {
      cols.push(c)
      values.push(v)
    }
  }
  start[n] = cols.length()
  { cols, values, start, diag, }
}

///|
/// `y = A x`.
pub fn SparseMatrix::mul(
  self : SparseMatrix,
  x : Array[Double],
  y : Array[Double],
) -> Unit {
  let n = self.diag.length()
  for i = 0; i < n; i = i + 1 {
    let mut acc = self.diag[i] * x[i]
    for k = self.start[i]; k < self.start[i + 1]; k = k + 1 {
      acc = acc + self.values[k] * x[self.cols[k]]
    }
    y[i] = acc
  }
}

///|
/// Whether `v` is neither NaN nor infinite.
pub fn finite(v : Double) -> Bool {
  !v.is_nan() && !v.is_inf()
}

///|
/// `y = A x` restricted to the active rows and columns, so inactive entries of
/// `x` or `y` are never read or written.
pub fn SparseMatrix::mul_active(
  self : SparseMatrix,
  x : Array[Double],
  y : Array[Double],
  active : Array[Bool],
) -> Unit {
  let n = self.diag.length()
  for i = 0; i < n; i = i + 1 {
    if active[i] {
      let mut acc = self.diag[i] * x[i]
      for k = self.start[i]; k < self.start[i + 1]; k = k + 1 {
        let j = self.cols[k]
        // A column that is not an unknown carries p = 0 and drops out.
        if !active[j] {
          continue
        }
        acc = acc + self.values[k] * x[j]
      }
      y[i] = acc
    }
  }
}

///|
/// Euclidean norm.
pub fn norm(values : Array[Double]) -> Double {
  let mut acc = 0.0
  for v in values {
    acc = acc + v * v
  }
  acc.sqrt()
}

///|
/// Dot product.
pub fn dot_product(a : Array[Double], b : Array[Double]) -> Double {
  let mut acc = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    acc = acc + a[i] * b[i]
  }
  acc
}

///|
/// Solves `A x = b` for a symmetric positive semi-definite `A` with the
/// Jacobi-preconditioned conjugate gradient method, writing into `x` (initially
/// considered zero) and returning the iteration count.
///
/// Iteration stops when the preconditioned residual norm drops below
/// `tolerance * |b|`, when `max_iter` is reached, or as soon as the direction
/// search stops making progress (which happens only for a singular system,
/// e.g. a fluid patch with no coupling to a boundary).
pub fn conjugate_gradient(
  a : SparseMatrix,
  b : Array[Double],
  x : Array[Double],
  max_iter : Int32,
  tolerance : Double,
) -> Int32 {
  let active = Array::make(b.length(), true)
  conjugate_gradient_masked(a, b, x, active, max_iter, tolerance)
}

///|
/// [`conjugate_gradient`] over the subset of rows and columns marked in
/// `active`; inactive entries of `x` stay untouched.
pub fn conjugate_gradient_masked(
  a : SparseMatrix,
  b : Array[Double],
  x : Array[Double],
  active : Array[Bool],
  max_iter : Int32,
  tolerance : Double,
) -> Int32 {
  let n = b.length()
  let r = Array::make(n, 0.0)
  let z = Array::make(n, 0.0)
  let p = Array::make(n, 0.0)
  let ap = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    x[i] = 0.0
    if active[i] {
      r[i] = b[i]
    }
  }
  let mut rz = 0.0
  for i = 0; i < n; i = i + 1 {
    if active[i] {
      if a.diag[i] > 0.0 {
        z[i] = r[i] / a.diag[i]
      } else {
        z[i] = r[i]
      }
      p[i] = z[i]
      rz = rz + r[i] * z[i]
    }
  }
  let target = tolerance * masked_norm(b, active)

  for it = 0; it < max_iter; it = it + 1 {
    let res = masked_norm(r, active)
    if res <= target {
      return it
    }
    a.mul_active(p, ap, active)
    let mut pap = 0.0
    for i = 0; i < n; i = i + 1 {
      if active[i] {
        pap = pap + p[i] * ap[i]
      }
    }
    if !(pap > 0.0) || !finite(pap) || !(rz > 0.0) {
      return it
    }
    let alpha = rz / pap
    for i = 0; i < n; i = i + 1 {
      if active[i] {
        x[i] = x[i] + alpha * p[i]
        r[i] = r[i] - alpha * ap[i]
      }
    }
    let mut rz_next = 0.0
    for i = 0; i < n; i = i + 1 {
      if active[i] {
        if a.diag[i] > 0.0 {
          z[i] = r[i] / a.diag[i]
        } else {
          z[i] = r[i]
        }
        rz_next = rz_next + r[i] * z[i]
      }
    }
    if !finite(rz_next) {
      return it + 1
    }
    let beta = rz_next / rz
    rz = rz_next
    for i = 0; i < n; i = i + 1 {
      if active[i] {
        p[i] = z[i] + beta * p[i]
      }
    }
  }
  max_iter
}

///|
fn masked_dot(
  a : Array[Double],
  b : Array[Double],
  active : Array[Bool],
) -> Double {
  let mut acc = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    if active[i] {
      acc = acc + a[i] * b[i]
    }
  }
  acc
}

///|
fn masked_norm(a : Array[Double], active : Array[Bool]) -> Double {
  masked_dot(a, a, active).sqrt()
}
