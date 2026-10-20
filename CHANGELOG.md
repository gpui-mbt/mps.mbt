# Changelog

## 0.1.0

### Added

- MoonBit MPS foundation: `Vec2`, fixed-decimal formatting, deterministic RNG,
  uniform-grid neighbour search with Verlet lists, CSR sparse matrix with a
  masked Jacobi-preconditioned conjugate gradient.
- Dam-break scene with wall rings, reference density, MPS kernels, viscosity,
  CFL time stepping and typed step status.
- Deterministic kinematic demo mode used by the hosts.
- Frame rendering: tab-separated snapshots, water palette, bitmap and terminal
  output.
- Native terminal host with `--animate` and headless snapshot modes.
- Browser host: a `wasm-gc` session module with a `foreign_library` export, and a
  Canvas viewer that replays each 300-step session at 60 fps.
- `tools/smoke.sh` cross-backend gate and CI for native, `wasm-gc` and `js`.

### Known issues

- The full MPS pressure step (`Params::mps()`) does not build pressure in a
  hydrostatic column yet; see `docs/physics-status.md`.
