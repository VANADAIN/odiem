package utils_tests

import "core:testing"
import "core:math/big"
import "core:mem"
import "core:encoding/hex"
import utils "../"
import types "../../types"

@(test)
test_sign_and_recover :: proc(t: ^testing.T) {
	// Known test private key (DO NOT use in production)
	pk_hex := "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
	pk_bytes, pk_ok := hex.decode(transmute([]u8)pk_hex, context.temp_allocator)
	testing.expect(t, pk_ok, "decode privkey hex")

	privkey: [32]u8
	mem.copy(&privkey, raw_data(pk_bytes), 32)

	message := transmute([]u8)string("hello world")

	sig, sign_err := utils.sign_message(privkey, message)
	testing.expect(t, sign_err == .None, "sign should succeed")

	// Recover the address
	recovered, recover_err := utils.recover_address(message, sig)
	testing.expect(t, recover_err == .None, "recover should succeed")

	// The expected address for this private key is:
	// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (Hardhat account #0)
	expected_addr, addr_ok := utils.get_address("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
	testing.expect(t, addr_ok, "parse expected address")

	testing.expect(t, recovered == expected_addr, "recovered address should match signer")
}

@(test)
test_sign_hash_deterministic :: proc(t: ^testing.T) {
	pk_hex := "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
	pk_bytes, _ := hex.decode(transmute([]u8)pk_hex, context.temp_allocator)
	privkey: [32]u8
	mem.copy(&privkey, raw_data(pk_bytes), 32)

	message := transmute([]u8)string("test message")

	sig1, err1 := utils.sign_message(privkey, message)
	sig2, err2 := utils.sign_message(privkey, message)

	testing.expect(t, err1 == .None && err2 == .None, "both signs succeed")
	testing.expect(t, sig1.r == sig2.r, "r should be deterministic")
	testing.expect(t, sig1.s == sig2.s, "s should be deterministic")
	testing.expect(t, sig1.v == sig2.v, "v should be deterministic")
}

@(test)
test_recover_wrong_message :: proc(t: ^testing.T) {
	pk_hex := "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
	pk_bytes, _ := hex.decode(transmute([]u8)pk_hex, context.temp_allocator)
	privkey: [32]u8
	mem.copy(&privkey, raw_data(pk_bytes), 32)

	message := transmute([]u8)string("correct message")
	sig, _ := utils.sign_message(privkey, message)

	// Recover with wrong message should give a different address
	wrong_msg := transmute([]u8)string("wrong message")
	recovered, err := utils.recover_address(wrong_msg, sig)
	testing.expect(t, err == .None, "recover should succeed")

	expected_addr, _ := utils.get_address("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
	testing.expect(t, recovered != expected_addr, "wrong message should recover different address")
}
