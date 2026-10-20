///|
/// Browser host entry point.
///
/// The module is started from JavaScript with `spectest.print_char` wired to a
/// frame collector, so the entry point only has to keep printing `FRAME` lines
/// until the requested number of steps has run.
fn main {
  @browser.run(@browser.default_steps())
}
