///|
/// Interaction pairs cached across simulation stages.
///
/// [`UniformGrid::build`] is the only source of pairs: [`NeighborList::build`]
/// stores, for each particle, the ascending list of indices inside the padded
/// interaction radius `radius + skin`, copied out of the grid so later
/// position updates cannot disturb it.
///
/// The list is valid while every particle moved less than `skin` since
/// [`NeighborList::build`] (or the last [`NeighborList::refresh`]), because the
/// padding guarantees that no new pair can enter the interaction radius before
/// that. Refreshing is explicit so the caller controls when the cost of a
/// rebuild is paid.
pub(all) struct NeighborList {
  /// Flattened neighbour indices; particle `i` owns `start[i] .. start[i+1]`.
  mut neighbors : Array[Int32]
  /// Start offset of each particle's entries in `neighbors`.
  mut start : Array[Int32]
  /// Positions captured at build time.
  mut anchor : Array[Vec2]
  /// Padding added on top of the interaction radius.
  skin : Double
  /// Number of rebuilds performed by `refresh`.
  mut rebuilds : Int32
}

///|
/// Builds a list for `positions` with interaction radius `radius` and padding
/// `skin`.
pub fn NeighborList::build(
  positions : Array[Vec2],
  radius : Double,
  skin : Double,
) -> NeighborList {
  let padded = radius + skin
  let grid = UniformGrid::build(positions, padded)
  let n = positions.length()
  let neighbors : Array[Int32] = []
  let start = Array::make(n + 1, 0)
  for i = 0; i < n; i = i + 1 {
    start[i] = neighbors.length()
    for j in grid.neighbors_within(positions, i, padded) {
      neighbors.push(j)
    }
  }
  start[n] = neighbors.length()
  { neighbors, start, anchor: positions.copy(), skin, rebuilds: 0, }
}

///|
/// Neighbour indices of particle `i`, ascending.
pub fn NeighborList::neighbors_of(
  self : NeighborList,
  i : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  for k = self.start[i]; k < self.start[i + 1]; k = k + 1 {
    out.push(self.neighbors[k])
  }
  out
}

///|
/// Total number of directed neighbour entries.
pub fn NeighborList::entry_count(self : NeighborList) -> Int32 {
  self.neighbors.length()
}

///|
/// Largest component-wise displacement of any particle from its anchored
/// position since the last build.
pub fn NeighborList::drift(
  self : NeighborList,
  positions : Array[Vec2],
) -> Double {
  let mut drift = 0.0
  let n = positions.length().min(self.anchor.length())
  for i = 0; i < n; i = i + 1 {
    drift = drift.max(max_abs(positions[i] - self.anchor[i], Vec2::zero()))
  }
  drift
}

///|
/// Whether `positions` still fit the cached list.
pub fn NeighborList::is_valid(
  self : NeighborList,
  positions : Array[Vec2],
) -> Bool {
  positions.length() == self.anchor.length() &&
  self.drift(positions) < self.skin
}

///|
/// Rebuilds in place when the list no longer fits; returns whether it did.
pub fn NeighborList::refresh(
  self : NeighborList,
  positions : Array[Vec2],
  radius : Double,
) -> Bool {
  if self.is_valid(positions) {
    return false
  }
  let rebuilt = NeighborList::build(positions, radius, self.skin)
  self.neighbors = rebuilt.neighbors
  self.start = rebuilt.start
  self.anchor = rebuilt.anchor
  self.rebuilds = self.rebuilds + 1
  true
}
