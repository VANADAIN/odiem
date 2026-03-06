package public_actions

import "../../clients"

// Get the chain ID (delegates to clients.get_chain_id).
get_chain_id :: proc(
	client: ^clients.Public_Client,
) -> (u64, clients.Client_Error) {
	return clients.get_chain_id(client)
}

// Get the current network version (net_version).
get_net_version :: proc(
	client: ^clients.Public_Client,
) -> (string, clients.Client_Error) {
	result, _, err := clients.rpc_call(client, "net_version", allocator = context.temp_allocator)
	if err != .None do return "", err

	s, is_str := result.(json.String)
	if !is_str do return "", .Invalid_Response

	return s, .None
}

import "core:encoding/json"
