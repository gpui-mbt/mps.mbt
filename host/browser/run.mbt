///|
/// Number of steps the browser runs before the module exits.
///
/// Large enough to show the whole dam break and the settling pool at the
/// demonstration time step, small enough that the module finishes in a few
/// seconds inside a browser worker.
pub fn default_steps() -> Int32 {
  6000
}

///|
/// Runs the demo and prints one `FRAME` line per step through the module's
/// only import, `spectest.print_char`.
///
/// The browser worker collects the characters until the newline that ends each
/// line and forwards the parsed frame to the page, so the wasm module itself
/// never needs a DOM, a canvas or a timer.
pub fn run(steps : Int32) -> Unit {
  let params = @mps.Params::kinematic()
  let domain = @mps.Domain::{ min_x: 0.0, min_y: 0.0, max_x: 0.4, max_y: 0.3, }
  let sim = @mps.Simulation::new(params, domain, 0.2, 0.3)
  println(@render.snapshot_line(@render.frame_of(sim, "start")))
  for k = 0; k < steps; k = k + 1 {
    let result = sim.step()
    let status = match result.status {
      @mps.StepStatus::Ok => "ok"
      @mps.StepStatus::TimestepTooSmall => "stalled"
      @mps.StepStatus::Diverged => "diverged"
    }
    println(@render.snapshot_line(@render.frame_of(sim, status)))
    if result.status is @mps.StepStatus::Diverged {
      break
    }
  }
}
