package chains

@(private)
_optimism_explorers := [?]Block_Explorer{{"Etherscan", "https://optimistic.etherscan.io"}}
@(private)
_optimism_sepolia_explorers := [?]Block_Explorer{{"Etherscan", "https://sepolia-optimistic.etherscan.io"}}

optimism :: proc() -> Chain {
	return Chain{
		id              = 10,
		name            = "OP Mainnet",
		network         = "optimism",
		native_currency = ETH_CURRENCY,
		block_explorers = _optimism_explorers[:],
		testnet         = false,
	}
}

optimism_sepolia :: proc() -> Chain {
	return Chain{
		id              = 11155420,
		name            = "OP Sepolia",
		network         = "optimism-sepolia",
		native_currency = ETH_CURRENCY,
		block_explorers = _optimism_sepolia_explorers[:],
		testnet         = true,
	}
}
