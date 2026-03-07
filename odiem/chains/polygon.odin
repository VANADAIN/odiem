package chains

MATIC_CURRENCY :: Native_Currency{
	name     = "POL",
	symbol   = "POL",
	decimals = 18,
}

@(private)
_polygon_explorers := [?]Block_Explorer{{"PolygonScan", "https://polygonscan.com"}}
@(private)
_amoy_explorers := [?]Block_Explorer{{"PolygonScan", "https://amoy.polygonscan.com"}}

polygon :: proc() -> Chain {
	return Chain{
		id              = 137,
		name            = "Polygon",
		network         = "matic",
		native_currency = MATIC_CURRENCY,
		block_explorers = _polygon_explorers[:],
		testnet         = false,
	}
}

polygon_amoy :: proc() -> Chain {
	return Chain{
		id              = 80002,
		name            = "Polygon Amoy",
		network         = "amoy",
		native_currency = MATIC_CURRENCY,
		block_explorers = _amoy_explorers[:],
		testnet         = true,
	}
}
