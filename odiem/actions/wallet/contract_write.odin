package wallet_actions

import "core:encoding/json"
import "core:fmt"
import "../../clients"
import "../../types"

// Write to a contract by sending a transaction with encoded calldata.
// The calldata should be pre-encoded (e.g. via odin-abi).
// Returns the transaction hash.
write_contract :: proc(
	client: ^clients.Wallet_Client,
	to: types.Address,
	calldata: []u8,
	value: u64 = 0,
	allocator := context.allocator,
) -> (types.Hash, clients.Client_Error) {
	tx_obj := make(json.Object, allocator = context.temp_allocator)
	tx_obj["from"] = json.Value(clients.address_to_hex(client.account.address))
	tx_obj["to"] = json.Value(clients.address_to_hex(to))
	if len(calldata) > 0 {
		tx_obj["data"] = json.Value(_bytes_to_hex(calldata))
	}
	if value > 0 {
		tx_obj["value"] = json.Value(fmt.tprintf("0x%x", value))
	}

	params := make(json.Array, 1, context.temp_allocator)
	params[0] = tx_obj

	result, _, err := clients.wallet_rpc_call(client, "eth_sendTransaction", params, context.temp_allocator)
	if err != .None do return {}, err

	return _hex_string_to_hash(result)
}
