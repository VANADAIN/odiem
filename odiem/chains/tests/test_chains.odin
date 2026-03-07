package chains_tests

import "core:testing"
import ch "../"

// --- Ethereum ---

@(test)
test_mainnet :: proc(t: ^testing.T) {
	c := ch.mainnet()
	testing.expect_value(t, c.id, u64(1))
	testing.expect_value(t, c.name, "Ethereum")
	testing.expect_value(t, c.native_currency.symbol, "ETH")
	testing.expect_value(t, c.native_currency.decimals, u8(18))
	testing.expect(t, !c.testnet, "mainnet should not be testnet")
}

@(test)
test_goerli :: proc(t: ^testing.T) {
	c := ch.goerli()
	testing.expect_value(t, c.id, u64(5))
	testing.expect(t, c.testnet, "goerli should be testnet")
}

@(test)
test_sepolia :: proc(t: ^testing.T) {
	c := ch.sepolia()
	testing.expect_value(t, c.id, u64(11155111))
	testing.expect_value(t, c.name, "Sepolia")
	testing.expect(t, c.testnet, "sepolia should be testnet")
}

@(test)
test_holesky :: proc(t: ^testing.T) {
	c := ch.holesky()
	testing.expect_value(t, c.id, u64(17000))
	testing.expect(t, c.testnet, "holesky should be testnet")
}

// --- L2s ---

@(test)
test_polygon :: proc(t: ^testing.T) {
	c := ch.polygon()
	testing.expect_value(t, c.id, u64(137))
	testing.expect_value(t, c.native_currency.symbol, "POL")
	testing.expect(t, !c.testnet, "polygon should not be testnet")
}

@(test)
test_arbitrum :: proc(t: ^testing.T) {
	c := ch.arbitrum()
	testing.expect_value(t, c.id, u64(42161))
	testing.expect_value(t, c.name, "Arbitrum One")
	testing.expect(t, !c.testnet, "arbitrum should not be testnet")
}

@(test)
test_optimism :: proc(t: ^testing.T) {
	c := ch.optimism()
	testing.expect_value(t, c.id, u64(10))
	testing.expect_value(t, c.name, "OP Mainnet")
	testing.expect(t, !c.testnet, "optimism should not be testnet")
}

@(test)
test_base_chain :: proc(t: ^testing.T) {
	c := ch.base()
	testing.expect_value(t, c.id, u64(8453))
	testing.expect_value(t, c.native_currency.symbol, "ETH")
	testing.expect(t, !c.testnet, "base should not be testnet")
}

@(test)
test_bsc :: proc(t: ^testing.T) {
	c := ch.bsc()
	testing.expect_value(t, c.id, u64(56))
	testing.expect_value(t, c.native_currency.symbol, "BNB")
	testing.expect(t, !c.testnet, "bsc should not be testnet")
}

@(test)
test_avalanche :: proc(t: ^testing.T) {
	c := ch.avalanche()
	testing.expect_value(t, c.id, u64(43114))
	testing.expect_value(t, c.native_currency.symbol, "AVAX")
	testing.expect(t, !c.testnet, "avalanche should not be testnet")
}

// --- Local ---

@(test)
test_hardhat :: proc(t: ^testing.T) {
	c := ch.hardhat()
	testing.expect_value(t, c.id, u64(31337))
	testing.expect_value(t, c.name, "Hardhat")
	testing.expect(t, c.testnet, "hardhat should be testnet")
	testing.expect(t, len(c.rpc_urls) > 0, "should have rpc url")
}

@(test)
test_anvil :: proc(t: ^testing.T) {
	c := ch.anvil()
	testing.expect_value(t, c.id, u64(31337))
	testing.expect_value(t, c.name, "Anvil")
	testing.expect(t, c.testnet, "anvil should be testnet")
}

@(test)
test_localhost :: proc(t: ^testing.T) {
	c := ch.localhost()
	testing.expect_value(t, c.id, u64(1337))
	testing.expect_value(t, c.name, "Localhost")
}

// --- Testnets ---

@(test)
test_polygon_amoy :: proc(t: ^testing.T) {
	c := ch.polygon_amoy()
	testing.expect_value(t, c.id, u64(80002))
	testing.expect(t, c.testnet, "amoy should be testnet")
}

@(test)
test_arbitrum_sepolia :: proc(t: ^testing.T) {
	c := ch.arbitrum_sepolia()
	testing.expect_value(t, c.id, u64(421614))
	testing.expect(t, c.testnet, "arbitrum sepolia should be testnet")
}

@(test)
test_optimism_sepolia :: proc(t: ^testing.T) {
	c := ch.optimism_sepolia()
	testing.expect_value(t, c.id, u64(11155420))
	testing.expect(t, c.testnet, "optimism sepolia should be testnet")
}

@(test)
test_base_sepolia :: proc(t: ^testing.T) {
	c := ch.base_sepolia()
	testing.expect_value(t, c.id, u64(84532))
	testing.expect(t, c.testnet, "base sepolia should be testnet")
}

@(test)
test_bsc_testnet :: proc(t: ^testing.T) {
	c := ch.bsc_testnet()
	testing.expect_value(t, c.id, u64(97))
	testing.expect(t, c.testnet, "bsc testnet should be testnet")
}

@(test)
test_avalanche_fuji :: proc(t: ^testing.T) {
	c := ch.avalanche_fuji()
	testing.expect_value(t, c.id, u64(43113))
	testing.expect(t, c.testnet, "fuji should be testnet")
}

// --- Custom chain ---

@(test)
test_custom_chain :: proc(t: ^testing.T) {
	c := ch.custom(
		id                = 999,
		name              = "My Chain",
		network           = "mychain",
		currency_name     = "MyCoin",
		currency_symbol   = "MYC",
		currency_decimals = 18,
	)
	testing.expect_value(t, c.id, u64(999))
	testing.expect_value(t, c.name, "My Chain")
	testing.expect_value(t, c.native_currency.symbol, "MYC")
	testing.expect(t, !c.testnet, "custom chain should not be testnet")
}

@(test)
test_custom_chain_testnet :: proc(t: ^testing.T) {
	c := ch.custom(
		id                = 12345,
		name              = "Test Network",
		network           = "testnet",
		currency_name     = "Test",
		currency_symbol   = "TST",
		currency_decimals = 18,
		testnet           = true,
	)
	testing.expect_value(t, c.id, u64(12345))
	testing.expect(t, c.testnet, "should be testnet")
}

// --- Block explorers ---

@(test)
test_mainnet_has_explorer :: proc(t: ^testing.T) {
	c := ch.mainnet()
	testing.expect(t, len(c.block_explorers) == 1, "should have one explorer")
	testing.expect_value(t, c.block_explorers[0].name, "Etherscan")
}
