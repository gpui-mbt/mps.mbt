///|
/// A PCG-style 64-bit linear congruential generator (LCG) with a scrambled
/// output function.
///
/// The MPS initial layout needs a small, deterministic amount of randomness
/// for particle jitter. A generator implemented on `UInt64` produces the same
/// sequence on every MoonBit backend, which the native-versus-`wasm-gc`
/// snapshot comparison relies on.
pub struct Rng {
  mut state : UInt64
}

///|
pub fn Rng::new(seed : UInt64) -> Rng {
  Rng::{ state: seed, }
}

///|
/// Advances the state and returns the next 64-bit value.
pub fn Rng::next_u64(self : Rng) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  let x = self.state
  // SplitMix64 finalizer: a bijective mix of the LCG state.
  let y = ((x >> 30) ^ x) * 0xBF58476D1CE4E5B9UL
  let z = ((y >> 27) ^ y) * 0x94D049BB133111EBUL
  (z >> 31) ^ z
}

///|
/// Uniform value in `[0, 1)` with 53 bits of precision.
pub fn Rng::next_double(self : Rng) -> Double {
  // 2^-53 expressed as a division keeps the constant free of decimal literals.
  let unit = 1.0 / 9007199254740992.0
  (self.next_u64() >> 11).to_double() * unit
}

///|
/// Uniform value in `[-scale, scale)`.
pub fn Rng::jitter(self : Rng, scale : Double) -> Double {
  (self.next_double() * 2.0 - 1.0) * scale
}
