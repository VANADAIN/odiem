package utils

import "core:crypto/legacy/keccak"
import "../types"

keccak256 :: proc(data: []u8) -> types.Hash {
	hash: types.Hash
	ctx: keccak.Context
	keccak.init_256(&ctx)
	keccak.update(&ctx, data)
	keccak.final(&ctx, hash[:])
	return hash
}
