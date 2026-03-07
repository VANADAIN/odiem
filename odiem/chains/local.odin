package chains

@(private)
_local_rpc := [?]string{"http://127.0.0.1:8545"}

hardhat :: proc() -> Chain {
	return Chain{
		id              = 31337,
		name            = "Hardhat",
		network         = "hardhat",
		native_currency = ETH_CURRENCY,
		rpc_urls        = _local_rpc[:],
		testnet         = true,
	}
}

anvil :: proc() -> Chain {
	return Chain{
		id              = 31337,
		name            = "Anvil",
		network         = "anvil",
		native_currency = ETH_CURRENCY,
		rpc_urls        = _local_rpc[:],
		testnet         = true,
	}
}

foundry :: proc() -> Chain {
	return Chain{
		id              = 31337,
		name            = "Foundry",
		network         = "foundry",
		native_currency = ETH_CURRENCY,
		rpc_urls        = _local_rpc[:],
		testnet         = true,
	}
}

localhost :: proc() -> Chain {
	return Chain{
		id              = 1337,
		name            = "Localhost",
		network         = "localhost",
		native_currency = ETH_CURRENCY,
		rpc_urls        = _local_rpc[:],
		testnet         = true,
	}
}
