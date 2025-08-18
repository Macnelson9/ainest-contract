#[starknet::contract]
mod AInestRegistry {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::storage::Map;
    use starknet::storage::StorageMapReadAccess;
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use core::byte_array::ByteArray;
    use core::num::traits::Zero;
    use starknet::syscalls::call_contract_syscall;

    #[storage]
    struct Storage {
        datasets: Map<u256, Dataset>,
        dataset_count: u256,
        ipfs_hashes: Map<felt252, bool>,
        strk_token: ContractAddress,
        marketplace_address: ContractAddress,
        owner: ContractAddress, 
        is_purchasing: bool, // Reentrancy guard
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Dataset {
        owner: ContractAddress,
        name: ByteArray,
        ipfs_hash: felt252, 
        price: u256,
        category: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DatasetRegistered: DatasetRegistered,
        DatasetTransferred: DatasetTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct DatasetRegistered {
        dataset_id: u256,
        owner: ContractAddress,
        name: ByteArray,
        ipfs_hash: felt252,
        price: u256,
        category: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct DatasetTransferred {
        dataset_id: u256,
        from: ContractAddress,
        to: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, strk_token: ContractAddress, marketplace_address: ContractAddress) {
        let caller = get_caller_address();
        self.dataset_count.write(0);
        self.strk_token.write(strk_token);
        self.marketplace_address.write(marketplace_address);
        self.owner.write(caller); 
        self.is_purchasing.write(false);
    }

    #[external(v0)]
    fn register_dataset(
        ref self: ContractState,
        name: ByteArray,
        ipfs_hash: felt252,
        price: u256,
        category: ByteArray
    ) -> u256 {
        // Ensure dataset hash is unique
        let exists = self.ipfs_hashes.read(ipfs_hash);
        assert(!exists, 'IPFS hash already used');

        // Mark IPFS hash as taken
        self.ipfs_hashes.write(ipfs_hash, true);

        let caller = get_caller_address();
        let dataset_id = self.dataset_count.read() + 1;
        self.dataset_count.write(dataset_id);

        // Save dataset details
        let name_for_storage = name.clone();
        let category_for_storage = category.clone();
        let name_for_event = name;
        let category_for_event = category;
        self.datasets.write(
            dataset_id,
            Dataset { 
                owner: caller, 
                name: name_for_storage, 
                ipfs_hash, 
                price, 
                category: category_for_storage 
            }
        );

        // Emit event
        self.emit(DatasetRegistered {
            dataset_id,
            owner: caller,
            name: name_for_event,
            ipfs_hash,
            price,
            category: category_for_event
        });

        dataset_id
    }

    #[external(v0)]
    fn get_dataset(self: @ContractState, dataset_id: u256) -> Dataset {
        let dataset = self.datasets.read(dataset_id);
        assert(!dataset.owner.is_zero(), 'Dataset does not exist');
        return dataset;
    }

    #[external(v0)]
    fn get_dataset_count(self: @ContractState) -> u256 {
        return self.dataset_count.read();
    }

    #[external(v0)]
    fn verify_ipfs_hash(self: @ContractState, ipfs_hash: felt252) -> bool {
        // Returns true if hash exists (already registered)
        return self.ipfs_hashes.read(ipfs_hash);
    }

    #[external(v0)]
    fn purchase_dataset(ref self: ContractState, dataset_id: u256) {
        // --- Reentrancy Guard ---
        assert(!self.is_purchasing.read(), 'Reentrancy guard');
        self.is_purchasing.write(true);

        let caller = get_caller_address();
        let dataset = self.datasets.read(dataset_id);

        // --- Validations ---
        assert(!dataset.owner.is_zero(), 'Dataset does not exist');
        assert(dataset.owner != caller, 'Cannot purchase own dataset');
        assert(!dataset.price.is_zero(), 'Dataset not for sale');
        assert(dataset.price >= 5_u256, 'Price too low for fee');

        let hash_exists = self.ipfs_hashes.read(dataset.ipfs_hash);
        assert(hash_exists, 'IPFS hash not registered');

        let seller = dataset.owner;
        let price = dataset.price;

        // --- Transfer STRK from buyer to this contract ---
        let transfer_in = call_contract_syscall(
            self.strk_token.read(),
            selector!("transferFrom"),
            array![
                caller.into(),
                get_contract_address().into(),
                price.low.into(),
                price.high.into()
            ].span()
        );
        assert(transfer_in.is_ok(), 'Token transferFrom failed');

        // --- Fee calculation ---
        let fee = price * 5_u256 / 100_u256;
        let remaining = price - fee;
        assert(!remaining.is_zero(), 'Remaining amount is zero');

        // --- Transfer fee to marketplace ---
        let fee_transfer = call_contract_syscall(
            self.strk_token.read(),
            selector!("transfer"),
            array![
                self.marketplace_address.read().into(),
                fee.low.into(),
                fee.high.into()
            ].span()
        );
        assert(fee_transfer.is_ok(), 'Fee transfer failed');

        // --- Transfer remaining amount to seller ---
        let seller_transfer = call_contract_syscall(
            self.strk_token.read(),
            selector!("transfer"),
            array![
                seller.into(),
                remaining.low.into(),
                remaining.high.into()
            ].span()
        );
        assert(seller_transfer.is_ok(), 'Seller transfer failed');

        // --- Update dataset ownership ---
        self.datasets.write(dataset_id, Dataset {
            owner: caller,
            name: dataset.name,
            ipfs_hash: dataset.ipfs_hash,
            price: dataset.price,
            category: dataset.category
        });

        // --- Emit event ---
        self.emit(DatasetTransferred { dataset_id, from: seller, to: caller });

        // --- Reset reentrancy guard ---
        self.is_purchasing.write(false);
    }
}
