package utils_tests

import "core:testing"
import "core:math/big"
import utils "../"

@(test)
test_to_hex :: proc(t: ^testing.T) {
	data := [?]u8{0xDE, 0xAD, 0xBE, 0xEF}
	result := utils.to_hex(data[:])
	defer delete(result)
	testing.expect_value(t, result, "0xdeadbeef")
}

@(test)
test_to_hex_empty :: proc(t: ^testing.T) {
	result := utils.to_hex(nil)
	defer delete(result)
	testing.expect_value(t, result, "0x")
}

@(test)
test_from_hex_with_prefix :: proc(t: ^testing.T) {
	data, ok := utils.from_hex("0xdeadbeef")
	defer delete(data)
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, len(data), 4)
	testing.expect_value(t, data[0], u8(0xDE))
	testing.expect_value(t, data[3], u8(0xEF))
}

@(test)
test_from_hex_without_prefix :: proc(t: ^testing.T) {
	data, ok := utils.from_hex("ABCD")
	defer delete(data)
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, len(data), 2)
	testing.expect_value(t, data[0], u8(0xAB))
}

@(test)
test_from_hex_empty :: proc(t: ^testing.T) {
	data, ok := utils.from_hex("0x")
	testing.expect(t, ok, "empty hex is valid")
	testing.expect(t, data == nil, "should be nil")
}

@(test)
test_big_int_to_hex :: proc(t: ^testing.T) {
	val: big.Int
	defer big.destroy(&val)
	big.set(&val, 255)

	result, ok := utils.big_int_to_hex(&val)
	defer delete(result)
	testing.expect(t, ok, "should convert")
	testing.expect_value(t, result, "0xff")
}

@(test)
test_big_int_to_hex_zero :: proc(t: ^testing.T) {
	val: big.Int
	defer big.destroy(&val)

	result, ok := utils.big_int_to_hex(&val)
	defer delete(result)
	testing.expect(t, ok, "should convert")
	testing.expect_value(t, result, "0x0")
}

@(test)
test_hex_to_big_int :: proc(t: ^testing.T) {
	val: big.Int
	defer big.destroy(&val)
	ok := utils.hex_to_big_int("0xff", &val)
	testing.expect(t, ok, "should parse")

	expected: big.Int
	defer big.destroy(&expected)
	big.set(&expected, 255)
	cmp, _ := big.cmp(&val, &expected)
	testing.expect(t, cmp == 0, "should be 255")
}

@(test)
test_hex_to_big_int_odd_length :: proc(t: ^testing.T) {
	val: big.Int
	defer big.destroy(&val)
	ok := utils.hex_to_big_int("0xf", &val)
	testing.expect(t, ok, "should parse odd hex")

	expected: big.Int
	defer big.destroy(&expected)
	big.set(&expected, 15)
	cmp, _ := big.cmp(&val, &expected)
	testing.expect(t, cmp == 0, "should be 15")
}

@(test)
test_hex_roundtrip :: proc(t: ^testing.T) {
	original: big.Int
	defer big.destroy(&original)
	big.set(&original, 123456789)

	hex_str, ok1 := utils.big_int_to_hex(&original)
	defer delete(hex_str)
	testing.expect(t, ok1, "to hex")

	result: big.Int
	defer big.destroy(&result)
	ok2 := utils.hex_to_big_int(hex_str, &result)
	testing.expect(t, ok2, "from hex")

	cmp, _ := big.cmp(&original, &result)
	testing.expect(t, cmp == 0, "roundtrip")
}
