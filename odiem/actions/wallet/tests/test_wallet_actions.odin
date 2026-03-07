package wallet_actions_tests

import "core:testing"
import "core:encoding/json"
import "core:mem"
import "core:strings"
import wa "../"
import "../../../clients"
import "../../../types"
import "../../../transport"

// --- Mock transport ---

Mock_State :: struct {
	response:    string,
	last_method: string,
	last_params: string,
	call_count:  int,
	should_fail: bool,
}

_mock_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, transport.Transport_Error) {
	state := cast(^Mock_State)ctx
	state.call_count += 1

	if parsed, err := json.parse(data, allocator = context.temp_allocator); err == .None {
		if obj, is_obj := parsed.(json.Object); is_obj {
			if method, has := obj["method"]; has {
				if ms, is_str := method.(json.String); is_str {
					state.last_method = ms
				}
			}
			if params, has := obj["params"]; has {
				if pb, merr := json.marshal(params, allocator = context.temp_allocator); merr == nil {
					state.last_params = string(pb)
				}
			}
		}
	}

	if state.should_fail do return nil, .Send_Failed

	resp := state.response
	result := make([]u8, len(resp), allocator)
	mem.copy(raw_data(result), raw_data(resp), len(resp))
	return result, .None
}

_mock_close :: proc(ctx: rawptr) {}

// --- Mock account ---

_mock_sign :: proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool) {
	sig: types.Signature
	sig.v = 27
	sig.r[31] = 0xAA
	sig.s[31] = 0xBB
	return sig, true
}

_mock_sign_fail :: proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool) {
	return {}, false
}

_make_wallet :: proc(state: ^Mock_State, sign_fn: proc(rawptr, types.Hash) -> (types.Signature, bool) = _mock_sign) -> clients.Wallet_Client {
	tp := transport.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = state,
	}
	addr: types.Address
	addr[19] = 0x42
	account := clients.Account{
		address   = addr,
		sign_hash = sign_fn,
		ctx       = nil,
	}
	return clients.wallet_client_create(tp, account)
}

// --- Sign tests ---

@(test)
test_sign_hash :: proc(t: ^testing.T) {
	state := Mock_State{}
	wallet := _make_wallet(&state)

	hash: types.Hash
	hash[0] = 0xFF

	sig, err := wa.sign_hash(&wallet, hash)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, sig.v, u8(27))
	testing.expect_value(t, sig.r[31], u8(0xAA))
	testing.expect_value(t, sig.s[31], u8(0xBB))
	testing.expect_value(t, state.call_count, 0) // no RPC call
}

@(test)
test_sign_message :: proc(t: ^testing.T) {
	state := Mock_State{}
	wallet := _make_wallet(&state)

	msg := transmute([]u8)string("hello")
	sig, err := wa.sign_message(&wallet, msg)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, sig.v, u8(27))
	testing.expect_value(t, state.call_count, 0) // no RPC call
}

@(test)
test_sign_hash_failure :: proc(t: ^testing.T) {
	state := Mock_State{}
	wallet := _make_wallet(&state, _mock_sign_fail)

	hash: types.Hash
	_, err := wa.sign_hash(&wallet, hash)
	testing.expect_value(t, err, clients.Client_Error.Invalid_Response)
}

// --- Send raw transaction ---

@(test)
test_send_raw_transaction :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"}`,
	}
	wallet := _make_wallet(&state)

	tx_data := [?]u8{0x02, 0xf8, 0x73}
	hash, err := wa.send_raw_transaction(&wallet, tx_data[:])
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_sendRawTransaction")
	testing.expect_value(t, hash[0], u8(0xab))
	testing.expect_value(t, hash[1], u8(0xcd))
}

@(test)
test_send_raw_transaction_transport_fail :: proc(t: ^testing.T) {
	state := Mock_State{should_fail = true}
	wallet := _make_wallet(&state)

	_, err := wa.send_raw_transaction(&wallet, nil)
	testing.expect_value(t, err, clients.Client_Error.Transport_Error)
}

// --- Send transaction ---

@(test)
test_send_transaction :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"}`,
	}
	wallet := _make_wallet(&state)

	tx_data := [?]u8{0x01, 0x02, 0x03}
	hash, err := wa.send_transaction(&wallet, tx_data[:])
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_sendRawTransaction")
	testing.expect_value(t, hash[0], u8(0x12))
}

// --- Write contract ---

@(test)
test_write_contract :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0xdeadbeef00000000deadbeef00000000deadbeef00000000deadbeef00000000"}`,
	}
	wallet := _make_wallet(&state)

	to: types.Address
	to[19] = 0x01
	calldata := [?]u8{0x70, 0xa0, 0x82, 0x31}

	hash, err := wa.write_contract(&wallet, to, calldata[:])
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_sendTransaction")
	testing.expect_value(t, hash[0], u8(0xde))

	// Verify params contain from and to addresses
	testing.expect(t, strings.contains(state.last_params, "from"), "should have from")
	testing.expect(t, strings.contains(state.last_params, "to"), "should have to")
	testing.expect(t, strings.contains(state.last_params, "data"), "should have data")
}

@(test)
test_write_contract_with_value :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x0000000000000000000000000000000000000000000000000000000000000001"}`,
	}
	wallet := _make_wallet(&state)

	to: types.Address
	hash, err := wa.write_contract(&wallet, to, nil, 1000)
	testing.expect(t, err == .None, "should succeed")
	testing.expect(t, strings.contains(state.last_params, "value"), "should have value")
}

// --- Deploy contract ---

@(test)
test_deploy_contract :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}`,
	}
	wallet := _make_wallet(&state)

	bytecode := [?]u8{0x60, 0x80, 0x60, 0x40, 0x52}
	hash, err := wa.deploy_contract(&wallet, bytecode[:])
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_sendTransaction")
	testing.expect_value(t, hash[0], u8(0xAA))

	// Deploy should have from and data but no to
	testing.expect(t, strings.contains(state.last_params, "from"), "should have from")
	testing.expect(t, strings.contains(state.last_params, "data"), "should have data")
}

// --- Helpers ---

@(test)
test_bytes_to_hex :: proc(t: ^testing.T) {
	data := [?]u8{0xDE, 0xAD}
	result := wa._bytes_to_hex(data[:])
	testing.expect_value(t, result, "0xdead")
}

@(test)
test_hex_string_to_hash :: proc(t: ^testing.T) {
	val: json.Value = "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
	hash, err := wa._hex_string_to_hash(val)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, hash[0], u8(0xAB))
	testing.expect_value(t, hash[1], u8(0xCD))
	testing.expect_value(t, hash[2], u8(0xEF))
}

@(test)
test_hex_string_to_hash_invalid :: proc(t: ^testing.T) {
	val: json.Value = json.Integer(42)
	_, err := wa._hex_string_to_hash(val)
	testing.expect_value(t, err, clients.Client_Error.Invalid_Response)
}
