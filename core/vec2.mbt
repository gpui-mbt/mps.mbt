///|
/// A two-dimensional vector stored by value in `Double` precision.
///
/// All MPS arithmetic — positions, velocities, pressure gradients and kernel
/// distances — is expressed with `Vec2` so that summation order and rounding
/// stay identical across the `native`, `wasm-gc` and `js` backends.
pub(all) struct Vec2 {
  x : Double
  y : Double
}

///|
pub extend Vec2 with Show::{to_string, output}

///|
pub impl Show for Vec2 with fn to_string(self : Vec2) {
  "(" + fmt_coord(self.x) + ", " + fmt_coord(self.y) + ")"
}

///|
pub extend Vec2 with Add::{add}

///|
pub impl Add for Vec2 with fn add(self : Vec2, other : Vec2) {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
pub extend Vec2 with Sub::{sub}

///|
pub impl Sub for Vec2 with fn sub(self : Vec2, other : Vec2) {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
pub extend Vec2 with Neg::{neg}

///|
pub impl Neg for Vec2 with fn neg(self : Vec2) {
  { x: -self.x, y: -self.y, }
}

///|
pub fn Vec2::new(x : Double, y : Double) -> Vec2 {
  { x, y, }
}

///|
pub fn Vec2::zero() -> Vec2 {
  { x: 0.0, y: 0.0, }
}

///|
pub fn Vec2::splat(v : Double) -> Vec2 {
  { x: v, y: v, }
}

///|
/// Scalar multiplication.
///
/// Kept as a named method rather than a `Mul` impl: the `Mul` trait's
/// signature pairs two values of the same type, which a `Vec2 × Double`
/// product does not satisfy.
pub fn Vec2::scale(self : Vec2, s : Double) -> Vec2 {
  { x: self.x * s, y: self.y * s, }
}

///|
pub fn Vec2::dot(self : Vec2, other : Vec2) -> Double {
  self.x * other.x + self.y * other.y
}

///|
/// Squared Euclidean length.
///
/// Callers that only compare distances use this to avoid a square root and to
/// keep the `dist2 < r2` test exact.
pub fn Vec2::len_sq(self : Vec2) -> Double {
  self.x * self.x + self.y * self.y
}

///|
pub fn Vec2::len(self : Vec2) -> Double {
  self.len_sq().sqrt()
}

///|
/// Unit vector in the same direction, or zero when the length is not a finite
/// positive number.
pub fn Vec2::normalize(self : Vec2) -> Vec2 {
  let len = self.len()
  if len == 0.0 || len.is_nan() || len.is_inf() {
    Vec2::zero()
  } else {
    self.scale(1.0 / len)
  }
}

///|
/// Squared distance between two points.
pub fn dist2(a : Vec2, b : Vec2) -> Double {
  (a - b).len_sq()
}

///|
/// Largest component magnitude out of two vectors.
///
/// The Verlet-list rebuild test compares per-particle displacement against a
/// skin distance with this helper.
pub fn max_abs(a : Vec2, b : Vec2) -> Double {
  a.x.abs().max(b.x.abs()).max(a.y.abs().max(b.y.abs()))
}
