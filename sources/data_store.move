/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::data_store {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use std::option::Option;
    use sui::transfer;
    use std::vector;
    use sui::address;
    use sui::bcs;
    use sui::hash;

    // local modules
    use bluefin_cross_margin_dex::bank::{Self, Asset, AssetBank,};
    use bluefin_cross_margin_dex::constants;
    use bluefin_cross_margin_dex::events;
    use bluefin_cross_margin_dex::errors;
    use bluefin_cross_margin_dex::admin::{AdminCap};
    use bluefin_cross_margin_dex::perpetual::{Self, Perpetual};
    use bluefin_cross_margin_dex::account::{Self, Account};
    use bluefin_cross_margin_dex::bcs_handler;

    // friend modules
    friend bluefin_cross_margin_dex::exchange;
    friend bluefin_cross_margin_dex::margining_engine;

    #[test_only]
    friend bluefin_cross_margin_dex::test_utils;
    #[test_only]
    friend bluefin_cross_margin_dex::test_data_store;
    #[test_only]
    friend bluefin_cross_margin_dex::test_operator_controlled_methods;
    #[test_only]
    friend bluefin_cross_margin_dex::test_bank;
    #[test_only]
    friend bluefin_cross_margin_dex::test_trade;
    #[test_only]
    friend bluefin_cross_margin_dex::test_margin_leverage_adjustment;
    #[test_only]
    friend bluefin_cross_margin_dex::test_liquidations;

  

    //===========================================================//
    //                           Structs                         //
    //===========================================================//


    /// Represents the perpetual store in EDS
    struct EDSPerpetual has store {
        /// The perpetual config
        perpetual: Perpetual,
        /// Bool indicating if the perpetual has been replicated/synced in IDS
        synced: bool
    }

    struct OrderFill has store, drop {
        quantity: u64,
        timestamp: u64,
    }

    /// Represents the internal data store of the protocol owned by the sequencer 
    struct InternalDataStore has key {
        /// ID of the data Storage object
        id: UID,
        /// The protocol version that storage supports
        version: u64,
        /// Current sequence hash updated after each tx execution
        sequence_hash: vector<u8>,
        /// Map of account address and their account balance
        accounts: Table<address, Account>,
        /// Map of perpetuals
        perpetuals: Table<String, Perpetual>,
        /// Map of the payload bytes executed till data. Used to prevent the replay of a tx
        hashes: Table<vector<u8>, u64>,
        /// Map of the orders filled quantities
        filled_orders: Table<vector<u8>, OrderFill>,
        /// Map of the assets currently supported by protocol indexed using asset name
        supported_assets: Table<String, Asset>,
        /// Map of special accounts that can perform certain actions on exchange
        operators: Table<String, address>,
        /// List of whitelisted wallets that can perform liquidations
        liquidators: vector<address>,
        /// the gas charges to be applied on traders
        gas_fee: u64,
        /// The address that will receive gas amount
        gas_pool: address,
        /// Incremental sequence number that increments with each action on IDS
        sequence_number: u128
    }

    /// Represents the shared external data store
    struct ExternalDataStore has key {
        /// ID of the data Storage object
        id: UID,
        /// The protocol version that storage supports
        version: u64,
        /// The id of the internal data store 
        internal_data_store: ID,
        /// Map of perpetuals
        perpetuals: Table<String, EDSPerpetual>,        
        /// Map of the operators (privileged accounts) that can perform certain privileged actions
        operators: Table<String, address>,
        /// The external/asset bank that stores user deposits
        asset_bank: AssetBank,
        /// An incremental counter to keep track of number of actions performed on shared objects
        /// such as deposit to AssetBanks, Updating perpetuals
        sequence_number: u128
    }

    //===========================================================//
    //                    Initialization                         //
    //===========================================================//

    /// Initializes the module by creating the internal and external data stores.
    /// This function is only called during the module's setup phase, 
    /// ensuring that administrative privileges are correctly established. 
    ///
    /// Parameters:
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    fun init(ctx: &mut TxContext) {
        let sequencer = tx_context::sender(ctx);

        // create internal data store and get its id
        let internal_data_store = internal_data_store_creator(sequencer, 0, ctx);

        // create external data store
        external_data_store_creator(internal_data_store, ctx);
    }


    //===============================================================//
    //                          Entry Methods                        //
    //===============================================================//

    /// Allows admin of the protocol to support the given asset type.
    /// Once supported, the Asset Bank allows users to deposit that type of coins.
    ///
    /// Parameters:
    /// - _: The AdminCap, ensuring that the method can only be invoked by exchange admin
    /// - eds: Mutable reference to External Data Store
    /// - asset_symbol: Name of the coins that can be deposited into the bank
    /// - decimals: The number of decimals the supported coin has
    /// - weight: The discounted price percentage to be used for the coin
    /// - price: The starting price of the asset
    /// - accepted_as_collateral: Boolean indicating if the underlying can be used for opening positions or not 
    /// - min_deposit: The minimum deposit of asset that is acceptable (must be in 1e9)
    /// - max_deposit: The maximum deposit of asset that is acceptable (must be in 1e9)
    entry fun support_asset<T>(
        _: &AdminCap, 
        eds: &mut ExternalDataStore, 
        asset_symbol: String, 
        decimals: u8, 
        weight: u64, 
        price: u64, 
        accepted_as_collateral: bool, 
        min_deposit: u64,
        max_deposit: u64,
    ) {
        
        // Ensure version of the eds and package match
        assert!(eds.version == constants::get_version(), errors::version_mismatch());
        
        // use bank module to support the asset
        let asset = bank::support_asset<T>(
            &mut eds.asset_bank, 
            asset_symbol, 
            decimals, 
            weight, 
            price, 
            accepted_as_collateral,
            min_deposit,
            max_deposit,
        );
     
        // increment the sequence number
        let sequence_number = eds_increment_sequence_number(eds);

        // emit event
        events::emit_asset_supported_event(*object::uid_as_inner(&eds.id), asset, sequence_number);

    }

    /// Creates the internal data storage object
    /// Only the holder of current Admin Cap can invoke the method
    ///
    /// Parameters:
    /// - _: The AdminCap, ensuring that the method can only be invoked by exchange admin
    /// - eds: Mutable reference to External Data Store
    /// - sequencer: The address of the sequencer operator that will own the ids
    /// - ctx: Mutable reference to `TxContext`, the transaction context.

    entry fun create_internal_data_store(_: &AdminCap, eds: &mut ExternalDataStore, sequencer: address, ctx: &mut TxContext) {

        // Ensure version of the eds and package match
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        eds_increment_sequence_number(eds);

        let internal_data_store = internal_data_store_creator(sequencer, eds.sequence_number, ctx);

        // update the eds to have the new internal store id
        eds.internal_data_store = internal_data_store;
    }

    /// Allows the current sequencer to transfer the internal store to new sequencer
    ///
    /// Parameters:
    /// - ids: A mutable reference to internal data store
    /// - sequencer: The address of the sequencer operator that will own the ids
    entry fun transfer_ids(ids: InternalDataStore, sequencer: address) {
        transfer::transfer(ids, sequencer);
    }

    /// Allows the owner(Sequencer) of internal data store to increment its version
    ///
    /// Parameters:
    /// - ids: Mutable reference to the Internal Data Store
    entry fun increment_internal_data_store_version(ids: &mut InternalDataStore){
        ids.version = ids.version + 1;

        assert!(ids.version <= constants::get_version(), errors::latest_supported_contract_version());

    }

    /// Allows the admin of exchange to increment external data store version
    ///
    /// Parameters:
    /// - _: Reference to admin cap to ensure only the admin of exchange can invoke the method
    /// - eds: Mutable reference to the External Data Store
    entry fun increment_external_data_store_version(_: &AdminCap, eds: &mut ExternalDataStore){
        eds.version = eds.version + 1;
        assert!(eds.version <= constants::get_version(), errors::latest_supported_contract_version());

    }

    /// Allows the admin of exchange to create a new perpetual in external data store
    ///
    /// Parameters:
    /// - _: Reference to admin cap to ensure only the admin of exchange can invoke the method
    /// - clock: Reference to Sui clock
    /// - eds: Mutable reference to the External Data Store
    /// - *: Perpetual attributes
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    entry fun create_perpetual(
        _: &AdminCap, 
        eds: &mut ExternalDataStore, 
        symbol: String,
        imr: u64,
        mmr: u64,
        step_size: u64,
        tick_size: u64,
        min_trade_qty: u64,
        max_trade_qty: u64,
        min_trade_price: u64,
        max_trade_price: u64,
        max_notional_at_open: vector<u64>,
        mtb_long: u64,
        mtb_short: u64,
        maker_fee: u64,
        taker_fee: u64,
        max_funding_rate: u64,
        insurance_pool_ratio: u64,
        trading_start_time: u64,
        insurance_pool: address,
        fee_Pool: address,
        isolated_only: bool,
        base_asset_symbol: vector<u8>,
        base_asset_name: vector<u8>,
        base_asset_decimals: u64,
        max_limit_order_quantity: u64,
        max_market_order_quantity: u64,
        default_leverage: u64,
        ctx: &mut TxContext
        ){
        
        // Ensure version of the eds and package match
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        // Ensure that a perpetual with same symbol doesn't exist
        assert!(!table::contains(&eds.perpetuals, symbol), errors::perpetual_already_exists());

        // Create a unique id for perpetual
        let uid = object::new(ctx);
        let id = object::uid_to_address(&uid);
        object::delete(uid);


        // create perpetual object
        let perpetual = perpetual::create_perpetual(
            id,
            symbol,
            imr,
            mmr,
            step_size,
            tick_size,
            min_trade_qty,
            max_trade_qty,
            min_trade_price,
            max_trade_price,
            max_notional_at_open,
            mtb_long,
            mtb_short,
            maker_fee,
            taker_fee,
            max_funding_rate,
            insurance_pool_ratio,
            trading_start_time,
            insurance_pool,
            fee_Pool,
            isolated_only,
            string::utf8(base_asset_symbol),
            string::utf8(base_asset_name),
            base_asset_decimals,
            max_limit_order_quantity,
            max_market_order_quantity,
            default_leverage
        );

        // add perpetual to the map
        table::add(&mut eds.perpetuals, symbol, EDSPerpetual {perpetual, synced:false});

        let sequence_number = eds_increment_sequence_number(eds);

        // emit perpetual creation event
        events::emit_perpetual_update_event(object::uid_to_inner(&eds.id), perpetual, sequence_number);
    }


    /// Allows the admin of exchange to update any parameter of the perpetual config
    ///
    /// Parameters:
    /// - _: Reference to admin cap to ensure only the admin of exchange can invoke the method
    /// - eds: Mutable reference to the External Data Store
    /// - perpetual: Perpetual symbol/name for which the tick size is to be updated
    /// - field: The name of the field/config being updated in bytes
    /// - value: BCS encoded value to be set on the provided field
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    entry fun update_perpetual(_: &AdminCap, eds: &mut ExternalDataStore, perpetual: String, field: vector<u8>, value: vector<u8>){
        
        // Ensure version of the eds and package match
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        let sequence_number = eds_increment_sequence_number(eds);

        let eds_id = object::uid_to_inner(&eds.id);
        let eds_perp = get_perpetual_from_eds(eds, perpetual);

       // Ensure that the latest changes made to the perp in EDS are already replicated in IDS
        assert!(eds_perp.synced, errors::sync_already_pending());
        
        let bcs_bytes = bcs::new(value);

        if(field == b"tick_size"){
            perpetual::set_tick_size(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if(field == b"step_size" || field == b"min_trade_quantity") {
            perpetual::set_step_size_and_min_trade_qty(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if(field == b"max_limit_order_quantity") {
            perpetual::set_max_limit_order_quantity(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if(field == b"max_market_order_quantity") {
            perpetual::set_max_market_order_quantity(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"max_trade_quantity") {
            perpetual::set_max_trade_qty(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"initial_margin_required") {
            perpetual::set_imr(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"maintenance_margin_required") {
            perpetual::set_mmr(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"min_trade_price") {
            perpetual::set_min_trade_price(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"max_trade_price") {
            perpetual::set_max_trade_price(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"mtb_long") {
            perpetual::set_mtb(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes), true);
        } else if( field == b"mtb_short") {
            perpetual::set_mtb(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes), false);
        } else if( field == b"maker_fee") {
            perpetual::set_fee(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes), true);
        } else if( field == b"taker_fee") {
            perpetual::set_fee(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes), false);
        } else if( field == b"max_funding_rate") {
            perpetual::set_max_funding_rate(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"insurance_pool_address") {
            perpetual::set_insurance_pool_address(&mut eds_perp.perpetual, bcs::peel_address(&mut bcs_bytes));
        } else if( field == b"fee_pool_address") {
            perpetual::set_fee_pool_address(&mut eds_perp.perpetual, bcs::peel_address(&mut bcs_bytes));
        } else if( field == b"insurance_pool_ratio") {
            perpetual::set_insurance_pool_liquidation_premium_percentage(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        } else if( field == b"isolated_only") {
            perpetual::set_isolated_only(&mut eds_perp.perpetual, bcs::peel_bool(&mut bcs_bytes));
        } else if( field == b"trading_status") {
            perpetual::set_trading_status(&mut eds_perp.perpetual, bcs::peel_bool(&mut bcs_bytes));
        } else if( field == b"delist") {
            perpetual::delist(&mut eds_perp.perpetual, bcs::peel_u64(&mut bcs_bytes));
        }  else if( field == b"max_allowed_oi_open") {
            perpetual::set_max_allowed_oi_open(&mut eds_perp.perpetual, bcs::peel_vec_u64(&mut bcs_bytes));
        } else {
            abort errors::invalid_perpetual_config()
        };

        // set perpetual to be synced
        eds_perp.synced = false;

        // emit update event
        events::emit_perpetual_update_event(
            eds_id, 
            eds_perp.perpetual,
            sequence_number
        );
    }


    /// Allows the admin to change the address of an operator on external data store
    ///
    /// Parameters:
    /// - _: Reference to admin cap to ensure only the admin of exchange can invoke the method
    /// - eds: Mutable reference to external data store
    /// - type: Bytes representing a utf8 string. This will be be `funding`, `fee`, `guardian` etc..
    /// - new_operator: The address of the new operator
    entry fun set_operator(_ : &AdminCap, eds: &mut ExternalDataStore, type: vector<u8>, new_operator:address) {

        // Ensure version of the eds and package match
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        // The operator address can not be zero
        assert!(new_operator != @0, errors::can_not_be_zero_address());

        let operator_type = string::utf8(type);

        let supported_operators = constants::get_supported_operators();

        let store_id = object::uid_to_inner(&eds.id);

        // Revert if the operator type is invalid
        assert!(vector::contains(&supported_operators, &operator_type), errors::invalid_operator_type());

        let previous_operator = update_operator_entry(&mut eds.operators, operator_type, new_operator);

        // Revert if the new operator address is same as existing one.
        assert!(previous_operator != new_operator, errors::operator_already_set());

        // increment sequence number
        let sequence_number = eds_increment_sequence_number(eds);

        events::emit_eds_operator_update(
            store_id,  
            operator_type,
            previous_operator,
            new_operator,
            sequence_number
        );

    }


    
    /// Allows sequencer to synchronize perpetual data between internal and external store
    /// This method is invoked every time a change to a perpetual is made by the Admin in external store
    /// The changes are replicated to internal store using this method
    ///
    /// Parameters:
    /// - ids: Mutable reference to internal data store
    /// - eds: Reference to external data store
    /// - perpetual: Symbol of the perpetual that is to be synchronized
    /// - sequence_hash: The expected sequence hash to be computed on-chain after synchronization
    entry fun sync_perpetual(ids: &mut InternalDataStore, eds: &mut ExternalDataStore, perpetual:String, sequence_hash:vector<u8>){

        let ids_id  = object::uid_to_inner(&ids.id);

        // Ensure version of the internal and external stores match the package version
        assert!(ids.version == constants::get_version(), errors::version_mismatch());
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        // Ensure that the id of IDS is the one set in EDS
        assert!(object::uid_to_inner(&ids.id) == eds.internal_data_store, errors::invalid_internal_data_store());

        // Ensure that the perpetual to be synced exists
        assert!(table::contains(&eds.perpetuals, perpetual), errors::nothing_to_sync());

        let sequence_number = ids_increment_sequence_number(ids);

        // get perpetual from the eds
        let perp_eds = get_perpetual_from_eds(eds, perpetual);

        // if perpetual provided does not exist in internal data store.
        if(!table::contains(&ids.perpetuals, perpetual)){
            table::add(&mut ids.perpetuals, perpetual, perp_eds.perpetual);
        };

        // get perpetual from ids
        let perp_ids  = get_perpetual_from_ids(ids, perpetual);

        // if the perpetual is already synced revert
        assert!(!perp_eds.synced, errors::already_synced());

        // copy relevant data from perpetual of eds to ids and get its bcs bytes
        let bytes = perpetual::replicate_perp_data(perp_ids, &perp_eds.perpetual);

        let perpetual = *perp_ids;

        // set eds perpetual as synced
        perp_eds.synced = true;       

        // create account for fee pool and insurance pool if not exists. 
        // These account will receive trade fee and insurance portion of liquidation
        create_user_account(ids, perpetual::get_fee_pool_address(&perp_eds.perpetual));
        create_user_account(ids, perpetual::get_insurance_pool_address(&perp_eds.perpetual));
  
        // update data storage with new sequence hash
        // this will revert if the new sequence hash does not
        // matches the off-chain sequence hash
        compute_and_update_sequence_hash(ids, bytes, sequence_hash);


        events::emit_perpetual_synced_event(
            ids_id,
            perpetual,
            sequence_number
        )

    }
    
    /// Allows sequencer to synchronize the supported asset between external and internal stores
    ///
    /// Parameters:
    /// - ids: Mutable reference to internal data store
    /// - eds: Reference to external data store
    /// - asset: Name of the asset to be synchronized
    /// - sequence_hash: The expected sequence hash to be computed on-chain after synchronization
    entry fun sync_supported_asset(ids: &mut InternalDataStore, eds: &mut ExternalDataStore, asset_symbol: String, sequence_hash:vector<u8>){
                
        // Ensure version of the internal and external stores match the package version
        assert!(ids.version == constants::get_version(), errors::version_mismatch());
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        // Ensure that the id of IDS is the one set in EDS
        assert!(object::uid_to_inner(&ids.id) == eds.internal_data_store, errors::invalid_internal_data_store());

        // Ensure that the asset to be synced is supported
        assert!(bank::is_asset_supported(&eds.asset_bank, asset_symbol), errors::asset_not_supported());

        // ensure that the asset is not already synced in ids
        assert!(!bank::is_asset_synced(&eds.asset_bank, asset_symbol), errors::already_synced());

        let asset = bank::get_supported_asset(&eds.asset_bank, asset_symbol);

        // add the asset to internal store table
        // @dev this will throw if trying to re-add an existing asset        
        table::add(&mut ids.supported_assets, asset_symbol, asset);

        bank::set_asset_status_as_synced(&mut eds.asset_bank, asset_symbol);
        
        let sequence_number = ids_increment_sequence_number(ids);


        // update data storage with new sequence hash
        // this will revert if the new sequence hash does not
        // matches the off-chain sequence hash
        compute_and_update_sequence_hash(ids, bcs::to_bytes<Asset>(&asset), sequence_hash);

        events::emit_asset_synced_event(
            *object::uid_as_inner(&eds.id),
            *object::uid_as_inner(&ids.id),
            asset_symbol,
            sequence_number
        )

    }


    /// Allows sequencer to synchronize the address of provided operator type between external and internal stores
    ///
    /// Parameters:
    /// - ids: Mutable reference to internal data store
    /// - eds: Reference to external data store
    /// - type: The operator type to be synced.
    /// - sequence_hash: The expected sequence hash to be computed on-chain after synchronization    
    entry fun sync_operator(ids: &mut InternalDataStore, eds: &mut ExternalDataStore, type: vector<u8>, sequence_hash: vector<u8>){

        // Ensure version of the internal and external stores match the package version
        assert!(ids.version == constants::get_version(), errors::version_mismatch());
        assert!(eds.version == constants::get_version(), errors::version_mismatch());

        // Ensure that the id of IDS is the one set in EDS
        assert!(object::uid_to_inner(&ids.id) == eds.internal_data_store, errors::invalid_internal_data_store());

        let store_id = object::uid_to_inner(&ids.id);

        let operator_type = string::utf8(type);

        let supported_operators = constants::get_supported_operators();

        // Revert if the operator type is invalid
        assert!(vector::contains(&supported_operators, &operator_type), errors::invalid_operator_type());
        
        // Revert if there is no entry of provided operator type in eds
        assert!(table::contains(&eds.operators, operator_type), errors::nothing_to_sync());

        let new_operator = *table::borrow(&eds.operators, operator_type);

        let previous_operator = update_operator_entry(&mut ids.operators, operator_type, new_operator);

        // The address of new operator can not be same as existing one. 
        assert!(new_operator != previous_operator, errors::already_synced());

        // remove the operator from EDS as it has been synced with IDS
        table::remove(&mut eds.operators, operator_type);

        // update data storage with new sequence hash
        // this will revert if the new sequence hash does not
        // matches the off-chain sequence hash
        compute_and_update_sequence_hash(ids, bcs_handler::enc_operator_update(operator_type, previous_operator, new_operator), sequence_hash);

        let sequence_number = ids_increment_sequence_number(ids);

        events::emit_operator_synced_event(
            store_id,  
            operator_type,
            previous_operator,
            new_operator,
            sequence_number
        );

    }

    //===============================================================//
    //                         Friend Methods                        //
    //===============================================================//
    
    // Returns true if the provided perpetual exists in ids map
    public (friend) fun check_if_perp_exists_in_ids(ids: &InternalDataStore, perpetual: String): bool {
        table::contains(&ids.perpetuals, perpetual)
    }

    // Returns true if the provided perpetual exists in provided perpetuals table
    public (friend) fun check_if_perp_exists(table: &Table<String, Perpetual>, perpetual: String): bool {
        table::contains(table, perpetual)
    }

 
    /// Returns the accounts table from Internal data store
    public (friend) fun get_mutable_accounts_table_from_ids(ids: &mut InternalDataStore): &mut Table<address, Account>{
        &mut ids.accounts
    }

    /// Returns the id of Internal Data Store
    public (friend) fun get_ids_id(ids: &InternalDataStore): ID {
        object::uid_to_inner(&ids.id)
    }

    /// Returns the address of Internal Data Store
    public (friend) fun get_ids_address(ids: &InternalDataStore): address {
        object::uid_to_address(&ids.id)
    }

    /// Returns the version of Internal Data Store
    public (friend) fun get_ids_version(ids: &InternalDataStore): u64 {
        ids.version
    }

    /// Returns the id of External Data Store
    public (friend) fun get_eds_id(eds: &ExternalDataStore): ID {
        object::uid_to_inner(&eds.id)
    }

    /// Returns the address of External Data Store
    public (friend) fun get_eds_address(eds: &ExternalDataStore): address {
        object::uid_to_address(&eds.id)
    }

    /// Returns the version of External Data Store
    public (friend) fun get_eds_version(eds: &ExternalDataStore): u64 {
        eds.version
    }

    /// Returns the asset bank on EDS
    public (friend) fun get_asset_bank(eds: &mut ExternalDataStore): &mut AssetBank {
        &mut eds.asset_bank
    }
    /// Returns the id of the current internal data store stored in External Data Store
    public (friend) fun get_current_ids_id(eds: &ExternalDataStore): ID {
        eds.internal_data_store
    }


    /// Returns the account of provided address if exists, else will revert
    public (friend) fun get_mutable_account_from_accounts_table(accounts: &mut Table<address, Account>, account:address): &mut Account{
        // revert if the provided account does not exist in account map
        // implies that account has no position and no margin in bank
        assert!(table::contains(accounts, account), errors::account_does_not_exist());

        table::borrow_mut(accounts, account)
    }

    /// Returns the account of provided address if exists, else will revert
    public (friend) fun get_immutable_account_from_accounts_table(accounts: &Table<address, Account>, account:address): &Account{
        // revert if the provided account does not exist in account map
        // implies that account has no position and no margin in bank
        assert!(table::contains(accounts, account), errors::account_does_not_exist());

        table::borrow(accounts, account)
    }

    /// Returns the account of provided address if exists, else will revert
    public (friend) fun get_mutable_account_from_ids(ids: &mut InternalDataStore, account:address): &mut Account{
        get_mutable_account_from_accounts_table(&mut ids.accounts, account)
    }
    
    /// Returns the account of provided address if exists, else will revert
    public (friend) fun get_immutable_account_from_ids(ids: &InternalDataStore, account:address): &Account{
        get_immutable_account_from_accounts_table(&ids.accounts, account)
    }

    /// Creates a user account for provided address if one doesn't exist
    public (friend) fun create_user_account(ids: &mut InternalDataStore, account: address) {
        if(!table::contains(&ids.accounts, account)){
            table::add(&mut ids.accounts, account, account::initialize(account));
        }
    }

    /// Computes the new sequence hash of the protocol and updates in storage
    /// The sequence hash is computed by:
    /// 1) Appending the new tx bytes to existing sequence hash
    /// 2) Taking the sha 256 hash of appended vector
    ///
    /// Parameters:
    /// - ids: Mutable reference to internal data store
    /// - bytes: the bcs serialized bytes of the transaction
    /// - sequence_hash: the expected sequence hash
    public (friend) fun compute_and_update_sequence_hash(ids: &mut InternalDataStore, bytes: vector<u8>, sequence_hash: vector<u8>) {
 
        let count = vector::length(&bytes);
        // append bytes to the datastore sequence hash
        let i = 0;
        while (i < count){
            let elem = vector::borrow(&bytes, i);
            vector::push_back(&mut ids.sequence_hash, *elem);
            i = i+1;
        };

        // take its blake2b hash
        ids.sequence_hash = hash::blake2b256(&ids.sequence_hash);

        // revert if computed sequence hash does not match the expected sequence hash
        assert!(ids.sequence_hash == sequence_hash, errors::invalid_sequence_hash());

    }

    /// Returns the perpetual stored against provided address in External data store
    public (friend) fun get_perpetual_from_eds(eds: &mut ExternalDataStore, perpetual:String): &mut EDSPerpetual {
        assert!(table::contains(&eds.perpetuals, perpetual), errors::perpetual_does_not_exists());
        return table::borrow_mut(&mut eds.perpetuals, perpetual)
    }

    /// Returns the perpetual stored against provided address in External data store
    public (friend) fun get_perpetual_from_ids(ids: &mut InternalDataStore, perpetual:String): &mut Perpetual {
        assert!(table::contains(&ids.perpetuals, perpetual), errors::perpetual_does_not_exists());
        return table::borrow_mut(&mut ids.perpetuals, perpetual)
    }

    /// Returns the perpetual stored against provided address in IDS
    public (friend) fun get_immutable_perpetual_from_ids(ids: &InternalDataStore, perpetual:String): &Perpetual {
        assert!(table::contains(&ids.perpetuals, perpetual), errors::perpetual_does_not_exists());
        return table::borrow(&ids.perpetuals, perpetual)
    }

    /// Returns the perpetual stored against provided address in provided perpetuals table
    public (friend) fun get_immutable_perpetual_from_table(table: &Table<String, Perpetual>, perpetual:String): &Perpetual {
        assert!(table::contains(table, perpetual), errors::perpetual_does_not_exists());
        return table::borrow(table, perpetual)
    }

    /// Returns immutable reference to perpetuals table in IDS
    public (friend) fun get_immutable_perpetual_table_from_ids(ids: &InternalDataStore): & Table<String, Perpetual> {
        return &ids.perpetuals
    }

    /// Returns immutable reference to assets table in IDS
    public (friend) fun get_immutable_assets_table_from_ids(ids: &InternalDataStore): & Table<String, Asset> {
        return &ids.supported_assets
    }


    /// Returns the filled quantity of the provided order
    public (friend) fun filled_order_quantity(ids: &InternalDataStore, order_hash: vector<u8>): u64 {
        filled_order_quantity_from_table(&ids.filled_orders, order_hash)
    }


    /// Returns the filled quantity of the provided order from the provided filled orders table
    public (friend) fun filled_order_quantity_from_table(fills: &Table<vector<u8>, OrderFill>, order_hash: vector<u8>): u64 {
        if (table::contains(fills, order_hash)){
            let filled_order = table::borrow(fills, order_hash);
            filled_order.quantity
        } else {
            (0 as u64)
        }
    }


    /// Tries to store the given payload bytes in executed tx payload map if possible else reverts
    public (friend) fun validate_tx_replay(ids: &mut InternalDataStore, payload: vector<u8>, timestamp: u64): vector<u8>  {

        let hash = hash::blake2b256(&payload);

        // revert if the payload bytes already exist in map. Indicates a replay
        assert!(!table::contains(&ids.hashes, hash), errors::transaction_replay());

        // store payload bytes in map
        table::add(&mut ids.hashes, hash, timestamp);
        
        hash
    }


    /// Friend function to update the oracle prices of provided perpetuals
    ///
    /// Parameters:
    /// - ids: Mutable reference to internal data store
    /// - perpetuals: addresses of perpetuals
    /// - prices: new oracle price of provided perpetuals
    public (friend) fun update_oracle_prices(ids: &mut InternalDataStore, perpetuals: vector<String>, prices: vector<u64>){
 
        // Ensure version of the ids and package match
        assert!(ids.version == constants::get_version(), errors::version_mismatch());

        let i = 0; 
        let count = vector::length(&perpetuals);
        while(i < count) {

            let perp_symbol = *vector::borrow(& perpetuals, i);
            let perp_oracle_price = *vector::borrow(&prices, i );

            let perp = get_perpetual_from_ids(ids, perp_symbol);

            // Update oracle price
            perpetual::update_oracle_price(perp, perp_oracle_price);

            i = i + 1;
        };

        // emit event
        events::emit_oracle_price_update_event(perpetuals, prices, ids.sequence_number);

    }

    /// Updates the fill quantity of the provided order hash by the provided amount
    public (friend) fun update_order_fill(ids: &mut InternalDataStore, order_hash: vector<u8>, quantity: u64, timestamp: u64){        
        update_order_fill_internal(&mut ids.filled_orders, order_hash, quantity, timestamp);
    }

    /// Updates the fill quantity of the provided order hash by the provided amount
    public (friend) fun update_order_fill_internal(fills: &mut Table<vector<u8>, OrderFill>, order_hash: vector<u8>, quantity: u64, timestamp: u64){
        
        if(!table::contains(fills, order_hash)){
            table::add(fills, order_hash, OrderFill {quantity: 0, timestamp});
        };

        let filled_order = table::borrow_mut(fills, order_hash);
        filled_order.quantity = filled_order.quantity + quantity;

    }

    /// Increments the sequence index of External Data Store
    public (friend) fun eds_increment_sequence_number(eds: &mut ExternalDataStore): u128 {
        eds.sequence_number = eds.sequence_number + 1;
        eds.sequence_number
    }

    /// Increments the sequence index of Internal Data Store
    public (friend) fun ids_increment_sequence_number(ids: &mut InternalDataStore): u128 {
        ids.sequence_number = ids.sequence_number + 1;
        ids.sequence_number
    }

    /// Returns the address of operator. If the operator does not exists, will revert
    public (friend) fun get_operator_address(ids: &InternalDataStore, operator_type: vector<u8>): address {
        
        let key = string::utf8(operator_type);

        assert!(table::contains(&ids.operators, key), errors::invalid_operator_type());

        *table::borrow(&ids.operators, key)
    }


    /// Applies funding rate to all the accounts provided
    public (friend) fun apply_funding_rate(ids: &mut InternalDataStore, market_symbol: Option<String>, accounts: vector<address>, sequence_number: u128) {

        // Get list of all perpetuals
        let imm_perpetual_table = &ids.perpetuals;

        // iterate over each provided account and apply 
        // funding rate on all of their positions
        while(vector::length(&accounts) > 0){
            // get account address
            let acct_address = vector::pop_back(&mut accounts);
            // get account from ids
            assert!(table::contains(&ids.accounts, acct_address), errors::account_does_not_exist());
            let account =  table::borrow_mut(&mut ids.accounts, acct_address);
            // apply funding rate to the account and update all its positions
            let funding_applied = account::apply_funding_rate(account, imm_perpetual_table, market_symbol);

            // emit funding application events
            while(vector::length(&funding_applied) > 0) {
                let applied = vector::pop_back(&mut funding_applied);
                let (position, assets, funding_rate, funding_amount) = account::dec_funding_applied(&applied);
                events::emit_funding_rate_applied_event(
                    acct_address,
                    position,
                    assets,
                    funding_rate,
                    funding_amount,
                    sequence_number
                );
            }
        };
    }

    /// Allows the whitelisted pruner account to prune stored request hashes from chain
    public (friend) fun prune_table(ids: &mut InternalDataStore, hashes: vector<vector<u8>>, table_type: u8, timestamp: u64){

        let hash_lifespan = constants::lifespan();
        timestamp = timestamp - hash_lifespan;

        if(table_type == constants::history_table()){
            prune_history_table(ids, hashes, timestamp);
        } else if (table_type == constants::fills_table()){
            prune_order_fills_table(ids, hashes, timestamp);
        } else {
            abort errors::invalid_table_type()
        }
    }


    /// Allows the guardian to whitelist an account as a liquidator
    public (friend) fun authorize_liquidator(ids: &mut InternalDataStore, account: address, authorized: bool){

        // if authorized
        if(authorized){

            // add to authorized vector only if the user is not already authorized
            let (exists,_) = vector::index_of(&ids.liquidators, &account);
            if(exists == false){
                vector::push_back(&mut ids.liquidators, account);
            }

        } 
        // if un-authorized
        else {

            // remove user/user from authorized vector if exists
            let (exists, index) = vector::index_of(&ids.liquidators, &account);
            if(exists){
                vector::remove(&mut ids.liquidators, index);
            }
        };
    }
    
    // Returns true if the provided address is whitelisted as bankrupt liquidator
    public (friend) fun is_whitelisted_liquidator(ids: &InternalDataStore, account: address): bool {
        let (exists, _) = vector::index_of(&ids.liquidators, &account);
        exists
    }

    // Sets the provided gas fee on the IDS
    public (friend) fun set_gas_fee(ids: &mut InternalDataStore, amount: u64) {
        ids.gas_fee = amount;
    }

    // Sets the provided gas pool on the IDS
    public (friend) fun set_gas_pool(ids: &mut InternalDataStore, pool: address) {
        ids.gas_pool = pool;
        create_user_account(ids, pool)
    }


    public (friend) fun is_first_fill(ids: &InternalDataStore, order_hash: vector<u8>): bool{
        !table::contains(&ids.filled_orders, order_hash)
    }

    public (friend) fun is_first_fill_in_table(fills: &Table<vector<u8>, OrderFill>, order_hash: vector<u8>): bool{
        !table::contains(fills, order_hash)
    }

    public (friend) fun get_mutable_order_fills_table_from_ids(ids: &mut InternalDataStore): &mut Table<vector<u8>, OrderFill> {
        &mut ids.filled_orders
    }   


    public (friend) fun get_tables_from_ids(ids: &mut InternalDataStore): (
        &mut Table<vector<u8>, OrderFill>,  
        &mut Table<address, Account>, 
        &Table<String, Perpetual>,
        & Table<String, Asset>,
        address, address, u64) {
      (
        &mut ids.filled_orders, 
        &mut ids.accounts, 
        &ids.perpetuals, 
        &ids.supported_assets, 
        ids.gas_pool, 
        object::uid_to_address(&ids.id),
        ids.gas_fee)   
    }


    public fun get_gas_fee_amount(ids: &InternalDataStore): u64 {
        ids.gas_fee
    }

    public fun get_gas_pool(ids: &InternalDataStore): address {
        ids.gas_pool
    }

    public fun get_asset(ids: &InternalDataStore, asset_symbol: String): &Asset {
        assert!(table::contains(&ids.supported_assets, asset_symbol), errors::asset_not_supported());
        table::borrow(&ids.supported_assets, asset_symbol)
    }



    
    //===============================================================//
    //                        Private Methods                        //
    //===============================================================//

    /// Creates the internal data storage object
    ///
    /// Parameters:
    /// - sequencer: The address of the sequencer operator that will own the bank
    /// - sequence_number: The incremental sequence counter
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    fun internal_data_store_creator(sequencer: address, sequence_number: u128, ctx: &mut TxContext): ID {
        // the sequencer can not be zero address
        assert!(sequencer != @0, errors::can_not_be_zero_address());

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        // create the storage
        let ids = InternalDataStore {
            id:uid,
            version: constants::get_version(),
            // the starting sequence hash is 0000......0000
            sequence_hash: address::to_bytes(@0),
            accounts: table::new<address, Account>(ctx),
            perpetuals: table::new<String, Perpetual>(ctx),
            hashes: table::new<vector<u8>, u64>(ctx),
            filled_orders: table::new<vector<u8>, OrderFill>(ctx),
            supported_assets: table::new<String, Asset>(ctx),
            operators: table::new<String, address>(ctx),
            liquidators: vector::empty<address>(),
            gas_fee: 30000000,
            gas_pool: sequencer,
            sequence_number: 0
        };

        // create the account for sequencer to collect gas fees
        create_user_account(&mut ids, sequencer);

        // transfer the internal store to sequencer
        transfer::transfer(ids, sequencer);    

        // emit event
        events::emit_internal_exchange_created_event(id, sequencer, sequence_number);

        // return internal data store id
        return id
    }


    /// Creates the external data storage object
    ///
    /// Parameters:
    /// - internal_data_store: The id of the internal storage object
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    fun external_data_store_creator(internal_data_store: ID, ctx: &mut TxContext) {
       
        let asset_bank = bank::create_asset_bank(ctx);

        // create the external store
        let eds = ExternalDataStore {
            id:object::new(ctx),
            version: constants::get_version(),
            internal_data_store,
            perpetuals: table::new<String, EDSPerpetual>(ctx),
            operators: table::new<String, address>(ctx),
            asset_bank,
            sequence_number: 0,
        };

        // share the external store publicly
        transfer::share_object(eds);    
    }

    /// Helps update the address of provided operator type in the table
    /// Returns the address of previous operator that got updated
    fun update_operator_entry(operators: &mut Table<String, address>, operator_type: String, account: address): address{

        if(!table::contains(operators, operator_type)){
            table::add(operators, operator_type, @0);
        };

        let operator = table::borrow_mut(operators, operator_type);

        let previous_operator = *operator;

        *operator = account;

        previous_operator
    }


    fun prune_history_table(ids: &mut InternalDataStore, hashes: vector<vector<u8>>, timestamp: u64){

        let count = vector::length(&hashes);
        let i = 0;

        while(i < count){

            let hash = vector::pop_back(&mut hashes);

            // revert if the provided hash does not exists
            assert!(table::contains(&ids.hashes, hash), errors::trying_to_prune_non_existent_entry());

            let signed_at_time = *table::borrow(&ids.hashes, hash);

            // only remove a hash if it is older than current time - hash lifespan
            if (signed_at_time < timestamp){
                table::remove(&mut ids.hashes, hash);
            };
            i = i + 1;
        }

    }


    fun prune_order_fills_table(ids: &mut InternalDataStore, hashes: vector<vector<u8>>, timestamp: u64){

        let count = vector::length(&hashes);
        let i = 0;

        while(i < count){
            let hash = vector::pop_back(&mut hashes);

            // revert if the provided hash does not exists
            assert!(table::contains(&ids.filled_orders, hash), errors::trying_to_prune_non_existent_entry());

            let signed_at_time = table::borrow(&ids.filled_orders, hash).timestamp;

            // only remove a hash if it is older than current time - hash lifespan
            if (signed_at_time < timestamp){
                table::remove(&mut ids.filled_orders, hash);
            };
            i = i + 1;
        }
    }


    #[test_only]
    public fun test_init(ctx: &mut TxContext){
        init(ctx);
    }


    #[test_only]
    public fun set_eds_version(eds: &mut ExternalDataStore, version: u64){
        eds.version = version;
    }

    #[test_only]
    public fun set_ids_version(ids: &mut InternalDataStore, version: u64){
        ids.version = version;
    }

    #[test_only]
    public fun get_eds_perp_bytes(eds: &mut ExternalDataStore, perpetual: vector<u8>): vector<u8> {
        let eds_perp = get_perpetual_from_eds(eds, string::utf8(perpetual));
        bcs::to_bytes<Perpetual>(&eds_perp.perpetual)
    }

    #[test_only]
    public fun get_next_sequence_hash(ids: &InternalDataStore, bytes: vector<u8>): vector<u8> {
 
        let complete_data_bytes = vector::empty<u8>();
        let count = vector::length(&ids.sequence_hash);

        let i = 0;
        while (i < count){
            let elem = vector::borrow(&ids.sequence_hash, i);
            vector::push_back(&mut complete_data_bytes, *elem);
            i = i+1;
        };
        count = vector::length(&bytes);
        i = 0;
        while (i < count){
            let elem = vector::borrow(&bytes, i);
            vector::push_back(&mut complete_data_bytes, *elem);
            i = i+1;
        };

        // take its blake2b hash
        hash::blake2b256(&complete_data_bytes)
    }

    #[test_only]
    public fun set_ids_id_on_eds(eds: &mut ExternalDataStore, id: address){
        eds.internal_data_store = object::id_from_address(id);
    }

    #[test_only]
    public fun get_asset_bank_from_eds(eds: &mut ExternalDataStore): &mut AssetBank {
        &mut eds.asset_bank
    }

    #[test_only]
    public fun set_tx_replay_hash(ids: &mut InternalDataStore, payload: vector<u8>, timestamp: u64){
        let hash = hash::blake2b256(&payload);
        table::add(&mut ids.hashes, hash, timestamp);
    }

    #[test_only]
    public fun insert_tx_hash_in_ids(ids: &mut InternalDataStore, hash: vector<u8>, timestamp: u64){
        table::add(&mut ids.hashes, hash, timestamp);
    }

    #[test_only]
    public fun insert_order_fill_in_ids(ids: &mut InternalDataStore, hash: vector<u8>, quantity: u64, timestamp: u64){
        table::add(&mut ids.filled_orders, hash, OrderFill {quantity, timestamp});
    }
}


