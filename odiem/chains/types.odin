package chains

import "../types"

Chain :: types.Chain
Native_Currency :: types.Native_Currency
Block_Explorer :: types.Block_Explorer

// Create a custom chain with the given parameters.
custom :: proc(
	id: u64,
	name: string,
	network: string,
	currency_name: string,
	currency_symbol: string,
	currency_decimals: u8,
	rpc_urls: []string = {},
	block_explorers: []Block_Explorer = {},
	testnet: bool = false,
) -> Chain {
	return Chain{
		id              = id,
		name            = name,
		network         = network,
		native_currency = Native_Currency{
			name     = currency_name,
			symbol   = currency_symbol,
			decimals = currency_decimals,
		},
		rpc_urls        = rpc_urls,
		block_explorers = block_explorers,
		testnet         = testnet,
	}
}
