///|
test "cg solves a tridiagonal system" {
  let n = 5
  let rows : Array[Array[(Int32, Double)]] = []
  let diag : Array[Double] = []
  let truth : Array[Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
  for i = 0; i < n; i = i + 1 {
    let row : Array[(Int32, Double)] = []
    let mut d = 2.0
    if i > 0 {
      row.push((i - 1, -1.0))
      d = d + 1.0
    }
    if i < n - 1 {
      row.push((i + 1, -1.0))
      d = d + 1.0
    }
    rows.push(row)
    diag.push(d)
  }
  let a = SparseMatrix::from_rows(rows, diag)
  let b = Array::make(n, 0.0)
  a.mul(truth, b)
  let x = Array::make(n, 0.0)
  let it = conjugate_gradient(a, b, x, 50, 1.0e-12)
  assert_true(it > 0 && it <= n)
  assert_true((x[0] - 1.0).abs() < 1.0e-9)
  assert_true((x[4] - 5.0).abs() < 1.0e-9)
}

///|
test "cg stops on a singular system instead of producing NaN" {
  // Pure Neumann tridiagonal: the matrix has a zero eigenvalue.
  let n = 4
  let rows : Array[Array[(Int32, Double)]] = []
  let diag : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let row : Array[(Int32, Double)] = []
    let mut d = 0.0
    if i > 0 {
      row.push((i - 1, 1.0))
    }
    if i < n - 1 {
      row.push((i + 1, 1.0))
    }
    for (_, v) in row {
      d = d + v.abs()
    }
    rows.push(row)
    diag.push(d)
  }
  let a = SparseMatrix::from_rows(rows, diag)
  let b = [1.0, -1.0, 1.0, -1.0]
  let x = Array::make(n, 0.0)
  let _ = conjugate_gradient(a, b, x, 100, 1.0e-12)
  for v in x {
    assert_true(finite(v))
  }
}
