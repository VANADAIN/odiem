package chains

BNB_CURRENCY :: Native_Currency{
	name     = "BNB",
	symbol   = "BNB",
	decimals = 18,
}

@(private)
_bsc_explorers := [?]Block_Explorer{{"BscScan", "https://bscscan.com"}}
@(private)
_bsc_testnet_explorers := [?]Block_Explorer{{"BscScan", "https://testnet.bscscan.com"}}

bsc :: proc() -> Chain {
	return Chain{
		id              = 56,
		name            = "BNB Smart Chain",
		network         = "bsc",
		native_currency = BNB_CURRENCY,
		block_explorers = _bsc_explorers[:],
		testnet         = false,
	}
}

bsc_testnet :: proc() -> Chain {
	return Chain{
		id              = 97,
		name            = "BNB Smart Chain Testnet",
		network         = "bsc-testnet",
		native_currency = BNB_CURRENCY,
		block_explorers = _bsc_testnet_explorers[:],
		testnet         = true,
	}
}
