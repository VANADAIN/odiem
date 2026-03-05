package utils_tests

import "core:testing"
import "core:math/big"
import utils "../"

@(test)
test_parse_ether_integer :: proc(t: ^testing.T) {
	result: big.Int
	defer big.destroy(&result)
	ok := utils.parse_ether("1", &result)
	testing.expect(t, ok, "parse 1 ether")

	// 1 ether = 10^18 wei
	expected: big.Int
	defer big.destroy(&expected)
	big.atoi(&expected, "1000000000000000000")
	cmp, _ := big.cmp(&result, &expected)
	testing.expect(t, cmp == 0, "should be 10^18 wei")
}

@(test)
test_parse_ether_decimal :: proc(t: ^testing.T) {
	result: big.Int
	defer big.destroy(&result)
	ok := utils.parse_ether("1.5", &result)
	testing.expect(t, ok, "parse 1.5 ether")

	expected: big.Int
	defer big.destroy(&expected)
	big.atoi(&expected, "1500000000000000000")
	cmp, _ := big.cmp(&result, &expected)
	testing.expect(t, cmp == 0, "should be 1.5 * 10^18 wei")
}

@(test)
test_parse_ether_small :: proc(t: ^testing.T) {
	result: big.Int
	defer big.destroy(&result)
	ok := utils.parse_ether("0.001", &result)
	testing.expect(t, ok, "parse 0.001 ether")

	expected: big.Int
	defer big.destroy(&expected)
	big.atoi(&expected, "1000000000000000")
	cmp, _ := big.cmp(&result, &expected)
	testing.expect(t, cmp == 0, "should be 10^15 wei")
}

@(test)
test_format_ether_integer :: proc(t: ^testing.T) {
	wei: big.Int
	defer big.destroy(&wei)
	big.atoi(&wei, "1000000000000000000")

	result, ok := utils.format_ether(&wei)
	defer delete(result)
	testing.expect(t, ok, "format")
	testing.expect_value(t, result, "1")
}

@(test)
test_format_ether_decimal :: proc(t: ^testing.T) {
	wei: big.Int
	defer big.destroy(&wei)
	big.atoi(&wei, "1500000000000000000")

	result, ok := utils.format_ether(&wei)
	defer delete(result)
	testing.expect(t, ok, "format")
	testing.expect_value(t, result, "1.5")
}

@(test)
test_format_ether_small :: proc(t: ^testing.T) {
	wei: big.Int
	defer big.destroy(&wei)
	big.set(&wei, 1)

	result, ok := utils.format_ether(&wei)
	defer delete(result)
	testing.expect(t, ok, "format")
	testing.expect_value(t, result, "0.000000000000000001")
}

@(test)
test_parse_gwei :: proc(t: ^testing.T) {
	result: big.Int
	defer big.destroy(&result)
	ok := utils.parse_gwei("30", &result)
	testing.expect(t, ok, "parse 30 gwei")

	expected: big.Int
	defer big.destroy(&expected)
	big.atoi(&expected, "30000000000")
	cmp, _ := big.cmp(&result, &expected)
	testing.expect(t, cmp == 0, "30 gwei = 30 * 10^9 wei")
}

@(test)
test_format_gwei :: proc(t: ^testing.T) {
	wei: big.Int
	defer big.destroy(&wei)
	big.atoi(&wei, "30000000000")

	result, ok := utils.format_gwei(&wei)
	defer delete(result)
	testing.expect(t, ok, "format")
	testing.expect_value(t, result, "30")
}

@(test)
test_ether_roundtrip :: proc(t: ^testing.T) {
	original: big.Int
	defer big.destroy(&original)
	big.atoi(&original, "123456789000000000")

	formatted, ok1 := utils.format_ether(&original)
	defer delete(formatted)
	testing.expect(t, ok1, "format")

	parsed: big.Int
	defer big.destroy(&parsed)
	ok2 := utils.parse_ether(formatted, &parsed)
	testing.expect(t, ok2, "parse back")

	cmp, _ := big.cmp(&original, &parsed)
	testing.expect(t, cmp == 0, "roundtrip")
}
