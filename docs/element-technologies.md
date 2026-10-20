# MPS を MoonBit で動かすのに不足していた要素技術

Moving Particle Semi-implicit 法（MPS 法）を MoonBit で native とブラウザの両方で動かすまでに、言語・ツールチェーン・自前実装のどれが足りなかったかを、実際に測った結果にもとづいて整理する。

結論から言うと、**MoonBit 言語とツールチェーン側の不足は無い**。不足していたのは次の 8 系統である。いずれも `moonbitlang/*` と core だけで内製でき、この repo の各パッケージがその実装になっている。

| # | 要素技術 | 状況 | この repo での実装 |
|---|---------|------|-------------------|
| 1 | 数値基盤（ベクトル・固定桁出力・乱数） | `Vec2` も固定桁フォーマッタも標準には無い。`Double` の補間文字列は backend で揃うが、`Int`/`Char` は揃わない | `core/vec2.mbt`, `core/format.mbt`, `core/rng.mbt` |
| 2 | 近傍探索 | 無い。相互作用半径 4 粒子分・粒子数 600 程度でも O(N²) は避けたい | `core/grid.mbt`（一様グリッド CSR）, `core/neighbor.mbt`（Verlet リスト） |
| 3 | 疎行列ソルバ | 無い。圧力ポアソン方程式は必須 | `mps/matrix.mbt`（CSR + Jacobi 前処理 CG、active マスク付き） |
| 4 | 流体モデル | 無い | `mps/*.mbt`（カーネル、数密度、粘性、CFL、圧力 ICP、勾配補正） |
| 5 | 描画 | 無い。文字端末も Canvas も自前 | `render/*.mbt`（Frame、palette、bitmap、terminal、snapshot） |
| 6 | ホスト I/O | core にあるのは `println` / `eprintln` だけ。`%print` は無い。`moonbitlang/x` の `sys` は wasm-gc で `env` 経由の import を増やす | `host/native`（cli + 1 行 1 回の再描画アニメーション）、`host/browser`（`spectest.print_char` のみを import） |
| 7 | wasm のホスト連携 | `moon bundle --target wasm-gc` は不可（`wasm.core` しか出ない）。関数の wasm エクスポートは `pkgtype(kind: "foreign_library")` + `#export_name` でだけ可能 | `host/browser`（セッション単位の実行）+ `web/`（Canvas 表示） |
| 8 | 移植性の検証 | native と wasm-gc の出力一致を見る仕組みが無い | `tools/smoke.sh`, `.github/workflows/ci.yml` |

## 実測した落とし穴

以下はどれも実際にこの repo を作る途中で踏んだもので、`docs/` に残す価値がある。

1. **backend で文字列化が違う。** `Double` の補間文字列（`"\{x}"`）は native / wasm-gc / js で完全に一致する（`0.3333333333333333`, `1e+21`, `NaN`, `Infinity`）。一方、`Int` の補間は native では `55` だが、`s.length()` で見ると 2 なのに連結後は `\u0037\u0037` のように code unit 数値列になる経路がある。`Char` の連結も同様に壊れる（`digits[hi].to_string() + digits[lo].to_string()` が `"#5456575098"` を返した）。**snapshot の数値は必ず `core.fmt_fixed` を通す**ことで回避している。
2. **`println` の実体は 1 個の print しか無い。** wasm-gc の import は `spectest.print_char` だけで、native は libc の `printf` 経由。`%print`（改行なし）はコンパイラ組み込みに存在しないため、再描画は 1 フレーム 1 回の `println` で出す設計にした。
3. **`extern "js"` は wasm-gc でエラーになる**（`extern "js" is unsupported in wasm-gc backend`）。1 つのモジュールを全 backend でビルドするなら `extern "js"` は使えない。
4. **`pkgtype(kind: "executable")` は `_start` しかエクスポートしない。** JS から関数を呼ぶには `pkgtype(kind: "foreign_library")` + `#export_name("...")` が必要。`Array[Double]` を跨ぎ渡す FFI はこの環境では `type incompatibility when transforming from/to JS` で失敗したため、座標は `FRAME` 行（テキスト）で渡している。
5. **`moon bundle --target wasm-gc` は `wasm.core` しか出さない。** 生の `.wasm` をブラウザの `WebAssembly.instantiate` に直接渡すのが現実的。
6. **`Int` の `%` は Euclidean**（`15 % 5 == 0`）、`Double::floor` は `trunc` ベースの実装、`Double::clamp` は境界で端点を返す。グリッド索引・固定桁出力はこれらに依存しない形で書いている。
7. **`Char` の code point 構築が backend で安定しない**（`unsafe_to_char` 系）。文字はリテラルの選択で作る。

## 自作が必要だった理由（依存を入れなかった理由）

- `moonbitlang/core` 以外の mooncake は、この環境の registry に限られることと、wasm-gc 向けの import を増やさないことを優先して使っていない。
- 乱数・行列・描画は数十〜数百行で作れて、テストで固定できる規模である。
- 外部依存を入れないことで、`moon check --target wasm-gc --deny-warn` の警告ゼロと import 1 個（`spectest.print_char`）を保てる。

## 不足が残っているもの

- **圧力ソルバの数値的検証。** `docs/physics-status.md` の通り、`Params::mps()` の完全な MPS ステップは静止水柱で圧力が立たないまま実験的に残している。デモは決定的な `Mode::Kinematic` で動かしている。
- **大きな粒子数。** 600 粒子・300 ステップ/セッションで、ブラウザでは 1 秒弱で計算し、3 秒分を 60 fps で再生する。数千粒子は空間ハッシュのチューニングが必要。
- **バイナリでの座標受け渡し。** wasm-gc の `Array[Double]`/`FixedArray[Double]` を JS から渡す FFI が通らなかったため、座標はテキストの `FRAME` 行。バイナリ化できればセッションを長くできる。

## 再現手順

```sh
moon build --release --target native
./_build/native/release/build/cmd/terminal/terminal.exe --animate --steps 400

moon build --release --target wasm-gc
node tools/serve.mjs 8080 .
# ブラウザで http://127.0.0.1:8080/web/ を開く

sh tools/smoke.sh          # native と wasm-gc の FRAME 行が 1 バイトも違わないこと
```
