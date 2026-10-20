///|
/// Renders `frame` for a character terminal.
///
/// Each character cell covers a part of the tank; a cell that holds at least
/// one fluid particle is painted with its colour as an ANSI background, an
/// empty cell stays a space. The rows are returned top row first.
pub fn render_terminal(
  frame : Frame,
  cols : Int32,
  rows : Int32,
) -> Array[String] {
  let w = cols.max(8)
  let h = rows.max(4)
  let out : Array[String] = []
  let scale = (w.to_double() / frame.width).min(h.to_double() / frame.height)
  let offset_x = (w.to_double() - frame.width * scale) * 0.5
  let offset_y = (h.to_double() - frame.height * scale) * 0.5
  // Grid of cells holding the colour of the last particle that landed there.
  let cells = Array::make(w * h, "")
  for i = 0; i < frame.fluid_x.length(); i = i + 1 {
    let cx = (offset_x + frame.fluid_x[i] * scale).to_int()
    let cy = (offset_y + frame.fluid_y[i] * scale).to_int()
    if cx >= 0 && cx < w && cy >= 0 && cy < h {
      cells[cy * w + cx] = water_ansi(
        frame.fluid_y[i],
        frame.max_pressure,
        frame.max_speed,
        frame.height,
      )
    }
  }
  for row = 0; row < h; row = row + 1 {
    let y = h - 1 - row
    let line = StringBuilder()
    for x = 0; x < w; x = x + 1 {
      let ansi = cells[y * w + x]
      if ansi == "" {
        line.write_string("\u{1b}[0m ")
      } else {
        line.write_string(ansi)
        line.write_string(" ")
      }
    }
    line.write_string("\u{1b}[0m")
    out.push(line.to_string())
  }
  out
}

///|
/// Joins terminal rows and adds the status footer.
pub fn terminal_text(frame : Frame, cols : Int32, rows : Int32) -> String {
  let lines = render_terminal(frame, cols, rows)
  let buf = StringBuilder()
  for line in lines {
    buf.write_string(line)
    buf.write_string("\n")
  }
  buf.write_string("t=")
  buf.write_string(@core.fmt_fixed(frame.time, 3))
  buf.write_string(" s   step ")
  buf.write_string(@core.fmt_fixed(frame.step.to_double(), 0))
  buf.write_string("   pmax=")
  buf.write_string(@core.fmt_fixed(frame.max_pressure, 0))
  buf.write_string(" Pa   vmax=")
  buf.write_string(@core.fmt_fixed(frame.max_speed, 3))
  buf.write_string(" m/s   ")
  buf.write_string(frame.status)
  buf.to_string()
}
