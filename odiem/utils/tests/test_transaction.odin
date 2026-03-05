package utils_tests

import "core:testing"
import "core:math/big"
import "core:encoding/hex"
import utils "../"
import types "../../types"

@(test)
test_serialize_legacy_tx :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .Legacy
	tx.nonce = 0
	gp: big.Int
	big.set(&gp, 20000000000) // 20 gwei
	tx.gas_price = gp
	tx.gas = 21000
	to, _ := utils.get_address("0x0000000000000000000000000000000000000001")
	tx.to = to
	big.set(&tx.value, 1000000000000000000) // 1 ETH
	tx.v = 27
	defer types.transaction_destroy(&tx)

	encoded, err := utils.serialize_transaction(&tx)
	defer delete(encoded)
	testing.expect(t, err == .None, "serialize legacy tx")
	testing.expect(t, len(encoded) > 0, "should produce bytes")
}

@(test)
test_serialize_eip1559_tx :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .EIP1559
	tx.chain_id = 1
	tx.nonce = 0
	mp: big.Int
	big.set(&mp, 2000000000) // 2 gwei priority
	tx.max_priority_fee_per_gas = mp
	mf: big.Int
	big.set(&mf, 30000000000) // 30 gwei max
	tx.max_fee_per_gas = mf
	tx.gas = 21000
	to, _ := utils.get_address("0x0000000000000000000000000000000000000001")
	tx.to = to
	big.set(&tx.value, 0)
	defer types.transaction_destroy(&tx)

	encoded, err := utils.serialize_transaction(&tx)
	defer delete(encoded)
	testing.expect(t, err == .None, "serialize EIP-1559 tx")
	testing.expect(t, len(encoded) > 0, "should produce bytes")
	// EIP-1559 tx should start with type byte 0x02
	testing.expect_value(t, encoded[0], u8(0x02))
}

@(test)
test_get_transaction_hash :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .Legacy
	tx.nonce = 0
	gp: big.Int
	big.set(&gp, 20000000000)
	tx.gas_price = gp
	tx.gas = 21000
	to, _ := utils.get_address("0x0000000000000000000000000000000000000001")
	tx.to = to
	big.set(&tx.value, 0)
	tx.v = 27
	defer types.transaction_destroy(&tx)

	hash, err := utils.get_transaction_hash(&tx)
	testing.expect(t, err == .None, "hash should succeed")

	// Hash should be non-zero
	zero := types.HASH_ZERO
	testing.expect(t, hash != zero, "hash should not be zero")
}

@(test)
test_serialize_eip2930_tx :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .EIP2930
	tx.chain_id = 1
	tx.nonce = 5
	gp: big.Int
	big.set(&gp, 10000000000)
	tx.gas_price = gp
	tx.gas = 21000
	to, _ := utils.get_address("0x0000000000000000000000000000000000000001")
	tx.to = to
	defer types.transaction_destroy(&tx)

	encoded, err := utils.serialize_transaction(&tx)
	defer delete(encoded)
	testing.expect(t, err == .None, "serialize EIP-2930 tx")
	testing.expect_value(t, encoded[0], u8(0x01))
}

@(test)
test_serialize_contract_creation :: proc(t: ^testing.T) {
	tx: types.Transaction
	tx.type = .Legacy
	tx.nonce = 0
	gp: big.Int
	big.set(&gp, 20000000000)
	tx.gas_price = gp
	tx.gas = 100000
	// to = nil for contract creation
	bytecode := [?]u8{0x60, 0x80, 0x60, 0x40}
	tx_data := make([]u8, 4)
	copy(tx_data, bytecode[:])
	tx.data = tx_data
	tx.v = 27
	defer types.transaction_destroy(&tx)

	encoded, err := utils.serialize_transaction(&tx)
	defer delete(encoded)
	testing.expect(t, err == .None, "serialize contract creation tx")
	testing.expect(t, len(encoded) > 0, "should produce bytes")
}
