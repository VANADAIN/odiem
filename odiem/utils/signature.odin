package utils

import "core:math/big"
import "core:mem"
import "core:fmt"
import secp "../../odin-secp256k1/secp256k1"
import "../types"

Signature_Error :: enum {
	None,
	Invalid_Key,
	Sign_Failed,
	Recover_Failed,
	Serialize_Failed,
	Invalid_Signature,
}

// EIP-191 personal sign: sign a message with a private key.
// Prepends "\x19Ethereum Signed Message:\n{len}" before hashing.
sign_message :: proc(privkey: [32]u8, message: []u8) -> (types.Signature, Signature_Error) {
	msg_hash := _eip191_hash(message)
	return _sign_hash(privkey, msg_hash)
}

// Recover the signer address from a message and signature.
recover_address :: proc(message: []u8, sig: types.Signature) -> (types.Address, Signature_Error) {
	msg_hash := _eip191_hash(message)
	return _recover_address_from_hash(msg_hash, sig)
}

// Sign a raw 32-byte hash (no prefix).
sign_hash :: proc(privkey: [32]u8, hash: types.Hash) -> (types.Signature, Signature_Error) {
	raw := transmute([32]u8)hash
	return _sign_hash(privkey, raw)
}

// Recover address from a raw hash and signature.
recover_address_from_hash :: proc(hash: types.Hash, sig: types.Signature) -> (types.Address, Signature_Error) {
	raw := transmute([32]u8)hash
	return _recover_address_from_hash(raw, sig)
}

// --- Internal ---

_sign_hash :: proc(privkey_bytes: [32]u8, msg_hash: [32]u8) -> (types.Signature, Signature_Error) {
	params: secp.Curve_Params
	if secp.init_curve_params(&params) != .None do return {}, .Invalid_Key
	defer secp.destroy_curve_params(&params)

	pk: big.Int
	defer big.destroy(&pk)
	pk_bytes := privkey_bytes
	if big.int_from_bytes_big(&pk, pk_bytes[:]) != nil do return {}, .Invalid_Key

	ecdsa_sig: secp.Signature
	defer secp.signature_destroy(&ecdsa_sig)

	if secp.sign(&ecdsa_sig, &pk, msg_hash, &params) != .None do return {}, .Sign_Failed

	result: types.Signature
	result.v = ecdsa_sig.v

	_big_int_to_32bytes(&ecdsa_sig.r, &result.r)
	_big_int_to_32bytes(&ecdsa_sig.s, &result.s)

	return result, .None
}

_recover_address_from_hash :: proc(msg_hash: [32]u8, sig: types.Signature) -> (types.Address, Signature_Error) {
	params: secp.Curve_Params
	if secp.init_curve_params(&params) != .None do return {}, .Recover_Failed
	defer secp.destroy_curve_params(&params)

	ecdsa_sig: secp.Signature
	defer secp.signature_destroy(&ecdsa_sig)

	r_bytes := sig.r
	s_bytes := sig.s
	if big.int_from_bytes_big(&ecdsa_sig.r, r_bytes[:]) != nil do return {}, .Invalid_Signature
	if big.int_from_bytes_big(&ecdsa_sig.s, s_bytes[:]) != nil do return {}, .Invalid_Signature

	// Normalize v: accept both 0/1 and 27/28
	recovery_id := sig.v
	if recovery_id >= 27 {
		recovery_id -= 27
	}

	pubkey: secp.Point
	defer secp.point_destroy(&pubkey)

	if secp.recover_pubkey(&pubkey, msg_hash, &ecdsa_sig, recovery_id, &params) != .None {
		return {}, .Recover_Failed
	}

	// Serialize uncompressed pubkey (65 bytes: 0x04 || x || y)
	uncompressed: [65]u8
	if secp.serialize_point_uncompressed(&uncompressed, &pubkey, &params) != .None {
		return {}, .Serialize_Failed
	}

	// Address = keccak256(pubkey[1:])[:20] (skip 0x04 prefix)
	pub_hash := keccak256(uncompressed[1:])
	addr: types.Address
	pub_hash_raw := transmute([32]u8)pub_hash
	mem.copy(&addr, &pub_hash_raw[12], 20)
	return addr, .None
}

_eip191_hash :: proc(message: []u8) -> [32]u8 {
	prefix := "\x19Ethereum Signed Message:\n"
	len_str := fmt.tprintf("%d", len(message))

	total := len(prefix) + len(len_str) + len(message)
	buf := make([]u8, total, context.temp_allocator)
	offset := 0
	mem.copy(&buf[offset], raw_data(prefix), len(prefix))
	offset += len(prefix)
	mem.copy(&buf[offset], raw_data(len_str), len(len_str))
	offset += len(len_str)
	if len(message) > 0 {
		mem.copy(&buf[offset], raw_data(message), len(message))
	}
	offset += len(message)

	hash := keccak256(buf[:offset])
	return transmute([32]u8)hash
}

_big_int_to_32bytes :: proc(val: ^big.Int, out: ^[32]u8) {
	mem.zero(out, 32)
	size, _ := big.int_to_bytes_size(val)
	if size > 0 && size <= 32 {
		big.int_to_bytes_big(val, out[32 - size:])
	}
}
