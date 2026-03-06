package public_actions

import "core:encoding/json"
import "core:math/big"
import "core:strings"
import "core:fmt"
import "../../clients"

// Build a 1-element JSON array param.
_make_params_1 :: proc(a: string) -> json.Value {
	params := make(json.Array, 1, context.temp_allocator)
	params[0] = json.Value(a)
	return params
}

// Build a 2-element JSON array param.
_make_params_2 :: proc(a: string, b: string) -> json.Value {
	params := make(json.Array, 2, context.temp_allocator)
	params[0] = json.Value(a)
	params[1] = json.Value(b)
	return params
}

// Parse a hex string JSON value into a big.Int.
_hex_to_big_int :: proc(v: json.Value, allocator := context.allocator) -> (big.Int, clients.Client_Error) {
	s, is_str := v.(json.String)
	if !is_str do return {}, .Invalid_Response

	str := s
	if strings.has_prefix(str, "0x") || strings.has_prefix(str, "0X") {
		str = str[2:]
	}
	if len(str) == 0 {
		str = "0"
	}

	result: big.Int
	if err := big.atoi(&result, str, 16); err != nil {
		return {}, .Unmarshal_Failed
	}
	return result, .None
}

// Encode bytes as a 0x-prefixed hex string.
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
