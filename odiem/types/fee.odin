package types

import "core:math/big"

Fee_History :: struct {
	oldest_block:    u64,
	base_fee_per_gas: []big.Int,
	gas_used_ratio:  []f64,
	reward:          [][]big.Int, // reward[block_index][percentile_index]
}

fee_history_destroy :: proc(f: ^Fee_History, allocator := context.allocator) {
	for &fee in f.base_fee_per_gas {
		big.destroy(&fee)
	}
	delete(f.base_fee_per_gas, allocator)
	delete(f.gas_used_ratio, allocator)
	for &block_rewards in f.reward {
		for &r in block_rewards {
			big.destroy(&r)
		}
		delete(block_rewards, allocator)
	}
	delete(f.reward, allocator)
}
