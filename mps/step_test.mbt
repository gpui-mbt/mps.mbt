///|
test "kinematic step is deterministic" {
  let params = Params::default()
  let a = Simulation::new(params, test_domain(), 0.2, 0.3)
  let b = Simulation::new(params, test_domain(), 0.2, 0.3)
  for k = 0; k < 50; k = k + 1 {
    let ra = a.step()
    let rb = b.step()
    assert_eq(ra.dt, rb.dt)
  }
  assert_eq(a.scene.state.x, b.scene.state.x)
  assert_eq(a.scene.state.y, b.scene.state.y)
  assert_eq(a.scene.state.time, b.scene.state.time)
}

///|
test "kinematic step follows semi-implicit free fall" {
  let params = Params::default()
  let sim = Simulation::new(params, test_domain(), 0.2, 0.3)
  let state = sim.scene.state
  // The top row of the column starts at 0.295 m and falls the farthest before
  // the floor stops it, so it is the particle to compare against.
  let top = 570
  let y0 = state.y[top]
  let mut expected_drop = 0.0
  for k = 0; k < 20; k = k + 1 {
    let r = sim.step()
    // Each step adds g dt to the velocity and then moves by v dt.
    expected_drop = expected_drop +
      r.dt * r.dt * params.gravity * (k + 1).to_double()
  }
  let drop = y0 - state.y[top]
  // The CFL bound makes dt a power of the step speed, so the discrete drop
  // matches the sum within rounding, not exactly.
  assert_true((drop - expected_drop).abs() < 1.0e-6)
  assert_true(state.vy[top] < 0.0)
  assert_eq(state.step, 20)
}

///|
test "kinematic step keeps every fluid particle inside the tank" {
  let params = Params::default()
  let sim = Simulation::new(params, test_domain(), 0.2, 0.3)
  let state = sim.scene.state
  for k = 0; k < 400; k = k + 1 {
    let r = sim.step()
    assert_true(!(r.status is StepStatus::Diverged))
  }
  let domain = test_domain()
  for i = 0; i < 600; i = i + 1 {
    assert_true(state.x[i] >= domain.min_x && state.x[i] <= domain.max_x)
    assert_true(state.y[i] >= domain.min_y && state.y[i] <= domain.max_y)
    assert_true(finite(state.x[i]) && finite(state.y[i]))
  }
}

///|
test "kinematic mode does not solve pressure" {
  let params = Params::default()
  let sim = Simulation::new(params, test_domain(), 0.2, 0.3)
  let r = sim.step()
  assert_eq(r.cg_iterations, 0)
  assert_true(r.status is StepStatus::Ok)
}

///|
test "mps mode is selectable" {
  let params = Params::mps()
  assert_true(params.mode is Mode::Mps)
  let sim = Simulation::new(params, test_domain(), 0.2, 0.3)
  let r = sim.step()
  // The experimental step must at least report a status and stay finite.
  assert_true(!(r.status is StepStatus::Diverged))
}
