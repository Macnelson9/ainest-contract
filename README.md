# 🧠 AInest Registry – Decentralized AI Dataset Marketplace (MVP)

AInest is a decentralized **AI dataset registry and marketplace** built on StarkNet using Cairo.
This MVP smart contract allows creators to **register, verify, list, purchase, and transfer datasets** securely on-chain, with IPFS storage integration and a fee model for marketplace sustainability.

Frontend: [AInest Frontend](https://ainest-pi.vercel.app/)

---

## 🚀 Project Overview

The goal of **AInest** is to solve a core problem in the AI ecosystem:

- AI practitioners lack a **trustless, transparent, and fair marketplace** to buy and sell datasets.
- Dataset creators often face **ownership disputes**, **lack of royalties**, and **poor verification mechanisms**.

This contract provides a foundation for a decentralized dataset marketplace where:

- Every dataset registered is **unique and verifiable** (via IPFS hashes).
- Ownership is **on-chain** and transferable.
- Buyers can securely purchase datasets with **STRK tokens**.
- The marketplace captures a **5% fee** on every dataset purchase.

---

## ⚙️ Core Features

### 1. Dataset Registration

- Users can register datasets with metadata:

  - **Name** (ByteArray)
  - **IPFS Hash** (felt252) → ensures dataset uniqueness
  - **Price** (u256)
  - **Category** (ByteArray)
  - **Description** (ByteArray)
  - **Format** (felt252, e.g. CSV, JSON, ZIP)
  - **Size** (u256, e.g. file size in bytes)

- Contract stores **original owner** (never changes) and current owner (can change after purchase).
- Emits `DatasetRegistered` event.

### 2. Dataset Uniqueness

- Each dataset’s **IPFS hash** is verified to be unique.
- Prevents duplicate datasets from being listed.

### 3. Dataset Ownership & Transfers

- Ownership is always **on-chain**.
- When a dataset is purchased:

  - Ownership is transferred to the buyer.
  - Downloads counter increases.
  - Dataset is automatically **unlisted**.

- Emits `DatasetTransferred` event.

### 4. Marketplace Fee & Token Handling

- All purchases are conducted in **STRK tokens**.
- A **5% fee** is deducted from every transaction and sent to the marketplace treasury address.
- The remaining **95% goes to the seller**.

### 5. Re-listing Datasets

- Owners can **relist datasets** at a new price.
- Emits `DatasetRelisted` event.

### 6. Querying & Verification

- `get_dataset(dataset_id)` → fetch full dataset metadata.
- `get_dataset_count()` → get total registered datasets.
- `verify_ipfs_hash(hash)` → check if an IPFS hash is already registered.

---

## 📜 Contract Architecture

### Storage Layout

- `datasets: Map<u256, Dataset>` → Stores all dataset records.
- `dataset_count: u256` → Tracks total number of datasets.
- `ipfs_hashes: Map<felt252, bool>` → Prevents duplicate dataset registration.
- `strk_token: ContractAddress` → Address of STRK token contract (ERC20-like).
- `marketplace_address: ContractAddress` → Address receiving marketplace fees.
- `owner: ContractAddress` → Contract deployer/owner.
- `is_purchasing: bool` → Reentrancy guard.

### Dataset Structure

```rust
struct Dataset {
    originalOwner: ContractAddress, // creator, immutable
    owner: ContractAddress,         // current owner
    name: ByteArray,
    ipfs_hash: felt252,
    price: u256,
    category: ByteArray,
    listed: bool,
    description: ByteArray,
    format: felt252,
    size: u256,
    createdAt: u64,
    downloads: u256,
}
```

---

## 🔑 Key Functions

### `constructor(strk_token, marketplace_address)`

Initializes the registry with:

- STRK token contract address.
- Marketplace treasury address.
- Sets deployer as `owner`.

---

### `register_dataset(name, ipfs_hash, price, category, description, format, size) -> u256`

Registers a new dataset:

- Verifies IPFS hash is unique.
- Increments dataset counter.
- Stores dataset metadata.
- Marks dataset as listed.
- Emits `DatasetRegistered`.
- Returns the new `dataset_id`.

---

### `get_dataset(dataset_id) -> Dataset`

Fetch full metadata for a dataset.

- Fails if dataset doesn’t exist.

---

### `get_dataset_count() -> u256`

Returns number of registered datasets.

---

### `verify_ipfs_hash(ipfs_hash) -> bool`

Checks if a dataset with this IPFS hash exists.

---

### `purchase_dataset(dataset_id)`

Handles dataset purchase:

1. Ensures dataset exists, is listed, and buyer isn’t the owner.
2. Transfers `price` amount in STRK from buyer → contract.
3. Splits amount:

   - 5% fee → marketplace address.
   - 95% → seller.

4. Updates ownership & increments downloads.
5. Marks dataset unlisted.
6. Emits `DatasetTransferred`.

---

### `list_for_sale(dataset_id, new_price)`

Allows current owner to relist dataset at a new price.

- Updates price & sets `listed = true`.
- Emits `DatasetRelisted`.

---

## 📡 Events

- **`DatasetRegistered`** → Triggered when a dataset is added.
- **`DatasetTransferred`** → Triggered when a dataset is purchased.
- **`DatasetRelisted`** → Triggered when owner relists dataset for sale.

---

## 🔐 Security Considerations

- **Reentrancy Guard** (`is_purchasing`) prevents nested purchases.
- **Unique IPFS Enforcement** prevents dataset duplication.
- **Zero-address checks** ensure datasets must exist before access.
- **Price Validation** ensures datasets cannot be listed at zero.

---

## 🌍 Future Improvements

This MVP focuses on the **core dataset registry & marketplace mechanics**. Future upgrades may include:

- **Royalties**: Ensure creators earn a percentage on every resale.
- **Dataset Bundling**: Sell multiple datasets together.
- **Reputation System**: Rate dataset quality and seller trustworthiness.
- **Decentralized Storage Integration**: Beyond IPFS pinning (e.g., Filecoin, Arweave).
- **DAO Governance**: Community-owned marketplace fee management.

---

## 📌 Summary

**AInest Registry** is a decentralized protocol for registering, selling, and purchasing AI datasets on StarkNet.
It ensures:
✔️ **Trustless ownership** of datasets.
✔️ **Fair and transparent pricing**.
✔️ **Marketplace sustainability** through fees.
✔️ **Security** with reentrancy protection and uniqueness checks.

This MVP lays the foundation for a full-featured **AI dataset economy** powered by blockchain.

---

_Note: This documentation is strictly based on the provided smart contract code and does not include any assumptions or external features not present in the code._ --- IGNORE ---
