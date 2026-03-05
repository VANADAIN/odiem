package utils_tests

import "core:testing"
import "core:mem"
import utils "../"
import types "../../types"

@(test)
test_is_address_valid :: proc(t: ^testing.T) {
	testing.expect(t, utils.is_address("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"), "valid address")
}

@(test)
test_is_address_invalid_length :: proc(t: ^testing.T) {
	testing.expect(t, !utils.is_address("0xdead"), "too short")
}

@(test)
test_is_address_no_prefix :: proc(t: ^testing.T) {
	testing.expect(t, !utils.is_address("d8dA6BF26964aF9D7eEd9e03E53415D37aA96045"), "missing 0x")
}

@(test)
test_is_address_invalid_chars :: proc(t: ^testing.T) {
	testing.expect(t, !utils.is_address("0xGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"), "non-hex chars")
}

@(test)
test_get_address_valid :: proc(t: ^testing.T) {
	addr, ok := utils.get_address("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, addr[0], u8(0xd8))
	testing.expect_value(t, addr[1], u8(0xdA))
}

@(test)
test_get_address_invalid :: proc(t: ^testing.T) {
	_, ok := utils.get_address("not an address")
	testing.expect(t, !ok, "should fail")
}

@(test)
test_checksum_address_vitalik :: proc(t: ^testing.T) {
	// Vitalik's address: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
	addr, ok := utils.get_address("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
	testing.expect(t, ok, "parse")

	checksum := utils.to_checksum_address(addr)
	defer delete(checksum)
	testing.expect_value(t, checksum, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
}

@(test)
test_checksum_address_all_caps :: proc(t: ^testing.T) {
	// Known EIP-55 test vector: all-caps address
	// 0x52908400098527886E0F7030069857D2E4169EE7
	addr, ok := utils.get_address("0x52908400098527886E0F7030069857D2E4169EE7")
	testing.expect(t, ok, "parse")

	checksum := utils.to_checksum_address(addr)
	defer delete(checksum)
	testing.expect_value(t, checksum, "0x52908400098527886E0F7030069857D2E4169EE7")
}

@(test)
test_checksum_address_zero :: proc(t: ^testing.T) {
	addr := types.ADDRESS_ZERO
	checksum := utils.to_checksum_address(addr)
	defer delete(checksum)
	testing.expect_value(t, checksum, "0x0000000000000000000000000000000000000000")
}
