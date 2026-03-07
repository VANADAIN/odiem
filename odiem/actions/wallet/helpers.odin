package wallet_actions

import "core:encoding/json"
import "core:crypto/legacy/keccak"
import "core:strings"
import "core:mem"
import "../../clients"
import "../../types"

// Encode bytes as 0x-prefixed hex string (temp allocated).
_bytes_to_hex :: proc(data: []u8) -> string {
	hex_chars := "0123456789abcdef"
	buf := make([]u8, 2 + len(data) * 2, context.temp_allocator)
	buf[0] = '0'
	buf[1] = 'x'
	for b, i in data {
		buf[2 + i * 2] = hex_chars[b >> 4]
		buf[2 + i * 2 + 1] = hex_chars[b & 0x0F]
	}
	return string(buf)
}

// Parse a hex hash string from a JSON value into a Hash.
_hex_string_to_hash :: proc(v: json.Value) -> (types.Hash, clients.Client_Error) {
	s, is_str := v.(json.String)
	if !is_str do return {}, .Invalid_Response

	str := s
	if strings.has_prefix(str, "0x") || strings.has_prefix(str, "0X") {
		str = str[2:]
	}

	hash: types.Hash
	hex_idx := 0
	for i in 0 ..< 32 {
		if hex_idx + 1 >= len(str) do break
		high := _hex_nibble(str[hex_idx])
		low := _hex_nibble(str[hex_idx + 1])
		hash[i] = (high << 4) | low
		hex_idx += 2
	}

	return hash, .None
}

_hex_nibble :: proc(c: u8) -> u8 {
	switch {
	case c >= '0' && c <= '9': return c - '0'
	case c >= 'a' && c <= 'f': return c - 'a' + 10
	case c >= 'A' && c <= 'F': return c - 'A' + 10
	}
	return 0
}

_keccak256 :: proc(data: []u8) -> types.Hash {
	hash: types.Hash
	ctx: keccak.Context
	keccak.init_256(&ctx)
	keccak.update(&ctx, data)
	keccak.final(&ctx, hash[:])
	return hash
}
