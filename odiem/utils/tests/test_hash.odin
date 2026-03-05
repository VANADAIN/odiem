package utils_tests

import "core:testing"
import "core:encoding/hex"
import utils "../"
import types "../../types"

to_upper :: proc(s: string) -> string {
	buf := make([]u8, len(s))
	for i in 0 ..< len(s) {
		c := s[i]
		if c >= 'a' && c <= 'f' {
			buf[i] = c - 32
		} else {
			buf[i] = c
		}
	}
	return string(buf)
}

@(test)
test_keccak256_empty :: proc(t: ^testing.T) {
	// keccak256("") = c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
	hash := utils.keccak256(nil)
	raw := transmute([32]u8)hash
	hex_bytes := hex.encode(raw[:])
	defer delete(hex_bytes)
	got := to_upper(string(hex_bytes))
	defer delete(got)
	testing.expect_value(t, got, "C5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470")
}

@(test)
test_keccak256_hello :: proc(t: ^testing.T) {
	// keccak256("hello") known hash
	data := transmute([]u8)string("hello")
	hash := utils.keccak256(data)
	raw := transmute([32]u8)hash
	hex_bytes := hex.encode(raw[:])
	defer delete(hex_bytes)
	got := to_upper(string(hex_bytes))
	defer delete(got)
	testing.expect_value(t, got, "1C8AFF950685C2ED4BC3174F3472287B56D9517B9C948127319A09A7A36DEAC8")
}
