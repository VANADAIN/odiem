package public_actions_tests

import "core:testing"
import "core:encoding/json"
import "core:math/big"
import "core:mem"
import "core:strings"
import pa "../"
import "../../../clients"
import "../../../types"
import "../../../transport"

// --- Mock transport ---

Mock_State :: struct {
	response:    string,
	last_method: string,
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
		}
	}

	if state.should_fail do return nil, .Send_Failed

	resp := state.response
	result := make([]u8, len(resp), allocator)
	mem.copy(raw_data(result), raw_data(resp), len(resp))
	return result, .None
}

_mock_close :: proc(ctx: rawptr) {}

_make_client :: proc(state: ^Mock_State) -> clients.Public_Client {
	tp := transport.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = state,
	}
	return clients.public_client_create(tp)
}

// --- Balance ---

@(test)
test_get_balance :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0xde0b6b3a7640000"}`,
	}
	client := _make_client(&state)

	addr: types.Address
	addr[0] = 0xAB

	balance, err := pa.get_balance(&client, addr)
	defer big.destroy(&balance)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getBalance")

	// 0xde0b6b3a7640000 = 1e18 (1 ETH in wei)
	str := big.int_to_string(&balance, 10) or_else "err"
	defer delete(str)
	testing.expect_value(t, str, "1000000000000000000")
}

@(test)
test_get_balance_zero :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x0"}`,
	}
	client := _make_client(&state)

	balance, err := pa.get_balance(&client, types.ADDRESS_ZERO)
	defer big.destroy(&balance)
	testing.expect(t, err == .None, "should succeed")
	is_zero, _ := big.is_zero(&balance)
	testing.expect(t, is_zero, "balance should be zero")
}

// --- Block number ---

@(test)
test_get_block_number :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x10d4f1"}`,
	}
	client := _make_client(&state)

	num, err := pa.get_block_number(&client)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, num, u64(0x10d4f1))
	testing.expect_value(t, state.last_method, "eth_blockNumber")
}

// --- Block ---

@(test)
test_get_block_by_number :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":{"number":"0x10","hash":"0xabc"}}`,
	}
	client := _make_client(&state)

	result, err := pa.get_block_by_number(&client, allocator = context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getBlockByNumber")

	obj := result.(json.Object)
	testing.expect_value(t, obj["number"].(json.String), "0x10")
}

@(test)
test_get_block_by_hash :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":{"number":"0x20"}}`,
	}
	client := _make_client(&state)

	hash: types.Hash
	hash[0] = 0xAB

	result, err := pa.get_block_by_hash(&client, hash, allocator = context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getBlockByHash")

	obj := result.(json.Object)
	testing.expect_value(t, obj["number"].(json.String), "0x20")
}

// --- Transaction ---

@(test)
test_get_transaction :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":{"hash":"0xdeadbeef","nonce":"0x5"}}`,
	}
	client := _make_client(&state)

	hash: types.Hash
	result, err := pa.get_transaction(&client, hash, context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getTransactionByHash")

	obj := result.(json.Object)
	testing.expect_value(t, obj["nonce"].(json.String), "0x5")
}

@(test)
test_get_transaction_receipt :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":{"status":"0x1","gasUsed":"0x5208"}}`,
	}
	client := _make_client(&state)

	hash: types.Hash
	result, err := pa.get_transaction_receipt(&client, hash, context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getTransactionReceipt")

	obj := result.(json.Object)
	testing.expect_value(t, obj["status"].(json.String), "0x1")
}

@(test)
test_get_transaction_count :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0xa"}`,
	}
	client := _make_client(&state)

	addr: types.Address
	nonce, err := pa.get_transaction_count(&client, addr)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, nonce, u64(10))
	testing.expect_value(t, state.last_method, "eth_getTransactionCount")
}

// --- Call & Estimate Gas ---

@(test)
test_eth_call :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x000000000000000000000000000000000000000000000000000000000000002a"}`,
	}
	client := _make_client(&state)

	to_addr: types.Address
	to_addr[19] = 0x01
	params := clients.Call_Params{
		to   = to_addr,
		data = transmute([]u8)string("\x70\xa0\x82\x31"), // balanceOf selector
	}

	result, err := pa.eth_call(&client, params)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_call")
	testing.expect(t, strings.has_prefix(result, "0x"), "result should be hex")
}

@(test)
test_estimate_gas :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x5208"}`,
	}
	client := _make_client(&state)

	to_addr: types.Address
	params := clients.Call_Params{
		to = to_addr,
	}

	gas, err := pa.estimate_gas(&client, params)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, gas, u64(21000))
	testing.expect_value(t, state.last_method, "eth_estimateGas")
}

// --- Gas price ---

@(test)
test_get_gas_price :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x3b9aca00"}`,
	}
	client := _make_client(&state)

	price, err := pa.get_gas_price(&client)
	defer big.destroy(&price)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_gasPrice")

	str := big.int_to_string(&price, 10) or_else "err"
	defer delete(str)
	testing.expect_value(t, str, "1000000000") // 1 gwei
}

@(test)
test_get_max_priority_fee :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x77359400"}`,
	}
	client := _make_client(&state)

	fee, err := pa.get_max_priority_fee(&client)
	defer big.destroy(&fee)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_maxPriorityFeePerGas")

	str := big.int_to_string(&fee, 10) or_else "err"
	defer delete(str)
	testing.expect_value(t, str, "2000000000") // 2 gwei
}

// --- Chain ---

@(test)
test_get_chain_id :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x1"}`,
	}
	client := _make_client(&state)

	id, err := pa.get_chain_id(&client)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, id, u64(1))
}

@(test)
test_get_net_version :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"1"}`,
	}
	client := _make_client(&state)

	version, err := pa.get_net_version(&client)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, version, "1")
	testing.expect_value(t, state.last_method, "net_version")
}

// --- Code & Storage ---

@(test)
test_get_code :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x6080604052"}`,
	}
	client := _make_client(&state)

	addr: types.Address
	code, err := pa.get_code(&client, addr)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, code, "0x6080604052")
	testing.expect_value(t, state.last_method, "eth_getCode")
}

@(test)
test_get_storage_at :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x0000000000000000000000000000000000000000000000000000000000000001"}`,
	}
	client := _make_client(&state)

	addr: types.Address
	slot: types.Hash
	storage, err := pa.get_storage_at(&client, addr, slot)
	testing.expect(t, err == .None, "should succeed")
	testing.expect(t, strings.has_prefix(storage, "0x"), "should be hex")
	testing.expect_value(t, state.last_method, "eth_getStorageAt")
}

// --- Logs ---

@(test)
test_get_logs :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":[{"address":"0x00","data":"0x"}]}`,
	}
	client := _make_client(&state)

	filter := clients.Log_Filter{
		from_block = types.Block_Tag.Latest,
		to_block   = types.Block_Tag.Latest,
	}

	result, err := pa.get_logs(&client, filter, context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_getLogs")

	arr := result.(json.Array)
	testing.expect_value(t, len(arr), 1)
}

// --- Fee history ---

@(test)
test_get_fee_history :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":{"oldestBlock":"0x10","baseFeePerGas":["0x1","0x2"]}}`,
	}
	client := _make_client(&state)

	result, err := pa.get_fee_history(&client, 4, allocator = context.temp_allocator)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, state.last_method, "eth_feeHistory")

	obj := result.(json.Object)
	testing.expect_value(t, obj["oldestBlock"].(json.String), "0x10")
}

// --- Helpers ---

@(test)
test_hex_to_big_int :: proc(t: ^testing.T) {
	val: json.Value = "0xde0b6b3a7640000"
	result, err := pa._hex_to_big_int(val)
	defer big.destroy(&result)
	testing.expect(t, err == .None, "should succeed")
	str := big.int_to_string(&result, 10) or_else "err"
	defer delete(str)
	testing.expect_value(t, str, "1000000000000000000")
}

@(test)
test_hex_to_big_int_zero :: proc(t: ^testing.T) {
	val: json.Value = "0x0"
	result, err := pa._hex_to_big_int(val)
	defer big.destroy(&result)
	testing.expect(t, err == .None, "should succeed")
	is_zero, _ := big.is_zero(&result)
	testing.expect(t, is_zero, "should be zero")
}

@(test)
test_bytes_to_hex :: proc(t: ^testing.T) {
	data := [?]u8{0xDE, 0xAD, 0xBE, 0xEF}
	result := pa._bytes_to_hex(data[:])
	testing.expect_value(t, result, "0xdeadbeef")
}

@(test)
test_bytes_to_hex_empty :: proc(t: ^testing.T) {
	result := pa._bytes_to_hex(nil)
	testing.expect_value(t, result, "0x")
}

// --- Transport failure ---

@(test)
test_transport_failure :: proc(t: ^testing.T) {
	state := Mock_State{should_fail = true}
	client := _make_client(&state)

	_, err := pa.get_block_number(&client)
	testing.expect_value(t, err, clients.Client_Error.Transport_Error)
}
