package types_tests

import "core:testing"
import "core:math/big"
import "core:mem"
import types "../"

// --- Address ---

@(test)
test_address_zero :: proc(t: ^testing.T) {
	addr := types.ADDRESS_ZERO
	for b in addr {
		testing.expect_value(t, b, u8(0))
	}
}

@(test)
test_address_size :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(types.Address), 20)
}

@(test)
test_address_distinct :: proc(t: ^testing.T) {
	// Address is distinct from [20]u8 — verify they're the same layout
	a: types.Address
	a[0] = 0xDE
	a[1] = 0xAD
	raw := transmute([20]u8)a
	testing.expect_value(t, raw[0], u8(0xDE))
	testing.expect_value(t, raw[1], u8(0xAD))
}

// --- Hash ---

@(test)
test_hash_zero :: proc(t: ^testing.T) {
	h := types.HASH_ZERO
	for b in h {
		testing.expect_value(t, b, u8(0))
	}
}

@(test)
test_hash_size :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(types.Hash), 32)
}

// --- Signature ---

@(test)
test_signature_layout :: proc(t: ^testing.T) {
	sig: types.Signature
	sig.r[0] = 0x01
	sig.s[31] = 0xFF
	sig.v = 27

	testing.expect_value(t, sig.r[0], u8(0x01))
	testing.expect_value(t, sig.s[31], u8(0xFF))
	testing.expect_value(t, sig.v, u8(27))
}

// --- Block_Number ---

@(test)
test_block_number_uint :: proc(t: ^testing.T) {
	bn := types.Block_Number(u64(12345))
	n, is_num := bn.(u64)
	testing.expect(t, is_num, "should be u64")
	testing.expect_value(t, n, u64(12345))
}

@(test)
test_block_number_tag :: proc(t: ^testing.T) {
	bn := types.Block_Number(types.Block_Tag.Latest)
	tag, is_tag := bn.(types.Block_Tag)
	testing.expect(t, is_tag, "should be Block_Tag")
	testing.expect_value(t, tag, types.Block_Tag.Latest)
}

@(test)
test_block_number_nil :: proc(t: ^testing.T) {
	bn: types.Block_Number
	_, is_num := bn.(u64)
	_, is_tag := bn.(types.Block_Tag)
	testing.expect(t, !is_num && !is_tag, "nil Block_Number should match nothing")
}

// --- Tx_Type ---

@(test)
test_tx_type_values :: proc(t: ^testing.T) {
	testing.expect_value(t, u8(types.Tx_Type.Legacy), u8(0x00))
	testing.expect_value(t, u8(types.Tx_Type.EIP2930), u8(0x01))
	testing.expect_value(t, u8(types.Tx_Type.EIP1559), u8(0x02))
	testing.expect_value(t, u8(types.Tx_Type.EIP4844), u8(0x03))
}

// --- Transaction ---

@(test)
test_transaction_create :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .EIP1559
	tx.chain_id = 1
	tx.nonce = 42
	tx.gas = 21000
	big.set(&tx.value, 1000000000000000000) // 1 ETH in wei
	defer types.transaction_destroy(&tx)

	testing.expect_value(t, tx.type, types.Tx_Type.EIP1559)
	testing.expect_value(t, tx.chain_id, u64(1))
	testing.expect_value(t, tx.nonce, u64(42))
	testing.expect_value(t, tx.gas, u64(21000))

	_, has_to := tx.to.?
	testing.expect(t, !has_to, "to should be nil for contract creation")
}

@(test)
test_transaction_with_to :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .Legacy
	addr: types.Address
	addr[0] = 0xDE
	addr[1] = 0xAD
	tx.to = addr
	defer types.transaction_destroy(&tx)

	to, has := tx.to.?
	testing.expect(t, has, "should have to address")
	testing.expect_value(t, to[0], u8(0xDE))
}

@(test)
test_transaction_access_list :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .EIP2930

	keys := make([]types.Hash, 1)
	keys[0][0] = 0x01

	al_addr: types.Address
	al_addr[0] = 0xAA

	entries := make([]types.Access_List_Entry, 1)
	entries[0] = types.Access_List_Entry{
		address = al_addr,
		storage_keys = keys,
	}
	tx.access_list = entries
	defer types.transaction_destroy(&tx)

	testing.expect_value(t, len(tx.access_list), 1)
	testing.expect_value(t, tx.access_list[0].address[0], u8(0xAA))
	testing.expect_value(t, len(tx.access_list[0].storage_keys), 1)
}

// --- Block ---

@(test)
test_block_create :: proc(t: ^testing.T) {
	b: types.Block
	b.number = 17000000
	b.gas_limit = 30000000
	b.gas_used = 15000000
	b.timestamp = 1681000000
	b.base_fee_per_gas = 30000000000 // 30 gwei
	defer types.block_destroy(&b)

	testing.expect_value(t, b.number, u64(17000000))
	fee, has := b.base_fee_per_gas.?
	testing.expect(t, has, "should have base fee")
	testing.expect_value(t, fee, u64(30000000000))
}

// --- Receipt ---

@(test)
test_receipt_success :: proc(t: ^testing.T) {
	r: types.Receipt
	r.status = .Success
	r.gas_used = 21000
	r.type = .EIP1559
	defer types.receipt_destroy(&r)

	testing.expect_value(t, r.status, types.Tx_Status.Success)
	testing.expect_value(t, u8(r.status), u8(1))
}

@(test)
test_receipt_failure :: proc(t: ^testing.T) {
	r: types.Receipt
	r.status = .Failure
	defer types.receipt_destroy(&r)

	testing.expect_value(t, r.status, types.Tx_Status.Failure)
	testing.expect_value(t, u8(r.status), u8(0))
}

// --- Log ---

@(test)
test_log_create :: proc(t: ^testing.T) {
	l: types.Log
	l.address[0] = 0xAA
	l.block_number = 100
	l.removed = false
	defer types.log_destroy(&l)

	testing.expect_value(t, l.address[0], u8(0xAA))
	testing.expect_value(t, l.block_number, u64(100))
	testing.expect(t, !l.removed, "should not be removed")
}

// --- Chain ---

@(test)
test_chain_ethereum_mainnet :: proc(t: ^testing.T) {
	eth := types.Chain{
		id = 1,
		name = "Ethereum",
		network = "mainnet",
		native_currency = {
			name = "Ether",
			symbol = "ETH",
			decimals = 18,
		},
		testnet = false,
	}

	testing.expect_value(t, eth.id, u64(1))
	testing.expect_value(t, eth.name, "Ethereum")
	testing.expect_value(t, eth.native_currency.symbol, "ETH")
	testing.expect_value(t, eth.native_currency.decimals, u8(18))
	testing.expect(t, !eth.testnet, "mainnet is not testnet")
}

// --- Fee_History ---

@(test)
test_fee_history_destroy :: proc(t: ^testing.T) {
	fh: types.Fee_History
	fh.oldest_block = 100

	fh.base_fee_per_gas = make([]big.Int, 2)
	big.set(&fh.base_fee_per_gas[0], 1000)
	big.set(&fh.base_fee_per_gas[1], 2000)

	fh.gas_used_ratio = make([]f64, 2)
	fh.gas_used_ratio[0] = 0.5
	fh.gas_used_ratio[1] = 0.8

	fh.reward = make([][]big.Int, 1)
	fh.reward[0] = make([]big.Int, 1)
	big.set(&fh.reward[0][0], 500)

	types.fee_history_destroy(&fh)

	testing.expect_value(t, fh.oldest_block, u64(100))
}

// --- Withdrawal ---

@(test)
test_withdrawal :: proc(t: ^testing.T) {
	w_addr: types.Address
	w_addr[0] = 0xBB
	w := types.Withdrawal{
		index = 1,
		validator_index = 42,
		address = w_addr,
		amount = 32000000000, // 32 ETH in Gwei
	}

	testing.expect_value(t, w.index, u64(1))
	testing.expect_value(t, w.validator_index, u64(42))
	testing.expect_value(t, w.address[0], u8(0xBB))
}
