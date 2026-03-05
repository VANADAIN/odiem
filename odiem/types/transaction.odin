package types

import "core:math/big"

Tx_Type :: enum u8 {
	Legacy  = 0x00,
	EIP2930 = 0x01,
	EIP1559 = 0x02,
	EIP4844 = 0x03,
}

// Unified transaction struct covering all types.
// Fields are optional depending on tx type.
Transaction :: struct {
	type:                    Tx_Type,
	chain_id:                u64,
	nonce:                   u64,
	to:                      Maybe(Address), // nil for contract creation
	value:                   big.Int,
	data:                    []u8,
	gas:                     u64,

	// Legacy / EIP-2930
	gas_price:               Maybe(big.Int),

	// EIP-1559 / EIP-4844
	max_fee_per_gas:         Maybe(big.Int),
	max_priority_fee_per_gas: Maybe(big.Int),

	// EIP-2930 / EIP-1559 / EIP-4844
	access_list:             []Access_List_Entry,

	// EIP-4844
	max_fee_per_blob_gas:    Maybe(big.Int),
	blob_versioned_hashes:   []Hash,

	// Signature
	v:                       u64,
	r:                       big.Int,
	s:                       big.Int,

	// Derived (populated after fetching from node)
	hash:                    Maybe(Hash),
	block_hash:              Maybe(Hash),
	block_number:            Maybe(u64),
	transaction_index:       Maybe(u64),
	from:                    Maybe(Address),
}

Access_List_Entry :: struct {
	address:      Address,
	storage_keys: []Hash,
}

transaction_destroy :: proc(tx: ^Transaction, allocator := context.allocator) {
	big.destroy(&tx.value)
	delete(tx.data, allocator)

	if gp, has := tx.gas_price.?; has {
		gp := gp
		big.destroy(&gp)
	}
	if mf, has := tx.max_fee_per_gas.?; has {
		mf := mf
		big.destroy(&mf)
	}
	if mp, has := tx.max_priority_fee_per_gas.?; has {
		mp := mp
		big.destroy(&mp)
	}
	if mb, has := tx.max_fee_per_blob_gas.?; has {
		mb := mb
		big.destroy(&mb)
	}

	for &entry in tx.access_list {
		delete(entry.storage_keys, allocator)
	}
	delete(tx.access_list, allocator)
	delete(tx.blob_versioned_hashes, allocator)
	big.destroy(&tx.r)
	big.destroy(&tx.s)
}
