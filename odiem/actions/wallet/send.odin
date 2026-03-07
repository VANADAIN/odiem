package wallet_actions

import "core:encoding/json"
import "core:mem"
import "../../clients"
import "../../types"

// Send a raw signed transaction.
send_raw_transaction :: proc(
	client: ^clients.Wallet_Client,
	signed_tx: []u8,
	allocator := context.allocator,
) -> (types.Hash, clients.Client_Error) {
	hex := _bytes_to_hex(signed_tx)

	params := make(json.Array, 1, context.temp_allocator)
	params[0] = json.Value(hex)

	result, _, err := clients.wallet_rpc_call(client, "eth_sendRawTransaction", params, context.temp_allocator)
	if err != .None do return {}, err

	return _hex_string_to_hash(result)
}

// Send a transaction: sign it locally then submit via eth_sendRawTransaction.
// The caller must provide a fully populated transaction (nonce, gas, etc).
// Returns the transaction hash.
send_transaction :: proc(
	client: ^clients.Wallet_Client,
	tx_data: []u8, // pre-serialized unsigned tx (e.g. RLP encoded)
	allocator := context.allocator,
) -> (types.Hash, clients.Client_Error) {
	// Hash the unsigned tx data for signing
	tx_hash := _keccak256(tx_data)

	// Sign using the account
	sig, ok := client.account.sign_hash(client.account.ctx, tx_hash)
	if !ok do return {}, .Invalid_Response

	// Append signature to tx data (simplified: caller is expected to handle
	// full RLP re-encoding with signature in production)
	signed := make([]u8, len(tx_data) + 65, context.temp_allocator)
	mem.copy(raw_data(signed), raw_data(tx_data), len(tx_data))
	mem.copy(&signed[len(tx_data)], &sig.r[0], 32)
	mem.copy(&signed[len(tx_data) + 32], &sig.s[0], 32)
	signed[len(tx_data) + 64] = sig.v

	return send_raw_transaction(client, signed, allocator)
}
