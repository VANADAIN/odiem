package wallet_actions

import "core:encoding/json"
import "core:fmt"
import "../../clients"
import "../../types"

// Deploy a contract by sending a transaction with bytecode as data.
// Returns the transaction hash. The contract address can be obtained
// from the transaction receipt.
deploy_contract :: proc(
	client: ^clients.Wallet_Client,
	bytecode: []u8,
	value: u64 = 0,
	allocator := context.allocator,
) -> (types.Hash, clients.Client_Error) {
	tx_obj := make(json.Object, allocator = context.temp_allocator)
	tx_obj["from"] = json.Value(clients.address_to_hex(client.account.address))
	tx_obj["data"] = json.Value(_bytes_to_hex(bytecode))
	if value > 0 {
		tx_obj["value"] = json.Value(fmt.tprintf("0x%x", value))
	}

	params := make(json.Array, 1, context.temp_allocator)
	params[0] = tx_obj

	result, _, err := clients.wallet_rpc_call(client, "eth_sendTransaction", params, context.temp_allocator)
	if err != .None do return {}, err

	return _hex_string_to_hash(result)
}
