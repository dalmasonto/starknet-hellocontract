#[starknet::interface]
trait IHelloStarknet<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod HelloStarknet {
    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[external(v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'amount cannot be 0');
            self.balance.write(self.balance.read() + amount);
        }
        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}

#[cfg(test)]
mod tests {
    use learnsncast::{IHelloStarknetDispatcherTrait, IHelloStarknetDispatcher};
    use snforge_std::{declare, ContractClassTrait};
    // use super::{IHelloStarknetDispatcher};

    #[test]
    fn call_and_invoke() {
        // Declare and deploy a contract
        let contract = declare('HelloStarknet');
        let contract_address = contract.deploy(@ArrayTrait::new()).unwrap();

        // Create a Dispatcher object for interaction with the deployed contract
        let dispatcher = IHelloStarknetDispatcher { contract_address };

        // Query a contract view function
        let balance = dispatcher.get_balance();
        assert(balance == 0, 'balance == 0');

        // Invoke a contract function to mutate state
        dispatcher.increase_balance(100);

        // Verify the transaction's effect
        let balance = dispatcher.get_balance();
        assert(balance == 100, 'balance == 100');
    }
}
