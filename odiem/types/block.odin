package types

import "core:math/big"

Block_Tag :: enum {
	Latest,
	Earliest,
	Pending,
	Safe,
	Finalized,
}

Block_Number :: union {
	u64,
	Block_Tag,
}

Block :: struct {
	number:            u64,
	hash:              Hash,
	parent_hash:       Hash,
	nonce:             u64,
	sha3_uncles:       Hash,
	logs_bloom:        [256]u8,
	transactions_root: Hash,
	state_root:        Hash,
	receipts_root:     Hash,
	miner:             Address,
	difficulty:        big.Int,
	total_difficulty:  big.Int,
	extra_data:        []u8,
	size:              u64,
	gas_limit:         u64,
	gas_used:          u64,
	timestamp:         u64,
	transactions:      []Hash, // transaction hashes (or full txs depending on request)
	uncles:            []Hash,

	// EIP-1559
	base_fee_per_gas:  Maybe(u64),

	// EIP-4844
	blob_gas_used:     Maybe(u64),
	excess_blob_gas:   Maybe(u64),

	// EIP-4895
	withdrawals_root:  Maybe(Hash),
	withdrawals:       []Withdrawal,
}

Withdrawal :: struct {
	index:           u64,
	validator_index: u64,
	address:         Address,
	amount:          u64, // in Gwei
}

block_destroy :: proc(b: ^Block, allocator := context.allocator) {
	big.destroy(&b.difficulty)
	big.destroy(&b.total_difficulty)
	delete(b.extra_data, allocator)
	delete(b.transactions, allocator)
	delete(b.uncles, allocator)
	delete(b.withdrawals, allocator)
}
