///|
test "fmt_fixed rounds half away from zero" {
  inspect(@core.fmt_fixed(0.0, 4), content="0.0000")
  inspect(@core.fmt_fixed(1.0, 2), content="1.00")
  inspect(@core.fmt_fixed(-1.0, 2), content="-1.00")
  inspect(@core.fmt_fixed(0.00005, 4), content="0.0001")
  inspect(@core.fmt_fixed(0.00004999, 4), content="0.0000")
  inspect(@core.fmt_fixed(-2.5, 0), content="-3")
  inspect(@core.fmt_fixed(2.5, 0), content="3")
  inspect(@core.fmt_fixed(2.4, 0), content="2")
}

///|
test "fmt_fixed keeps a fixed digit count" {
  inspect(@core.fmt_fixed(1234.5, 9), content="1234.500000000")
  inspect(@core.fmt_fixed(0.1, 9), content="0.100000000")
  inspect(@core.fmt_fixed(0.0000123, 9), content="0.000012300")
  inspect(@core.fmt_fixed(1234567.0, 0), content="1234567")
  inspect(@core.fmt_fixed(123456789012.0, 0), content="123456789012")
  inspect(@core.fmt_fixed(1234567890123456.0, 0), content="1234567890123456")
}

///|
test "fmt_fixed clamps digits and renders negative zero" {
  inspect(@core.fmt_fixed(1.0, -3), content="1")
  inspect(@core.fmt_fixed(1.0, 100), content="1.000000000")
  inspect(@core.fmt_fixed(-0.0, 3), content="0.000")
  inspect(@core.fmt_fixed(-0.00001, 4), content="0.0000")
}

///|
test "fmt_fixed renders non-finite values" {
  inspect(@core.fmt_fixed(0.0 / 0.0, 4), content="NaN")
  inspect(@core.fmt_fixed(1.0 / 0.0, 4), content="Infinity")
  inspect(@core.fmt_fixed(-1.0 / 0.0, 4), content="-Infinity")
}

///|
test "fmt_escape escapes line-breaking characters" {
  inspect(@core.fmt_escape("a\\b\tc\nd\re"), content="a\\\\b\\tc\\nd\\re")
  inspect(@core.fmt_escape("水"), content="水")
}
