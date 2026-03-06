package public_actions

import "core:encoding/json"
import "../../clients"
import "../../types"

// Get the code at an address.
get_code :: proc(
	client: ^clients.Public_Client,
	address: types.Address,
	block: types.Block_Number = types.Block_Tag.Latest,
) -> (string, clients.Client_Error) {
	params := _make_params_2(
		clients.address_to_hex(address),
		clients.block_number_to_hex(block),
	)

	result, _, err := clients.rpc_call(client, "eth_getCode", params, context.temp_allocator)
	if err != .None do return "", err

	s, is_str := result.(json.String)
	if !is_str do return "", .Invalid_Response

	return s, .None
}

// Get the storage value at a position for an address.
get_storage_at :: proc(
	client: ^clients.Public_Client,
	address: types.Address,
	slot: types.Hash,
	block: types.Block_Number = types.Block_Tag.Latest,
) -> (string, clients.Client_Error) {
	params := make(json.Array, 3, context.temp_allocator)
	params[0] = json.Value(clients.address_to_hex(address))
	params[1] = json.Value(clients.hash_to_hex(slot))
	params[2] = json.Value(clients.block_number_to_hex(block))

	result, _, err := clients.rpc_call(client, "eth_getStorageAt", params, context.temp_allocator)
	if err != .None do return "", err

	s, is_str := result.(json.String)
	if !is_str do return "", .Invalid_Response

	return s, .None
}
