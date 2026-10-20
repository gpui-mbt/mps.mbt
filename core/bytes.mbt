///|
/// A growable byte buffer used by the browser host to hand frame data to
/// JavaScript.
///
/// The buffer keeps its storage between frames so a running animation does not
/// allocate for every step; only the length changes.
pub(all) struct ByteBuffer {
  /// Backing storage; only the first `length` bytes are meaningful.
  mut bytes : Array[Byte]
  /// Number of bytes written.
  mut length : Int32
}

///|
/// Empty buffer with a small initial capacity.
pub fn ByteBuffer::new() -> ByteBuffer {
  { bytes: Array::make(64, 0), length: 0, }
}

///|
/// Number of bytes currently written.
pub fn ByteBuffer::len(self : ByteBuffer) -> Int32 {
  self.length
}

///|
/// Drops the content, keeping the allocated storage.
pub fn ByteBuffer::clear(self : ByteBuffer) -> Unit {
  self.length = 0
}

///|
/// Appends one byte.
pub fn ByteBuffer::write_byte(self : ByteBuffer, value : Int32) -> Unit {
  self.ensure(1)
  self.bytes[self.length] = value.to_byte()
  self.length = self.length + 1
}

///|
/// Appends a little-endian single-precision float.
///
/// `Float` is 32-bit on every backend MoonBit targets, so the four-byte layout
/// is what JavaScript's `Float32Array` reads.
pub fn ByteBuffer::write_f32(self : ByteBuffer, value : Double) -> Unit {
  let f = float_of(value)
  let bits = f.reinterpret_as_uint()
  self.write_byte((bits & 0xFF).reinterpret_as_int())
  self.write_byte(((bits >> 8) & 0xFF).reinterpret_as_int())
  self.write_byte(((bits >> 16) & 0xFF).reinterpret_as_int())
  self.write_byte(((bits >> 24) & 0xFF).reinterpret_as_int())
}

///|
/// Widens `value` to a single-precision float through the core intrinsic.
fn float_of(value : Double) -> Float = "%f64.to_f32"

///|
/// Ensures room for `extra` more bytes.
fn ByteBuffer::ensure(self : ByteBuffer, extra : Int32) -> Unit {
  let needed = self.length + extra
  if needed <= self.bytes.length() {
    return
  }
  let mut capacity = self.bytes.length().max(64)
  while capacity < needed {
    capacity = capacity * 2
  }
  let grown : Array[Byte] = Array::make(capacity, 0)
  for i = 0; i < self.length; i = i + 1 {
    grown[i] = self.bytes[i]
  }
  self.bytes = grown
}
