package chains

@(private)
_base_explorers := [?]Block_Explorer{{"BaseScan", "https://basescan.org"}}
@(private)
_base_sepolia_explorers := [?]Block_Explorer{{"BaseScan", "https://sepolia.basescan.org"}}

base :: proc() -> Chain {
	return Chain{
		id              = 8453,
		name            = "Base",
		network         = "base",
		native_currency = ETH_CURRENCY,
		block_explorers = _base_explorers[:],
		testnet         = false,
	}
}

base_sepolia :: proc() -> Chain {
	return Chain{
		id              = 84532,
		name            = "Base Sepolia",
		network         = "base-sepolia",
		native_currency = ETH_CURRENCY,
		block_explorers = _base_sepolia_explorers[:],
		testnet         = true,
	}
}
