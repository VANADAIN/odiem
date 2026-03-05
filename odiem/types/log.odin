package types

Log :: struct {
	address:           Address,
	topics:            [dynamic]Hash,
	data:              []u8,
	block_number:      u64,
	block_hash:        Hash,
	transaction_hash:  Hash,
	transaction_index: u64,
	log_index:         u64,
	removed:           bool,
}

log_destroy :: proc(l: ^Log, allocator := context.allocator) {
	delete(l.topics)
	delete(l.data, allocator)
}
