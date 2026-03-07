package chains

AVAX_CURRENCY :: Native_Currency{
	name     = "Avalanche",
	symbol   = "AVAX",
	decimals = 18,
}

@(private)
_avalanche_explorers := [?]Block_Explorer{{"SnowScan", "https://snowscan.xyz"}}
@(private)
_fuji_explorers := [?]Block_Explorer{{"SnowScan", "https://testnet.snowscan.xyz"}}

avalanche :: proc() -> Chain {
	return Chain{
		id              = 43114,
		name            = "Avalanche",
		network         = "avalanche",
		native_currency = AVAX_CURRENCY,
		block_explorers = _avalanche_explorers[:],
		testnet         = false,
	}
}

avalanche_fuji :: proc() -> Chain {
	return Chain{
		id              = 43113,
		name            = "Avalanche Fuji",
		network         = "avalanche-fuji",
		native_currency = AVAX_CURRENCY,
		block_explorers = _fuji_explorers[:],
		testnet         = true,
	}
}
