package transport

import "core:net"
import "core:mem"
import "core:strings"
import "core:fmt"
import "core:strconv"

// HTTP transport — sends JSON-RPC over HTTP POST.
// Uses raw TCP sockets with manual HTTP/1.1 framing.
HTTP_Transport :: struct {
	host:    string,
	port:    string,
	path:    string,
	headers: []Header,
	allocator: mem.Allocator,
}

// Create an HTTP transport from a URL like "http://localhost:8545".
http_create :: proc(url: string, headers: []Header = nil, allocator := context.allocator) -> (Transport, Transport_Error) {
	host, port, path, ok := _parse_http_url(url)
	if !ok do return {}, .Connection_Failed

	ht, alloc_err := new(HTTP_Transport, allocator)
	if alloc_err != nil do return {}, .Alloc_Failed

	ht.host = strings.clone(host, allocator)
	ht.port = strings.clone(port, allocator)
	ht.path = strings.clone(path, allocator)
	ht.headers = headers
	ht.allocator = allocator

	return Transport{
		send  = _http_send,
		close = _http_close,
		ctx   = ht,
	}, .None
}

// Destroy an HTTP transport.
http_destroy :: proc(t: ^Transport) {
	if t.close != nil {
		t.close(t.ctx)
	}
}

_http_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, Transport_Error) {
	ht := cast(^HTTP_Transport)ctx

	// Connect
	addr_str := strings.concatenate({ht.host, ":", ht.port}, context.temp_allocator)
	socket, net_err := net.dial_tcp_from_hostname_and_port_string(addr_str)
	if net_err != nil do return nil, .Connection_Failed
	defer net.close(socket)

	// Build HTTP request
	req := _build_http_request(ht, data)
	defer delete(req, context.temp_allocator)

	// Send
	total_sent := 0
	for total_sent < len(req) {
		n, send_err := net.send_tcp(socket, req[total_sent:])
		if send_err != .None do return nil, .Send_Failed
		total_sent += n
	}

	// Read response
	return _read_http_response(socket, allocator)
}

_http_close :: proc(ctx: rawptr) {
	ht := cast(^HTTP_Transport)ctx
	delete(ht.host, ht.allocator)
	delete(ht.port, ht.allocator)
	delete(ht.path, ht.allocator)
	free(ht, ht.allocator)
}

_build_http_request :: proc(ht: ^HTTP_Transport, body: []u8) -> []u8 {
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "POST %s HTTP/1.1\r\n", ht.path)
	fmt.sbprintf(&b, "Host: %s", ht.host)
	if ht.port != "80" && ht.port != "443" {
		fmt.sbprintf(&b, ":%s", ht.port)
	}
	strings.write_string(&b, "\r\n")
	strings.write_string(&b, "Content-Type: application/json\r\n")
	fmt.sbprintf(&b, "Content-Length: %d\r\n", len(body))
	strings.write_string(&b, "Connection: close\r\n")

	for h in ht.headers {
		fmt.sbprintf(&b, "%s: %s\r\n", h.name, h.value)
	}

	strings.write_string(&b, "\r\n")

	header_str := strings.to_string(b)
	result := make([]u8, len(header_str) + len(body), context.temp_allocator)
	mem.copy(raw_data(result), raw_data(header_str), len(header_str))
	if len(body) > 0 {
		mem.copy(&result[len(header_str)], raw_data(body), len(body))
	}
	return result
}

_read_http_response :: proc(socket: net.TCP_Socket, allocator: mem.Allocator) -> ([]u8, Transport_Error) {
	buf: [65536]u8
	total := 0

	// Read until we have the full response
	for {
		n, recv_err := net.recv_tcp(socket, buf[total:])
		if n > 0 {
			total += n
		}
		if recv_err != .None || n <= 0 {
			break
		}
		if total >= len(buf) do break
	}

	if total == 0 do return nil, .Recv_Failed

	resp := string(buf[:total])

	// Find end of headers
	header_end := strings.index(resp, "\r\n\r\n")
	if header_end < 0 do return nil, .Recv_Failed
	body_start := header_end + 4

	// Extract body
	body_len := total - body_start
	if body_len <= 0 do return nil, .Recv_Failed

	result, alloc_err := make([]u8, body_len, allocator)
	if alloc_err != nil do return nil, .Alloc_Failed
	mem.copy(raw_data(result), &buf[body_start], body_len)
	return result, .None
}

_parse_http_url :: proc(url: string) -> (host: string, port: string, path: string, ok: bool) {
	s := url
	if strings.has_prefix(s, "https://") {
		s = s[8:]
		port = "443"
	} else if strings.has_prefix(s, "http://") {
		s = s[7:]
		port = "80"
	} else {
		return "", "", "", false
	}

	path_idx := strings.index_byte(s, '/')
	host_part: string
	if path_idx >= 0 {
		host_part = s[:path_idx]
		path = s[path_idx:]
	} else {
		host_part = s
		path = "/"
	}

	colon_idx := strings.index_byte(host_part, ':')
	if colon_idx >= 0 {
		host = host_part[:colon_idx]
		port = host_part[colon_idx + 1:]
	} else {
		host = host_part
	}

	return host, port, path, true
}
