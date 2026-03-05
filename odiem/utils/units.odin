package utils

import "core:math/big"
import "core:strings"

ETHER_DECIMALS :: 18
GWEI_DECIMALS :: 9

// Parse an ether string (e.g. "1.5") to wei as big.Int.
parse_ether :: proc(s: string, result: ^big.Int) -> bool {
	return _parse_units(s, ETHER_DECIMALS, result)
}

// Format wei big.Int to ether string (e.g. "1.5").
format_ether :: proc(wei: ^big.Int, allocator := context.allocator) -> (string, bool) {
	return _format_units(wei, ETHER_DECIMALS, allocator)
}

// Parse a gwei string to wei as big.Int.
parse_gwei :: proc(s: string, result: ^big.Int) -> bool {
	return _parse_units(s, GWEI_DECIMALS, result)
}

// Format wei big.Int to gwei string.
format_gwei :: proc(wei: ^big.Int, allocator := context.allocator) -> (string, bool) {
	return _format_units(wei, GWEI_DECIMALS, allocator)
}

_parse_units :: proc(s: string, decimals: int, result: ^big.Int) -> bool {
	if len(s) == 0 do return false

	dot_idx := strings.index_byte(s, '.')
	if dot_idx < 0 {
		if big.atoi(result, s) != nil do return false
		multiplier: big.Int
		defer big.destroy(&multiplier)
		_pow10(&multiplier, decimals)
		big.mul(result, result, &multiplier)
		return true
	}

	whole_part := s[:dot_idx]
	frac_part := s[dot_idx + 1:]

	frac_len := min(len(frac_part), decimals)
	frac_part = frac_part[:frac_len]

	whole: big.Int
	defer big.destroy(&whole)
	if len(whole_part) > 0 {
		if big.atoi(&whole, whole_part) != nil do return false
	}

	multiplier: big.Int
	defer big.destroy(&multiplier)
	_pow10(&multiplier, decimals)
	big.mul(result, &whole, &multiplier)

	if frac_len > 0 {
		padded := make([]u8, decimals, context.temp_allocator)
		copy(padded, transmute([]u8)frac_part)
		for i in frac_len ..< decimals {
			padded[i] = '0'
		}
		frac: big.Int
		defer big.destroy(&frac)
		if big.atoi(&frac, string(padded)) != nil do return false

		if whole.sign == .Negative {
			big.sub(result, result, &frac)
		} else {
			big.add(result, result, &frac)
		}
	}

	return true
}

_format_units :: proc(wei: ^big.Int, decimals: int, allocator := context.allocator) -> (string, bool) {
	divisor: big.Int
	defer big.destroy(&divisor)
	_pow10(&divisor, decimals)

	quotient, remainder: big.Int
	defer big.destroy(&quotient, &remainder)
	if big.divmod(&quotient, &remainder, wei, &divisor) != nil do return "", false

	is_neg := wei.sign == .Negative
	if is_neg {
		abs_rem: big.Int
		defer big.destroy(&abs_rem)
		big.abs(&abs_rem, &remainder)
		big.set(&remainder, &abs_rem)
	}

	// Convert quotient to string
	whole_str, whole_err := big.int_to_string(&quotient)
	if whole_err != nil do return "", false
	defer delete(whole_str)

	// Convert remainder to string
	rem_str, rem_err := big.int_to_string(&remainder)
	if rem_err != nil do return "", false
	defer delete(rem_str)

	// Build fractional part with leading zeros
	frac := make([]u8, decimals, context.temp_allocator)
	for i in 0 ..< decimals {
		frac[i] = '0'
	}
	rem_bytes := transmute([]u8)rem_str
	offset := decimals - len(rem_bytes)
	if offset >= 0 {
		copy(frac[offset:], rem_bytes)
	}

	// Trim trailing zeros
	frac_end := decimals
	for frac_end > 0 && frac[frac_end - 1] == '0' {
		frac_end -= 1
	}

	b := strings.builder_make(allocator)
	if is_neg && whole_str[0] != '-' {
		strings.write_byte(&b, '-')
	}
	strings.write_string(&b, whole_str)
	if frac_end > 0 {
		strings.write_byte(&b, '.')
		strings.write_bytes(&b, frac[:frac_end])
	}

	return strings.to_string(b), true
}

_pow10 :: proc(result: ^big.Int, exp: int) {
	big.set(result, 1)
	ten: big.Int
	defer big.destroy(&ten)
	big.set(&ten, 10)
	for _ in 0 ..< exp {
		big.mul(result, result, &ten)
	}
}
