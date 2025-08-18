// #[cfg(test)]
// mod Tests {
//     use starknet::ContractAddress;
//     use starknet::contract_address_const;
//     use starknet::class_hash::Felt252TryIntoClassHash;
//     use starknet::testing::{set_caller_address, set_contract_address, mock_call, stop_mock_call};
//     use starknet::syscalls::deploy_syscall;
//     use core::byte_array::ByteArray;
//     use core::array::ArrayTrait;
//     use super::AInestRegistry;
//     use super::AInestRegistry::{Dataset, DatasetRegistered, DatasetTransferred};
//     use super::AInestRegistry::Event as AInestEvent;

//     // Helper to deploy the contract in tests
//     fn deploy_contract(strk_token: ContractAddress, marketplace_address: ContractAddress) -> ContractAddress {
//         let mut calldata = array![strk_token.into(), marketplace_address.into()];
//         let (contract_address, _) = deploy_syscall(AInestRegistry::class_hash(), 0, calldata.span(), false).unwrap();
//         contract_address
//     }

//     #[test]
//     #[available_gas(20000000)]
//     fn test_register_dataset_success() {
//         let caller = contract_address_const::<0x123>();
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         let name: ByteArray = "Test Dataset";
//         let ipfs_hash: felt252 = 0x6861736831; // Dummy hash
//         let price = 100_u256;

//         let dataset_id = AInestRegistry::register_dataset(name.clone(), ipfs_hash, price);

//         assert(dataset_id == 1, 'Invalid dataset ID');

//         let stored_dataset = AInestRegistry::get_dataset(dataset_id);
//         assert(stored_dataset.owner == caller, 'Invalid owner');
//         assert(stored_dataset.name == name, 'Invalid name');
//         assert(stored_dataset.ipfs_hash == ipfs_hash, 'Invalid hash');
//         assert(stored_dataset.price == price, 'Invalid price');

//         assert(AInestRegistry::verify_ipfs_hash(ipfs_hash), 'Hash not marked used');

//         // Check event
//         let event = starknet::testing::pop_log::<AInestEvent>(contract_address).unwrap();
//         match event {
//             AInestEvent::DatasetRegistered(e) => {
//                 assert(e.dataset_id == 1, 'Invalid event ID');
//                 assert(e.owner == caller, 'Invalid event owner');
//             },
//             _ => panic!("Wrong event")
//         }
//     }

//     #[test]
//     #[available_gas(1000000)]
//     #[should_panic(expected: ('IPFS hash already used',))]
//     fn test_register_dataset_duplicate_hash() {
//         let caller = contract_address_const::<0x123>();
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         let name: ByteArray = "Test Dataset";
//         let ipfs_hash: felt252 = 0x6861736831;
//         let price = 100_u256;

//         AInestRegistry::register_dataset(name.clone(), ipfs_hash, price);
//         AInestRegistry::register_dataset(name, ipfs_hash, price); // Duplicate
//     }

//     #[test]
//     #[available_gas(1000000)]
//     #[should_panic(expected: ('Dataset does not exist',))]
//     fn test_get_dataset_non_existent() {
//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         AInestRegistry::get_dataset(999);
//     }

//     #[test]
//     #[available_gas(20000000)]
//     fn test_verify_ipfs_hash() {
//         let caller = contract_address_const::<0x123>();
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         let ipfs_hash: felt252 = 0x6861736831;

//         assert(!AInestRegistry::verify_ipfs_hash(ipfs_hash), 'Hash should not be used initially');

//         let name: ByteArray = "Test Dataset";
//         let price = 100_u256;
//         AInestRegistry::register_dataset(name, ipfs_hash, price);

//         assert(AInestRegistry::verify_ipfs_hash(ipfs_hash), 'Hash should be used after registration');
//     }

//     #[test]
//     #[available_gas(30000000)]
//     fn test_purchase_dataset_success() {
//         let caller = contract_address_const::<0x123>(); // Seller
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x456>(), contract_address_const::<0x789>());

//         set_contract_address(contract_address);

//         let name: ByteArray = "Test Dataset";
//         let ipfs_hash: felt252 = 0x6861736831;
//         let price = 100_u256;

//         let dataset_id = AInestRegistry::register_dataset(name, ipfs_hash, price);

//         // Switch to buyer
//         let buyer = contract_address_const::<0xabc>();
//         set_caller_address(buyer);

//         // Mock STRK transfers (two calls: fee and remaining)
//         let strk_address = contract_address_const::<0x456>();
//         let marketplace = contract_address_const::<0x789>();

//         // Mock first transferFrom for fee (10% = 10)
//         mock_call(
//             strk_address,
//             selector!("transferFrom"),
//             array![buyer.into(), marketplace.into(), 10_u256.low.into(), 10_u256.high.into()].span()
//         );

//         // Mock second transferFrom for remaining (90)
//         mock_call(
//             strk_address,
//             selector!("transferFrom"),
//             array![buyer.into(), caller.into(), 90_u256.low.into(), 90_u256.high.into()].span()
//         );

//         AInestRegistry::purchase_dataset(dataset_id);

//         // Check ownership updated
//         let updated_dataset = AInestRegistry::get_dataset(dataset_id);
//         assert(updated_dataset.owner == buyer, 'Ownership not transferred');

//         // Check event
//         let event = starknet::testing::pop_log::<AInestEvent>(contract_address).unwrap();
//         match event {
//             AInestEvent::DatasetTransferred(e) => {
//                 assert(e.dataset_id == dataset_id, 'Invalid event ID');
//                 assert(e.from == caller, 'Invalid from');
//                 assert(e.to == buyer, 'Invalid to');
//             },
//             _ => panic!("Wrong event")
//         }

//         // Stop mocks
//         stop_mock_call(strk_address, selector!("transferFrom"));
//     }

//     #[test]
//     #[available_gas(1000000)]
//     #[should_panic(expected: ('Dataset not for sale',))]
//     fn test_purchase_dataset_zero_price() {
//         let caller = contract_address_const::<0x123>();
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         let name: ByteArray = "Test Dataset";
//         let ipfs_hash: felt252 = 0x6861736831;
//         let price = 0_u256; // Zero price
//         let dataset_id = AInestRegistry::register_dataset(name, ipfs_hash, price);

//         let buyer = contract_address_const::<0xabc>();
//         set_caller_address(buyer);

//         AInestRegistry::purchase_dataset(dataset_id);
//     }

//     #[test]
//     #[available_gas(1000000)]
//     #[should_panic(expected: ('Cannot purchase own dataset',))]
//     fn test_purchase_dataset_own() {
//         let caller = contract_address_const::<0x123>();
//         set_caller_address(caller);

//         let contract_address = deploy_contract(contract_address_const::<0x0>(), contract_address_const::<0x0>());

//         set_contract_address(contract_address);

//         let name: ByteArray = "Test Dataset";
//         let ipfs_hash: felt252 = 0x6861736831;
//         let price = 100_u256;
//         let dataset_id = AInestRegistry::register_dataset(name, ipfs_hash, price);

//         AInestRegistry::purchase_dataset(dataset_id); // Same caller
//     }
// }