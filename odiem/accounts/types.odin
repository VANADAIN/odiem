package accounts

import "../types"
import "../clients"

// Re-export Account from clients for convenience.
Account :: clients.Account

Account_Error :: enum {
	None,
	Invalid_Key,
	Derive_Failed,
	Sign_Failed,
	Alloc_Failed,
}
