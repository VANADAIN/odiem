# odiem-ecosystem

Monorepo for Odiem and its dependencies — an Odin port of [viem](https://viem.sh) for EVM blockchains.

## Projects

| Project | Description |
|---|---|
| [odiem](./odiem/) | Main library — Odin interface for Ethereum |
| [odin-secp256k1](./odin-secp256k1/) | secp256k1 elliptic curve cryptography |
| [odin-rlp](./odin-rlp/) | RLP (Recursive Length Prefix) encoding |
| [odin-abi](./odin-abi/) | Ethereum ABI encoding/decoding |
| [odin-websocket](./odin-websocket/) | WebSocket client (RFC 6455) |
| [odin-jsonrpc](./odin-jsonrpc/) | JSON-RPC 2.0 client |

## Architecture

```
odiem-ecosystem/
  odiem/              ← main library (depends on all below)
  odin-secp256k1/     ← pure Odin secp256k1 (standalone)
  odin-rlp/           ← pure Odin RLP encoding (standalone)
  odin-abi/           ← Ethereum ABI (depends on keccak from core)
  odin-websocket/     ← WebSocket client (standalone)
  odin-jsonrpc/       ← JSON-RPC client (depends on odin-websocket)
```

Each sub-project is designed as an independent library with its own git repo,
usable outside of Odiem.
