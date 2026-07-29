# GateDelay Contracts

Foundry project for GateDelay smart contracts.

## Layout (single source of truth)

| Path | Purpose |
|------|---------|
| `src/` | **All production contracts** (Foundry `src` root) |
| `test/` | Forge tests |
| `script/` | Deploy scripts |
| `lib/` | Dependencies (OpenZeppelin, forge-std, prb-math) |

Former `Contracts/contracts/`, root-level `contracts/` (Burnable, FlashLoanProtection, Liquidation, MarketMinter, RoleManager), and any `Contracts/*.sol` at the package root were consolidated into `src/`. Do not add new production contracts outside `src/`.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

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
$ forge script script/<DeployScript>.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
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
