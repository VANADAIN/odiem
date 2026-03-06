package public_actions

import "core:encoding/json"
import "../../clients"
import "../../types"

// Get the current block number.
get_block_number :: proc(
	client: ^clients.Public_Client,
) -> (u64, clients.Client_Error) {
	result, _, err := clients.rpc_call(client, "eth_blockNumber", allocator = context.temp_allocator)
	if err != .None do return 0, err

	return clients._hex_to_u64(result), .None
}

// Get a block by number.
get_block_by_number :: proc(
	client: ^clients.Public_Client,
	block: types.Block_Number = types.Block_Tag.Latest,
	full_transactions: bool = false,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := make(json.Array, 2, context.temp_allocator)
	params[0] = json.Value(clients.block_number_to_hex(block))
	params[1] = json.Value(full_transactions)

	result, _, err := clients.rpc_call(client, "eth_getBlockByNumber", params, allocator)
	if err != .None do return nil, err

	return result, .None
}

// Get a block by hash.
get_block_by_hash :: proc(
	client: ^clients.Public_Client,
	hash: types.Hash,
	full_transactions: bool = false,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := make(json.Array, 2, context.temp_allocator)
	params[0] = json.Value(clients.hash_to_hex(hash))
	params[1] = json.Value(full_transactions)

	result, _, err := clients.rpc_call(client, "eth_getBlockByHash", params, allocator)
	if err != .None do return nil, err

	return result, .None
}
