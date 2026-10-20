///|
/// A uniform-grid spatial index over particle positions.
///
/// The grid is aligned to the origin rather than to the particle bounding box,
/// so a cell index depends only on the position and the cell size:
/// `ix = floor(x / cell)`, `iy = floor(y / cell)`. Grid bounds are derived from
/// the positions at build time. Positions outside the bounds clamp to the
/// border cells so a stray particle is still indexed.
///
/// Layout is CSR: `cell_start` gives each cell's slice of `items`, and `items`
/// holds particle indices in ascending order inside a cell, so every query
/// visits indices in a reproducible order on every backend.
pub(all) struct UniformGrid {
  cell_size : Double
  nx : Int32
  ny : Int32
  cell_start : Array[Int32]
  items : Array[Int32]
}

///|
/// Number of cells that cover `extent` with `cell_size` cells, at least one.
fn cell_count(extent : Double, cell_size : Double) -> Int32 {
  let raw = (extent / cell_size).floor()
  let n = if raw < 0.0 { 0.0 } else { raw }
  n.to_int() + 1
}

///|
/// Builds the index for `positions`, sized so every position fits.
pub fn UniformGrid::build(
  positions : Array[Vec2],
  cell_size : Double,
) -> UniformGrid {
  let mut max_x = 0.0
  let mut max_y = 0.0
  for p in positions {
    max_x = max_x.max(p.x)
    max_y = max_y.max(p.y)
  }
  let nx = cell_count(max_x, cell_size)
  let ny = cell_count(max_y, cell_size)
  let cells = nx * ny
  let cell_of = Array::make(positions.length(), 0)
  for i = 0; i < positions.length(); i = i + 1 {
    cell_of[i] = cell_index(positions[i], cell_size, nx, ny)
  }
  let cell_start = Array::make(cells + 1, 0)
  for i = 0; i < positions.length(); i = i + 1 {
    cell_start[cell_of[i] + 1] = cell_start[cell_of[i] + 1] + 1
  }
  for c = 0; c < cells; c = c + 1 {
    cell_start[c + 1] = cell_start[c + 1] + cell_start[c]
  }
  let cursor = cell_start.copy()
  let items = Array::make(positions.length(), 0)
  for i = 0; i < positions.length(); i = i + 1 {
    let slot = cursor[cell_of[i]]
    items[slot] = i
    cursor[cell_of[i]] = slot + 1
  }
  { cell_size, nx, ny, cell_start, items, }
}

///|
fn cell_index(p : Vec2, cell_size : Double, nx : Int32, ny : Int32) -> Int32 {
  let ix = (p.x / cell_size).floor().to_int().clamp(min=0, max=nx - 1)
  let iy = (p.y / cell_size).floor().to_int().clamp(min=0, max=ny - 1)
  iy * nx + ix
}

///|
/// Index of the cell that holds `p`.
pub fn UniformGrid::cell_of(self : UniformGrid, p : Vec2) -> Int32 {
  cell_index(p, self.cell_size, self.nx, self.ny)
}

///|
/// Number of cells in the index.
pub fn UniformGrid::cell_count(self : UniformGrid) -> Int32 {
  self.nx * self.ny
}

///|
/// Particle indices stored in `cell`, ascending.
pub fn UniformGrid::cell_items(
  self : UniformGrid,
  cell : Int32,
) -> Array[Int32] {
  let start = self.cell_start[cell]
  let end = self.cell_start[cell + 1]
  let out : Array[Int32] = []
  for k = start; k < end; k = k + 1 {
    out.push(self.items[k])
  }
  out
}

///|
/// Indices `j != q` with `dist2(positions[q], positions[j]) < radius²`,
/// ascending.
///
/// The scan covers the 3×3 block of cells around `q`, which is exact for any
/// radius that does not exceed the cell size in each direction. Callers that
/// build the grid with `cell_size == radius` (or larger) always satisfy that.
pub fn UniformGrid::neighbors_within(
  self : UniformGrid,
  positions : Array[Vec2],
  q : Int32,
  radius : Double,
) -> Array[Int32] {
  let r2 = radius * radius
  let p = positions[q]
  let cell = self.cell_of(p)
  let cx = cell % self.nx
  let cy = cell / self.nx
  let out : Array[Int32] = []
  for dy = 0; dy < 3; dy = dy + 1 {
    let y = cy - 1 + dy
    if y < 0 || y >= self.ny {
      continue
    }
    for dx = 0; dx < 3; dx = dx + 1 {
      let x = cx - 1 + dx
      if x < 0 || x >= self.nx {
        continue
      }
      for j in self.cell_items(y * self.nx + x) {
        if j != q && dist2(p, positions[j]) < r2 {
          out.push(j)
        }
      }
    }
  }
  out.sort()
  out
}
