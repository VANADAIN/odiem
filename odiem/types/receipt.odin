package types

import "core:math/big"

Tx_Status :: enum {
	Failure = 0,
	Success = 1,
}

Receipt :: struct {
	transaction_hash:    Hash,
	transaction_index:   u64,
	block_hash:          Hash,
	block_number:        u64,
	from:                Address,
	to:                  Maybe(Address), // nil for contract creation
	cumulative_gas_used: u64,
	gas_used:            u64,
	effective_gas_price: big.Int,
	contract_address:    Maybe(Address), // set if contract creation
	logs:                []Log,
	logs_bloom:          [256]u8,
	status:              Tx_Status,
	type:                Tx_Type,

	// EIP-4844
	blob_gas_used:       Maybe(u64),
	blob_gas_price:      Maybe(big.Int),
}

receipt_destroy :: proc(r: ^Receipt, allocator := context.allocator) {
	big.destroy(&r.effective_gas_price)
	for &l in r.logs {
		log_destroy(&l, allocator)
	}
	delete(r.logs, allocator)
	if bgp, has := r.blob_gas_price.?; has {
		bgp := bgp
		big.destroy(&bgp)
	}
}
