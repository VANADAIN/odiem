package public_actions

import "core:encoding/json"
import "core:time"
import "../../clients"
import "../../types"

// Wait for a transaction receipt, polling until it's available.
// Returns the raw JSON receipt once mined.
wait_for_transaction_receipt :: proc(
	client: ^clients.Public_Client,
	hash: types.Hash,
	confirmations: u64 = 1,
	poll_interval_ms: int = 1000,
	timeout_ms: int = 60000,
	allocator := context.allocator,
) -> (json.Value, clients.Client_Error) {
	params := _make_params_1(clients.hash_to_hex(hash))
	elapsed := 0

	for elapsed < timeout_ms {
		result, _, err := clients.rpc_call(client, "eth_getTransactionReceipt", params, allocator)
		if err != .None do return nil, err

		// Check if receipt exists (not null)
		if result != nil {
			_, is_null := result.(json.Null)
			if !is_null {
				if confirmations <= 1 {
					return result, .None
				}

				// Check confirmations
				if obj, is_obj := result.(json.Object); is_obj {
					if bn_val, has := obj["blockNumber"]; has {
						receipt_block := clients._hex_to_u64(bn_val)
						current_block, block_err := get_block_number(client)
						if block_err == .None && current_block >= receipt_block + confirmations - 1 {
							return result, .None
						}
					}
				}

				json.destroy_value(result, allocator)
			}
		}

		time.sleep(time.Duration(poll_interval_ms) * time.Millisecond)
		elapsed += poll_interval_ms
	}

	return nil, .Transport_Error // timeout
}
