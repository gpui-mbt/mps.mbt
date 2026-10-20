///|
/// Recomputes the number density of every particle from its neighbour list.
///
/// `n[i] = sum_j w(|x_i - x_j|²)` over the cached padded neighbourhood;
/// weights beyond `re` are zero, so the padding contributes nothing.
pub fn update_density(
  state : State,
  list : @core.NeighborList,
  re2 : Double,
  out : Array[Double],
) -> Unit {
  let n = state.x.length()
  for i = 0; i < n; i = i + 1 {
    let mut acc = 0.0
    let xi = state.x[i]
    let yi = state.y[i]
    // Neighbours within the padded radius; weights beyond `re` are zero.
    for j in list.neighbors_of(i) {
      let dx = state.x[j] - xi
      let dy = state.y[j] - yi
      acc = acc + weight(dx * dx + dy * dy, re2)
    }
    out[i] = acc
  }
}

///|
/// Number density of every particle by direct summation.
///
/// The O(n²) reference used to validate [`update_density`] on small scenes.
pub fn density_by_direct_sum(state : State, re2 : Double) -> Array[Double] {
  let n = state.x.length()
  let out = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    let mut acc = 0.0
    for j = 0; j < n; j = j + 1 {
      let dx = state.x[j] - state.x[i]
      let dy = state.y[j] - state.y[i]
      acc = acc + weight(dx * dx + dy * dy, re2)
    }
    out[i] = acc
  }
  out
}
