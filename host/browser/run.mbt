///|
/// Steps per page session.
///
/// The browser restarts the module for the next slice with the continuation
/// encoded in its arguments, so one instantiation never has to finish the whole
/// demo: each page load renders a smooth, real-time slice and then chains the
/// next slice into a fresh instantiation.
pub const SESSION_STEPS : Int32 = 300

///|
/// Number of completed steps at which the page starts a new session.
pub fn session_steps() -> Int32 {
  SESSION_STEPS
}

///|
/// Runs one slice of the demo and prints one `FRAME` line per step.
///
/// Every step of the slice prints one line; the page runs a few sessions one
/// after another and replays each slice at real time, so a page never waits on
/// a long run. The module's only import is `spectest.print_char`, which the page
/// turns into parsed frames; the browser needs no FFI beyond that.
pub fn run(start_step : Int32) -> Unit {
  let params = @mps.Params::kinematic()
  let domain = @mps.Domain::{ min_x: 0.0, min_y: 0.0, max_x: 0.4, max_y: 0.3, }
  let sim = @mps.Simulation::new(params, domain, 0.2, 0.3)
  if start_step > 0 {
    // Replay the deterministic prefix without printing anything, so a chained
    // session continues exactly where the previous one stopped.
    for k = 0; k < start_step; k = k + 1 {
      let _ = sim.step()
    }
  }
  let end = start_step + SESSION_STEPS
  for k = 0; k < end; k = k + 1 {
    let result = sim.step()
    if k >= start_step {
      let status = match result.status {
        @mps.StepStatus::Ok => "ok"
        @mps.StepStatus::TimestepTooSmall => "stalled"
        @mps.StepStatus::Diverged => "diverged"
      }
      println(@render.snapshot_line(@render.frame_of(sim, status)))
    }
    if result.status is @mps.StepStatus::Diverged {
      break
    }
  }
}
