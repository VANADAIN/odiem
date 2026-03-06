package public_actions

import "core:encoding/json"
import "../../clients"
import "../../types"

// Get a transaction by hash.
get_transaction :: proc(
	client: ^clients.Public_Client,
	hash: types.Hash,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := _make_params_1(clients.hash_to_hex(hash))

	result, _, err := clients.rpc_call(client, "eth_getTransactionByHash", params, allocator)
	if err != .None do return nil, err

	return result, .None
}

// Get a transaction receipt.
get_transaction_receipt :: proc(
	client: ^clients.Public_Client,
	hash: types.Hash,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := _make_params_1(clients.hash_to_hex(hash))

	result, _, err := clients.rpc_call(client, "eth_getTransactionReceipt", params, allocator)
	if err != .None do return nil, err

	return result, .None
}

// Get the transaction count (nonce) for an address.
get_transaction_count :: proc(
	client: ^clients.Public_Client,
	address: types.Address,
	block: types.Block_Number = types.Block_Tag.Latest,
) -> (u64, clients.Client_Error) {
	params := _make_params_2(
		clients.address_to_hex(address),
		clients.block_number_to_hex(block),
	)

	result, _, err := clients.rpc_call(client, "eth_getTransactionCount", params, context.temp_allocator)
	if err != .None do return 0, err

	return clients._hex_to_u64(result), .None
}
