package clients

import "core:encoding/json"
import "core:mem"
import "../types"
import "../transport"

// Wallet client — extends public client with signing and sending capabilities.
Wallet_Client :: struct {
	// Embedded public client for read-only operations.
	public:    Public_Client,
	// Account used for signing.
	account:   Account,
	allocator: mem.Allocator,
}

// Create a wallet client with transport, chain, and account.
wallet_client_create :: proc(
	tp: transport.Transport,
	account: Account,
	chain: types.Chain = {},
	allocator := context.allocator,
) -> Wallet_Client {
	return Wallet_Client{
		public    = public_client_create(tp, chain, allocator),
		account   = account,
		allocator = allocator,
	}
}

// Close the wallet client.
wallet_client_destroy :: proc(client: ^Wallet_Client) {
	public_client_destroy(&client.public)
}

// Get the wallet's address.
wallet_address :: proc(client: ^Wallet_Client) -> types.Address {
	return client.account.address
}

// Send a JSON-RPC call through the wallet's public client.
wallet_rpc_call :: proc(
	client: ^Wallet_Client,
	method: string,
	params: json.Value = nil,
	allocator := context.allocator,
) -> (json.Value, RPC_Error, Client_Error) {
	return rpc_call(&client.public, method, params, allocator)
}
