///|
test "rng is deterministic" {
  let a = @core.Rng::new(7UL)
  let b = @core.Rng::new(7UL)
  for i = 0; i < 100; i = i + 1 {
    let x = a.next_u64()
    let y = b.next_u64()
    assert_true(x == y)
  }
  assert_true(@core.Rng::new(1UL).next_u64() != @core.Rng::new(2UL).next_u64())
}

///|
test "rng outputs stay in range" {
  let r = @core.Rng::new(1UL)
  for i = 0; i < 1000; i = i + 1 {
    let v = r.next_double()
    assert_true(v >= 0.0 && v < 1.0)
    let j = r.jitter(0.25)
    assert_true(j >= -0.25 && j < 0.25)
  }
}

///|
test "rng first draw depends only on the seed" {
  // Two independent generators with the same seed agree on their first draw;
  // reusing one generator must advance it.
  let a = @core.Rng::new(42UL)
  let first = a.next_double()
  let restarted = @core.Rng::new(42UL)
  assert_true(first == restarted.next_double())
  let second = a.next_double()
  assert_true(second != first)
}
