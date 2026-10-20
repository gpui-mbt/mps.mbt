///|
test "vec2 arithmetic" {
  let a = @core.Vec2::new(3.0, 4.0)
  let b = @core.Vec2::new(-1.0, 2.0)
  inspect(a + b, content="(2.0000, 6.0000)")
  inspect(a - b, content="(4.0000, 2.0000)")
  inspect(a.scale(2.0), content="(6.0000, 8.0000)")
  inspect(a.scale(0.5), content="(1.5000, 2.0000)")
  inspect(-a, content="(-3.0000, -4.0000)")
  inspect(a.dot(b), content="5")
  inspect(a.len_sq(), content="25")
  inspect(a.len(), content="5")
  inspect(@core.dist2(a, b), content="20")
}

///|
test "vec2 normalize handles degenerate input" {
  inspect(@core.Vec2::zero().normalize(), content="(0.0000, 0.0000)")
  inspect(@core.Vec2::new(0.0, -2.0).normalize(), content="(0.0000, -1.0000)")
  let inf = @core.Vec2::new(1.0 / 0.0, 0.0).normalize()
  inspect(inf, content="(0.0000, 0.0000)")
  let nan = @core.Vec2::new(0.0 / 0.0, 0.0).normalize()
  inspect(nan, content="(0.0000, 0.0000)")
}

///|
test "max_abs takes the largest component magnitude" {
  let a = @core.Vec2::new(-3.0, 2.0)
  let b = @core.Vec2::new(1.0, -7.0)
  inspect(@core.max_abs(a, b), content="7")
}
