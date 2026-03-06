package public_actions

import "core:encoding/json"
import "../../clients"
import "../../types"

// Get logs matching a filter.
get_logs :: proc(
	client: ^clients.Public_Client,
	filter: clients.Log_Filter,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	filter_obj := make(json.Object, allocator = context.temp_allocator)
	filter_obj["fromBlock"] = json.Value(clients.block_number_to_hex(filter.from_block))
	filter_obj["toBlock"] = json.Value(clients.block_number_to_hex(filter.to_block))

	if addr, has := filter.address.?; has {
		filter_obj["address"] = json.Value(clients.address_to_hex(addr))
	}

	if len(filter.topics) > 0 {
		topics_arr := make(json.Array, len(filter.topics), context.temp_allocator)
		for topic, i in filter.topics {
			if h, has := topic.?; has {
				topics_arr[i] = json.Value(clients.hash_to_hex(h))
			} else {
				topics_arr[i] = nil
			}
		}
		filter_obj["topics"] = topics_arr
	}

	params := make(json.Array, 1, context.temp_allocator)
	params[0] = filter_obj

	result, _, err := clients.rpc_call(client, "eth_getLogs", params, allocator)
	if err != .None do return nil, err

	return result, .None
}
