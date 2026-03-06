package transport

import "core:mem"
import ws "../../odin-websocket/websocket"

// WebSocket transport — sends JSON-RPC over a persistent WebSocket connection.
WS_Transport :: struct {
	client:    ^ws.Client,
	allocator: mem.Allocator,
}

// Create a WebSocket transport by connecting to a ws:// URL.
ws_create :: proc(url: string, allocator := context.allocator) -> (Transport, Transport_Error) {
	client, err := ws.connect(url, allocator)
	if err != .None do return {}, .Connection_Failed

	wst, alloc_err := new(WS_Transport, allocator)
	if alloc_err != nil {
		ws.close_connection(client, allocator)
		return {}, .Alloc_Failed
	}

	wst.client = client
	wst.allocator = allocator

	return Transport{
		send  = _ws_send,
		close = _ws_close,
		ctx   = wst,
	}, .None
}

_ws_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, Transport_Error) {
	wst := cast(^WS_Transport)ctx

	// Send as text frame
	send_err := ws.send_text(wst.client, string(data))
	if send_err != .None do return nil, .Send_Failed

	// Receive response
	msg, recv_err := ws.recv(wst.client, allocator)
	if recv_err != .None do return nil, .Recv_Failed

	return msg.payload, .None
}

_ws_close :: proc(ctx: rawptr) {
	wst := cast(^WS_Transport)ctx
	ws.close_connection(wst.client, wst.allocator)
	free(wst, wst.allocator)
}
