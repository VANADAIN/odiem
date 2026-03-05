# Odiem

Odin port of [viem](https://viem.sh) — a TypeScript Interface for Ethereum.

Pure-Odin library for interacting with EVM-compatible blockchains.

## Status

Early development. See [IMPL.md](./IMPL.md) for the full implementation plan.

## Dependencies

This project is part of the `odiem-ecosystem` monorepo and depends on:

- `odin-secp256k1` — secp256k1 elliptic curve cryptography
- `odin-rlp` — RLP encoding/decoding
- `odin-abi` — Ethereum ABI encoding/decoding
- `odin-websocket` — WebSocket client
- `odin-jsonrpc` — JSON-RPC 2.0 client
- [laytan/odin-http](https://github.com/laytan/odin-http) — HTTP client (external)

## Odin Standard Library Usage

- `core:crypto/legacy/keccak` — Keccak-256 hashing
- `core:math/big` — Arbitrary precision integers
- `core:encoding/json` — JSON encoding/decoding
- `core:encoding/hex` — Hex encoding/decoding
- `core:net` — TCP sockets
