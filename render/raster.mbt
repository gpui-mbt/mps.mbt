///|
/// RGB bitmap of one frame.
///
/// Pixels are stored row-major from the bottom-left corner, three bytes per
/// pixel, which is the order the browser viewer needs after flipping vertically.
pub(all) struct Bitmap {
  width : Int32
  height : Int32
  /// `3 * width * height` bytes, `r`, `g`, `b` per pixel.
  pixels : Array[Int32]
}

///|
/// Renders `frame` into a `width` × `height` bitmap.
///
/// The world rectangle is mapped proportionally and centred, so a non-square
/// canvas keeps the tank square. Particles are splatted as a small square
/// whose side is one particle spacing in pixels (at least one pixel), so the
/// fluid stays continuous at any resolution. Later particles overwrite earlier
/// ones, which is deterministic because the frame order is fixed.
pub fn render_bitmap(frame : Frame, width : Int32, height : Int32) -> Bitmap {
  let w = width.max(1)
  let h = height.max(1)
  let pixels = Array::make(w * h * 3, 0)
  fill_background(pixels, w, h)
  let scale = (w.to_double() / frame.width).min(h.to_double() / frame.height)
  let offset_x = (w.to_double() - frame.width * scale) * 0.5
  let offset_y = (h.to_double() - frame.height * scale) * 0.5
  let splat = scale * 0.01
  let side = splat.to_int().max(1)
  for i = 0; i < frame.fluid_x.length(); i = i + 1 {
    let c = water_color(
      frame.fluid_y[i],
      frame.max_pressure,
      frame.max_speed,
      frame.height,
    )
    let px = (offset_x + frame.fluid_x[i] * scale).to_int()
    let py = (offset_y + frame.fluid_y[i] * scale).to_int()
    for dy = 0; dy < side; dy = dy + 1 {
      for dx = 0; dx < side; dx = dx + 1 {
        put_pixel(pixels, w, h, px + dx, py + dy, c)
      }
    }
  }
  { width: w, height: h, pixels, }
}

///|
fn fill_background(pixels : Array[Int32], w : Int32, h : Int32) -> Unit {
  for y = 0; y < h; y = y + 1 {
    // Vertical gradient from a pale sky at the top to a dark floor.
    let t = y.to_double() / h.max(1).to_double()
    let r = (28.0 + 22.0 * t).to_int()
    let g = (32.0 + 26.0 * t).to_int()
    let b = (40.0 + 30.0 * t).to_int()
    for x = 0; x < w; x = x + 1 {
      let k = (y * w + x) * 3
      pixels[k] = r
      pixels[k + 1] = g
      pixels[k + 2] = b
    }
  }
}

///|
fn put_pixel(
  pixels : Array[Int32],
  w : Int32,
  h : Int32,
  x : Int32,
  y : Int32,
  c : Rgb,
) -> Unit {
  if x < 0 || x >= w || y < 0 || y >= h {
    return
  }
  let k = (y * w + x) * 3
  pixels[k] = c.r
  pixels[k + 1] = c.g
  pixels[k + 2] = c.b
}
