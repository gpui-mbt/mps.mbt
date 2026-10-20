///|
/// Native host for the dam-break demo.
///
/// Parses the command line, prints the help text on `--help`, rejects unknown
/// arguments with a usage error, and otherwise runs the simulation.
fn main {
  let args = @env.args()
  let opts = @native.Options::parse(args) catch {
    @native.CliError::Help => {
      println(@native.help_text())
      return
    }
    @native.CliError::Usage(message) => {
      eprintln("mps: " + message)
      eprintln(@native.help_text())
      return
    }
  }
  let status = @native.run(opts)
  if status != 0 {
    @native.report_failure(status)
  }
}
