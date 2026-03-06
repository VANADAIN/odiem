package public_actions

import "core:encoding/json"
import "core:fmt"
import "../../clients"
import "../../types"

// Execute a call without creating a transaction (eth_call).
eth_call :: proc(
	client: ^clients.Public_Client,
	params: clients.Call_Params,
	block: types.Block_Number = types.Block_Tag.Latest,
	allocator := context.allocator,
) -> (string, clients.Client_Error) {
	call_obj := _build_call_object(params)

	rpc_params := make(json.Array, 2, context.temp_allocator)
	rpc_params[0] = call_obj
	rpc_params[1] = json.Value(clients.block_number_to_hex(block))

	result, _, err := clients.rpc_call(client, "eth_call", rpc_params, context.temp_allocator)
	if err != .None do return "", err

	s, is_str := result.(json.String)
	if !is_str do return "", .Invalid_Response

	return s, .None
}

// Estimate gas for a call.
estimate_gas :: proc(
	client: ^clients.Public_Client,
	params: clients.Call_Params,
) -> (u64, clients.Client_Error) {
	call_obj := _build_call_object(params)

	rpc_params := make(json.Array, 1, context.temp_allocator)
	rpc_params[0] = call_obj

	result, _, err := clients.rpc_call(client, "eth_estimateGas", rpc_params, context.temp_allocator)
	if err != .None do return 0, err

	return clients._hex_to_u64(result), .None
}

_build_call_object :: proc(params: clients.Call_Params) -> json.Value {
	obj := make(json.Object, allocator = context.temp_allocator)
	if from, has := params.from.?; has {
		obj["from"] = json.Value(clients.address_to_hex(from))
	}
	if to, has := params.to.?; has {
		obj["to"] = json.Value(clients.address_to_hex(to))
	}
	if gas, has := params.gas.?; has {
		obj["gas"] = json.Value(fmt.tprintf("0x%x", gas))
	}
	if value, has := params.value.?; has {
		obj["value"] = json.Value(fmt.tprintf("0x%x", value))
	}
	if len(params.data) > 0 {
		obj["data"] = json.Value(_bytes_to_hex(params.data))
	}
	return obj
}
