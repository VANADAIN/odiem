package chains

ETH_CURRENCY :: Native_Currency{
	name     = "Ether",
	symbol   = "ETH",
	decimals = 18,
}

@(private)
_mainnet_explorers := [?]Block_Explorer{{"Etherscan", "https://etherscan.io"}}
@(private)
_goerli_explorers := [?]Block_Explorer{{"Etherscan", "https://goerli.etherscan.io"}}
@(private)
_sepolia_explorers := [?]Block_Explorer{{"Etherscan", "https://sepolia.etherscan.io"}}
@(private)
_holesky_explorers := [?]Block_Explorer{{"Etherscan", "https://holesky.etherscan.io"}}

mainnet :: proc() -> Chain {
	return Chain{
		id              = 1,
		name            = "Ethereum",
		network         = "homestead",
		native_currency = ETH_CURRENCY,
		block_explorers = _mainnet_explorers[:],
		testnet         = false,
	}
}

goerli :: proc() -> Chain {
	return Chain{
		id              = 5,
		name            = "Goerli",
		network         = "goerli",
		native_currency = Native_Currency{name = "Goerli Ether", symbol = "ETH", decimals = 18},
		block_explorers = _goerli_explorers[:],
		testnet         = true,
	}
}

sepolia :: proc() -> Chain {
	return Chain{
		id              = 11155111,
		name            = "Sepolia",
		network         = "sepolia",
		native_currency = Native_Currency{name = "Sepolia Ether", symbol = "ETH", decimals = 18},
		block_explorers = _sepolia_explorers[:],
		testnet         = true,
	}
}

holesky :: proc() -> Chain {
	return Chain{
		id              = 17000,
		name            = "Holesky",
		network         = "holesky",
		native_currency = Native_Currency{name = "Holesky Ether", symbol = "ETH", decimals = 18},
		block_explorers = _holesky_explorers[:],
		testnet         = true,
	}
}
