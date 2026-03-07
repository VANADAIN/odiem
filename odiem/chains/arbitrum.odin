package chains

@(private)
_arbitrum_explorers := [?]Block_Explorer{{"Arbiscan", "https://arbiscan.io"}}
@(private)
_arbitrum_sepolia_explorers := [?]Block_Explorer{{"Arbiscan", "https://sepolia.arbiscan.io"}}

arbitrum :: proc() -> Chain {
	return Chain{
		id              = 42161,
		name            = "Arbitrum One",
		network         = "arbitrum",
		native_currency = ETH_CURRENCY,
		block_explorers = _arbitrum_explorers[:],
		testnet         = false,
	}
}

arbitrum_sepolia :: proc() -> Chain {
	return Chain{
		id              = 421614,
		name            = "Arbitrum Sepolia",
		network         = "arbitrum-sepolia",
		native_currency = ETH_CURRENCY,
		block_explorers = _arbitrum_sepolia_explorers[:],
		testnet         = true,
	}
}
