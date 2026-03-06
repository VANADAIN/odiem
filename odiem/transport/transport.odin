package transport

import "core:encoding/json"
import "core:mem"

// Transport error shared across all transport types.
Transport_Error :: enum {
	None,
	Connection_Failed,
	Send_Failed,
	Recv_Failed,
	Timeout,
	Closed,
	Alloc_Failed,
}

// Transport interface — send raw JSON-RPC bytes and receive response bytes.
// All transports implement this common shape.
Transport :: struct {
	// Send raw JSON bytes and receive raw JSON response bytes.
	// Caller owns the returned bytes.
	send:  proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, Transport_Error),
	// Close the transport.
	close: proc(ctx: rawptr),
	// Opaque implementation context.
	ctx:   rawptr,
}

// Transport configuration.
Transport_Config :: struct {
	url:     string,
	timeout: int,     // milliseconds, 0 = no timeout
	headers: []Header,
}

Header :: struct {
	name:  string,
	value: string,
}
