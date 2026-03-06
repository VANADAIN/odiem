package transport_tests

import "core:testing"
import "core:mem"
import "core:strings"
import tp "../"

// --- Mock transport helpers ---

Mock_State :: struct {
	response:    []u8,
	should_fail: bool,
	call_count:  int,
}

_mock_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, tp.Transport_Error) {
	state := cast(^Mock_State)ctx
	state.call_count += 1

	if state.should_fail do return nil, .Send_Failed

	result := make([]u8, len(state.response), allocator)
	mem.copy(raw_data(result), raw_data(state.response), len(state.response))
	return result, .None
}

_mock_close :: proc(ctx: rawptr) {}

_make_mock :: proc(state: ^Mock_State) -> tp.Transport {
	return tp.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = state,
	}
}

// --- Transport interface tests ---

@(test)
test_transport_send :: proc(t: ^testing.T) {
	state := Mock_State{
		response = transmute([]u8)string(`{"result":"ok"}`),
	}
	transport := _make_mock(&state)

	data := transmute([]u8)string(`{"method":"test"}`)
	result, err := transport.send(transport.ctx, data, context.temp_allocator)
	testing.expect(t, err == .None, "send should succeed")
	testing.expect_value(t, string(result), `{"result":"ok"}`)
	testing.expect_value(t, state.call_count, 1)
}

@(test)
test_transport_send_failure :: proc(t: ^testing.T) {
	state := Mock_State{should_fail = true}
	transport := _make_mock(&state)

	data := transmute([]u8)string(`{}`)
	_, err := transport.send(transport.ctx, data, context.temp_allocator)
	testing.expect_value(t, err, tp.Transport_Error.Send_Failed)
}

// --- URL parsing ---

@(test)
test_parse_http_url :: proc(t: ^testing.T) {
	host, port, path, ok := tp._parse_http_url("http://localhost:8545")
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, host, "localhost")
	testing.expect_value(t, port, "8545")
	testing.expect_value(t, path, "/")
}

@(test)
test_parse_http_url_with_path :: proc(t: ^testing.T) {
	host, port, path, ok := tp._parse_http_url("http://rpc.example.com/v1/mainnet")
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, host, "rpc.example.com")
	testing.expect_value(t, port, "80")
	testing.expect_value(t, path, "/v1/mainnet")
}

@(test)
test_parse_https_url :: proc(t: ^testing.T) {
	host, port, path, ok := tp._parse_http_url("https://mainnet.infura.io/v3/key")
	testing.expect(t, ok, "should parse")
	testing.expect_value(t, host, "mainnet.infura.io")
	testing.expect_value(t, port, "443")
	testing.expect_value(t, path, "/v3/key")
}

@(test)
test_parse_invalid_url :: proc(t: ^testing.T) {
	_, _, _, ok := tp._parse_http_url("ws://localhost:8545")
	testing.expect(t, !ok, "ws:// should be invalid for http parser")
}

// --- Fallback transport ---

@(test)
test_fallback_first_succeeds :: proc(t: ^testing.T) {
	s1 := Mock_State{response = transmute([]u8)string(`{"id":1}`)}
	s2 := Mock_State{response = transmute([]u8)string(`{"id":2}`)}

	transports := [?]tp.Transport{_make_mock(&s1), _make_mock(&s2)}
	fb, err := tp.fallback_create(transports[:], context.temp_allocator)
	testing.expect(t, err == .None, "create should succeed")

	data := transmute([]u8)string(`{}`)
	result, send_err := fb.send(fb.ctx, data, context.temp_allocator)
	testing.expect(t, send_err == .None, "send should succeed")
	testing.expect_value(t, string(result), `{"id":1}`)
	testing.expect_value(t, s1.call_count, 1)
	testing.expect_value(t, s2.call_count, 0)
}

@(test)
test_fallback_first_fails :: proc(t: ^testing.T) {
	s1 := Mock_State{should_fail = true}
	s2 := Mock_State{response = transmute([]u8)string(`{"id":2}`)}

	transports := [?]tp.Transport{_make_mock(&s1), _make_mock(&s2)}
	fb, err := tp.fallback_create(transports[:], context.temp_allocator)
	testing.expect(t, err == .None, "create should succeed")

	data := transmute([]u8)string(`{}`)
	result, send_err := fb.send(fb.ctx, data, context.temp_allocator)
	testing.expect(t, send_err == .None, "should fallback to second")
	testing.expect_value(t, string(result), `{"id":2}`)
	testing.expect_value(t, s1.call_count, 1)
	testing.expect_value(t, s2.call_count, 1)
}

@(test)
test_fallback_all_fail :: proc(t: ^testing.T) {
	s1 := Mock_State{should_fail = true}
	s2 := Mock_State{should_fail = true}

	transports := [?]tp.Transport{_make_mock(&s1), _make_mock(&s2)}
	fb, err := tp.fallback_create(transports[:], context.temp_allocator)
	testing.expect(t, err == .None, "create should succeed")

	data := transmute([]u8)string(`{}`)
	_, send_err := fb.send(fb.ctx, data, context.temp_allocator)
	testing.expect_value(t, send_err, tp.Transport_Error.Send_Failed)
}

// --- HTTP request building ---

@(test)
test_build_http_request :: proc(t: ^testing.T) {
	ht := tp.HTTP_Transport{
		host = "localhost",
		port = "8545",
		path = "/",
	}
	body := transmute([]u8)string(`{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}`)
	req := tp._build_http_request(&ht, body)
	req_str := string(req)

	testing.expect(t, strings.has_prefix(req_str, "POST / HTTP/1.1\r\n"), "should start with POST")
	testing.expect(t, strings.contains(req_str, "Host: localhost:8545\r\n"), "should have Host header with port")
	testing.expect(t, strings.contains(req_str, "Content-Type: application/json\r\n"), "should have Content-Type")
	testing.expect(t, strings.contains(req_str, "Content-Length: 51\r\n"), "should have Content-Length")
	testing.expect(t, strings.contains(req_str, "Connection: close\r\n"), "should have Connection: close")
	testing.expect(t, strings.contains(req_str, `"eth_blockNumber"`), "body should be appended")
}

@(test)
test_build_http_request_custom_headers :: proc(t: ^testing.T) {
	headers := [?]tp.Header{
		{name = "Authorization", value = "Bearer token123"},
	}
	ht := tp.HTTP_Transport{
		host    = "rpc.example.com",
		port    = "80",
		path    = "/v1",
		headers = headers[:],
	}
	body := transmute([]u8)string(`{}`)
	req := tp._build_http_request(&ht, body)
	req_str := string(req)

	testing.expect(t, strings.contains(req_str, "Host: rpc.example.com\r\n"), "port 80 should not show in host")
	testing.expect(t, strings.contains(req_str, "Authorization: Bearer token123\r\n"), "custom header")
}
