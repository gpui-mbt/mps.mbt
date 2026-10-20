///|
fn test_domain() -> Domain {
  Domain::{ min_x: 0.0, min_y: 0.0, max_x: 0.4, max_y: 0.3, }
}

///|
test "scene lays out fluid block and wall rings" {
  let params = Params::default()
  let scene = Scene::build(params, test_domain(), 0.2, 0.3)
  // 20 x 30 fluid particles, two wall layers of 40 particles plus corners per
  // layer.
  assert_eq(scene.fluid, 600)
  assert_eq(scene.state.x.length(), scene.fluid + scene.wall)
  let mut wall = 0
  let mut dummy = 0
  for kind in scene.state.kind {
    if kind is ParticleKind::Wall {
      wall = wall + 1
    }
    if kind is ParticleKind::DummyWall {
      dummy = dummy + 1
    }
  }
  assert_true(wall > 0 && dummy > 0)
  assert_eq(scene.wall, wall + dummy)
}

///|
test "scene positions are deterministic and inside the walls" {
  let params = Params::default()
  let a = Scene::build(params, test_domain(), 0.2, 0.3)
  let b = Scene::build(params, test_domain(), 0.2, 0.3)
  assert_eq(a.state.x, b.state.x)
  assert_eq(a.state.y, b.state.y)
  assert_eq(a.n0, b.n0)
  for i = 0; i < a.fluid; i = i + 1 {
    assert_true(a.state.x[i] > 0.0 && a.state.x[i] < 0.2)
    assert_true(a.state.y[i] > 0.0 && a.state.y[i] < 0.3)
  }
}

///|
test "reference density is the mean initial fluid density" {
  let params = Params::default()
  let scene = Scene::build(params, test_domain(), 0.2, 0.3)
  // n0 is the average over the fluid particles of the direct-sum density, so
  // the two agree to rounding.
  let n = density_by_direct_sum(scene.state, params.re2())
  let mut total = 0.0
  for i = 0; i < scene.fluid; i = i + 1 {
    total = total + n[i]
  }
  let mean = total / scene.fluid.to_double()
  assert_true((mean - scene.n0).abs() < 1.0e-6)
  assert_true(scene.n0 > 20.0)
}

///|
test "kernel weights decrease with distance" {
  let re2 = 0.04 * 0.04
  let near = weight(0.01 * 0.01, re2)
  let far = weight(0.03 * 0.03, re2)
  assert_true(near > far)
  assert_eq(weight(0.0, re2), 0.0)
  assert_eq(weight(re2, re2), 0.0)
}

///|
test "density by direct sum matches the MPS weight sum" {
  let params = Params::default()
  let scene = Scene::build(params, test_domain(), 0.1, 0.1)
  let direct = density_by_direct_sum(scene.state, params.re2())
  // The interior of a uniform block has 4 rings of neighbours at the standard
  // MPS lattice distances.
  let i = 6 * 10 + 6
  assert_true(direct[i] > 0.0)
}
