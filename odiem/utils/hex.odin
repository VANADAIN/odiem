package utils

import "core:encoding/hex"
import "core:math/big"
import "core:strings"
import "core:mem"

// Convert bytes to 0x-prefixed hex string.
to_hex :: proc(data: []u8, allocator := context.allocator) -> string {
	hex_bytes := hex.encode(data, allocator)
	result := make([]u8, len(hex_bytes) + 2, allocator)
	result[0] = '0'
	result[1] = 'x'
	copy(result[2:], hex_bytes)
	delete(hex_bytes, allocator)
	return string(result)
}

// Parse 0x-prefixed (or plain) hex string to bytes.
from_hex :: proc(s: string, allocator := context.allocator) -> ([]u8, bool) {
	str := s
	if len(str) >= 2 && str[0] == '0' && (str[1] == 'x' || str[1] == 'X') {
		str = str[2:]
	}
	if len(str) == 0 {
		return nil, true
	}
	data, ok := hex.decode(transmute([]u8)str, allocator)
	return data, ok
}

// Convert big.Int to 0x-prefixed hex string.
big_int_to_hex :: proc(val: ^big.Int, allocator := context.allocator) -> (string, bool) {
	size, size_err := big.int_to_bytes_size(val)
	if size_err != nil do return "", false

	if size == 0 {
		return strings.clone("0x0", allocator), true
	}

	buf := make([]u8, size, context.temp_allocator)
	write_err := big.int_to_bytes_big(val, buf)
	if write_err != nil do return "", false

	return to_hex(buf, allocator), true
}

// Parse 0x-prefixed hex string to big.Int.
hex_to_big_int :: proc(s: string, result: ^big.Int) -> bool {
	str := s
	if len(str) >= 2 && str[0] == '0' && (str[1] == 'x' || str[1] == 'X') {
		str = str[2:]
	}
	if len(str) == 0 {
		big.set(result, 0)
		return true
	}
	// Pad to even length
	padded: string
	if len(str) % 2 != 0 {
		temp_buf := make([]u8, len(str) + 1, context.temp_allocator)
		temp_buf[0] = '0'
		copy(temp_buf[1:], transmute([]u8)str)
		padded = string(temp_buf)
	} else {
		padded = str
	}
	bytes, ok := hex.decode(transmute([]u8)padded, context.temp_allocator)
	if !ok do return false
	if big.int_from_bytes_big(result, bytes) != nil do return false
	return true
}
