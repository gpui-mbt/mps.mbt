///|
/// Command-line options of the demo host.
pub(all) struct Options {
  /// Step model.
  mut mode : @mps.Mode
  /// Number of steps to run (or frames to render in animate mode).
  mut steps : Int32
  /// Terminal animation instead of a headless snapshot.
  mut animate : Bool
  /// Emit one `FRAME` line per step instead of a summary.
  mut snapshot : Bool
  /// Terminal columns and rows used by the animation.
  mut cols : Int32
  mut rows : Int32
}

///|
/// Default options: 3000 kinematic steps in headless snapshot mode.
pub fn Options::default() -> Options {
  {
    mode: @mps.Mode::Kinematic,
    steps: 3000,
    animate: false,
    snapshot: true,
    cols: 80,
    rows: 30,
  }
}

///|
/// Parses `--key value` and `--flag` arguments.
///
/// Unknown arguments are rejected with an error message so a typo never
/// silently changes what the host runs.
pub fn Options::parse(args : Array[String]) -> Options raise CliError {
  // `env.args()` may include the program name as its first element depending
  // on the backend, so leading arguments that name an executable are skipped.
  let mut start = 0
  while start < args.length() && args[start].contains("/") {
    start = start + 1
  }
  let opts = Options::default()
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--animate" => opts.animate = true
      "--snapshot" => opts.snapshot = true
      "--mps" => opts.mode = @mps.Mode::Mps
      "--kinematic" => opts.mode = @mps.Mode::Kinematic
      "--steps" => {
        i = i + 1
        opts.steps = int_arg(args, i, "--steps")
      }
      "--cols" => {
        i = i + 1
        opts.cols = int_arg(args, i, "--cols")
      }
      "--rows" => {
        i = i + 1
        opts.rows = int_arg(args, i, "--rows")
      }
      "--help" => raise CliError::Help
      _ => raise CliError::Usage("unknown argument: " + arg)
    }
    i = i + 1
  }
  opts
}

///|
/// Raised when `--help` is requested or the command line is invalid.
pub suberror CliError {
  /// The user asked for the help text.
  Help
  /// The command line is invalid; the message names the offending argument.
  Usage(String)
}

///|
fn int_arg(
  args : Array[String],
  i : Int32,
  flag : String,
) -> Int32 raise CliError {
  if i >= args.length() {
    raise CliError::Usage(flag + " needs a value")
  }
  let text = args[i]
  let mut value = 0
  let mut any = false
  for ch in text {
    let digit = ch.to_int() - '0'.to_int()
    if digit < 0 || digit > 9 {
      raise CliError::Usage(
        flag + " expects a non-negative integer, got " + text,
      )
    }
    value = value * 10 + digit
    any = true
  }
  if !any {
    raise CliError::Usage(flag + " expects a non-negative integer, got " + text)
  }
  value
}

///|
/// The help text of the demo host.
pub fn help_text() -> String {
  "mps dam-break demo\n" +
  "\n" +
  "  --animate        run the terminal animation\n" +
  "  --snapshot       print one FRAME line per step (default)\n" +
  "  --steps N        steps to run (default 3000)\n" +
  "  --kinematic      free-fall demo model (default)\n" +
  "  --mps            experimental MPS pressure model\n" +
  "  --cols N         terminal columns for --animate (default 80)\n" +
  "  --rows N         terminal rows for --animate (default 30)\n"
}
