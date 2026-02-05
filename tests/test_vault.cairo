use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use havilah_vault::{
    IHavilahVaultDispatcher, IHavilahVaultDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
};

fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn USER1() -> ContractAddress {
    starknet::contract_address_const::<'USER1'>()
}

fn USER2() -> ContractAddress {
    starknet::contract_address_const::<'USER2'>()
}

fn deploy_token(initial_supply: felt252, recipient: ContractAddress) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let constructor_args = array!['TestToken', 'TT', 18, initial_supply, recipient.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

fn deploy_vault(token: ContractAddress) -> ContractAddress {
    let contract = declare("HavilahVault").unwrap().contract_class();
    let constructor_args = array![token.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

#[test]
fn test_initial_state() {
    let token_address = deploy_token(1000000, OWNER());
    let vault_address = deploy_vault(token_address);
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    assert(vault.contract_total_supply() == 0, 'Total supply should be 0');
    assert(vault.user_balance_of(OWNER()) == 0, 'Owner balance should be 0');
}

#[test]
fn test_first_deposit() {
    let token_address = deploy_token(1000000, USER1());
    let vault_address = deploy_vault(token_address);

    let token = IERC20Dispatcher { contract_address: token_address };
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 1000;

    start_cheat_caller_address(token_address, USER1());
    token.approve(vault_address, deposit_amount.low.into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER1());
    vault.deposit(deposit_amount);
    stop_cheat_caller_address(vault_address);

    assert(vault.user_balance_of(USER1()) == deposit_amount, 'Shares should equal deposit');
    assert(vault.contract_total_supply() == deposit_amount, 'Total supply mismatch');
}

#[test]
fn test_second_deposit_same_ratio() {
    let token_address = deploy_token(1000000, USER1());
    let vault_address = deploy_vault(token_address);

    let token = IERC20Dispatcher { contract_address: token_address };
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    let first_deposit: u256 = 1000;

    start_cheat_caller_address(token_address, USER1());
    token.approve(vault_address, (first_deposit.low * 2).into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER1());
    vault.deposit(first_deposit);
    vault.deposit(first_deposit);
    stop_cheat_caller_address(vault_address);

    assert(vault.user_balance_of(USER1()) == first_deposit * 2, 'Shares should double');
    assert(vault.contract_total_supply() == first_deposit * 2, 'Total supply should double');
}

#[test]
fn test_withdraw_all() {
    let token_address = deploy_token(1000000, USER1());
    let vault_address = deploy_vault(token_address);

    let token = IERC20Dispatcher { contract_address: token_address };
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 1000;
    let initial_balance: u256 = token.balance_of(USER1()).into();

    start_cheat_caller_address(token_address, USER1());
    token.approve(vault_address, deposit_amount.low.into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER1());
    vault.deposit(deposit_amount);

    let shares = vault.user_balance_of(USER1());
    vault.withdraw(shares);
    stop_cheat_caller_address(vault_address);

    assert(vault.user_balance_of(USER1()) == 0, 'User shares should be 0');
    assert(vault.contract_total_supply() == 0, 'Total supply should be 0');

    let final_balance: u256 = token.balance_of(USER1()).into();
    assert(final_balance == initial_balance, 'Should recover tokens');
}

#[test]
fn test_multiple_users_deposit() {
    let token_address = deploy_token(1000000, OWNER());
    let vault_address = deploy_vault(token_address);

    let token = IERC20Dispatcher { contract_address: token_address };
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    start_cheat_caller_address(token_address, OWNER());
    token.transfer(USER1(), 5000);
    token.transfer(USER2(), 5000);
    stop_cheat_caller_address(token_address);

    let deposit1: u256 = 1000;
    let deposit2: u256 = 2000;

    start_cheat_caller_address(token_address, USER1());
    token.approve(vault_address, deposit1.low.into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER1());
    vault.deposit(deposit1);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(token_address, USER2());
    token.approve(vault_address, deposit2.low.into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER2());
    vault.deposit(deposit2);
    stop_cheat_caller_address(vault_address);

    assert(vault.user_balance_of(USER1()) == deposit1, 'USER1 shares mismatch');
    assert(vault.user_balance_of(USER2()) == deposit2, 'USER2 shares mismatch');
    assert(vault.contract_total_supply() == deposit1 + deposit2, 'Total mismatch');
}

#[test]
fn test_user_balance_of_zero_for_non_depositor() {
    let token_address = deploy_token(1000000, OWNER());
    let vault_address = deploy_vault(token_address);

    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    assert(vault.user_balance_of(USER1()) == 0, 'Non-depositor should have 0');
    assert(vault.user_balance_of(USER2()) == 0, 'Non-depositor should have 0');
}

#[test]
fn test_partial_withdraw() {
    let token_address = deploy_token(1000000, USER1());
    let vault_address = deploy_vault(token_address);

    let token = IERC20Dispatcher { contract_address: token_address };
    let vault = IHavilahVaultDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 1000;

    start_cheat_caller_address(token_address, USER1());
    token.approve(vault_address, deposit_amount.low.into());
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(vault_address, USER1());
    vault.deposit(deposit_amount);

    let partial_withdraw: u256 = 400;
    vault.withdraw(partial_withdraw);
    stop_cheat_caller_address(vault_address);

    assert(vault.user_balance_of(USER1()) == deposit_amount - partial_withdraw, 'Shares mismatch');
    assert(
        vault.contract_total_supply() == deposit_amount - partial_withdraw, 'Total supply mismatch',
    );
}
