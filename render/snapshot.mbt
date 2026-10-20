///|
/// Serialises `frame` as one line of text.
///
/// The format is tab separated so a host can split it without a JSON parser:
///
/// `FRAME <step> <time> <width> <height> <max_pressure> <max_speed> <status>
/// <fluid_count> <x> <y> <x> <y> ...`
///
/// Every number goes through `@core.fmt_fixed` (seven decimals, about ten
/// micrometres at the dam-break scale), so the line is byte-identical on the
/// native and `wasm-gc` backends. The line never contains newlines or tabs
/// inside `status`.
pub fn snapshot_line(frame : Frame) -> String {
  let out = StringBuilder()
  out.write_string("FRAME")
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.step.to_double(), 0))
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.time, 7))
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.width, 7))
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.height, 7))
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.max_pressure, 7))
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.max_speed, 7))
  out.write_string("\t")
  out.write_string(frame.status)
  out.write_string("\t")
  out.write_string(@core.fmt_fixed(frame.fluid_x.length().to_double(), 0))
  out.write_string(" ")
  for i = 0; i < frame.fluid_x.length(); i = i + 1 {
    if i > 0 {
      out.write_string(" ")
    }
    out.write_string(@core.fmt_fixed(frame.fluid_x[i], 7))
    out.write_string(" ")
    out.write_string(@core.fmt_fixed(frame.fluid_y[i], 7))
  }
  out.to_string()
}
