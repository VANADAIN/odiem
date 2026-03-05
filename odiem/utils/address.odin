package utils

import "core:encoding/hex"
import "core:mem"
import "../types"

// Check if a string is a valid hex address (0x + 40 hex chars).
is_address :: proc(s: string) -> bool {
	if len(s) != 42 do return false
	if s[0] != '0' || (s[1] != 'x' && s[1] != 'X') do return false
	for i in 2 ..< 42 {
		c := s[i]
		if !_is_hex_char(c) do return false
	}
	return true
}

// Parse a hex string into an Address. Returns false if invalid.
get_address :: proc(s: string) -> (types.Address, bool) {
	if !is_address(s) do return {}, false
	hex_part := s[2:]
	bytes, ok := hex.decode(transmute([]u8)hex_part, context.temp_allocator)
	if !ok do return {}, false
	addr: types.Address
	mem.copy(&addr, raw_data(bytes), 20)
	return addr, true
}

// EIP-55 mixed-case checksum encoding.
to_checksum_address :: proc(addr: types.Address, allocator := context.allocator) -> string {
	// Hex-encode the address (lowercase)
	addr_copy := addr
	hex_bytes := hex.encode(addr_copy[:], context.temp_allocator)
	hex_lower := string(hex_bytes)

	// Hash the lowercase hex (without 0x prefix)
	hash := keccak256(hex_bytes)

	buf := make([]u8, 42, allocator)
	buf[0] = '0'
	buf[1] = 'x'
	for i in 0 ..< 40 {
		c := hex_lower[i]
		// Get the corresponding nibble from the hash
		hash_raw := transmute([32]u8)hash
		hash_byte := hash_raw[i / 2]
		nibble := (hash_byte >> (4 if i % 2 == 0 else 0)) & 0x0F
		if nibble >= 8 && c >= 'a' && c <= 'f' {
			buf[i + 2] = c - 32 // uppercase
		} else {
			buf[i + 2] = c
		}
	}
	return string(buf)
}

_is_hex_char :: proc(c: u8) -> bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}
