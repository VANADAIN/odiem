package accounts

import "core:encoding/json"
import "core:mem"
import "core:fmt"
import "core:strings"
import "../types"
import "../clients"
import "../transport"

// Internal state for a JSON-RPC account.
// Delegates signing to the connected node via eth_sign.
JSON_RPC_State :: struct {
	address:   types.Address,
	transport: transport.Transport,
}

// Create a JSON-RPC account that delegates signing to the node.
from_json_rpc :: proc(
	address: types.Address,
	tp: transport.Transport,
	allocator := context.allocator,
) -> (Account, Account_Error) {
	state, alloc_err := new(JSON_RPC_State, allocator)
	if alloc_err != nil do return {}, .Alloc_Failed

	state.address = address
	state.transport = tp

	return Account{
		address   = address,
		sign_hash = _jsonrpc_sign_hash,
		ctx       = state,
	}, .None
}

// Destroy a JSON-RPC account.
json_rpc_destroy :: proc(account: ^Account, allocator := context.allocator) {
	if account.ctx == nil do return
	free(account.ctx, allocator)
	account.ctx = nil
}

_jsonrpc_sign_hash :: proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool) {
	state := cast(^JSON_RPC_State)ctx

	// Build eth_sign request
	addr_hex := _address_to_hex(state.address)
	hash_hex := _hash_to_hex(hash)

	req_obj := make(json.Object, allocator = context.temp_allocator)
	req_obj["jsonrpc"] = json.Value("2.0")
	req_obj["method"] = json.Value("eth_sign")

	params := make(json.Array, 2, context.temp_allocator)
	params[0] = json.Value(addr_hex)
	params[1] = json.Value(hash_hex)
	req_obj["params"] = params
	req_obj["id"] = json.Value(json.Integer(1))

	req_bytes, marshal_err := json.marshal(req_obj, allocator = context.temp_allocator)
	if marshal_err != nil do return {}, false

	resp_bytes, terr := state.transport.send(state.transport.ctx, req_bytes, context.temp_allocator)
	if terr != .None do return {}, false

	// Parse response
	parsed, parse_err := json.parse(resp_bytes, allocator = context.temp_allocator)
	if parse_err != .None do return {}, false

	obj, is_obj := parsed.(json.Object)
	if !is_obj do return {}, false

	result, has_result := obj["result"]
	if !has_result do return {}, false

	sig_hex, is_str := result.(json.String)
	if !is_str do return {}, false

	return _parse_signature_hex(sig_hex)
}

_address_to_hex :: proc(addr: types.Address) -> string {
	local := addr
	hex_chars := "0123456789abcdef"
	buf: [42]u8
	buf[0] = '0'
	buf[1] = 'x'
	for i in 0 ..< 20 {
		buf[2 + i * 2] = hex_chars[local[i] >> 4]
		buf[2 + i * 2 + 1] = hex_chars[local[i] & 0x0F]
	}
	return strings.clone_from_bytes(buf[:], context.temp_allocator)
}

_hash_to_hex :: proc(h: types.Hash) -> string {
	local := h
	hex_chars := "0123456789abcdef"
	buf: [66]u8
	buf[0] = '0'
	buf[1] = 'x'
	for i in 0 ..< 32 {
		buf[2 + i * 2] = hex_chars[local[i] >> 4]
		buf[2 + i * 2 + 1] = hex_chars[local[i] & 0x0F]
	}
	return strings.clone_from_bytes(buf[:], context.temp_allocator)
}

// Parse a 65-byte hex signature (0x + r(32) + s(32) + v(1)) into a Signature.
_parse_signature_hex :: proc(hex: string) -> (types.Signature, bool) {
	s := hex
	if strings.has_prefix(s, "0x") || strings.has_prefix(s, "0X") {
		s = s[2:]
	}
	// Expect 130 hex chars (65 bytes)
	if len(s) != 130 do return {}, false

	sig: types.Signature
	for i in 0 ..< 32 {
		sig.r[i] = _hex_byte(s[i * 2], s[i * 2 + 1])
	}
	for i in 0 ..< 32 {
		sig.s[i] = _hex_byte(s[64 + i * 2], s[64 + i * 2 + 1])
	}
	sig.v = _hex_byte(s[128], s[129])
	return sig, true
}

_hex_byte :: proc(high, low: u8) -> u8 {
	return (_hex_nibble(high) << 4) | _hex_nibble(low)
}

_hex_nibble :: proc(c: u8) -> u8 {
	switch {
	case c >= '0' && c <= '9': return c - '0'
	case c >= 'a' && c <= 'f': return c - 'a' + 10
	case c >= 'A' && c <= 'F': return c - 'A' + 10
	}
	return 0
}
