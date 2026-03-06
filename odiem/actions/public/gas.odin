package public_actions

import "core:math/big"
import "../../clients"

// Get the current gas price.
get_gas_price :: proc(
	client: ^clients.Public_Client,
	allocator := context.allocator,
) -> (big.Int, clients.Client_Error) {
	result, _, err := clients.rpc_call(client, "eth_gasPrice", allocator = context.temp_allocator)
	if err != .None do return {}, err

	return _hex_to_big_int(result, allocator)
}

// Get the max priority fee per gas (EIP-1559).
get_max_priority_fee :: proc(
	client: ^clients.Public_Client,
	allocator := context.allocator,
) -> (big.Int, clients.Client_Error) {
	result, _, err := clients.rpc_call(client, "eth_maxPriorityFeePerGas", allocator = context.temp_allocator)
	if err != .None do return {}, err

	return _hex_to_big_int(result, allocator)
}
