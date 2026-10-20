///|
/// Starts one browser session at `from_step`.
///
/// The page calls this once per session and then starts the module with
/// [`start`]; the step count only carries the continuation of a chained session.
#export_name("mps_session")
pub fn session(from_step : Int32) -> Unit {
  start_step.val = from_step
}

///|
/// Step the current session continues from.
let start_step : Ref[Int32] = { val: 0, }

///|
/// Runs the session set by [`session`].
///
/// The module has no `main` of its own in this build shape, so the page calls
/// this after [`session`] and reads the FRAME lines from the module's print
/// import.
#export_name("mps_run")
pub fn start() -> Unit {
  @browser.run(start_step.val)
}
