package accounts

import "core:math/big"
import "core:mem"
import "core:crypto/legacy/keccak"
import secp "../../odin-secp256k1/secp256k1"
import "../types"

// Derive an Ethereum address from a private key.
derive_address :: proc(privkey: [32]u8) -> (types.Address, Account_Error) {
	params: secp.Curve_Params
	if secp.init_curve_params(&params) != .None do return {}, .Derive_Failed
	defer secp.destroy_curve_params(&params)

	pk: big.Int
	defer big.destroy(&pk)
	pk_bytes := privkey
	if big.int_from_bytes_big(&pk, pk_bytes[:]) != nil do return {}, .Invalid_Key

	pubkey: secp.Point
	defer secp.point_destroy(&pubkey)
	if secp.privkey_to_pubkey(&pubkey, &pk, &params) != .None do return {}, .Derive_Failed

	// Serialize uncompressed: 0x04 || x (32 bytes) || y (32 bytes)
	uncompressed: [65]u8
	if secp.serialize_point_uncompressed(&uncompressed, &pubkey, &params) != .None {
		return {}, .Derive_Failed
	}

	// Address = keccak256(pubkey_bytes[1:])[-20:]
	hash := _keccak256(uncompressed[1:])
	addr: types.Address
	mem.copy(&addr, &hash[12], 20)
	return addr, .None
}

// Sign a hash using secp256k1.
local_sign_hash :: proc(privkey: [32]u8, hash: types.Hash) -> (types.Signature, Account_Error) {
	params: secp.Curve_Params
	if secp.init_curve_params(&params) != .None do return {}, .Sign_Failed
	defer secp.destroy_curve_params(&params)

	pk: big.Int
	defer big.destroy(&pk)
	pk_bytes := privkey
	if big.int_from_bytes_big(&pk, pk_bytes[:]) != nil do return {}, .Invalid_Key

	ecdsa_sig: secp.Signature
	defer secp.signature_destroy(&ecdsa_sig)

	msg_hash := transmute([32]u8)hash
	if secp.sign(&ecdsa_sig, &pk, msg_hash, &params) != .None do return {}, .Sign_Failed

	result: types.Signature
	result.v = ecdsa_sig.v
	_big_int_to_32bytes(&ecdsa_sig.r, &result.r)
	_big_int_to_32bytes(&ecdsa_sig.s, &result.s)
	return result, .None
}

// --- Internal ---

_big_int_to_32bytes :: proc(val: ^big.Int, out: ^[32]u8) {
	mem.zero(out, 32)
	size, _ := big.int_to_bytes_size(val)
	if size > 0 && size <= 32 {
		big.int_to_bytes_big(val, out[32 - size:])
	}
}

_keccak256 :: proc(data: []u8) -> [32]u8 {
	hash: [32]u8
	ctx: keccak.Context
	keccak.init_256(&ctx)
	keccak.update(&ctx, data)
	keccak.final(&ctx, hash[:])
	return hash
}
