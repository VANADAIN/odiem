package clients

import "core:encoding/json"
import "core:mem"
import "../types"
import "../transport"

// Shared client error type.
Client_Error :: enum {
	None,
	Transport_Error,
	Marshal_Failed,
	Unmarshal_Failed,
	RPC_Error,
	Invalid_Response,
	Not_Connected,
	Alloc_Failed,
}

// JSON-RPC error returned by the node.
RPC_Error :: struct {
	code:    i64,
	message: string,
	data:    json.Value,
}

// Call parameters for eth_call / eth_estimateGas.
Call_Params :: struct {
	from:     Maybe(types.Address),
	to:       Maybe(types.Address),
	gas:      Maybe(u64),
	value:    Maybe(u64),
	data:     []u8,
}

// Log filter for eth_getLogs.
Log_Filter :: struct {
	from_block: types.Block_Number,
	to_block:   types.Block_Number,
	address:    Maybe(types.Address),
	topics:     []Maybe(types.Hash),
}

// Account interface — procedure pointers for signing.
Account :: struct {
	// The account's address.
	address:          types.Address,
	// Sign a message hash, returning the signature.
	sign_hash:        proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool),
	// Opaque context for the account implementation.
	ctx:              rawptr,
}
