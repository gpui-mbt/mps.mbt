///|
/// MPS interaction weight `w(r) = re/r - 1` for `0 < r < re`, and zero beyond.
///
/// This kernel is the standard choice in the pressure and gradient models of
/// Koshizuka & Oka (1996). The Laplacian model needs `r²w = r re - r²`, which is
/// bounded on `[0, re]`, so the stencil of a particle stays finite even when a
/// neighbour passes through `r = 0`.
///
/// The singularity at `r = 0` is defined as zero here so coincident particles
/// cannot produce infinite densities or gradients; callers skip `r2 == 0`.
pub fn weight(r2 : Double, re2 : Double) -> Double {
  if r2 <= 0.0 || r2 >= re2 {
    return 0.0
  }
  let r = r2.sqrt()
  let re = re2.sqrt()
  re / r - 1.0
}
