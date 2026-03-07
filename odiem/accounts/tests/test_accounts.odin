package accounts_tests

import "core:testing"
import "core:encoding/json"
import "core:mem"
import "core:strings"
import acc "../"
import "../../types"
import "../../transport"

// Well-known test private key (DO NOT use in production)
// Private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// This is Hardhat/Anvil account #0
TEST_PRIVKEY :: [32]u8{
	0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
	0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
	0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
	0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80,
}

// Expected address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
TEST_ADDRESS :: types.Address{
	0xf3, 0x9F, 0xd6, 0xe5, 0x1a, 0xad, 0x88, 0xF6,
	0xF4, 0xce, 0x6a, 0xB8, 0x82, 0x72, 0x79, 0xcf,
	0xfF, 0xb9, 0x22, 0x66,
}

// --- Derive address ---

@(test)
test_derive_address :: proc(t: ^testing.T) {
	addr, err := acc.derive_address(TEST_PRIVKEY)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, addr, TEST_ADDRESS)
}

@(test)
test_derive_address_zero_key :: proc(t: ^testing.T) {
	zero_key: [32]u8
	_, err := acc.derive_address(zero_key)
	// Zero key may fail or produce an address; implementation-dependent
	// Just ensure it doesn't crash
	_ = err
}

// --- Private key account ---

@(test)
test_from_private_key :: proc(t: ^testing.T) {
	account, err := acc.from_private_key(TEST_PRIVKEY)
	defer acc.private_key_destroy(&account)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, account.address, TEST_ADDRESS)
	testing.expect(t, account.sign_hash != nil, "should have sign_hash")
	testing.expect(t, account.ctx != nil, "should have ctx")
}

@(test)
test_private_key_sign :: proc(t: ^testing.T) {
	account, err := acc.from_private_key(TEST_PRIVKEY)
	defer acc.private_key_destroy(&account)
	testing.expect(t, err == .None, "create should succeed")

	// Sign a known hash
	hash: types.Hash
	hash[0] = 0xAB
	hash[31] = 0xCD

	sig, ok := account.sign_hash(account.ctx, hash)
	testing.expect(t, ok, "sign should succeed")
	// v should be 0 or 1 (low-level recovery id)
	testing.expect(t, sig.v == 0 || sig.v == 1, "v should be 0 or 1")
	// r and s should be non-zero
	r_nonzero := false
	for b in sig.r {
		if b != 0 { r_nonzero = true; break }
	}
	testing.expect(t, r_nonzero, "r should be non-zero")

	s_nonzero := false
	for b in sig.s {
		if b != 0 { s_nonzero = true; break }
	}
	testing.expect(t, s_nonzero, "s should be non-zero")
}

@(test)
test_private_key_sign_deterministic :: proc(t: ^testing.T) {
	account, _ := acc.from_private_key(TEST_PRIVKEY)
	defer acc.private_key_destroy(&account)

	hash: types.Hash
	hash[0] = 0x01

	sig1, ok1 := account.sign_hash(account.ctx, hash)
	sig2, ok2 := account.sign_hash(account.ctx, hash)
	testing.expect(t, ok1 && ok2, "both signs should succeed")
	// RFC 6979 should produce deterministic signatures
	testing.expect_value(t, sig1.r, sig2.r)
	testing.expect_value(t, sig1.s, sig2.s)
	testing.expect_value(t, sig1.v, sig2.v)
}

@(test)
test_private_key_destroy :: proc(t: ^testing.T) {
	account, _ := acc.from_private_key(TEST_PRIVKEY)
	acc.private_key_destroy(&account)
	testing.expect(t, account.ctx == nil, "ctx should be nil after destroy")
}

// --- Local sign hash ---

@(test)
test_local_sign_hash :: proc(t: ^testing.T) {
	hash: types.Hash
	hash[0] = 0xFF

	sig, err := acc.local_sign_hash(TEST_PRIVKEY, hash)
	testing.expect(t, err == .None, "should succeed")
	testing.expect(t, sig.v == 0 || sig.v == 1, "v should be 0 or 1")
}

// --- JSON-RPC account ---

Mock_State :: struct {
	response: string,
}

_mock_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, transport.Transport_Error) {
	state := cast(^Mock_State)ctx
	resp := state.response
	result := make([]u8, len(resp), allocator)
	mem.copy(raw_data(result), raw_data(resp), len(resp))
	return result, .None
}

_mock_close :: proc(ctx: rawptr) {}

@(test)
test_json_rpc_account_create :: proc(t: ^testing.T) {
	state := Mock_State{}
	tp := transport.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = &state,
	}

	addr: types.Address
	addr[19] = 0x42

	account, err := acc.from_json_rpc(addr, tp)
	defer acc.json_rpc_destroy(&account)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, account.address[19], u8(0x42))
}

@(test)
test_json_rpc_account_sign :: proc(t: ^testing.T) {
	// Build a mock response with a 65-byte hex signature
	// r = 0x01...00 (32 bytes), s = 0x02...00 (32 bytes), v = 0x1b (27)
	r_hex := "0100000000000000000000000000000000000000000000000000000000000000"
	s_hex := "0200000000000000000000000000000000000000000000000000000000000000"
	v_hex := "1b"
	sig_hex := strings.concatenate({"0x", r_hex, s_hex, v_hex}, context.temp_allocator)
	resp := strings.concatenate({`{"jsonrpc":"2.0","id":1,"result":"`, sig_hex, `"}`}, context.temp_allocator)

	state := Mock_State{response = resp}
	tp := transport.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = &state,
	}

	addr: types.Address
	account, _ := acc.from_json_rpc(addr, tp)
	defer acc.json_rpc_destroy(&account)

	hash: types.Hash
	hash[0] = 0xAB

	sig, ok := account.sign_hash(account.ctx, hash)
	testing.expect(t, ok, "sign should succeed")
	testing.expect_value(t, sig.r[0], u8(0x01))
	testing.expect_value(t, sig.s[0], u8(0x02))
	testing.expect_value(t, sig.v, u8(0x1b))
}

// --- Signature hex parsing ---

@(test)
test_parse_signature_hex :: proc(t: ^testing.T) {
	r_hex := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	s_hex := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	v_hex := "1c"
	hex := strings.concatenate({"0x", r_hex, s_hex, v_hex}, context.temp_allocator)

	sig, ok := acc._parse_signature_hex(hex)
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, sig.r[0], u8(0xAA))
	testing.expect_value(t, sig.s[0], u8(0xBB))
	testing.expect_value(t, sig.v, u8(0x1C))
}

@(test)
test_parse_signature_hex_invalid_length :: proc(t: ^testing.T) {
	_, ok := acc._parse_signature_hex("0xdeadbeef")
	testing.expect(t, !ok, "should fail with short input")
}
