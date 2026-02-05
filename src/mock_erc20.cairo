#[starknet::contract]
pub mod MockERC20 {
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: felt252,
        recipient: ContractAddress,
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        let supply: u256 = initial_supply.into();
        self.total_supply.write(supply);
        self.balances.write(recipient, supply);
    }

    #[abi(embed_v0)]
    impl MockERC20Impl of havilah_vault::IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> felt252 {
            self.total_supply.read().try_into().unwrap()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> felt252 {
            self.balances.read(account).try_into().unwrap()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> felt252 {
            self.allowances.read((owner, spender)).try_into().unwrap()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: felt252) {
            let caller = starknet::get_caller_address();
            let amount_u256: u256 = amount.into();
            let caller_balance = self.balances.read(caller);
            assert(caller_balance >= amount_u256, 'Insufficient balance');
            self.balances.write(caller, caller_balance - amount_u256);
            self.balances.write(recipient, self.balances.read(recipient) + amount_u256);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: felt252,
        ) {
            let caller = starknet::get_caller_address();
            let amount_u256: u256 = amount.into();
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount_u256, 'Insufficient allowance');
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount_u256, 'Insufficient balance');

            self.allowances.write((sender, caller), current_allowance - amount_u256);
            self.balances.write(sender, sender_balance - amount_u256);
            self.balances.write(recipient, self.balances.read(recipient) + amount_u256);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: felt252) {
            let caller = starknet::get_caller_address();
            self.allowances.write((caller, spender), amount.into());
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: felt252,
        ) {
            let caller = starknet::get_caller_address();
            let current = self.allowances.read((caller, spender));
            let added: u256 = added_value.into();
            self.allowances.write((caller, spender), current + added);
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: felt252,
        ) {
            let caller = starknet::get_caller_address();
            let current = self.allowances.read((caller, spender));
            let subtracted: u256 = subtracted_value.into();
            assert(current >= subtracted, 'Allowance below zero');
            self.allowances.write((caller, spender), current - subtracted);
        }
    }
}
