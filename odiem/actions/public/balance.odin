package public_actions

import "core:encoding/json"
import "core:math/big"
import "../../clients"
import "../../types"

// Get the balance of an address at a given block.
get_balance :: proc(
	client: ^clients.Public_Client,
	address: types.Address,
	block: types.Block_Number = types.Block_Tag.Latest,
	allocator := context.allocator,
) -> (big.Int, clients.Client_Error) {
	params := _make_params_2(
		clients.address_to_hex(address),
		clients.block_number_to_hex(block),
	)

	result, _, err := clients.rpc_call(client, "eth_getBalance", params, context.temp_allocator)
	if err != .None do return {}, err

	return _hex_to_big_int(result, allocator)
}
