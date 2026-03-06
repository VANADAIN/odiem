package clients_tests

import "core:testing"
import "core:encoding/json"
import "core:mem"
import "core:strings"
import cl "../"
import "../../types"
import "../../transport"

// --- Mock transport ---

Mock_State :: struct {
	response:    string,
	last_method: string, // extracted from last request
	call_count:  int,
	should_fail: bool,
}

_mock_send :: proc(ctx: rawptr, data: []u8, allocator: mem.Allocator) -> ([]u8, transport.Transport_Error) {
	state := cast(^Mock_State)ctx
	state.call_count += 1

	// Extract method from request for verification
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

_make_mock :: proc(state: ^Mock_State) -> transport.Transport {
	return transport.Transport{
		send  = _mock_send,
		close = _mock_close,
		ctx   = state,
	}
}

// --- Mock account ---

_mock_sign :: proc(ctx: rawptr, hash: types.Hash) -> (types.Signature, bool) {
	sig: types.Signature
	sig.v = 27
	sig.r[31] = 0x01
	sig.s[31] = 0x02
	return sig, true
}

_make_mock_account :: proc() -> cl.Account {
	addr: types.Address
	addr[19] = 0x01
	return cl.Account{
		address   = addr,
		sign_hash = _mock_sign,
		ctx       = nil,
	}
}

// --- Public client tests ---

@(test)
test_public_client_create :: proc(t: ^testing.T) {
	state := Mock_State{}
	tp := _make_mock(&state)

	chain := types.Chain{id = 1, name = "Ethereum"}
	client := cl.public_client_create(tp, chain)

	testing.expect_value(t, client.chain.id, u64(1))
	testing.expect_value(t, client.chain.name, "Ethereum")
}

@(test)
test_rpc_call_success :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x10"}`,
	}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp)

	result, _, err := cl.rpc_call(&client, "eth_blockNumber", allocator = context.temp_allocator)
	testing.expect(t, err == .None, "call should succeed")
	testing.expect_value(t, result.(json.String), "0x10")
	testing.expect_value(t, state.last_method, "eth_blockNumber")
}

@(test)
test_rpc_call_with_params :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x100"}`,
	}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp)

	params := make(json.Array, 2, context.temp_allocator)
	params[0] = json.Value("0xdead")
	params[1] = json.Value("latest")

	result, _, err := cl.rpc_call(&client, "eth_getBalance", params, context.temp_allocator)
	testing.expect(t, err == .None, "call should succeed")
	testing.expect_value(t, result.(json.String), "0x100")
	testing.expect_value(t, state.last_method, "eth_getBalance")
}

@(test)
test_rpc_call_error :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}`,
	}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp)

	_, rpc_err, err := cl.rpc_call(&client, "bad_method", allocator = context.temp_allocator)
	testing.expect_value(t, err, cl.Client_Error.RPC_Error)
	testing.expect_value(t, rpc_err.code, i64(-32601))
}

@(test)
test_rpc_call_transport_failure :: proc(t: ^testing.T) {
	state := Mock_State{should_fail = true}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp)

	_, _, err := cl.rpc_call(&client, "eth_blockNumber", allocator = context.temp_allocator)
	testing.expect_value(t, err, cl.Client_Error.Transport_Error)
}

@(test)
test_auto_increment_id :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":null}`,
	}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp)

	cl.rpc_call(&client, "eth_blockNumber", allocator = context.temp_allocator)
	cl.rpc_call(&client, "eth_chainId", allocator = context.temp_allocator)
	testing.expect_value(t, client.next_id, u64(3))
}

@(test)
test_get_chain_id_from_config :: proc(t: ^testing.T) {
	state := Mock_State{}
	tp := _make_mock(&state)
	chain := types.Chain{id = 137}
	client := cl.public_client_create(tp, chain)

	chain_id, err := cl.get_chain_id(&client)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, chain_id, u64(137))
	testing.expect_value(t, state.call_count, 0) // no RPC call needed
}

@(test)
test_get_chain_id_from_node :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x1"}`,
	}
	tp := _make_mock(&state)
	client := cl.public_client_create(tp) // no chain config

	chain_id, err := cl.get_chain_id(&client)
	testing.expect(t, err == .None, "should succeed")
	testing.expect_value(t, chain_id, u64(1))
	testing.expect_value(t, state.last_method, "eth_chainId")
}

// --- Wallet client tests ---

@(test)
test_wallet_client_create :: proc(t: ^testing.T) {
	state := Mock_State{}
	tp := _make_mock(&state)
	account := _make_mock_account()
	chain := types.Chain{id = 1}

	wallet := cl.wallet_client_create(tp, account, chain)

	addr := cl.wallet_address(&wallet)
	testing.expect_value(t, addr[19], u8(0x01))
	testing.expect_value(t, wallet.public.chain.id, u64(1))
}

@(test)
test_wallet_rpc_call :: proc(t: ^testing.T) {
	state := Mock_State{
		response = `{"jsonrpc":"2.0","id":1,"result":"0x5"}`,
	}
	tp := _make_mock(&state)
	account := _make_mock_account()
	wallet := cl.wallet_client_create(tp, account)

	result, _, err := cl.wallet_rpc_call(&wallet, "eth_getTransactionCount", allocator = context.temp_allocator)
	testing.expect(t, err == .None, "call should succeed")
	testing.expect_value(t, result.(json.String), "0x5")
}

@(test)
test_wallet_account_sign :: proc(t: ^testing.T) {
	account := _make_mock_account()
	hash: types.Hash
	hash[0] = 0xFF

	sig, ok := account.sign_hash(account.ctx, hash)
	testing.expect(t, ok, "sign should succeed")
	testing.expect_value(t, sig.v, u8(27))
	testing.expect_value(t, sig.r[31], u8(0x01))
	testing.expect_value(t, sig.s[31], u8(0x02))
}

// --- Helper tests ---

@(test)
test_block_number_to_hex :: proc(t: ^testing.T) {
	testing.expect_value(t, cl.block_number_to_hex(u64(255)), "0xff")
	testing.expect_value(t, cl.block_number_to_hex(u64(0)), "0x0")
	testing.expect_value(t, cl.block_number_to_hex(types.Block_Tag.Latest), "latest")
	testing.expect_value(t, cl.block_number_to_hex(types.Block_Tag.Earliest), "earliest")
	testing.expect_value(t, cl.block_number_to_hex(types.Block_Tag.Pending), "pending")
	testing.expect_value(t, cl.block_number_to_hex(types.Block_Tag.Safe), "safe")
	testing.expect_value(t, cl.block_number_to_hex(types.Block_Tag.Finalized), "finalized")
}

@(test)
test_address_to_hex :: proc(t: ^testing.T) {
	addr: types.Address
	addr[0] = 0xDE
	addr[1] = 0xAD
	addr[18] = 0xBE
	addr[19] = 0xEF

	result := cl.address_to_hex(addr)
	testing.expect(t, strings.has_prefix(result, "0x"), "should be 0x prefixed")
	testing.expect_value(t, len(result), 42)
	testing.expect(t, strings.has_prefix(result, "0xdead"), "should start with dead")
	testing.expect(t, strings.has_suffix(result, "beef"), "should end with beef")
}

@(test)
test_hash_to_hex :: proc(t: ^testing.T) {
	h: types.Hash
	h[0] = 0xAB
	h[31] = 0xCD

	result := cl.hash_to_hex(h)
	testing.expect(t, strings.has_prefix(result, "0x"), "should be 0x prefixed")
	testing.expect_value(t, len(result), 66)
	testing.expect(t, strings.has_prefix(result, "0xab"), "should start with ab")
	testing.expect(t, strings.has_suffix(result, "cd"), "should end with cd")
}

@(test)
test_parse_hex_u64 :: proc(t: ^testing.T) {
	testing.expect_value(t, cl._parse_hex_u64("0x10"), u64(16))
	testing.expect_value(t, cl._parse_hex_u64("0xff"), u64(255))
	testing.expect_value(t, cl._parse_hex_u64("0x0"), u64(0))
	testing.expect_value(t, cl._parse_hex_u64("0x1234"), u64(0x1234))
	testing.expect_value(t, cl._parse_hex_u64("ff"), u64(255))
}
