///|
test "neighbour lists hold every interaction pair once per endpoint" {
  let rng = @core.Rng::new(5UL)
  let positions : Array[@core.Vec2] = []
  for i = 0; i < 200; i = i + 1 {
    positions.push(
      @core.Vec2::new(rng.next_double() * 6.0, rng.next_double() * 6.0),
    )
  }
  let radius = 0.5
  let list = @core.NeighborList::build(positions, radius, 0.1)
  let r2 = radius * radius
  for i = 0; i < positions.length(); i = i + 1 {
    let actual = list.neighbors_of(i)
    for j in actual {
      assert_true(
        @core.dist2(positions[i], positions[j]) <
        (radius + 0.1) * (radius + 0.1),
      )
    }
    // Every real interaction partner is present, and the list is sorted.
    for j = 0; j < positions.length(); j = j + 1 {
      if j != i && @core.dist2(positions[i], positions[j]) < r2 {
        assert_true(actual.contains(j))
      }
    }
    let sorted = actual.copy()
    sorted.sort()
    assert_eq(actual, sorted)
  }
}

///|
test "neighbour list stays valid until a particle drifts by the skin" {
  // Three points 0.5 apart, well inside a 1.0 radius with 0.1 padding.
  let positions : Array[@core.Vec2] = [
    @core.Vec2::new(1.0, 1.0),
    @core.Vec2::new(1.5, 1.0),
    @core.Vec2::new(1.0, 1.5),
  ]
  let radius = 1.0
  let skin = 0.1
  let list = @core.NeighborList::build(positions, radius, skin)
  assert_eq(list.entry_count(), 6)
  // Unchanged positions are always valid.
  assert_true(list.is_valid(positions))
  assert_false(list.refresh(positions, radius))
  assert_eq(list.rebuilds, 0)
  // A particle displaced by at least the skin forces exactly one rebuild.
  let jumped = positions.copy()
  jumped[0] = @core.Vec2::new(0.5, 1.0)
  assert_false(list.is_valid(jumped))
  assert_true(list.refresh(jumped, radius))
  assert_eq(list.rebuilds, 1)
  assert_false(list.refresh(jumped, radius))
  assert_eq(list.rebuilds, 1)
  // Adding a particle forces another rebuild.
  let grown = jumped.copy()
  grown.push(@core.Vec2::new(4.0, 4.0))
  assert_true(list.refresh(grown, radius))
  assert_eq(list.rebuilds, 2)
}
