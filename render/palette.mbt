///|
/// 8-bit RGB colour of a water particle.
///
/// Deep water is a dark blue that brightens with pressure and turns cyan where
/// the surface is fast, so a still dam reads as a blue block and a breaking wave
/// reads as a bright moving front.
pub(all) struct Rgb {
  r : Int32
  g : Int32
  b : Int32
}

///|
/// Colour of a water particle at height `y` with pressure `p` and speed `v`,
/// all in SI units, inside a domain of height `height`.
pub fn water_color(y : Double, p : Double, v : Double, height : Double) -> Rgb {
  let depth = 1.0 - (y / height).clamp(min=0.0, max=1.0)
  let pressure = (p / 3000.0).clamp(min=0.0, max=1.0)
  let speed = (v / 2.5).clamp(min=0.0, max=1.0)
  let base = 40.0 + 120.0 * pressure
  let r = base + 60.0 * speed
  let g = 70.0 + 120.0 * pressure + 90.0 * speed
  let b = 200.0 - 40.0 * depth + 40.0 * speed
  rgb_of(r, g, b)
}

///|
/// Clamps and rounds three channels into an [`Rgb`].
pub fn rgb_of(r : Double, g : Double, b : Double) -> Rgb {
  { r: channel(r), g: channel(g), b: channel(b), }
}

///|
fn channel(v : Double) -> Int32 {
  v.clamp(min=0.0, max=255.0).to_int()
}

///|
/// CSS hex colour of `c`, as `#rrggbb`.
pub fn Rgb::to_css(self : Rgb) -> String {
  "#" + hex2(self.r) + hex2(self.g) + hex2(self.b)
}

///|
/// Two lowercase hex digits of `v`, clamped to one byte.
fn hex2(v : Int32) -> String {
  hex_digit(v / 16) + hex_digit(v % 16)
}

///|
/// Lowercase hex digit of `d & 0xf`, computed without character lookup: a
/// `Char` built from a code point does not survive string concatenation on
/// every backend, so the digit is chosen from literals.
fn hex_digit(d : Int32) -> String {
  match d & 0xf {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
/// Terminal background colour for a water particle, as an ANSI truecolor escape.
pub fn water_ansi(
  y : Double,
  p : Double,
  v : Double,
  height : Double,
) -> String {
  let c = water_color(y, p, v, height)
  "\u{1b}[48;2;\{c.r};\{c.g};\{c.b}m"
}

///|
/// ANSI escape that clears the terminal.
pub fn clear_screen() -> String {
  "\u{1b}[2J\u{1b}[H"
}

///|
/// ANSI escape that hides the cursor.
pub fn hide_cursor() -> String {
  "\u{1b}[?25l"
}

///|
/// ANSI escape that restores the cursor.
pub fn show_cursor() -> String {
  "\u{1b}[?25h"
}
