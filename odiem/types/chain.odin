package types

Chain :: struct {
	id:              u64,
	name:            string,
	network:         string,
	native_currency: Native_Currency,
	rpc_urls:        []string,
	block_explorers: []Block_Explorer,
	testnet:         bool,
}

Native_Currency :: struct {
	name:     string,
	symbol:   string,
	decimals: u8,
}

Block_Explorer :: struct {
	name: string,
	url:  string,
}
