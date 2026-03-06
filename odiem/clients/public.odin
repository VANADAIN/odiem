package clients

import "core:encoding/json"
import "core:mem"
import "core:fmt"
import "core:strings"
import "../types"
import "../transport"

// Public client — read-only blockchain access.
Public_Client :: struct {
	transport: transport.Transport,
	chain:     types.Chain,
	next_id:   u64,
	allocator: mem.Allocator,
}

// Create a public client with the given transport and chain.
public_client_create :: proc(
	tp: transport.Transport,
	chain: types.Chain = {},
	allocator := context.allocator,
) -> Public_Client {
	return Public_Client{
		transport = tp,
		chain     = chain,
		next_id   = 1,
		allocator = allocator,
	}
}

// Close the public client and its transport.
public_client_destroy :: proc(client: ^Public_Client) {
	if client.transport.close != nil {
		client.transport.close(client.transport.ctx)
	}
}

// Send a JSON-RPC call and return the raw result.
rpc_call :: proc(
	client: ^Public_Client,
	method: string,
	params: json.Value = nil,
	allocator := context.allocator,
) -> (json.Value, RPC_Error, Client_Error) {
	id := client.next_id
	client.next_id += 1

	// Build request JSON
	req_obj := make(json.Object, allocator = context.temp_allocator)
	req_obj["jsonrpc"] = json.Value("2.0")
	req_obj["method"] = json.Value(method)
	req_obj["id"] = json.Value(json.Integer(id))
	if params != nil {
		req_obj["params"] = params
	}

	req_bytes, marshal_err := json.marshal(req_obj, allocator = context.temp_allocator)
	if marshal_err != nil do return nil, {}, .Marshal_Failed

	// Send via transport
	resp_bytes, terr := client.transport.send(client.transport.ctx, req_bytes, context.temp_allocator)
	if terr != .None do return nil, {}, .Transport_Error

	// Parse response
	return _parse_rpc_response(resp_bytes, allocator)
}

// Get the chain ID from the client config, or query the node.
get_chain_id :: proc(client: ^Public_Client) -> (u64, Client_Error) {
	if client.chain.id != 0 {
		return client.chain.id, .None
	}

	result, _, err := rpc_call(client, "eth_chainId", allocator = context.temp_allocator)
	if err != .None do return 0, err

	return _hex_to_u64(result), .None
}

// --- Helpers ---

// Encode a block number as a hex string for JSON-RPC params.
block_number_to_hex :: proc(bn: types.Block_Number) -> string {
	switch v in bn {
	case u64:
		return fmt.tprintf("0x%x", v)
	case types.Block_Tag:
		switch v {
		case .Latest:    return "latest"
		case .Earliest:  return "earliest"
		case .Pending:   return "pending"
		case .Safe:      return "safe"
		case .Finalized: return "finalized"
		}
	}
	return "latest"
}

// Encode an address as a 0x-prefixed hex string.
address_to_hex :: proc(addr: types.Address) -> string {
	local := addr
	buf: [42]u8
	buf[0] = '0'
	buf[1] = 'x'
	hex_chars := "0123456789abcdef"
	for i in 0 ..< 20 {
		buf[2 + i * 2] = hex_chars[local[i] >> 4]
		buf[2 + i * 2 + 1] = hex_chars[local[i] & 0x0F]
	}
	return strings.clone_from_bytes(buf[:], context.temp_allocator)
}

// Encode a hash as a 0x-prefixed hex string.
hash_to_hex :: proc(h: types.Hash) -> string {
	local := h
	buf: [66]u8
	buf[0] = '0'
	buf[1] = 'x'
	hex_chars := "0123456789abcdef"
	for i in 0 ..< 32 {
		buf[2 + i * 2] = hex_chars[local[i] >> 4]
		buf[2 + i * 2 + 1] = hex_chars[local[i] & 0x0F]
	}
	return strings.clone_from_bytes(buf[:], context.temp_allocator)
}

// Parse a JSON-RPC response.
_parse_rpc_response :: proc(data: []u8, allocator := context.allocator) -> (json.Value, RPC_Error, Client_Error) {
	parsed, parse_err := json.parse(data, allocator = allocator)
	if parse_err != .None do return nil, {}, .Unmarshal_Failed

	obj, is_obj := parsed.(json.Object)
	if !is_obj {
		json.destroy_value(parsed, allocator)
		return nil, {}, .Unmarshal_Failed
	}

	if err_val, has_err := obj["error"]; has_err {
		if err_obj, is_err_obj := err_val.(json.Object); is_err_obj {
			rpc_err := RPC_Error{}
			if code, has_code := err_obj["code"]; has_code {
				rpc_err.code = _json_to_i64(code)
			}
			if msg, has_msg := err_obj["message"]; has_msg {
				if msg_str, is_str := msg.(json.String); is_str {
					rpc_err.message = msg_str
				}
			}
			if d, has_data := err_obj["data"]; has_data {
				rpc_err.data = d
			}
			return nil, rpc_err, .RPC_Error
		}
	}

	if result, has_result := obj["result"]; has_result {
		return result, {}, .None
	}

	return nil, {}, .None
}

_json_to_i64 :: proc(v: json.Value) -> i64 {
	#partial switch val in v {
	case json.Integer: return i64(val)
	case json.Float:   return i64(val)
	}
	return 0
}

_hex_to_u64 :: proc(v: json.Value) -> u64 {
	s, is_str := v.(json.String)
	if !is_str do return 0
	return _parse_hex_u64(s)
}

_parse_hex_u64 :: proc(s: string) -> u64 {
	str := s
	if strings.has_prefix(str, "0x") || strings.has_prefix(str, "0X") {
		str = str[2:]
	}
	result: u64 = 0
	for c in str {
		result <<= 4
		switch {
		case c >= '0' && c <= '9': result |= u64(c - '0')
		case c >= 'a' && c <= 'f': result |= u64(c - 'a' + 10)
		case c >= 'A' && c <= 'F': result |= u64(c - 'A' + 10)
		}
	}
	return result
}
