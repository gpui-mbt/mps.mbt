///|
/// Deterministic pseudo-random positions, used by the search tests so every
/// case is reproducible.
fn scatter(rng : @core.Rng, count : Int32, size : Double) -> Array[@core.Vec2] {
  let out : Array[@core.Vec2] = []
  for i = 0; i < count; i = i + 1 {
    let x = rng.next_double() * size
    let y = rng.next_double() * size
    out.push(@core.Vec2::new(x, y))
  }
  out
}

///|
/// Brute-force reference for the grid search, ascending.
fn reference_neighbors(
  positions : Array[@core.Vec2],
  q : Int32,
  radius : Double,
) -> Array[Int32] {
  let r2 = radius * radius
  let out : Array[Int32] = []
  for j = 0; j < positions.length(); j = j + 1 {
    if j != q && @core.dist2(positions[q], positions[j]) < r2 {
      out.push(j)
    }
  }
  out
}

///|
test "grid search matches brute force on scattered points" {
  let rng = @core.Rng::new(11UL)
  let positions = scatter(rng, 300, 10.0)
  let radius = 0.7
  let grid = @core.UniformGrid::build(positions, radius)
  for q = 0; q < positions.length(); q = q + 1 {
    assert_eq(
      grid.neighbors_within(positions, q, radius),
      reference_neighbors(positions, q, radius),
    )
  }
}

///|
test "grid search orders neighbours by index" {
  let positions : Array[@core.Vec2] = [
    @core.Vec2::new(2.1, 2.1),
    @core.Vec2::new(1.0, 1.0),
    @core.Vec2::new(2.1, 1.1),
    @core.Vec2::new(1.1, 2.1),
    @core.Vec2::new(1.1, 1.1),
  ]
  let grid = @core.UniformGrid::build(positions, 1.0)
  // Query 0 sits in cell (2, 2) and every other point is inside radius 2.0.
  // Cell traversal order differs from index order; the result is ascending.
  assert_eq(grid.neighbors_within(positions, 0, 2.0), [1, 2, 3, 4])
}

///|
test "grid indexes every point exactly once and clamps strays" {
  let positions : Array[@core.Vec2] = [
    @core.Vec2::new(0.5, 0.5),
    @core.Vec2::new(0.5, 0.5),
    @core.Vec2::new(-3.0, -2.0),
    @core.Vec2::new(4.0, 0.0),
  ]
  let grid = @core.UniformGrid::build(positions, 1.0)
  let all : Array[Int32] = []
  for cell = 0; cell < grid.cell_count(); cell = cell + 1 {
    for i in grid.cell_items(cell) {
      all.push(i)
    }
  }
  assert_eq(all, [0, 1, 2, 3])
  // The negative point clamps into the origin cell and the point at x = 4 into
  // the last column of its row (cells are 0..4 wide with size 4).
  assert_eq(grid.cell_of(positions[2]), 0)
  assert_eq(grid.cell_of(positions[3]), 4)
}

///|
test "empty input produces an empty index" {
  let positions : Array[@core.Vec2] = []
  let grid = @core.UniformGrid::build(positions, 1.0)
  assert_eq(grid.nx, 1)
  assert_eq(grid.ny, 1)
  assert_eq(grid.items.length(), 0)
}
