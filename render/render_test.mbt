///|
fn sample_frame() -> Frame {
  let params = @mps.Params::default()
  let domain = @mps.Domain::{ min_x: 0.0, min_y: 0.0, max_x: 0.4, max_y: 0.3, }
  let scene = @mps.Scene::build(params, domain, 0.2, 0.3)
  let sim = @mps.Simulation::new(params, domain, 0.2, 0.3)
  let _ = scene
  frame_of(sim, "ok")
}

///|
test "frame collects only fluid particles" {
  let frame = sample_frame()
  assert_eq(frame.fluid_x.length(), 600)
  assert_eq(frame.width, 0.4)
  assert_eq(frame.height, 0.3)
  assert_eq(frame.status, "ok")
  assert_eq(frame.max_speed, 0.0)
}

///|
test "snapshot line is tab separated and backend independent" {
  let line = snapshot_line(sample_frame())
  let head : Array[String] = []
  for part in line.split("\t") {
    head.push(part.to_owned())
  }
  assert_eq(head.length(), 9)
  assert_eq(head[0], "FRAME")
  assert_eq(head[1], "0")
  assert_eq(head[7], "ok")
  // The body starts with the fluid count in step with the frame data.
  assert_true(head[8].has_prefix("600 "))
}

///|
test "bitmap has the requested size and an opaque background" {
  let bm = render_bitmap(sample_frame(), 64, 32)
  assert_eq(bm.width, 64)
  assert_eq(bm.height, 32)
  assert_eq(bm.pixels.length(), 64 * 32 * 3)
  // The top-left corner is outside the tank: background, not water.
  assert_true(bm.pixels[0] < 60)
}

///|
test "water colour brightens with pressure and speed" {
  let still = water_color(0.05, 0.0, 0.0, 0.3)
  let fast = water_color(0.05, 3000.0, 3.0, 0.3)
  assert_true(fast.r + fast.g > still.r + still.g)
  // Channels stay inside the byte range.
  for c in [still, fast] {
    assert_true(c.r >= 0 && c.r <= 255)
    assert_true(c.g >= 0 && c.g <= 255)
    assert_true(c.b >= 0 && c.b <= 255)
  }
}

///|
test "css colour has seven characters" {
  let c = @render.water_color(0.05, 1000.0, 1.0, 0.3)
  let css = c.to_css()
  assert_eq(css.length(), 7)
  assert_eq(css.has_prefix("#"), true)
}

///|
test "terminal render has one string per row" {
  let lines = render_terminal(sample_frame(), 40, 15)
  assert_eq(lines.length(), 15)
  let text = terminal_text(sample_frame(), 40, 15)
  assert_true(text.contains("pmax="))
}
