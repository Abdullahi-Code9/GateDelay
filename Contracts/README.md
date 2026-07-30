## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### FeeHandler build notes

The `FeeHandler` contract at `contracts/FeeHandler.sol` was verified with the current Foundry toolchain in this repository:

- Verified Foundry version: `forge 1.7.1`
- Compiler configuration: `solc = "0.8.28"` in `foundry.toml`
- Contract target: `contracts/FeeHandler.sol`
- Verified build command from the `Contracts/` directory:

```shell
$ forge build contracts/FeeHandler.sol
```

Dependencies are pulled from the repository's Foundry library remappings (`@openzeppelin/contracts`, `forge-std`, and `@prb/math`). When they are missing, `forge build` will prompt to install them; no additional contract behavior changes were required.

Known blocker: the repository currently has unrelated Solidity parsing issues in other contracts/tests, so a full `forge build` is not a reliable signal for the `FeeHandler` path. For this Phase 1 stabilization work, the verified build path for `FeeHandler` is the targeted command above.

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
