package types

Signature :: struct {
	r: [32]u8,
	s: [32]u8,
	v: u8, // recovery id: 0 or 1 (or 27/28 for legacy)
}
