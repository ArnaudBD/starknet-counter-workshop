#[starknet::interface]
trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}

#[starknet::contract]
mod Counter {
    use super::ICounter;
    use kill_switch::IKillSwitchDispatcherTrait;
    use kill_switch::IKillSwitchDispatcher;
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl = OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event{
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32,
    }
    #[constructor]
    fn constructor(ref self: ContractState, input: u32, kill_switch_address: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(input);
        let dispatcher = IKillSwitchDispatcher { contract_address: kill_switch_address };
        self.kill_switch.write(dispatcher);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl ICounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert!( !self.kill_switch.read().is_active(), "Kill Switch is active");
            self.counter.write(self.counter.read() + 1);
            self.emit(CounterIncreased{counter: self.counter.read()});
        }
    }

    #[external(v0)]
    fn only_owner_allowed(ref self: ContractState) {
        self.ownable.assert_only_owner();
    }
}