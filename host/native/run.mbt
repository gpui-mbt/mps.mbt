///|
/// Runs `opts` and returns the process exit code.
///
/// Snapshot mode prints one `FRAME` line per step; the browser worker and the
/// cross-backend gate consume those lines. Animate mode paints the terminal
/// and prints a one-line summary. Failures are reported through the exit code
/// instead of a panic so hosts stay scriptable.
pub fn run(opts : Options) -> Int32 {
  let params = if opts.mode is @mps.Mode::Mps {
    @mps.Params::mps()
  } else {
    @mps.Params::kinematic()
  }
  let domain = @mps.Domain::{ min_x: 0.0, min_y: 0.0, max_x: 0.4, max_y: 0.3, }
  let sim = @mps.Simulation::new(params, domain, 0.2, 0.3)
  if opts.animate {
    return animate(sim, opts)
  }
  // Snapshot mode emits one line per frame, which the browser worker and the
  // cross-backend gate read back.
  let lines = snapshot_lines(sim, opts.steps)
  for line in lines {
    println(line)
  }
  0
}

///|
/// The `FRAME` line of the initial state.
pub fn start_line(sim : @mps.Simulation) -> String {
  @render.snapshot_line(@render.frame_of(sim, "start"))
}

///|
/// Runs `steps` steps and returns every `FRAME` line, initial state first.
pub fn snapshot_lines(sim : @mps.Simulation, steps : Int32) -> Array[String] {
  let lines : Array[String] = []
  lines.push(start_line(sim))
  for k = 0; k < steps; k = k + 1 {
    let result = sim.step()
    lines.push(
      @render.snapshot_line(@render.frame_of(sim, status_word(result.status))),
    )
    if result.status is @mps.StepStatus::Diverged {
      break
    }
  }
  lines
}

///|
/// Terminates the process after a failed run.
///
/// The host has no portable `exit`, so a failed run ends through the core
/// `abort`, whose message states the already reported outcome.
pub fn report_failure(status : Int32) -> Unit {
  abort("mps: run failed with status " + @core.fmt_fixed(status.to_double(), 0))
}

///|
/// Maps a step status to the frame status word.
pub fn status_word(status : @mps.StepStatus) -> String {
  match status {
    @mps.StepStatus::Ok => "ok"
    @mps.StepStatus::TimestepTooSmall => "stalled"
    @mps.StepStatus::Diverged => "diverged"
  }
}

///|
/// Animates the simulation for `opts.steps` frames, one repaint per step.
pub fn animate(sim : @mps.Simulation, opts : Options) -> Int32 {
  // One whole repaint per step, printed in a single call so the terminal does
  // not flicker between the clear and the frame.
  println(@render.hide_cursor())
  for k = 0; k < opts.steps; k = k + 1 {
    let result = sim.step()
    let frame = @render.frame_of(sim, status_word(result.status))
    println(
      @render.clear_screen() +
      @render.terminal_text(frame, opts.cols, opts.rows),
    )
    if result.status is @mps.StepStatus::Diverged {
      println(@render.show_cursor())
      eprintln(
        "mps: simulation diverged at t=" +
        @core.fmt_fixed(sim.scene.state.time, 3) +
        " s",
      )
      return 1
    }
  }
  println(@render.show_cursor())
  0
}
