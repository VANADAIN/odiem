package transport

import "core:mem"
import "core:strings"
import "base:runtime"
import "core:c"
import curl "vendor:curl"

// Curl-based HTTP/HTTPS transport using libcurl.
// Supports TLS for connecting to production RPC providers.
Curl_Transport :: struct {
	url:       string,
	headers:   []Header,
	allocator: mem.Allocator,
}

Curl_Response :: struct {
	body: [dynamic]u8,
	ctx:  runtime.Context,
}

// Create a curl transport from a URL (supports both http:// and https://).
curl_create :: proc(url: string, headers: []Header = nil, allocator := context.allocator) -> (Transport, Transport_Error) {
	ct, alloc_err := new(Curl_Transport, allocator)
	if alloc_err != nil do return {}, .Alloc_Failed

	ct.url = strings.clone(url, allocator)
	ct.headers = headers
	ct.allocator = allocator

	return Transport{
		send  = _curl_send,
		close = _curl_close,
		ctx   = ct,
	}, .None
}

_curl_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, Transport_Error) {
	ct := cast(^Curl_Transport)ctx

	handle := curl.easy_init()
	if handle == nil do return nil, .Connection_Failed
	defer curl.easy_cleanup(handle)

	resp := Curl_Response{
		body = make([dynamic]u8, allocator),
		ctx  = runtime.default_context(),
	}
	resp.ctx.allocator = allocator

	url_cstr := strings.clone_to_cstring(ct.url, context.temp_allocator)
	curl.easy_setopt(handle, .URL, url_cstr)
	curl.easy_setopt(handle, .POST, c.long(1))
	curl.easy_setopt(handle, .POSTFIELDSIZE, c.long(len(data)))
	curl.easy_setopt(handle, .POSTFIELDS, raw_data(data))
	curl.easy_setopt(handle, .WRITEFUNCTION, _curl_write_callback)
	curl.easy_setopt(handle, .WRITEDATA, &resp)

	// Set headers
	header_list: ^curl.slist
	header_list = curl.slist_append(header_list, "Content-Type: application/json")
	for h in ct.headers {
		header_str := strings.concatenate({h.name, ": ", h.value}, context.temp_allocator)
		header_cstr := strings.clone_to_cstring(header_str, context.temp_allocator)
		header_list = curl.slist_append(header_list, header_cstr)
	}
	curl.easy_setopt(handle, .HTTPHEADER, header_list)
	defer curl.slist_free_all(header_list)

	res := curl.easy_perform(handle)
	if res != .E_OK {
		delete(resp.body)
		return nil, .Send_Failed
	}

	result := make([]u8, len(resp.body), allocator)
	copy(result, resp.body[:])
	delete(resp.body)
	return result, .None
}

_curl_write_callback :: proc "c" (ptr: [^]u8, size: c.size_t, nmemb: c.size_t, userdata: rawptr) -> c.size_t {
	resp := cast(^Curl_Response)userdata
	context = resp.ctx
	total := size * nmemb
	for i in 0..<total {
		append(&resp.body, ptr[i])
	}
	return total
}

_curl_close :: proc(ctx: rawptr) {
	ct := cast(^Curl_Transport)ctx
	delete(ct.url, ct.allocator)
	free(ct, ct.allocator)
}
