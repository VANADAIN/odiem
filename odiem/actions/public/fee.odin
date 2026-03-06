package public_actions

import "core:encoding/json"
import "core:fmt"
import "../../clients"
import "../../types"

// Get fee history.
get_fee_history :: proc(
	client: ^clients.Public_Client,
	block_count: u64,
	newest_block: types.Block_Number = types.Block_Tag.Latest,
	reward_percentiles: []f64 = nil,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := make(json.Array, 3, context.temp_allocator)
	params[0] = json.Value(fmt.tprintf("0x%x", block_count))
	params[1] = json.Value(clients.block_number_to_hex(newest_block))

	if len(reward_percentiles) > 0 {
		pcts := make(json.Array, len(reward_percentiles), context.temp_allocator)
		for p, i in reward_percentiles {
			pcts[i] = json.Value(json.Float(p))
		}
		params[2] = pcts
	} else {
		params[2] = make(json.Array, 0, context.temp_allocator)
	}

	result, _, err := clients.rpc_call(client, "eth_feeHistory", params, allocator)
	if err != .None do return nil, err

	return result, .None
}
