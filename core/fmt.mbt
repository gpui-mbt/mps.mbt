///|
/// Renders `value` with exactly `digits` fractional digits using a fixed,
/// backend-independent algorithm.
///
/// The three MoonBit backends stringify integers and characters differently
/// (`Int` interpolation goes through the host language, so `native` prints a
/// different digit sequence than `wasm-gc`), which makes core `println` output
/// unusable as a cross-target reference. Simulation snapshots therefore format
/// every number through this function, which only uses `Double` arithmetic and
/// integer digit extraction expressed as `Double` operations.
///
/// Rounding is half away from zero. `NaN`, `Infinity` and `-Infinity` are
/// rendered as `NaN`, `Infinity` and `-Infinity`; `digits` is clamped to
/// `0..=9` and negative zero renders as `0`.
pub fn fmt_fixed(value : Double, digits : Int32) -> String {
  let d = digits.clamp(min=0, max=9)
  if value.is_nan() {
    return "NaN"
  }
  if value == 1.0 / 0.0 {
    return "Infinity"
  }
  if value == -1.0 / 0.0 {
    return "-Infinity"
  }
  let sign = value < 0.0
  let scale = pow10(d).to_double()
  let scaled = (value.abs() * scale).round_half_away().to_uint64()
  let int_part = scaled / pow10u(d)
  let frac_part = scaled % pow10u(d)
  let buf = StringBuilder()
  if sign && scaled != 0UL {
    buf.write_string("-")
  }
  buf.write_string(u64_digits(int_part))
  if d > 0 {
    buf.write_string(".")
    let frac = u64_digits(frac_part)
    for i = 0; i < d - frac.length(); i = i + 1 {
      buf.write_string("0")
    }
    buf.write_string(frac)
  }
  buf.to_string()
}

///|
/// `10^n` for `0 <= n <= 9` as an `Int`, computed by repeated multiplication so
/// no integer literal conversion is involved.
fn pow10(n : Int32) -> Int32 {
  let mut p = 1
  for i = 0; i < n; i = i + 1 {
    p = p * 10
  }
  p
}

///|
/// `10^n` for `0 <= n <= 19` as a `UInt64`.
fn pow10u(n : Int32) -> UInt64 {
  let mut p = 1UL
  for i = 0; i < n; i = i + 1 {
    p = p * 10UL
  }
  p
}

///|
/// Rounds half away from zero on the magnitude.
fn Double::round_half_away(self : Double) -> Double {
  let floor = self - self % 1.0
  if self - floor >= 0.5 {
    floor + 1.0
  } else {
    floor
  }
}

///|
/// Decimal digits of a non-negative integer, without a leading sign or zeros
/// beyond the most significant digit.
///
/// Delegates to `UInt64`'s `Show`, which core implements in MoonBit itself, so
/// the digits are identical on every backend (only host-based integer
/// interpolation differs across backends).
fn u64_digits(value : UInt64) -> String {
  value.to_string()
}

///|
/// Formats a coordinate for snapshots: four fractional digits, which resolve
/// one particle spacing (`l0 = 0.01` in the dam-break scenario) to a hundredth
/// of `l0`.
pub fn fmt_coord(value : Double) -> String {
  fmt_fixed(value, 4)
}

///|
/// Escapes a string for the single-line snapshot format: `\` → `\\`, tab →
/// `\t`, newline → `\n`, carriage return → `\r`. Non-ASCII code points are
/// emitted verbatim so the line stays UTF-8.
pub fn fmt_escape(text : String) -> String {
  let buf = StringBuilder()
  for ch in text {
    match ch {
      '\\' => buf.write_string("\\\\")
      '\t' => buf.write_string("\\t")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}
