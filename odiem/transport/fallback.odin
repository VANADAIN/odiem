package transport

import "core:mem"

// Fallback transport — tries transports in order, falls back on failure.
Fallback_Transport :: struct {
	transports: []Transport,
	allocator:  mem.Allocator,
}

// Create a fallback transport from a list of transports.
// Tries each in order; returns the first successful response.
fallback_create :: proc(transports: []Transport, allocator := context.allocator) -> (Transport, Transport_Error) {
	ft, alloc_err := new(Fallback_Transport, allocator)
	if alloc_err != nil do return {}, .Alloc_Failed

	// Copy the transport slice
	ts, ts_err := make([]Transport, len(transports), allocator)
	if ts_err != nil {
		free(ft, allocator)
		return {}, .Alloc_Failed
	}
	for t, i in transports {
		ts[i] = t
	}

	ft.transports = ts
	ft.allocator = allocator

	return Transport{
		send  = _fallback_send,
		close = _fallback_close,
		ctx   = ft,
	}, .None
}

_fallback_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, Transport_Error) {
	ft := cast(^Fallback_Transport)ctx

	last_err: Transport_Error = .Connection_Failed
	for &t in ft.transports {
		if t.send == nil do continue
		result, err := t.send(t.ctx, data, allocator)
		if err == .None {
			return result, .None
		}
		last_err = err
	}

	return nil, last_err
}

_fallback_close :: proc(ctx: rawptr) {
	ft := cast(^Fallback_Transport)ctx
	for &t in ft.transports {
		if t.close != nil {
			t.close(t.ctx)
		}
	}
	delete(ft.transports, ft.allocator)
	free(ft, ft.allocator)
}
