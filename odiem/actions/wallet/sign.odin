package wallet_actions

import "core:encoding/json"
import "../../clients"
import "../../types"
import "../../utils"

// Sign a message using the wallet's account (EIP-191 personal sign).
sign_message :: proc(
	client: ^clients.Wallet_Client,
	message: []u8,
) -> (types.Signature, clients.Client_Error) {
	// Hash with EIP-191 prefix
	hash := utils._eip191_hash(message)
	typed_hash := transmute(types.Hash)hash

	sig, ok := client.account.sign_hash(client.account.ctx, typed_hash)
	if !ok do return {}, .Invalid_Response

	return sig, .None
}

// Sign a raw 32-byte hash using the wallet's account.
sign_hash :: proc(
	client: ^clients.Wallet_Client,
	hash: types.Hash,
) -> (types.Signature, clients.Client_Error) {
	sig, ok := client.account.sign_hash(client.account.ctx, hash)
	if !ok do return {}, .Invalid_Response

	return sig, .None
}
