package utils

import "core:math/big"
import "core:mem"
import rlp "../../odin-rlp/rlp"
import "../types"

Tx_Error :: enum {
	None,
	Invalid_Type,
	Encode_Failed,
	Decode_Failed,
	Alloc_Failed,
}

// Serialize a transaction to RLP-encoded bytes (EIP-2718 typed envelope).
serialize_transaction :: proc(tx: ^types.Transaction, allocator := context.allocator) -> ([]u8, Tx_Error) {
	switch tx.type {
	case .Legacy:
		return _serialize_legacy(tx, allocator)
	case .EIP2930:
		return _serialize_typed(0x01, tx, allocator)
	case .EIP1559:
		return _serialize_typed(0x02, tx, allocator)
	case .EIP4844:
		return _serialize_typed(0x03, tx, allocator)
	}
	return nil, .Invalid_Type
}

// Get the transaction hash: keccak256(serialized_tx).
get_transaction_hash :: proc(tx: ^types.Transaction) -> (types.Hash, Tx_Error) {
	serialized, err := serialize_transaction(tx, context.temp_allocator)
	if err != .None do return {}, err
	return keccak256(serialized), .None
}

// --- Internal serialization ---

_serialize_legacy :: proc(tx: ^types.Transaction, allocator := context.allocator) -> ([]u8, Tx_Error) {
	items := make([]rlp.Item, 9, context.temp_allocator)

	items[0] = _uint_item(tx.nonce)
	gp := tx.gas_price.? or_else big.Int{}
	items[1] = _big_int_item(&gp)
	items[2] = _uint_item(tx.gas)
	items[3] = _address_item(tx.to)
	items[4] = _big_int_item(&tx.value)
	items[5] = _bytes_item(tx.data)
	items[6] = _uint_item(tx.v)
	items[7] = _big_int_item(&tx.r)
	items[8] = _big_int_item(&tx.s)

	list := rlp.Item(rlp.List(items))
	encoded, rlp_err := rlp.encode(list, allocator)
	if rlp_err != .None do return nil, .Encode_Failed
	return encoded, .None
}

_serialize_typed :: proc(type_byte: u8, tx: ^types.Transaction, allocator := context.allocator) -> ([]u8, Tx_Error) {
	items: []rlp.Item
	switch type_byte {
	case 0x01:
		items = _build_eip2930_items(tx)
	case 0x02:
		items = _build_eip1559_items(tx)
	case 0x03:
		items = _build_eip4844_items(tx)
	case:
		return nil, .Invalid_Type
	}

	list := rlp.Item(rlp.List(items))
	rlp_encoded, rlp_err := rlp.encode(list, context.temp_allocator)
	if rlp_err != .None do return nil, .Encode_Failed

	result, alloc_err := make([]u8, 1 + len(rlp_encoded), allocator)
	if alloc_err != nil do return nil, .Alloc_Failed
	result[0] = type_byte
	copy(result[1:], rlp_encoded)
	return result, .None
}

_build_eip2930_items :: proc(tx: ^types.Transaction) -> []rlp.Item {
	items := make([]rlp.Item, 11, context.temp_allocator)
	gp := tx.gas_price.? or_else big.Int{}
	items[0] = _uint_item(tx.chain_id)
	items[1] = _uint_item(tx.nonce)
	items[2] = _big_int_item(&gp)
	items[3] = _uint_item(tx.gas)
	items[4] = _address_item(tx.to)
	items[5] = _big_int_item(&tx.value)
	items[6] = _bytes_item(tx.data)
	items[7] = _access_list_item(tx.access_list)
	items[8] = _uint_item(tx.v)
	items[9] = _big_int_item(&tx.r)
	items[10] = _big_int_item(&tx.s)
	return items
}

_build_eip1559_items :: proc(tx: ^types.Transaction) -> []rlp.Item {
	items := make([]rlp.Item, 12, context.temp_allocator)
	mp := tx.max_priority_fee_per_gas.? or_else big.Int{}
	mf := tx.max_fee_per_gas.? or_else big.Int{}
	items[0] = _uint_item(tx.chain_id)
	items[1] = _uint_item(tx.nonce)
	items[2] = _big_int_item(&mp)
	items[3] = _big_int_item(&mf)
	items[4] = _uint_item(tx.gas)
	items[5] = _address_item(tx.to)
	items[6] = _big_int_item(&tx.value)
	items[7] = _bytes_item(tx.data)
	items[8] = _access_list_item(tx.access_list)
	items[9] = _uint_item(tx.v)
	items[10] = _big_int_item(&tx.r)
	items[11] = _big_int_item(&tx.s)
	return items
}

_build_eip4844_items :: proc(tx: ^types.Transaction) -> []rlp.Item {
	items := make([]rlp.Item, 14, context.temp_allocator)
	mp := tx.max_priority_fee_per_gas.? or_else big.Int{}
	mf := tx.max_fee_per_gas.? or_else big.Int{}
	mb := tx.max_fee_per_blob_gas.? or_else big.Int{}
	items[0] = _uint_item(tx.chain_id)
	items[1] = _uint_item(tx.nonce)
	items[2] = _big_int_item(&mp)
	items[3] = _big_int_item(&mf)
	items[4] = _uint_item(tx.gas)
	items[5] = _address_item(tx.to)
	items[6] = _big_int_item(&tx.value)
	items[7] = _bytes_item(tx.data)
	items[8] = _access_list_item(tx.access_list)
	items[9] = _big_int_item(&mb)
	items[10] = _blob_hashes_item(tx.blob_versioned_hashes)
	items[11] = _uint_item(tx.v)
	items[12] = _big_int_item(&tx.r)
	items[13] = _big_int_item(&tx.s)
	return items
}

// --- RLP item helpers ---

_uint_item :: proc(val: u64) -> rlp.Item {
	if val == 0 {
		return rlp.Item(rlp.Bytes(nil))
	}
	buf := make([]u8, 8, context.temp_allocator)
	v := val
	i := 7
	for v > 0 {
		buf[i] = u8(v & 0xFF)
		v >>= 8
		i -= 1
	}
	start := i + 1
	return rlp.Item(rlp.Bytes(buf[start:]))
}

_big_int_item :: proc(val: ^big.Int) -> rlp.Item {
	size, _ := big.int_to_bytes_size(val)
	if size == 0 {
		return rlp.Item(rlp.Bytes(nil))
	}
	buf := make([]u8, size, context.temp_allocator)
	big.int_to_bytes_big(val, buf)
	return rlp.Item(rlp.Bytes(buf))
}

_bytes_item :: proc(data: []u8) -> rlp.Item {
	return rlp.Item(rlp.Bytes(data))
}

_address_item :: proc(addr: Maybe(types.Address)) -> rlp.Item {
	a, has := addr.?
	if !has {
		return rlp.Item(rlp.Bytes(nil))
	}
	buf := make([]u8, 20, context.temp_allocator)
	mem.copy(raw_data(buf), &a, 20)
	return rlp.Item(rlp.Bytes(buf))
}

_access_list_item :: proc(entries: []types.Access_List_Entry) -> rlp.Item {
	if len(entries) == 0 {
		return rlp.Item(rlp.List(nil))
	}
	items := make([]rlp.Item, len(entries), context.temp_allocator)
	for entry, i in entries {
		pair := make([]rlp.Item, 2, context.temp_allocator)
		addr_buf := make([]u8, 20, context.temp_allocator)
		a := entry.address
		mem.copy(raw_data(addr_buf), &a, 20)
		pair[0] = rlp.Item(rlp.Bytes(addr_buf))

		key_items := make([]rlp.Item, len(entry.storage_keys), context.temp_allocator)
		for key, j in entry.storage_keys {
			key_buf := make([]u8, 32, context.temp_allocator)
			k := key
			mem.copy(raw_data(key_buf), &k, 32)
			key_items[j] = rlp.Item(rlp.Bytes(key_buf))
		}
		pair[1] = rlp.Item(rlp.List(key_items))
		items[i] = rlp.Item(rlp.List(pair))
	}
	return rlp.Item(rlp.List(items))
}

_blob_hashes_item :: proc(hashes: []types.Hash) -> rlp.Item {
	if len(hashes) == 0 {
		return rlp.Item(rlp.List(nil))
	}
	items := make([]rlp.Item, len(hashes), context.temp_allocator)
	for hash, i in hashes {
		buf := make([]u8, 32, context.temp_allocator)
		h := hash
		mem.copy(raw_data(buf), &h, 32)
		items[i] = rlp.Item(rlp.Bytes(buf))
	}
	return rlp.Item(rlp.List(items))
}
