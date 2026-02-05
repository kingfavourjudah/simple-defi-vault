# Havilah Vault

A simple DeFi vault contract built on Starknet using Cairo.

## What is it?

Havilah Vault lets users deposit ERC20 tokens and receive "shares" in return. When you withdraw, you get your tokens back based on how many shares you own.

## How it works

### Deposit
1. You deposit tokens into the vault
2. The vault gives you shares based on your contribution
3. First depositor: 1 token = 1 share
4. Later depositors: shares = (your deposit * total shares) / vault balance

### Withdraw
1. You burn your shares
2. The vault calculates your portion: tokens = (your shares * vault balance) / total shares
3. You receive your tokens back

### Example

```
Alice deposits 100 tokens -> Gets 100 shares
Bob deposits 200 tokens   -> Gets 200 shares
Total: 300 tokens, 300 shares

Alice withdraws 100 shares -> Gets 100 tokens back
Bob withdraws 200 shares   -> Gets 200 tokens back
```

## Project Structure

```
havilah_vault/
├── src/
│   ├── lib.cairo        # Main vault contract
│   └── mock_erc20.cairo # Mock token for testing
└── tests/
    └── test_vault.cairo # Test suite
```

## Build

```bash
scarb build
```

## Test

```bash
snforge test
```

## Contract Interface

```cairo
trait IHavilahVault {
    fn deposit(amount: u256);           // Deposit tokens, receive shares
    fn withdraw(shares: u256);          // Burn shares, receive tokens
    fn user_balance_of(account) -> u256; // Check share balance
    fn contract_total_supply() -> u256;  // Total shares issued
}
```

## Requirements

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (for testing)

## License

MIT
