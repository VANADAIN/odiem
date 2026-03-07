package accounts

import "core:mem"
import "../types"
import "../clients"

// Internal state for a private key account.
Private_Key_State :: struct {
	privkey: [32]u8,
}

// Create an Account from a raw 32-byte private key.
// Derives the public key and Ethereum address.
from_private_key :: proc(privkey: [32]u8, allocator := context.allocator) -> (Account, Account_Error) {
	addr, err := derive_address(privkey)
	if err != .None do return {}, err

	state, alloc_err := new(Private_Key_State, allocator)
	if alloc_err != nil do return {}, .Alloc_Failed
	state.privkey = privkey

	return Account{
		address   = addr,
		sign_hash = _privkey_sign_hash,
		ctx       = state,
	}, .None
}

// Destroy a private key account, zeroing the key material.
private_key_destroy :: proc(account: ^Account, allocator := context.allocator) {
	if account.ctx == nil do return
	state := cast(^Private_Key_State)account.ctx
	mem.zero(&state.privkey, 32)
	free(state, allocator)
	account.ctx = nil
}

_privkey_sign_hash :: proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool) {
	state := cast(^Private_Key_State)ctx
	sig, err := local_sign_hash(state.privkey, hash)
	if err != .None do return {}, false
	return sig, true
}
