package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math/big"
import "core:mem"
import "core:encoding/json"
import "../odiem/accounts"
import "../odiem/chains"
import "../odiem/clients"
import "../odiem/transport"
import "../odiem/types"
import "../odiem/utils"
import pub "../odiem/actions/public"
import wal "../odiem/actions/wallet"
import abi "../odin-abi/abi"

USDT_CONTRACT :: "0xdAC17F958D2ee523a2206206994597C13D831ec7"
TRANSFER_TO   :: "0x1881B5562dc51Fb27B263582321214D84cDCf0f1"
USDT_AMOUNT   :: "1000000"  // 1 USDT (6 decimals)
ETH_AMOUNT    :: "0.0001"

main :: proc() {
	// ==================== Validate inputs ====================

	privkey, env_ok := load_privkey_from_env()
	if !env_ok {
		fmt.eprintln("Error: could not load PRIVATE_KEY from .env file")
		fmt.eprintln("Expected format: PRIVATE_KEY=0xabc123...")
		os.exit(1)
	}

	rpc_url := env_get("RPC_URL", "http://127.0.0.1:8545")

	transfer_to := parse_address_or_exit(TRANSFER_TO)
	usdt_address := parse_address_or_exit(USDT_CONTRACT)

	usdt_amount: big.Int
	defer big.destroy(&usdt_amount)
	if big.atoi(&usdt_amount, USDT_AMOUNT) != nil {
		fmt.eprintfln("Error: invalid USDT_AMOUNT: %s", USDT_AMOUNT)
		os.exit(1)
	}

	usdt_calldata, abi_err := build_erc20_transfer_calldata(transfer_to, &usdt_amount)
	if abi_err != .None {
		fmt.eprintfln("Error encoding ERC20 transfer: %v", abi_err)
		os.exit(1)
	}
	defer delete(usdt_calldata)

	eth_wei: big.Int
	defer big.destroy(&eth_wei)
	if !utils.parse_ether(ETH_AMOUNT, &eth_wei) {
		fmt.eprintfln("Error: invalid ETH_AMOUNT: %s", ETH_AMOUNT)
		os.exit(1)
	}

	// ==================== Set up client ====================

	account, acc_err := accounts.from_private_key(privkey)
	if acc_err != .None {
		fmt.eprintfln("Error creating account: %v", acc_err)
		os.exit(1)
	}
	defer accounts.private_key_destroy(&account)

	tp, tp_err := transport.curl_create(rpc_url)
	if tp_err != .None {
		fmt.eprintfln("Error creating transport: %v", tp_err)
		os.exit(1)
	}

	chain := chains.mainnet()
	wallet := clients.wallet_client_create(tp, account, chain)
	defer clients.wallet_client_destroy(&wallet)

	fmt.printfln("Wallet address: %s", clients.address_to_hex(account.address))
	fmt.printfln("Transfer to:    %s", TRANSFER_TO)
	fmt.printfln("Connected to:   %s", rpc_url)

	// ==================== Initial balances ====================

	print_balance(&wallet.public, "Sender ETH balance", account.address)
	print_balance(&wallet.public, "Recipient ETH balance", transfer_to)

	// ==================== ERC20 USDT transfer ====================

	fmt.println("\n--- ERC20 USDT Transfer ---")
	fmt.printfln("USDT amount (raw): %s", USDT_AMOUNT)
	fmt.printfln("USDT contract:     %s", USDT_CONTRACT)

	zero_val: big.Int
	defer big.destroy(&zero_val)
	usdt_hash, usdt_err := sign_and_send(
		&wallet, privkey, usdt_address, &zero_val, usdt_calldata, is_erc20 = true,
	)
	if usdt_err != .None {
		fmt.eprintfln("ERC20 transfer failed: %v", usdt_err)
	} else {
		fmt.printfln("ERC20 tx hash:      %s", clients.hash_to_hex(usdt_hash))
		print_receipt_wait(&wallet.public, "ERC20", usdt_hash)
	}

	// ==================== Native ETH transfer ====================

	fmt.println("\n--- Native ETH Transfer ---")

	wei_str, _ := big.int_to_string(&eth_wei)
	defer delete(wei_str)
	fmt.printfln("ETH amount: %s ETH (%s wei)", ETH_AMOUNT, wei_str)

	eth_hash, eth_err := sign_and_send(
		&wallet, privkey, transfer_to, &eth_wei, nil, is_erc20 = false,
	)
	if eth_err != .None {
		fmt.eprintfln("ETH transfer failed: %v", eth_err)
	} else {
		fmt.printfln("ETH tx hash: %s", clients.hash_to_hex(eth_hash))
		print_receipt_wait(&wallet.public, "ETH", eth_hash)
	}

	// ==================== Final balances ====================

	fmt.println("\n--- Final Balances ---")
	print_balance(&wallet.public, "Sender ETH balance", account.address)
	print_balance(&wallet.public, "Recipient ETH balance", transfer_to)

	fmt.println("\nDone.")
}

// --- Core transaction logic ---

// Build, sign locally, and send a raw transaction via eth_sendRawTransaction.
sign_and_send :: proc(
	client: ^clients.Wallet_Client,
	privkey: [32]u8,
	to: types.Address,
	value: ^big.Int,
	data: []u8,
	is_erc20: bool,
) -> (types.Hash, clients.Client_Error) {
	// Get nonce
	nonce, nonce_err := pub.get_transaction_count(&client.public, client.account.address)
	if nonce_err != .None do return {}, nonce_err

	// Get gas price
	gas_price, gas_err := pub.get_gas_price(&client.public)
	if gas_err != .None {
		big.destroy(&gas_price)
		return {}, gas_err
	}
	// Note: no defer destroy — ownership transfers to tx, cleaned up by transaction_destroy

	// Get chain ID
	chain_id, chain_err := clients.get_chain_id(&client.public)
	if chain_err != .None do return {}, chain_err

	// Estimate gas
	call_params := clients.Call_Params{
		from  = client.account.address,
		to    = to,
		data  = data,
	}
	if !is_erc20 {
		// For native ETH, we know gas is 21000
		// For ERC20, estimate via eth_estimateGas
	}
	gas: u64 = 21000
	if is_erc20 {
		estimated, est_err := pub.estimate_gas(&client.public, call_params)
		if est_err != .None do return {}, est_err
		gas = estimated + estimated / 10 // +10% buffer
	}

	// Build unsigned EIP-155 legacy transaction
	tx: types.Transaction
	defer {
		tx.data = nil // borrowed slice — caller owns it
		types.transaction_destroy(&tx)
	}
	tx.type = .Legacy
	tx.chain_id = chain_id
	tx.nonce = nonce
	tx.to = to
	big.set(&tx.value, value)
	tx.gas = gas
	tx.gas_price = gas_price
	tx.data = data

	// EIP-155: v = chain_id, r = 0, s = 0 for signing hash
	tx.v = chain_id
	big.set(&tx.r, 0)
	big.set(&tx.s, 0)

	// Serialize unsigned tx and hash it
	unsigned_bytes, ser_err := utils.serialize_transaction(&tx, context.temp_allocator)
	if ser_err != .None do return {}, .Marshal_Failed

	tx_hash := utils.keccak256(unsigned_bytes)

	// Sign the hash locally
	sig, sign_err := accounts.local_sign_hash(privkey, tx_hash)
	if sign_err != .None do return {}, .Marshal_Failed

	// Set signature on tx (EIP-155: v = recovery_id + chain_id * 2 + 35)
	tx.v = u64(sig.v) + chain_id * 2 + 35
	big.int_from_bytes_big(&tx.r, sig.r[:])
	big.int_from_bytes_big(&tx.s, sig.s[:])

	// Serialize signed tx
	signed_bytes, signed_err := utils.serialize_transaction(&tx, context.temp_allocator)
	if signed_err != .None do return {}, .Marshal_Failed

	// Send via eth_sendRawTransaction
	return wal.send_raw_transaction(client, signed_bytes)
}

// --- Helpers ---

// Build ERC20 transfer(address,uint256) calldata.
build_erc20_transfer_calldata :: proc(
	to: types.Address,
	amount: ^big.Int,
) -> ([]u8, abi.Error) {
	selector := abi.compute_selector("transfer(address,uint256)")

	amount_copy: big.Int
	big.set(&amount_copy, amount)

	addr_val := abi.Val_Address{val = transmute([20]u8)to}
	uint_val := abi.Val_Uint{bits = 256, val = amount_copy}

	values := [?]abi.Value{addr_val, uint_val}
	result, err := abi.encode_function_data(selector, values[:])

	big.destroy(&amount_copy)
	return result, err
}

// Print an ETH balance for an address.
print_balance :: proc(client: ^clients.Public_Client, label: string, addr: types.Address) {
	balance, err := pub.get_balance(client, addr)
	defer big.destroy(&balance)
	if err != .None {
		fmt.eprintfln("  %s: error (%v)", label, err)
		return
	}
	eth_str, ok := utils.format_ether(&balance)
	if ok {
		defer delete(eth_str)
		fmt.printfln("  %s: %s ETH", label, eth_str)
	} else {
		bal_str, _ := big.int_to_string(&balance)
		defer delete(bal_str)
		fmt.printfln("  %s: %s wei", label, bal_str)
	}
}

// Wait for a tx receipt and print it.
print_receipt_wait :: proc(client: ^clients.Public_Client, label: string, hash: types.Hash) {
	receipt, err := pub.wait_for_transaction_receipt(
		client, hash,
		poll_interval_ms = 500,
		timeout_ms = 120000,
	)
	if err != .None {
		fmt.eprintfln("Error waiting for %s receipt: %v", label, err)
		return
	}
	print_receipt(label, receipt)
}

// Print transaction receipt details from raw JSON.
print_receipt :: proc(label: string, receipt: json.Value) {
	obj, is_obj := receipt.(json.Object)
	if !is_obj {
		fmt.printfln("  %s receipt: (not an object)", label)
		return
	}

	fmt.printfln("  %s receipt:", label)
	print_field(obj, "transactionHash", "tx hash")
	print_field(obj, "blockNumber",     "block")
	print_field(obj, "blockHash",       "block hash")
	print_field(obj, "gasUsed",         "gas used")
	print_field(obj, "effectiveGasPrice","gas price")
	print_field(obj, "from",            "from")
	print_field(obj, "to",              "to")
	print_field(obj, "transactionIndex","tx index")

	if v, ok := obj["status"]; ok {
		if s, is_str := v.(json.String); is_str {
			status := "success" if s == "0x1" else fmt.tprintf("failed (%s)", s)
			fmt.printfln("    status:      %s", status)
		}
	}
	if v, ok := obj["logs"]; ok {
		if logs, is_arr := v.(json.Array); is_arr {
			fmt.printfln("    logs:        %d event(s)", len(logs))
			for log, i in logs {
				if log_obj, is_log_obj := log.(json.Object); is_log_obj {
					if topics, has_topics := log_obj["topics"]; has_topics {
						if topic_arr, is_topic_arr := topics.(json.Array); is_topic_arr {
							for topic, j in topic_arr {
								if ts, is_ts := topic.(json.String); is_ts {
									fmt.printfln("      log[%d] topic[%d]: %s", i, j, ts)
								}
							}
						}
					}
				}
			}
		}
	}
}

print_field :: proc(obj: json.Object, key: string, label: string) {
	if v, ok := obj[key]; ok {
		if s, is_str := v.(json.String); is_str {
			fmt.printfln("    %-12s %s", fmt.tprintf("%s:", label), s)
		}
	}
}

// Parse a hex address string, exit on failure.
parse_address_or_exit :: proc(s: string) -> types.Address {
	bytes, ok := utils.from_hex(s, context.temp_allocator)
	if !ok || len(bytes) != 20 {
		fmt.eprintfln("Error: invalid address: %s", s)
		os.exit(1)
	}
	addr: types.Address
	mem.copy(&addr, raw_data(bytes), 20)
	return addr
}

// Load the private key from .env file.
load_privkey_from_env :: proc() -> ([32]u8, bool) {
	data, file_ok := os.read_entire_file(".env")
	if !file_ok do return {}, false
	defer delete(data)

	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "#") do continue
		if !strings.has_prefix(trimmed, "PRIVATE_KEY=") do continue

		val := strings.trim_space(trimmed[len("PRIVATE_KEY="):])
		if len(val) >= 2 && (val[0] == '"' || val[0] == '\'') {
			val = val[1:len(val) - 1]
		}

		key_bytes, ok := utils.from_hex(val, context.temp_allocator)
		if !ok || len(key_bytes) != 32 do return {}, false

		key: [32]u8
		mem.copy(&key, raw_data(key_bytes), 32)
		return key, true
	}

	return {}, false
}

// Read an env var from .env file, fallback to default.
env_get :: proc(name: string, default: string) -> string {
	data, ok := os.read_entire_file(".env")
	if !ok do return default
	defer delete(data)

	prefix := strings.concatenate({name, "="}, context.temp_allocator)
	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "#") do continue
		if !strings.has_prefix(trimmed, prefix) do continue

		val := strings.trim_space(trimmed[len(prefix):])
		if len(val) >= 2 && (val[0] == '"' || val[0] == '\'') {
			val = val[1:len(val) - 1]
		}
		return strings.clone(val)
	}
	return default
}
