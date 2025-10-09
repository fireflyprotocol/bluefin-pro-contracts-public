/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::bank {
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};
    use sui::transfer;
    use sui::dynamic_field;
    use std::type_name;
    use std::ascii;

    // local modules
    use bluefin_cross_margin_dex::errors;
    use bluefin_cross_margin_dex::utils;

    // friend modules
    friend bluefin_cross_margin_dex::data_store;
    friend bluefin_cross_margin_dex::exchange;

    //===========================================================//
    //                           Structs                         //
    //===========================================================//


    /// Represents an asset
    struct Asset has store, copy, drop {
        // symbol/name of the asset
        symbol: String,
        // The asset type `0x...package::module::struct`
        type: String,
        // the number of decimals the asset has
        decimals: u8,
        /// The discounted price percentage of the asset
        weight: u64,
        /// The current price of the asset
        price: u64,
        /// True if the asset can be used to open positions
        collateral: bool,
        /// the minimum amount of deposit allowed (must be in 1e9)
        min_deposit: u64,
        /// the maximum amount of deposit allowed (must be in 1e9)
        max_deposit: u64
    }

    /// Represents a deposit made to the asset bank
    /// The struct also stores a dynamic field by the name `coin` which stores the deposited coin
    /// The deposited coin stays inside this `Deposit` struct until the deposit is verified to be valid
    /// in which case the deposited coin moves to balance stored inside the Bank object as dynamic field
    /// or the deposit is tainted in which case the deposited coin is sent back to the depositor
    struct Deposit has key, store {
        // the id of the deposit
        id: UID,
        // The asset symbol that was deposited
        symbol: String,
        // The wallet that made the deposit
        from: address,
        // the account to which deposit was made
        account: address,
        // the amount deposited
        amount: u64,
    }

    /// Represents a supported asset by the bank
    struct SupportedAsset has store {
        /// The information about the asset
        asset_details: Asset,
        /// True if the details of this asset has been copied into the internal datastore 
        synced: bool
    }

    /// Represents the External bank that stores the margin/assets deposited by accounts
    /// The struct carries dynamic fields which are indexed using `asset_symbol` 
    /// that is used to store the balances of deposited coins
    struct AssetBank has key, store {
        id: UID,
        /// An incremental nonce to keep track of deposits made
        nonce: u128,
        /// Map of the assets currently supported by protocol indexed using asset name/symbol
        supported_assets: Table<String, SupportedAsset>,
        /// Map of all the pending deposits made to the bank that are yet not copied into the internal data store
        deposits: Table<u128, Deposit>
    }


    //===============================================================//
    //                         Friend Methods                        //
    //===============================================================//

    /// Allows creation of asset bank. Supposed to be invoked from data_store::external_data_store_creator
    /// Each external data store carries an asset bank for people to deposit funds into.
    public (friend) fun create_asset_bank(ctx: &mut TxContext): AssetBank {
        AssetBank {
            id: object::new(ctx),
            nonce: 0,
            supported_assets: table::new<String, SupportedAsset>(ctx),
            deposits: table::new<u128, Deposit>(ctx),
        }
    }

    /// Supports the provided asset. Invoked when `data_store:::support_asset` is invoked by the admin
    /// 
    /// Parameters:
    /// - bank: Mutable reference to the asset bank that will be supporting this asset
    /// - asset_symbol: Name of the coins that can be deposited into the bank
    /// - decimals: The number of decimals the supported coin has
    /// - weight: The discounted price percentage to be used for the coin
    /// - price: The starting price of the asset
    /// - accepted_as_collateral: Boolean indicating if the underlying can be used for opening positions or not
    /// - min_deposit: The minimum deposit of asset that is acceptable (must be in 1e9)
    /// - max_deposit: The maximum deposit of asset that is acceptable (must be in 1e9)
    public (friend) fun support_asset<T>(
        bank: &mut AssetBank,
        asset_symbol: String, 
        decimals: u8, 
        weight: u64, 
        price: u64, 
        accepted_as_collateral: bool, 
        min_deposit: u64,
        max_deposit: u64
    ): Asset {

        // revert if provided asset is already supported
        assert!(!is_asset_supported(bank, asset_symbol), errors::asset_already_supported());
        // min deposit amount cant be zero and has to be < max deposit amount
        assert!(min_deposit > 0 && min_deposit < max_deposit, errors::invalid_quantity());

        // get the asset type
        let asset_type = get_asset_type<T>();

        // create asset
        let asset = create_asset(
            asset_type,
            asset_symbol,
            decimals, 
            weight, 
            price, 
            accepted_as_collateral,
            min_deposit,
            max_deposit
        );

        // create supported asset struct
        let supported_asset = SupportedAsset {
            asset_details: asset,
            synced: false
        };

        // add the asset to supported list of assets
        table::add(&mut bank.supported_assets, asset_symbol, supported_asset);

        // store the balance of this supported asset type as ZERO
        dynamic_field::add(&mut bank.id, asset_symbol, balance::zero<T>());

        asset

    }

    /// Sets the `sync` status of the provided asset as True.
    /// This is done once the internal data store syncs with internal data store
    /// on the given asset
    public (friend) fun set_asset_status_as_synced(bank: &mut AssetBank, asset_symbol:String){

        table::borrow_mut(&mut bank.supported_assets, asset_symbol).synced = true;

    }

    /// Allows caller to deposit the provided coin amount into the external bank
    ///
    /// Parameters:
    /// - bank: The external bank to deposit amount to
    /// - asset_symbol: The asset being deposited
    /// - account: The address of sub account that will receive the deposited coins in the bank
    /// - coin_base_amount: The amount/quantity of coins to deposit. Should be in decimals of the coin. For USDC it should have 6 decimals, for BLUE 9 etc.
    /// - coin: The coin to be deposited
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    /// 
    /// Returns:
    /// - nonce: the new nonce of the bank
    /// - amount: The amount deposited in standard 9 decimals
    public (friend) fun deposit_to_asset_bank<T>(bank: &mut AssetBank, asset_symbol: String, account: address, coin_base_amount: u64, coin: &mut Coin<T>, ctx: &mut TxContext): (u128, u64) {
        
        // revert if the asset being deposited is not supported
        assert!(is_asset_supported(bank, asset_symbol), errors::asset_not_supported());

        let asset_details = get_supported_asset(bank, asset_symbol);

        let asset_type = get_asset_type<T>();

        // revert if the provided asset/coin type does not match with the provided asset symbol's type
        assert!(asset_type == asset_details.type, errors::asset_type_and_symbol_mismatch());

        // convert the amount ( expected as input in decimals of the asset) to 9 decimals supported by protocol
        let amount = utils::convert_to_protocol_decimals(coin_base_amount, asset_details.decimals);

        // the amount being deposited must conform to min/max allowed deposit quantities
        assert!(amount >= asset_details.min_deposit && amount <= asset_details.max_deposit, errors::invalid_quantity());


        // Getting the amount of the coin
        let total_coin_value = coin::value(coin);

        // revert if amount > value of coin
        assert!(coin_base_amount <= total_coin_value, errors::coin_does_not_have_enough_amount());
        
        // // take the amount of coin for deposit
        let deposit_coin = coin::take(coin::balance_mut(coin), coin_base_amount, ctx);

        // create deposit payload
        let deposit = Deposit {
            id: object::new(ctx),
            symbol: asset_symbol,
            from: tx_context::sender(ctx),
            amount,
            account
        };

        // Store the deposited coin with in the Deposit struct
        dynamic_field::add(&mut deposit.id, b"coin", deposit_coin);

        // increment the bank nonce
        bank.nonce = bank.nonce + 1;

        // update entry in deposits table
        table::add(&mut bank.deposits, bank.nonce, deposit);

        (bank.nonce, amount)

    }


    /// Returns the deposit
    ///
    /// Parameters:
    /// - bank: The external bank to which amount was deposited
    /// - nonce: The nonce of the deposit (Generated at the time funds were deposited to external bank)
    /// 
    /// Returns:
    /// - from: The user that deposited the funds
    /// - to/account: the address to which amount was deposited in external/asset bank
    /// - amount: The amount deposited
    /// - asset_symbol: The symbol of the asset deposited
    /// - coin: The deposit coin
    public (friend) fun remove_deposit<T>(bank: &mut AssetBank, nonce:u128): (address, address, u64, String, Coin<T>){

        // revert if the nonce does not exist in the bank deposit table
        // this implies either the nonce is incorrect or the funds for the provided deposited are 
        // already moved to internal data store
        // @dev once funds are moved to IDS, the provided nonce is deleted from external/asset bank
        assert!(table::contains(&bank.deposits, nonce), errors::invalid_nonce());

        // Fetch and remove the deposit entry from external bank for given nonce
        // @dev we can keep the deposit entry in table for historical records
        // but we are paying gas fee for the entry and it is never going to be 
        // used again. Best to remove it.
        let deposit = table::remove(&mut bank.deposits, nonce);

        let coin = dynamic_field::remove(&mut deposit.id, b"coin");        
   
        let Deposit {id, symbol, from, account, amount } = deposit;
        
        object::delete(id);

        (
            from,
            account,
            amount, 
            symbol,
            coin
        )
    }

    public (friend) fun merge_coin_into_balance<T>(bank: &mut AssetBank, coin: Coin<T>, asset_symbol: String){

        // get coin balance in the bank
        let balance = dynamic_field::borrow_mut<String, Balance<T>>(&mut bank.id, asset_symbol);

        balance::join(balance, coin::into_balance<T>(coin));

    }
    
    /// Withdraws margin from external/asset bank to the account provided
    ///
    /// Parameters:
    /// - bank: Mutable reference to margin/external bank
    /// - asset_symbol: The symbol of the asset to be withdrawn
    /// - account: The account to transfer margin to
    /// - amount: The amount of margin to withdraw/transfer (will be in 9 decimals)
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    public (friend) fun withdraw_from_asset_bank<T>(bank: &mut AssetBank, asset_symbol: String, account: address, amount: u64, ctx: &mut TxContext){

        // revert if the asset being deposited is not supported
        assert!(is_asset_supported(bank, asset_symbol), errors::asset_not_supported());

        let asset_details = get_supported_asset(bank, asset_symbol);
        let asset_type = get_asset_type<T>();

        // revert if the provided asset/coin type does not match with the provide asset symbol's type
        assert!(asset_type == asset_details.type, errors::asset_type_and_symbol_mismatch());
                
        let coin_base_amount = utils::convert_to_provided_decimals((amount as u64), asset_details.decimals);

        // get coin balance in the bank
        let balance = dynamic_field::borrow_mut<String, Balance<T>>(&mut bank.id, asset_symbol);

        // withdrawing the coin from the bank
        let coin = coin::take(balance, (coin_base_amount as u64), ctx);

        // transferring the coin to the destination account
        transfer::public_transfer(
            coin,
            account
        );

    }

    //===============================================================//
    //                        Public Methods                         //
    //===============================================================//

    public fun is_asset_supported(bank: &AssetBank, asset_symbol: String): bool {
        table::contains(&bank.supported_assets, asset_symbol)
    }

    public fun asset_exists_in_table(assets_table: &Table<String, Asset>, asset_symbol: String): bool {
        table::contains(assets_table, asset_symbol)
    }


    /// Returns the values of the asset
    public fun asset_values(asset:Asset): (String, String, u8, u64, u64, bool){
        (
            asset.type,
            asset.symbol,
            asset.decimals,
            asset.weight,
            asset.price,
            asset.collateral
        )
    }

    /// Returns true/false if the asset is synced
    /// @dev the method will throw if the asset is not supported - please run `is_asset_supported()` method beforehand
    public fun is_asset_synced(bank: &AssetBank, asset_symbol: String): bool {
        table::borrow(&bank.supported_assets, asset_symbol).synced
    }

    /// Returns the supported asset
    /// @dev the method will throw if the asset is not supported.
    public fun get_supported_asset(bank: &AssetBank, asset_symbol: String): Asset {
        table::borrow(&bank.supported_assets, asset_symbol).asset_details
    }


    /// Returns the amount of provided asset quantity that is worth the provided amount of USD
    public fun get_asset_with_provided_usd_value(supported_assets_table: &Table<String, Asset>, asset_symbol: String, amount: u64): u64 {
        
        if (utils::is_empty_string(asset_symbol)) {
            return amount
        };

        assert!(asset_exists_in_table(supported_assets_table, asset_symbol), errors::asset_not_supported());

        let asset_details = *table::borrow(supported_assets_table, asset_symbol);
        let (_, _, _, weight, price, _) = asset_values(asset_details);
        
        // amount / (price * weight)
        // If user has selected BLUE token for fee payment which has weight 0.5 and price 0.1
        // If the fee required is 2 USD
        // They will need to pay 2 / (0.1 * 05) = 40 USD
        utils::base_div(amount, utils::base_mul(price, weight))
    }


    //===============================================================//
    //                       Internal Methods                        //
    //===============================================================//

     /// Creates an asset using provided details
    fun create_asset(
        type: String, 
        symbol: String, 
        decimals: u8, 
        weight: u64, 
        price: u64, 
        collateral: bool, 
        min_deposit: u64, 
        max_deposit:u64
    ): Asset{
        Asset {
            type,
            symbol,
            decimals,
            weight,
            price,
            collateral,
            min_deposit,
            max_deposit
        }
    }

    fun get_asset_type<T>(): String{
        let ascii_string = type_name::into_string(type_name::with_defining_ids<T>());
        let type_bytes =  ascii::into_bytes(ascii_string);
        string::utf8(type_bytes)
    }


    #[test_only]
    public fun get_deposited_asset(bank: &AssetBank, nonce: u128): &Deposit {
        assert!(table::contains(&bank.deposits, nonce), errors::invalid_nonce());
        table::borrow(&bank.deposits, nonce)
    }

    #[test_only]
    public fun get_deposit_values(bank: &mut AssetBank, nonce: u128): (address, address, u64, String) {
        let deposit = get_deposited_asset(bank, nonce);
        (deposit.from, deposit.account, deposit.amount, deposit.symbol)
    }


    #[test_only]
    public fun get_bank_nonce(bank: &AssetBank): u128 {
        bank.nonce
    }

    #[test_only]
    public fun withdraw_from_bank_directly<T>(bank: &mut AssetBank, asset_symbol: String, account: address, amount: u64, ctx: &mut TxContext){
        withdraw_from_asset_bank<T>(bank, asset_symbol, account, amount, ctx);
    }

    #[test_only]
    public fun add_deposit_directly<T>(bank: &mut AssetBank, asset_symbol: String, account: address, amount: u64, coin: &mut Coin<T>, ctx: &mut TxContext){
        deposit_to_asset_bank<T>(bank, asset_symbol, account, amount, coin, ctx);
    }


}
