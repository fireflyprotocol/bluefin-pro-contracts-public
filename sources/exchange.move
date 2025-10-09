/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::exchange {

use bluefin_cross_margin_dex::account::{Self, Position, Account, DepositedAsset};
use bluefin_cross_margin_dex::bank::{Self, Asset};
use bluefin_cross_margin_dex::bcs_handler;
use bluefin_cross_margin_dex::constants;
use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore, ExternalDataStore};
use bluefin_cross_margin_dex::errors;
use bluefin_cross_margin_dex::events;
use bluefin_cross_margin_dex::margining_engine;
use bluefin_cross_margin_dex::perpetual::{Self, Perpetual};
use bluefin_cross_margin_dex::signature;
use bluefin_cross_margin_dex::signed_number::{Self, Number};
use bluefin_cross_margin_dex::utils;
use std::option::{Self, Option};
use std::string::String;
use std::vector;
use sui::coin::{Self, Coin};
use sui::object;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

//===============================================================//
//                          Entry Methods                        //
//===============================================================//

/// Allows caller to deposit the provided coin amount into the provided external/margin bank
///
/// Parameters:
/// - eds: Mutable reference to External Data Store
/// - asset_symbol: The asset being deposited
/// - account: The address of the account to deposit to
/// - coin_base_amount: The amount/quantity of coins to deposit. Should be in decimals of the coin. For USDC it should have 6 decimals, for BLUE 9 etc
/// - coin: The coin to be deposited
/// - ctx: Mutable reference to `TxContext`, the transaction context.
#[allow(lint(public_entry))]
public entry fun deposit_to_asset_bank<T>(
    eds: &mut ExternalDataStore,
    asset_symbol: String,
    account: address,
    coin_base_amount: u64,
    coin: &mut Coin<T>,
    ctx: &mut TxContext,
) {
    // Ensure version of the internal and external stores match the package version
    assert!(
        data_store::get_eds_version(eds) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Deposits can not be made to zero address
    assert!(account != @0, errors::can_not_be_zero_address());

    // deposit amount can not be zero
    assert!(coin::value(coin) > 0, errors::can_not_be_zero());

    // increment the sequence number
    let sequence_number = data_store::eds_increment_sequence_number(eds);

    // perform deposit
    let (nonce, amount) = bank::deposit_to_asset_bank<T>(
        data_store::get_asset_bank(eds),
        asset_symbol,
        account,
        coin_base_amount,
        coin,
        ctx,
    );

    // emit deposit event
    events::emit_asset_bank_deposit_event(
        data_store::get_eds_id(eds),
        asset_symbol,
        tx_context::sender(ctx),
        account,
        amount,
        nonce,
        sequence_number,
    );
}

/// Allows the owner of the internal store (sequencer) to update account deposited amount in internal bank
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - eds: Mutable Reference to external data store
/// - nonce: The nonce of the deposit (Generated at the time funds were deposited to external/asset bank)
/// - sequence_hash: The expected sequence hash to be computed on-chain
entry fun deposit_to_internal_bank<T>(
    ids: &mut InternalDataStore,
    eds: &mut ExternalDataStore,
    nonce: u128,
    sequence_hash: vector<u8>,
) {
    // Ensure version of the internal and external stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );
    assert!(
        data_store::get_eds_version(eds) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the id of IDS is the one set in EDS
    assert!(
        data_store::get_ids_id(ids) == data_store::get_current_ids_id(eds),
        errors::invalid_internal_data_store(),
    );

    let ids_sequence_number = data_store::ids_increment_sequence_number(ids);
    let eds_sequence_number = data_store::eds_increment_sequence_number(eds);

    let bank = data_store::get_asset_bank(eds);

    // Delete the deposit entry from EDS
    let (from, to, amount, asset_symbol, coin) = bank::remove_deposit<T>(
        bank,
        nonce,
    );

    let deposited_amount = amount;

    // deposit the coin into balance of the EDS
    bank::merge_coin_into_balance<T>(bank, coin, asset_symbol);

    let eds_id = data_store::get_eds_id(eds);
    let ids_id = data_store::get_ids_id(ids);
    let eds_address = data_store::get_eds_address(eds);

    // return bcs serialized deposit payload
    let bytes = bcs_handler::enc_deposit(
        eds_address,
        asset_symbol,
        from,
        to,
        amount,
        nonce,
        false,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, bytes, sequence_hash);

    let accounts_table = data_store::get_mutable_accounts_table_from_ids(ids);

    // if the address to which amount was deposited in external/asset bank does not
    // have an account in internal data store
    if (!table::contains(accounts_table, to)) {
        table::add(accounts_table, to, account::initialize(to));
    };

    let account = table::borrow_mut(accounts_table, to);

    // iterate through each cross position and reduce the pending funding payment from the assets deposited
    let cross_positions = account::get_positions_vector(
        account,
        constants::empty_string(),
    );

    let i = 0; 
    let count = vector::length(&cross_positions);
    while(i < count && amount > 0) {
        let position = vector::borrow_mut(&mut cross_positions, i);
        
        let (
            _,
            size, 
            average_entry_price, 
            is_long,
            leverage, 
            margin, 
            _,
            pending_funding_payment, 
            ) = account::get_position_values(position);

        // subtract the pending funding payment from the amount deposited
        if(amount >= pending_funding_payment) {
            amount = amount - pending_funding_payment;
            pending_funding_payment = 0;

        } else {
            pending_funding_payment = pending_funding_payment - amount;
            amount = 0;
        };

        // update the position values in vector
        account::update_position_values(
            position, 
            size, 
            average_entry_price, 
            margin, 
            leverage, 
            is_long, 
            pending_funding_payment
        );

        i = i + 1;
    };

    // update account state with updated cross positions
    account::update_account_cross_positions(account, cross_positions);

    // increment account balance in internal bank by deposited amount - cross pending funding payments
    if(amount > 0) {
        account::add_margin(account, asset_symbol, amount);
    };

    // Emit account bank balance update
    events::emit_deposit_event(
        eds_id,
        ids_id,
        to,
        asset_symbol,
        deposited_amount,
        account::get_assets(account),
        sequence_hash,
        nonce,
        eds_sequence_number,
        ids_sequence_number,
    );
}

/// Allows sequencer to remove a tainted deposit made to our protocol. The tainted deposit
/// is sent back to the `from` of `sender` of the deposit
///
/// Parameters:
/// - ids: Mutable Reference to internal data store
/// - eds: Mutable Reference to external data store
/// - nonce: The nonce of the deposit (Generated at the time funds were deposited to external/asset bank)
/// - sequence_hash: The expected sequence hash to be computed on-chain
entry fun remove_tainted_asset<T>(
    ids: &mut InternalDataStore,
    eds: &mut ExternalDataStore,
    nonce: u128,
    sequence_hash: vector<u8>,
) {

    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    assert!(
        data_store::get_eds_version(eds) == constants::get_version(),
        errors::version_mismatch(),
    );

    let eds_id = data_store::get_eds_id(eds);
    let ids_id = data_store::get_ids_id(ids);

    let eds_sequence_number = data_store::eds_increment_sequence_number(eds);
    let ids_sequence_number = data_store::ids_increment_sequence_number(ids);

    let eds_address = data_store::get_eds_address(eds);
    let bank = data_store::get_asset_bank(eds);

    // Delete the deposit entry from EDS
    let (from, to, amount, asset_symbol, coin) = bank::remove_deposit<T>(
        bank,
        nonce,
    );

    // transferring the tainted coin to the sender/from
    transfer::public_transfer(
        coin,
        from,
    );

    // return bcs serialized deposit payload
    let bytes = bcs_handler::enc_deposit(
        eds_address,
        asset_symbol,
        from,
        to,
        amount,
        nonce,
        true,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, bytes, sequence_hash);

    events::emit_removed_tainted_deposit_event(
        eds_id,
        ids_id,
        from,
        to,
        asset_symbol,
        amount,
        nonce,
        sequence_hash,
        eds_sequence_number,
        ids_sequence_number,
    );
}

/// Allows sequencer to withdraw balance for the given account from margin bank into their address on-chain
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - eds: Reference to external data store
/// - payload: BCS serialized withdrawal payload
/// - signature: BCS serialized signature struct
/// - sequence_hash: The expected sequence hash to be computed on-chain after synchronization
/// - timestamp: The timestamp in milliseconds at which the withdraw was processed off-chain
/// - ctx: Mutable reference to `TxContext`, the transaction context.
entry fun withdraw_from_bank<T>(
    ids: &mut InternalDataStore,
    eds: &mut ExternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
    ctx: &mut TxContext,
) {
    // Ensure version of the internal and external stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );
    assert!(
        data_store::get_eds_version(eds) == constants::get_version(),
        errors::version_mismatch(),
);

    // Ensure that the id of IDS is the one set in EDS
    assert!(
        data_store::get_ids_id(ids) == data_store::get_current_ids_id(eds),
        errors::invalid_internal_data_store(),
    );

    // Ensure that the withdrawal payload is unique and never before executed and store it
    data_store::validate_tx_replay(ids, payload, timestamp);

    let eds_id = data_store::get_eds_id(eds);
    let ids_id = data_store::get_ids_id(ids);
    // increment the sequence number
    let ids_sequence_number = data_store::ids_increment_sequence_number(ids);
    let eds_sequence_number = data_store::eds_increment_sequence_number(eds);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let imm_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(ids);
    let imm_assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    let (
        target_eds,
        asset_symbol,
        account,
        amount,
        _,
        signed_at,
    ) = bcs_handler::dec_withdrawal(payload);

    // withdraw amount can not be zero
    assert!(amount > 0, errors::can_not_be_zero());

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // Ensure that the eds id provided in withdrawal request matches the eds provided
    assert!(object::id_from_address(target_eds) == eds_id, errors::invalid_eds());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, b"Bluefin Pro Withdrawal");

    // zk wallet signature are not verified and the signatory returned is zero address
    assert!(signatory == @0 || signatory == account, errors::invalid_permission());

    let immutable_account = data_store::get_immutable_account_from_ids(ids, account);
    let supported_assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    // the perpetual address zero means we need the cross assets
    // as deposits/withdrawal can only be made to cross assets
    let assets = account::get_assets_vector(immutable_account, constants::empty_string());

    // make a copy of assets to be passed as initial assets to verify health
    let initial_assets = assets;

    // get the cross positions as withdraw effects the mmr for cross
    let positions = account::get_positions_vector(
        immutable_account,
        constants::empty_string(),
    );

    // get the max withdrawable funds
    let max_withdrawable_amount = account::get_max_withdrawable_amount(
        &assets,
        &positions,
        imm_perpetual_table,
        supported_assets_table,
    );

    assert!(amount <= max_withdrawable_amount, errors::insufficient_funds());

    // reduce amount from assets, this will revert if amount > deposited assets
    account::sub_margin_from_asset_vector(
        &mut assets,
        amount,
        asset_symbol,
    );

    // verify account health
    margining_engine::verify_health(
        imm_perpetual_table,
        imm_assets_table,
        &assets,
        &positions,
        &initial_assets,
        &positions,
        0,
        constants::action_withdraw(),
        true, // is maker
    );

    // If we are here means all is good, we can update user assets and perform transfer of coins
    let mutable_account = data_store::get_mutable_account_from_ids(ids, account);
    account::update_account_cross_assets(mutable_account, assets);

    // transfers withdrawal amount to account
    bank::withdraw_from_asset_bank<T>(
        data_store::get_asset_bank(eds),
        asset_symbol,
        account,
        amount,
        ctx,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit event
    events::emit_withdraw_event(
        eds_id,
        ids_id,
        account,
        asset_symbol,
        amount,
        assets,
        sequence_hash,
        eds_sequence_number,
        ids_sequence_number,
    );
}

/// Allows sequencer to execute account authorization on behalf of the parent/wallet for one of its account
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: BCS serialized withdrawal payload
/// - signature: BCS serialized signature struct
/// - sequence_hash: The expected sequence hash to be computed on-chain after synchronization
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun authorize_account(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal store matches the pkg version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the withdrawal payload is unique and never before executed and store it
    data_store::validate_tx_replay(ids, payload, timestamp);

    let (
        target_ids,
        account,
        user,
        status,
        _,
        signed_at,
    ) = bcs_handler::dec_authorization(payload);

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // Create the user account if it does not exist
    // this function will do nothing if the account already exists
    data_store::create_user_account(ids, account);

    // validate that the signature is correct
    let signatory = signature::verify(
        payload,
        signature,
        b"Bluefin Pro Authorize Account",
    );

    // zk wallet signature are not verified and the signatory returned is zero address
    assert!(signatory == @0 || signatory == account, errors::invalid_permission());

    // fetch account state ( will revert if account does not exist)
    let account_state = data_store::get_mutable_account_from_ids(ids, account);

    let previous_authorized_accounts = account::get_authorized_accounts(account_state);

    // update authorization for the user
    account::set_authorized_user(account_state, user, status);

    let current_authorized_accounts = account::get_authorized_accounts(account_state);


    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    let sequence_number = data_store::ids_increment_sequence_number(ids);


    events::emit_authorized_accounts_updated_event(
        account,
        previous_authorized_accounts,
        current_authorized_accounts,
        sequence_number,
    );

}

/// Public batch trade method that takes as input a batch of maker/taker orders and executes them
/// Note: The method uses the gas fee set on-chain on IDS for all the trades in the batch
///
/// Pramaeters:
/// - ids: Mutable reference to internal data store
/// - makers_target_ids: vector of target ids for the makers
/// - makers_address: vector of maker addresses
/// - makers_perpetual: vector of perpetual symbols for the makers
/// - makers_price: vector of maker prices
/// - makers_quantity: vector of maker quantities
/// - makers_leverage: vector of maker leverages
/// - makers_is_long: vector of maker is long
/// - makers_is_isolated: vector of maker is isolated
/// - makers_expiry: vector of maker expiry
/// - makers_signed_at: vector of maker signed at
/// - makers_signature: vector of maker signatures
/// - makers_hash: vector of maker hashes
/// - takers_target_ids: vector of target ids for the takers
/// - takers_address: vector of taker addresses
/// - takers_perpetual: vector of perpetual symbols for the takers
/// - takers_price: vector of taker prices
/// - takers_quantity: vector of taker quantities
/// - takers_leverage: vector of taker leverages
/// - takers_is_long: vector of taker is long
/// - takers_is_isolated: vector of taker is isolated
/// - takers_expiry: vector of taker expiry
/// - takers_signed_at: vector of taker signed at
/// - takers_signature: vector of taker signatures
/// - takers_hash: vector of taker hashes
/// - fills: vector of fills
/// - perpetuals: vector of perpetual symbols
/// - oracle_prices: vector of oracle prices
/// - gas_fee: optional gas fee to be used for the entire batch
/// - batch_hash: vector of batch hash
/// - sequence_hash: vector of sequence hash
/// - timestamp: timestamp
entry fun batch_trade(
    ids: &mut InternalDataStore,
    makers_target_ids: vector<address>,
    makers_address: vector<address>,
    makers_perpetual: vector<String>,
    makers_price: vector<u64>,
    makers_quantity: vector<u64>,
    makers_leverage: vector<u64>,
    makers_is_long: vector<bool>,
    makers_is_isolated: vector<bool>,
    makers_expiry: vector<u64>,
    makers_signed_at: vector<u64>,
    makers_signature: vector<vector<u8>>,
    makers_hash: vector<vector<u8>>,
    takers_target_ids: vector<address>,
    takers_address: vector<address>,
    takers_perpetual: vector<String>,
    takers_price: vector<u64>,
    takers_quantity: vector<u64>,
    takers_leverage: vector<u64>,
    takers_is_long: vector<bool>,
    takers_is_isolated: vector<bool>,
    takers_expiry: vector<u64>,
    takers_signed_at: vector<u64>,
    takers_signature: vector<vector<u8>>,
    takers_hash: vector<vector<u8>>,
    fills: vector<u64>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    batch_hash: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    batch_trade_internal(
        ids,
        makers_target_ids,
        makers_address,
        makers_perpetual,
        makers_price,
        makers_quantity,
        makers_leverage,
        makers_is_long,
        makers_is_isolated,
        makers_expiry,
        makers_signed_at,
        makers_signature,
        makers_hash,
        takers_target_ids,
        takers_address,
        takers_perpetual,
        takers_price,
        takers_quantity,
        takers_leverage,
        takers_is_long,
        takers_is_isolated,
        takers_expiry,
        takers_signed_at,
        takers_signature,
        takers_hash,
        fills,
        perpetuals,
        oracle_prices,
        option::none<u64>(), // use the gas fee set on-chain on IDS for the entire batch
        batch_hash,
        sequence_hash,
        timestamp,
    )
}

/// Public batch trade method that takes as input a batch of maker/taker orders and executes them
/// Note: The method uses the provided gas fee for all the trades in the batch
///
/// Pramaeters:
/// - ids: Mutable reference to internal data store
/// - makers_target_ids: vector of target ids for the makers
/// - makers_address: vector of maker addresses
/// - makers_perpetual: vector of perpetual symbols for the makers
/// - makers_price: vector of maker prices
/// - makers_quantity: vector of maker quantities
/// - makers_leverage: vector of maker leverages
/// - makers_is_long: vector of maker is long
/// - makers_is_isolated: vector of maker is isolated
/// - makers_expiry: vector of maker expiry
/// - makers_signed_at: vector of maker signed at
/// - makers_signature: vector of maker signatures
/// - makers_hash: vector of maker hashes
/// - takers_target_ids: vector of target ids for the takers
/// - takers_address: vector of taker addresses
/// - takers_perpetual: vector of perpetual symbols for the takers
/// - takers_price: vector of taker prices
/// - takers_quantity: vector of taker quantities
/// - takers_leverage: vector of taker leverages
/// - takers_is_long: vector of taker is long
/// - takers_is_isolated: vector of taker is isolated
/// - takers_expiry: vector of taker expiry
/// - takers_signed_at: vector of taker signed at
/// - takers_signature: vector of taker signatures
/// - takers_hash: vector of taker hashes
/// - fills: vector of fills
/// - perpetuals: vector of perpetual symbols
/// - oracle_prices: vector of oracle prices
/// - gas_fee: optional gas fee to be used for the entire batch
/// - batch_hash: vector of batch hash
/// - sequence_hash: vector of sequence hash
/// - timestamp: timestamp
entry fun batch_trade_with_provided_gas_fee(
    ids: &mut InternalDataStore,
    makers_target_ids: vector<address>,
    makers_address: vector<address>,
    makers_perpetual: vector<String>,
    makers_price: vector<u64>,
    makers_quantity: vector<u64>,
    makers_leverage: vector<u64>,
    makers_is_long: vector<bool>,
    makers_is_isolated: vector<bool>,
    makers_expiry: vector<u64>,
    makers_signed_at: vector<u64>,
    makers_signature: vector<vector<u8>>,
    makers_hash: vector<vector<u8>>,
    takers_target_ids: vector<address>,
    takers_address: vector<address>,
    takers_perpetual: vector<String>,
    takers_price: vector<u64>,
    takers_quantity: vector<u64>,
    takers_leverage: vector<u64>,
    takers_is_long: vector<bool>,
    takers_is_isolated: vector<bool>,
    takers_expiry: vector<u64>,
    takers_signed_at: vector<u64>,
    takers_signature: vector<vector<u8>>,
    takers_hash: vector<vector<u8>>,
    fills: vector<u64>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    gas_fee: u64,
    batch_hash: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    batch_trade_internal(
        ids,
        makers_target_ids,
        makers_address,
        makers_perpetual,
        makers_price,
        makers_quantity,
        makers_leverage,
        makers_is_long,
        makers_is_isolated,
        makers_expiry,
        makers_signed_at,
        makers_signature,
        makers_hash,
        takers_target_ids,
        takers_address,
        takers_perpetual,
        takers_price,
        takers_quantity,
        takers_leverage,
        takers_is_long,
        takers_is_isolated,
        takers_expiry,
        takers_signed_at,
        takers_signature,
        takers_hash,
        fills,
        perpetuals,
        oracle_prices,
        option::some<u64>(gas_fee), // use the provided gas fee for the entire batch
        batch_hash,
        sequence_hash,
        timestamp,
    )
}

/// Allows sequencer to execute the trade of provided orders
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - maker_order: bcs serialized marker order
/// - taker_order: bcs serialized taker order
/// - maker_signature: bcs serialized marker order signature
/// - taker_signature: bcs serialized taker order signature
/// - quantity: the trade/fill quantity
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the trade
/// - timestamp: time in milliseconds - This is the timestamp at which trade was executed off-chain
entry fun trade(
    ids: &mut InternalDataStore,
    maker_order: vector<u8>,
    taker_order: vector<u8>,
    maker_signature: vector<u8>,
    taker_signature: vector<u8>,
    quantity: u64,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the trade is unique and is never executed before.
    // The maker and taker order signatures in combination of fill quantity and execution timestamp should always yield the unique hash
    let trade_bytes = bcs_handler::enc_trade(
        maker_order,
        taker_order,
        quantity,
        timestamp,
    );

    data_store::validate_tx_replay(ids, trade_bytes, timestamp);

    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    // deserialize the maker and taker orders
    let (
        maker_hash,
        maker_target_ids,
        maker_address,
        maker_perpetual,
        maker_price,
        maker_quantity,
        maker_leverage,
        maker_is_long,
        maker_is_isolated,
        maker_expiry,
        _,
        maker_signed_at,
    ) = bcs_handler::dec_order(maker_order);
    let (
        taker_hash,
        taker_target_ids,
        taker_address,
        taker_perpetual,
        taker_price,
        taker_quantity,
        taker_leverage,
        taker_is_long,
        taker_is_isolated,
        taker_expiry,
        _,
        taker_signed_at,
    ) = bcs_handler::dec_order(taker_order);

    let (
        order_fills_table,
        accounts_table,
        perpetuals_table,
        supported_assets_table,
        gas_pool_address,
        ids_address,
        gas_fee,
    ) = data_store::get_tables_from_ids(ids);

    // Revert if self trade
    assert!(maker_address != taker_address, errors::self_trade());

    // Revert if the target perps for both markets are not same
    assert!(maker_perpetual == taker_perpetual, errors::perpetuals_mismatch());

    // Revert if both orders are of the same side
    assert!(maker_is_long != taker_is_long, errors::orders_must_be_opposite());

    // Revert if the perpetual being traded on is not supported
    assert!(
        data_store::check_if_perp_exists(perpetuals_table, maker_perpetual),
        errors::perpetual_does_not_exists(),
    );

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        taker_target_ids == maker_target_ids 
            && taker_target_ids == ids_address,
        errors::invalid_internal_data_store(),
    );

    // get the perpetual details
    let perpetual = data_store::get_immutable_perpetual_from_table(
        perpetuals_table,
        maker_perpetual,
    );
    let max_notion_at_open = perpetual::max_allowed_oi_open(perpetual);
    let mark_price = perpetual::get_oracle_price(perpetual);
    let fee_pool_address = perpetual::get_fee_pool_address(perpetual);

    let immutable_maker_account = data_store::get_immutable_account_from_accounts_table(
        accounts_table,
        maker_address,
    );

    let immutable_taker_account = data_store::get_immutable_account_from_accounts_table(
        accounts_table,
        taker_address,
    );

    let maker_filled_order_quantity = data_store::filled_order_quantity_from_table(
        order_fills_table,
        maker_hash,
    );
    let taker_filled_order_quantity = data_store::filled_order_quantity_from_table(
        order_fills_table,
        taker_hash,
    );

    // perform pre-trade checks for maker
    pre_trade_checks(
        perpetuals_table,
        supported_assets_table,
        immutable_maker_account,
        perpetual,
        maker_is_isolated,
        maker_is_long,
        quantity,
    );

    // perform pre-trade checks for taker
    pre_trade_checks(
        perpetuals_table,
        supported_assets_table,
        immutable_taker_account,
        perpetual,
        taker_is_isolated,
        taker_is_long,
        quantity,
    );

    // validate the maker order
    validate_order(
        immutable_maker_account,
        maker_is_isolated,
        maker_is_long,
        false,
        maker_price,
        maker_quantity,
        maker_expiry,
        maker_signed_at,
        quantity,
        maker_price,
        maker_leverage,
        timestamp,
        option::some<vector<u8>>(maker_order),
        option::some<vector<u8>>(maker_signature),
        maker_filled_order_quantity,
        perpetual,
    );

    // validate the taker order
    validate_order(
        immutable_taker_account,
        taker_is_isolated,
        taker_is_long,
        true,
        taker_price,
        taker_quantity,
        taker_expiry,
        taker_signed_at,
        quantity,
        maker_price,
        taker_leverage,
        timestamp,
        option::some<vector<u8>>(taker_order),
        option::some<vector<u8>>(taker_signature),
        taker_filled_order_quantity,
        perpetual,
    );

    let is_first_fill = data_store::is_first_fill_in_table(order_fills_table, taker_hash);

    let (
        maker_fee,
        maker_fee_token_qty,
        maker_fee_token,
        maker_positions,
        maker_updated_position_index,
        maker_position,
        maker_assets,
        _,
        _,
    ) = margining_engine::apply_maths_internal(
        perpetuals_table,
        supported_assets_table,
        perpetual,
        immutable_maker_account,
        maker_price,
        quantity,
        maker_leverage,
        maker_is_long,
        maker_is_isolated,
        true,
        constants::action_trade(),
        option::none<Number>(),
        option::none<bool>(),
        gas_fee,
    );

    let (
        taker_fee,
        taker_fee_token_qty,
        taker_fee_token,
        taker_positions,
        taker_updated_position_index,
        taker_position,
        taker_assets,
        _,
        taker_gas_fee,
    ) = margining_engine::apply_maths_internal(
        perpetuals_table,
        supported_assets_table,
        perpetual,
        immutable_taker_account,
        maker_price,
        quantity,
        taker_leverage,
        taker_is_long,
        taker_is_isolated,
        false,
        constants::action_trade(),
        option::none<Number>(),
        option::some(is_first_fill),
        gas_fee,
    );

    // verify the max allowed oi open still holds for both maker and taker
    verify_notion(&maker_position, mark_price, max_notion_at_open, account::is_institution(immutable_maker_account));
    verify_notion(&taker_position, mark_price, max_notion_at_open, account::is_institution(immutable_maker_account));

    let mutable_maker_account = data_store::get_mutable_account_from_accounts_table(
        accounts_table,
        maker_address,
    );

    account::update_account(
        mutable_maker_account,
        &maker_assets,
        &maker_positions,
        maker_updated_position_index,
        maker_is_isolated,
    );

    let mutable_taker_account = data_store::get_mutable_account_from_accounts_table(
        accounts_table,
        taker_address,
    );

    account::update_account(
        mutable_taker_account,
        &taker_assets,
        &taker_positions,
        taker_updated_position_index,
        taker_is_isolated,
    );

    let mutable_fee_pool_account = data_store::get_mutable_account_from_accounts_table(
        accounts_table,
        fee_pool_address,
    );

    // if the maker fee is > 0 add maker fee token quantity to the fee pool account
    if (maker_fee > 0) {
        account::add_margin(
            mutable_fee_pool_account,
            maker_fee_token,
            maker_fee_token_qty,
        );
    };

    if (taker_fee > 0) {
        account::add_margin(
            mutable_fee_pool_account,
            taker_fee_token,
            taker_fee_token_qty,
        );
    };

    // update order fills
    data_store::update_order_fill_internal(
        order_fills_table,
        maker_hash,
        quantity,
        maker_signed_at,
    );
    data_store::update_order_fill_internal(
        order_fills_table,
        taker_hash,
        quantity,
        taker_signed_at,
    );

    // Transfer any accrued gas fee to gas pool
    let mutable_gas_pool_account = data_store::get_mutable_account_from_accounts_table(
        accounts_table,
        gas_pool_address,
    );

    if (taker_gas_fee > 0) {
        account::add_margin(
            mutable_gas_pool_account,
            constants::usdc_token_symbol(),
            taker_gas_fee,
        );
    };

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, trade_bytes, sequence_hash);

    // emit trade event
    events::emit_trade_executed_event(
        maker_perpetual,
        maker_address,
        taker_address,
        maker_hash,
        taker_hash,
        maker_position,
        taker_position,
        maker_assets,
        taker_assets,
        maker_fee,
        taker_fee,
        maker_fee_token_qty,
        taker_fee_token_qty,
        maker_fee_token,
        taker_fee_token,
        quantity,
        maker_price,
        taker_is_long,
        taker_gas_fee,
        sequence_hash,
        sequence_number,
    );
}

/// Allows sequencer to execute a liquidation request
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: The bcs serialized bytes of liquidation payload signed by the liquidator
/// - signature: The signature created by the liquidator
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the liquidation
/// - timestamp: time in milliseconds - This is the timestamp at which liquidation was executed off-chain
entry fun liquidate(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the liquidation is unique and is never executed before.
    let hash = data_store::validate_tx_replay(ids, payload, timestamp);

    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        payload_type,
        target_ids,
        liquidatee,
        liquidator,
        symbol,
        quantity,
        isolated,
        assume_as_cross,
        all_or_nothing,
        leverage,
        expiry,
        _,
        signed_at,
    ) = bcs_handler::dec_liquidation(payload);

    assert!(payload_type == constants::payload_type_liquidate(), errors::invalid_payload_type());

    // Revert if self trade
    assert!(liquidatee != liquidator, errors::self_trade());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that liquidation is signed with in last N months
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // revert if the liquidation request is expired
    assert!(expiry >= timestamp, errors::expired());

    // get liquidatee's account
    let immutable_liquidatee_account = data_store::get_immutable_account_from_ids(
        ids,
        liquidatee,
    );

    // get liquidator's account
    let immutable_liquidator_account = data_store::get_immutable_account_from_ids(
        ids,
        liquidator,
    );
    let liquidator_is_institution = account::is_institution(immutable_liquidator_account);

    assert_user_only_has_isolated_or_cross_position(
        immutable_liquidator_account,
        symbol,
        !assume_as_cross,
    );

    // get the position of the liquidatee getting liquidated
    let liquidatee_position = account::get_account_position(
        immutable_liquidatee_account,
        symbol,
        isolated,
    );

    // get all the positions of liquidatee
    let positions = account::get_positions_vector(
        immutable_liquidatee_account,
        if (isolated) { symbol } else { constants::empty_string() },
    );

    // get the liquidatee side and leverage
    let (
        _,
        liquidatee_size,
        _,
        liquidator_is_long, // liquidator is going this side
        liquidatee_leverage,
        _,
        _,
        _,
    ) = account::get_position_values(&liquidatee_position);

    let perpetual = data_store::get_immutable_perpetual_from_ids(ids, symbol);
    let insurance_pool_premium_ratio = perpetual::get_insurance_pool_ratio(perpetual);
    let is_isolated_only = perpetual::get_isolated_only(perpetual);
    let max_notion_at_open = perpetual::max_allowed_oi_open(perpetual);

    // trading should be permitted on the perp
    assert!(perpetual::get_trading_status(perpetual), errors::trading_not_permitted());

    // if all or nothing is false and the requested liquidation quantity is > liquidatee's position size
    if (!all_or_nothing && quantity > liquidatee_size) {
        quantity = liquidatee_size;
    };

    // revert if all or nothing condition is not holding up
    assert!(quantity <= liquidatee_size, errors::all_or_nothing());

    // revert if liquidation quantity does not conform to min trade size or step size
    assert!(
        quantity >= perpetual::get_min_trade_qty(perpetual) && 
            quantity % perpetual::get_step_size(perpetual) == 0,
        errors::invalid_quantity(),
    );

    // The market should support cross or the position must be assumed as isolated
    assert!(!is_isolated_only || !assume_as_cross, errors::isolated_only_market());

    // validate that the signer is itself the liquidator or an authorized account by liquidator
    let signatory = signature::verify(payload, signature, payload_type);

    assert!(
        account::has_permission(
            immutable_liquidator_account,
            signatory,
        ),
        errors::invalid_permission(),
    );

    // only a whitelisted account can perform liquidations
    assert!(
        data_store::is_whitelisted_liquidator(ids, liquidator),
        errors::unauthorized_liquidator(),
    );

    // Get list of all perpetuals
    let perpetual_table = data_store::get_immutable_perpetual_table_from_ids(ids);
    // Get list of all supported assets
    let assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    // Revert if the account is not liquidate-able
    assert!(
        account::is_liquidateable(
            immutable_liquidatee_account,
            symbol,
            isolated,
            perpetual_table,
            assets_table,
        ),
        errors::not_liquidateable(),
    );

    // pre-trade-checks on the taker/liquidator
    pre_trade_checks(
        perpetual_table,
        assets_table,
        immutable_liquidator_account,
        perpetual,
        !assume_as_cross,
        liquidator_is_long,
        quantity,
    );

    // Get the bankruptcy price and liquidator's purchase price for the position being liquidated
    let (
        bankruptcy_price,
        liq_purchase_price,
        mark_price,
        is_position_bankrupt,
        _,
    ) = account::get_position_bankruptcy_and_purchase_price(
        immutable_liquidatee_account,
        symbol,
        isolated,
        perpetual_table,
        assets_table,
    );

    // the position being liquidated must have the most positive PnL
    assert!(
        account::has_most_positive_pnl(&positions, perpetual_table, symbol),
        errors::invalid_position_for_liquidation(),
    );

    // Calculate the portion of liquidator vs insurance pool premium
    let (
        liquidators_premium_portion,
        insurance_pool_premium_portion,
    ) = margining_engine::calculate_liquidation_premium_portions(
        liquidator_is_long,
        liq_purchase_price,
        mark_price,
        quantity,
        is_position_bankrupt,
        insurance_pool_premium_ratio,
    );

    // if there is any liquidation premium, transfer the insurance pool portion
    if (insurance_pool_premium_portion > 0) {
        let insurance_pool_address = perpetual::get_insurance_pool_address(perpetual);

        let mutable_insurance_pool_account = data_store::get_mutable_account_from_ids(
            ids,
            insurance_pool_address,
        );

        account::add_margin(
            mutable_insurance_pool_account,
            constants::usdc_token_symbol(),
            insurance_pool_premium_portion,
        );
    };

    // apply margining maths to liquidatee
    let (
        _,
        _,
        _,
        liquidatee_position,
        liquidatee_assets,
        bad_debt,
        _,
    ) = margining_engine::apply_maths(
        ids,
        symbol,
        liquidatee,
        liq_purchase_price, // the liquidatee sells off their position at liquidator purchase price
        quantity,
        liquidatee_leverage,
        !liquidator_is_long,
        isolated,
        true,
        constants::action_liquidate(),
        option::none<Number>(),
        option::none<bool>(),
    );


    let premium_or_debt = signed_number::sub(signed_number::from(liquidators_premium_portion, true), signed_number::from(bad_debt, true));

    // apply margining maths to liquidator
    let (
        _,
        _,
        _,
        liquidator_position,
        liquidator_assets,
        _,
        _,
    ) = margining_engine::apply_maths(
        ids,
        symbol,
        liquidator,
        mark_price,
        quantity,
        leverage,
        liquidator_is_long,
        !assume_as_cross,
        false,
        constants::action_liquidate(),
        option::some<Number>(premium_or_debt),
        option::none<bool>(),
    );

    // verify liquidator's notional value
    verify_notion(&liquidator_position, mark_price, max_notion_at_open, liquidator_is_institution);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit liquidation event
    events::emit_liquidation_executed_event(
        symbol,
        hash,
        liquidatee,
        liquidator,
        liquidatee_position,
        liquidator_position,
        liquidatee_assets,
        liquidator_assets,
        quantity,
        liq_purchase_price,
        bankruptcy_price,
        mark_price,
        liquidator_is_long,
        premium_or_debt,
        insurance_pool_premium_portion,
        sequence_hash,
        sequence_number,
    );
}


/// Allows sequencer to execute the adjust margin call
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload that got signed by user
/// - signature: bcs serialized adjust margin payload signature
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the trade
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun adjust_margin(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        target_ids,
        account,
        symbol,
        add,
        amount,
        _,
        signed_at,
    ) = bcs_handler::dec_adjust_margin(payload);

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // get the perpetual for which margin is being adjusted
    let perpetual = data_store::get_immutable_perpetual_from_ids(ids, symbol);
    // ensure trading is permitted on the perpetual
    assert!(
        perpetual::get_trading_status(perpetual) && 
            !perpetual::get_delist_status(perpetual),
        errors::trading_not_permitted(),
    );

    // Get list of all perpetuals
    let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(
        ids,
    );
    // Get list of all supported assets
    let immutable_assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    // get user account
    let immutable_account = data_store::get_immutable_account_from_ids(ids, account);

    // validate that the signature is correct
    let signatory = signature::verify(
        payload,
        signature,
        b"Bluefin Pro Margin Adjustment",
    );
    // validate that signer has rights to perform the call
    assert!(
        signatory == @0 || account::has_permission(immutable_account, signatory),
        errors::invalid_permission(),
    );

    let account_isolated_positions = account::get_isolated_positions(immutable_account);
    let (is_open, _) = account::has_open_position(
        &account_isolated_positions,
        symbol,
    );
    // revert if the user does not have isolated position for provided perp
    assert!(is_open, errors::position_does_not_exist());

    // get current position for the perpetual
    let current_isolated_positions = account::get_positions_vector(
        immutable_account,
        symbol,
    );
    let initial_isolated_assets = account::get_assets_vector(
        immutable_account,
        symbol,
    );

    // get current cross positions and assets as well
    let current_cross_positions = account::get_positions_vector(
        immutable_account,
        constants::empty_string(),
    );
    let current_cross_assets = account::get_assets_vector(
        immutable_account,
        constants::empty_string(),
    );
    let initial_cross_assets = current_cross_assets;

    // make a copy of the current position vector
    let initial_isolated_positions = current_isolated_positions;

    let (current_position, position_index) = account::get_mutable_position_for_perpetual(
        &mut current_isolated_positions,
        symbol,
        true,
    );
    let (
        _,
        size,
        aep,
        side,
        leverage,
        margin,
        _,
        pending_funding_payment,
    ) = account::get_position_values(current_position);

    // start the new position margin as the current margin of the position
    let new_position_margin = margin;
    let position;

    if (add) {
        // if pending funding payment is greater than the amount to add,
        // the entire amount being added goes to cover up the pending funding payment
        if (pending_funding_payment > amount) {
            pending_funding_payment = pending_funding_payment - amount;
        } else {
            // if the amount to add is greater than the pending funding payment,
            // the new position margin is the current margin of the position + the amount to add - the pending funding payment
            new_position_margin = new_position_margin + amount - pending_funding_payment;
            // pending funding payment is now 0
            pending_funding_payment = 0;
        };

        // update the current position values
        account::update_position_values(
            current_position,
            size,
            aep,
            new_position_margin,
            leverage,
            side,
            pending_funding_payment,
        );

        // get position. This will be emitted in event
        position = *current_position;

        // remove the amount from the cross account
        account::sub_margin_from_asset_vector(
            &mut current_cross_assets,
            amount,
            constants::empty_string(),
        );

        // if margin is added to isolated position, verify the health of cross account
        // as money has been withdrawn from cross account to put into isolated account
        margining_engine::verify_health(
            immutable_perpetual_table,
            immutable_assets_table,
            &current_cross_assets,
            &current_cross_positions,
            &initial_cross_assets,
            &current_cross_positions, // no change has been made to the positions of the cross so current is initial
            0,
            constants::action_withdraw(),
            true, // is maker
        );
    } else {

        // margin required to keep the position open on on current user set leverage
        let margin_required = utils::mul_div_uint(size, aep, leverage);

        // Get perpetual table
        let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(
            ids,
        );

        // Get PnL of the position
        let pnl = account::compute_position_pnl(immutable_perpetual_table, current_position);

        // get the loss of the position
        let loss  = if(signed_number::gt_uint(pnl, 0)) { 0 } else { signed_number::value(pnl) };

        // start with the assumption that the user can remove all the margin
        let max_removeable_margin =  margin; 
        
        // reduce the max removeable margin by the amount required to keep the position open
        if(margin_required < max_removeable_margin) {
            max_removeable_margin = max_removeable_margin - margin_required;
        } else {
            max_removeable_margin = 0;
        };

        // reduce the max removeable margin by the loss of the position
        if(loss < max_removeable_margin) {
            max_removeable_margin = max_removeable_margin - loss;
        } else {
            max_removeable_margin = 0;
        };


        // revert if the amount to remove is greater than the max removeable margin
        assert!(amount <= max_removeable_margin, errors::insufficient_margin());


        // the new position margin is the current margin - the amount to remove
        new_position_margin = new_position_margin - amount;

        // update the current position values
        account::update_position_values(
            current_position,
            size,
            aep,
            new_position_margin,
            leverage,
            side,
            pending_funding_payment,
        );

        // get position. This will be emitted in event
        position = *current_position;

        // move the amount to the cross account
        account::add_margin_to_asset_vector(
            &mut current_cross_assets,
            amount,
            constants::empty_string(),
        );

        // Create updated isolated assets vector with the new position margin
        let current_isolated_assets = vector::empty<DepositedAsset>();
        vector::push_back(&mut current_isolated_assets, account::create_deposited_asset(constants::usdc_token_symbol(), new_position_margin));


        // if margin is removed from isolated position then verify health of isolated position
        margining_engine::verify_health(
            immutable_perpetual_table,
            immutable_assets_table,
            &current_isolated_assets,
            &current_isolated_positions,
            &initial_isolated_assets,
            &initial_isolated_positions,
            0,
            constants::action_remove_margin(),
            true, // is maker
        );
        
    };

    // Update the user account with new cross and isolated assets and positions
    let mutable_account = data_store::get_mutable_account_from_ids(ids, account);

    account::update_account(
        mutable_account,
        &current_cross_assets,
        &current_isolated_positions,
        position_index,
        true,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit event
    events::emit_margin_adjusted_event(
        account,
        amount,
        add,
        position,
        current_cross_assets,
        sequence_hash,
        sequence_number,
    );
}

/// Allows sequencer to execute the adjust leverage call
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload that got signed by user
/// - signature: bcs serialized adjust margin payload signature
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the trade
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun adjust_leverage(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        target_ids,
        account,
        symbol,
        leverage,
        _,
        signed_at,
    ) = bcs_handler::dec_adjust_leverage(payload);

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // Get list of all perpetuals
    let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(
        ids,
    );
    // Get list of all supported assets
    let immutable_assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    // get user account
    let immutable_account = data_store::get_immutable_account_from_ids(ids, account);

    // validate that the signature is correct
    let signatory = signature::verify(
        payload,
        signature,
        b"Bluefin Pro Leverage Adjustment",
    );
    // validate that signer has rights to perform the call
    assert!(
        signatory == @0 || account::has_permission(immutable_account, signatory),
        errors::invalid_permission(),
    );

    // get the perpetual for which margin is being adjusted
    let perpetual = data_store::get_immutable_perpetual_from_ids(ids, symbol);
    // ensure trading is permitted on the perpetual
    assert!(
        perpetual::get_trading_status(perpetual) && 
            !perpetual::get_delist_status(perpetual),
        errors::trading_not_permitted(),
    );

    // Revert if leverage is zero or
    // greater than max allowed leverage of the perpetual
    // or not a whole number
    assert!(
        leverage > 0 &&
            leverage <= utils::base_div(constants::base_uint(), perpetual::get_imr(perpetual)) &&
            leverage % constants::base_uint() == 0,
        errors::invalid_leverage(),
    );

    let account_isolated_positions = account::get_isolated_positions(immutable_account);
    let (is_open, _) = account::has_open_position(
        &account_isolated_positions,
        symbol,
    );
    // revert if the user does not have isolated position for provided perp
    assert!(is_open, errors::position_does_not_exist());

    // get current position for the perpetual
    let current_isolated_positions = account::get_positions_vector(
        immutable_account,
        symbol,
    );
    let current_isolated_assets = account::get_assets_vector(
        immutable_account,
        symbol,
    );

    // get current cross positions and assets as well
    let current_cross_positions = account::get_positions_vector(
        immutable_account,
        constants::empty_string(),
    );
    let current_cross_assets = account::get_assets_vector(
        immutable_account,
        constants::empty_string(),
    );
    let initial_cross_assets = current_cross_assets;

    // make a copy of the current position vector
    let initial_isolated_positions = current_isolated_positions;
    // make a copy of initial user assets vector
    let initial_isolated_assets = current_isolated_assets;

    // Get the position of the perpetual for which leverage is to be adjusted
    let (current_position, position_index) = account::get_mutable_position_for_perpetual(
        &mut current_isolated_positions,
        symbol,
        true,
    );
    let (
        _,
        size,
        average_entry_price,
        side,
        initial_leverage,
        margin_in_position,
        _,
        pending_funding_payment,
    ) = account::get_position_values(current_position);

    // Get the oracle price of the perpetual
    let oracle_price = perpetual::get_oracle_price(
        table::borrow(
            immutable_perpetual_table,
            symbol,
        ),
    );

    let max_notion_at_open = perpetual::max_allowed_oi_open(perpetual);

    //
    // Leverage adjustment calculations
    //
    // Oracle price is 200
    // User opens 2 quantity position at 4x leverage
    // Margin required = 2 * 200 / 4 = 100;
    // size: 2, aep: 200, margin: 100, leverage: 4,

    // Case 1: Oracle price changes to 300 and user wants to reduce leverage to 3
    // Margin required = 2 * 300 / 3 = 200; ( User already had 100 margin in position, they must add another 100 )
    // size: 2, aep: 300, margin: 200, leverage: 3

    // Case 2: Oracle price changes to 150 and user wants to reduce leverage to 3
    // Margin required = 2 * 150 / 3 = 100; (User don't need to deposit any margin to reduce the leverage )

    // Case 3: Oracle price changes to 300 and user wants to increase leverage to 8
    // Margin required = 2 * 300 / 8 = 75; (User already has 100 margin in position so 25 margin is returned to them)
    // size: 2, aep: 300, margin: 200, leverage: 3

    // Case 4: Oracle price changes to 150 and user wants to increase leverage to 8
    // Margin required = 2 * 150 / 8 = 37.5; (User already has 100 in margin so they will be given back 62.5 )

    // The initial margin required for the selected leverage
    // size * average entry price / leverage
    let initial_margin_required = utils::base_div(
        utils::base_mul(size, average_entry_price),
        leverage,
    );

    // update the current position values
    account::update_position_values(
        current_position,
        size,
        average_entry_price,
        // margin - amount will not over flow as this has been checked before
        initial_margin_required,
        leverage,
        side,
        0,
    );

    // only verify notion if leverage is increased
    if(leverage > initial_leverage) {
        verify_notion(current_position, oracle_price, max_notion_at_open, account::is_institution(immutable_account));
    };

    let margin_required = initial_margin_required + pending_funding_payment;

    // get position. This will be emitted in event
    let position = *current_position;

    // The margin required to keep the position open on this new leverage is >= margin in position
    // Move the margin from cross account into the position
    if (margin_required >= margin_in_position) {
        account::sub_margin_from_asset_vector(
            &mut current_cross_assets,
            margin_required - margin_in_position,
            constants::empty_string(),
        );
        account::add_margin_to_asset_vector(
            &mut current_isolated_assets,
            margin_required - margin_in_position,
            constants::empty_string(),
        );

        // verify health of the cross account is money is being withdrawn from it
        margining_engine::verify_health(
            immutable_perpetual_table,
            immutable_assets_table,
            &current_cross_assets,
            &current_cross_positions,
            &initial_cross_assets,
            &current_cross_positions, // no change has been made to the positions of the cross so current is initial
            0,
            constants::action_withdraw(),
            true, // is maker
        );
    } else {
        // The margin required for position after adjustment of leverage is < margin in position
        // Move the residual margin back to cross account
        account::sub_margin_from_asset_vector(
            &mut current_isolated_assets,
            margin_in_position - margin_required,
            constants::empty_string(),
        );
        account::add_margin_to_asset_vector(
            &mut current_cross_assets,
            margin_in_position - margin_required,
            constants::empty_string(),
        );
    };

    // verify health of the isolated account
    margining_engine::verify_health(
        immutable_perpetual_table,
        immutable_assets_table,
        &current_isolated_assets,
        &current_isolated_positions,
        &initial_isolated_assets,
        &initial_isolated_positions,
        0,
        constants::action_adjust_leverage(),
        true, // is maker
    );

    // Update the user account with new cross and isolated assets
    let mutable_account = data_store::get_mutable_account_from_ids(ids, account);

    account::update_account(
        mutable_account,
        &current_cross_assets,
        &current_isolated_positions,
        position_index,
        true,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit event
    events::emit_leverage_adjusted_event(
        account,
        position,
        current_cross_assets,
        sequence_hash,
        sequence_number,
    );
}

/// Allows sequencer to execute the set funding rate call to update funding rates for provided perpetuals
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload that got signed by user
/// - signature: bcs serialized set funding rate payload signature
/// - sequence_hash: The expected sequence hash to be computed after the trade
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun set_funding_rate(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // decode the payload bytes
    let (
        payload_type,
        target_ids,
        funding_time,
        market_funding_rates,
        _,
        signed_at,
    ) = bcs_handler::dec_set_funding_rate(
        payload,
    );

    assert!(payload_type == constants::payload_type_setting_funding_rate(), errors::invalid_payload_type());
    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let funding_operator = data_store::get_operator_address(ids, b"funding");

    // validate that signer has rights to perform the call
    assert!(signatory == funding_operator, errors::invalid_permission());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // revert if timestamp is not hourly
    assert!(funding_time % 3600000 == 0, errors::invalid_funding_time());

    let perpetuals = vector::empty<String>();
    let oracle_prices = vector::empty<u64>();

    // iterate over all market's funding rates and update perpetuals with new funding rate
    while (vector::length(&market_funding_rates) > 0) {
        let bcs_bytes = vector::pop_back(&mut market_funding_rates);
        let (market, value, sign, oracle_price) = bcs_handler::dec_market_details(
            bcs_bytes,
        );

        let perpetual = data_store::get_perpetual_from_ids(ids, market);

        // trading should be permitted on the perp
        assert!(
            perpetual::get_trading_status(perpetual) && 
                !perpetual::get_delist_status(perpetual),
            errors::trading_not_permitted(),
        );

        perpetual::update_funding_rate(perpetual, value, sign, funding_time);

        vector::push_back(&mut perpetuals, market);
        vector::push_back(&mut oracle_prices, oracle_price);

        events::emit_funding_rate_update_event(
            market,
            value,
            sign,
            funding_time,
            sequence_number,
        );
    };

    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);
}

/// Allows sequencer to apply funding rates on the accounts
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload containing account addresses and timestamp
/// - sequence_hash: The expected sequence hash to be computed after applying funding rate on the provided accounts
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun apply_funding_rate(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the payload is unique and is never executed before.
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (
        target_ids,
        _,
        accounts,
        _,
        signed_at,
        symbol,
    ) = bcs_handler::dec_apply_funding_rate(payload);

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // ensure that the payload is not expired
    assert!(signed_at >= timestamp - constants::lifespan(), errors::exceeds_lifespan());

    let market_symbol = if (symbol == constants::empty_string()) {
        option::none<String>()
    } else {
        option::some<String>(symbol)
    };

    data_store::apply_funding_rate(ids, market_symbol, accounts, sequence_number);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, payload, sequence_hash);
}

/// Allows sequencer to execute the pruning request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload of pruning request
/// - signature: bcs serialized signature generated by the pruning operator
/// - sequence_hash: The expected sequence hash to be computed after processing pruning request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun prune_table(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (
        payload_type,
        target_ids,
        hashes,
        type,
        _,
        signed_at,
    ) = bcs_handler::dec_prune_table(payload);

    assert!(payload_type == constants::payload_type_pruning_table(), errors::invalid_payload_type());


    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let pruning_operator = data_store::get_operator_address(ids, b"guardian");

    // validate that signer has rights to perform the call
    assert!(signatory == pruning_operator, errors::invalid_permission());

    // prune the table
    data_store::prune_table(
        ids,
        hashes,
        type,
        timestamp,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_table_pruned_event(
        type,
        sequence_number,
    );
}

/// Allows sequencer to execute the set liquidator request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload
/// - signature: the signature generated by the guardian
/// - sequence_hash: The expected sequence hash to be computed after processing the request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun authorize_liquidator(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (
        payload_type,
        target_ids,
        account,
        authorized,
        _,
        signed_at,
    ) = bcs_handler::dec_authorize_liquidator(payload);

    assert!(payload_type == constants::payload_type_authorizing_liquidator(), errors::invalid_payload_type());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let manager = data_store::get_operator_address(ids, b"guardian");

    // validate that signer has rights to perform the call
    assert!(signatory == manager, errors::invalid_permission());

    // prune the table
    data_store::authorize_liquidator(
        ids,
        account,
        authorized,
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_bankrupt_liquidator_authorized_event(
        account,
        authorized,
        sequence_number,
    );
}

/// Allows sequencer to execute the set fee tier request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload of set fee tier request
/// - signature: the signature generated by the fee operator
/// - sequence_hash: The expected sequence hash to be computed after processing the request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain

entry fun set_fee_tier(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (
        payload_type,
        target_ids,
        account,
        maker,
        taker,
        applied,
        _,
        signed_at,
    ) = bcs_handler::dec_set_fee_tier(payload);

    assert!(payload_type == constants::payload_type_setting_account_fee_tier(), errors::invalid_payload_type());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let manager = data_store::get_operator_address(ids, b"fee");

    // validate that signer has rights to perform the call
    assert!(signatory == manager, errors::invalid_permission());

    // get the account
    let target_account = data_store::get_mutable_account_from_ids(ids, account);

    account::set_fee_tier(target_account, maker, taker, applied);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_fee_tier_updated_event(
        account,
        maker,
        taker,
        applied,
        sequence_number,
    );
}

/// Allows sequencer to execute the set account type request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload of set fee tier request
/// - signature: the signature generated by the fee operator
/// - sequence_hash: The expected sequence hash to be computed after processing the request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun set_account_type(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (
        payload_type,
        target_ids,
        account,
        is_institution,
        _,
        signed_at,
    ) = bcs_handler::dec_set_account_type(payload);

    assert!(payload_type == constants::payload_type_setting_account_type(), errors::invalid_payload_type());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let manager = data_store::get_operator_address(ids, b"guardian");

    // validate that signer has rights to perform the call
    assert!(signatory == manager, errors::invalid_permission());

    // get the account
    let target_account = data_store::get_mutable_account_from_ids(ids, account);

    account::set_account_type(target_account, is_institution);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_account_type_updated_event(
        account,
        is_institution,
        sequence_number,
    );
}

/// Allows sequencer to execute the set gas fee request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload of set gas amount request
/// - signature: the signature generated by the guardian operator
/// - sequence_hash: The expected sequence hash to be computed after processing the request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun set_gas_fee(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (payload_type, target_ids, amount, _, signed_at) = bcs_handler::dec_set_gas_fee(
        payload,
    );

    assert!(payload_type == constants::payload_type_setting_gas_fee(), errors::invalid_payload_type());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let manager = data_store::get_operator_address(ids, b"guardian");

    // validate that signer has rights to perform the call
    assert!(signatory == manager, errors::invalid_permission());

    // set the gas fee
    data_store::set_gas_fee(ids, amount);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_gas_fee_updated_event(
        data_store::get_ids_id(ids),
        amount,
        sequence_number,
    );
}

/// Allows sequencer to execute the set gas pool request
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: bcs serialized payload of set gas pool request
/// - signature: the signature generated by the guardian operator
/// - sequence_hash: The expected sequence hash to be computed after processing the request
/// - timestamp: Time timestamp in milliseconds at which action was performed off-chain
entry fun set_gas_pool(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the signature is unique and is never executed before.
    // If the signature is unique, the payload is going to be unique
    data_store::validate_tx_replay(ids, payload, timestamp);

    // increment the sequence number
    let sequence_number = data_store::ids_increment_sequence_number(ids);

    let (payload_type, target_ids, pool, _, signed_at) = bcs_handler::dec_set_gas_pool(
        payload,
    );

    assert!(payload_type == constants::payload_type_setting_gas_pool(), errors::invalid_payload_type());

    assert!(pool != @0, errors::can_not_be_zero_address());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that request is not too old
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // validate that the signature is correct
    let signatory = signature::verify(payload, signature, payload_type);

    let manager = data_store::get_operator_address(ids, b"guardian");

    // validate that signer has rights to perform the call
    assert!(signatory == manager, errors::invalid_permission());

    let previous_pool = data_store::get_gas_pool(ids);

    // set the gas pool
    data_store::set_gas_pool(ids, pool);

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    events::emit_gas_pool_updated_event(
        data_store::get_ids_id(ids),
        previous_pool,
        pool,
        sequence_number,
    );
}

/// Allows sequencer to execute the deleverage request
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: The bcs serialized bytes of deleverage payload signed by the ADL operator
/// - signature: The signature of the ADL operator
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the adl
/// - timestamp: time in milliseconds - This is the timestamp at which adl was executed off-chain
entry fun deleverage(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the deleveraging request is unique and is never executed before.
    let hash = data_store::validate_tx_replay(ids, payload, timestamp);

    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        payload_type,
        target_ids,
        maker,
        taker,
        maker_is_isolated,
        taker_is_isolated,
        symbol,
        quantity,
        expiry,
        _,
        signed_at,
    ) = bcs_handler::dec_adl(payload);

    // Revert if self trade
    assert!(maker != taker, errors::self_trade());

    assert!(payload_type == constants::payload_type_adl(), errors::invalid_payload_type());

    // validate that the signer is itself the liquidator or an authorized account by liquidator
    let signatory = signature::verify(payload, signature, payload_type);

    let adl_operator = data_store::get_operator_address(ids, b"adl");

    assert!(adl_operator == signatory, errors::invalid_permission());

    let perpetual = data_store::get_immutable_perpetual_from_ids(ids, symbol);

    // trading should be permitted on the perp
    assert!(
        perpetual::get_trading_status(perpetual) && 
            !perpetual::get_delist_status(perpetual),
        errors::trading_not_permitted(),
    );

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that liquidation is signed with in last N months
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    // revert if the liquidation request is expired
    assert!(expiry >= timestamp, errors::expired());

    // revert if deleverage quantity does not conform to min/tax or step size
    assert!(
        quantity >= perpetual::get_min_trade_qty(perpetual) && 
            quantity <= perpetual::get_max_trade_qty(perpetual) && 
            quantity % perpetual::get_step_size(perpetual) == 0,
        errors::invalid_quantity(),
    );

    // Get list of all perpetuals
    let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(
        ids,
    );
    // Get list of all supported assets
    let immutable_assets_table = data_store::get_immutable_assets_table_from_ids(ids);

    // get maker account
    let immutable_maker_account = data_store::get_immutable_account_from_ids(
        ids,
        maker,
    );

    // get taker account
    let immutable_taker_account = data_store::get_immutable_account_from_ids(
        ids,
        taker,
    );

    // the maker should be bankrupt
    assert!(
        account::is_bankrupt(
            immutable_maker_account,
            symbol,
            maker_is_isolated,
            immutable_perpetual_table,
            immutable_assets_table,
        ),
        errors::not_bankrupt(),
    );

    let maker_position = account::get_position(
        immutable_maker_account,
        symbol,
        maker_is_isolated,
    );
    let taker_position = account::get_position(
        immutable_taker_account,
        symbol,
        taker_is_isolated,
    );

    let (
        _,
        maker_size,
        _,
        maker_is_long,
        maker_leverage,
        _,
        _,
        _,
    ) = account::get_position_values(&maker_position);
    let (
        _,
        taker_size,
        _,
        taker_is_long,
        taker_leverage,
        _,
        _,
        _,
    ) = account::get_position_values(&taker_position);

    // maker and taker must be of opposite side
    assert!(taker_is_long != maker_is_long, errors::orders_must_be_opposite());

    // the maker and taker position should have size >= the amount being deleveraged
    assert!(
        quantity <= maker_size && quantity <= taker_size,
        errors::insufficient_position_size(),
    );

    let pnl = account::compute_position_pnl(immutable_perpetual_table, &taker_position);

    assert!(signed_number::gt_uint(pnl, 0), errors::negative_pnl());

    // pre-trade-checks on the taker
    pre_trade_checks(
        immutable_perpetual_table,
        immutable_assets_table,
        immutable_taker_account,
        perpetual,
        taker_is_isolated,
        !taker_is_long,
        quantity,
    );

    // Get the bankruptcy price and liquidator's purchase price for the position being liquidated
    let (
        bankruptcy_price,
        _,
        mark_price,
        _,
        _,
    ) = account::get_position_bankruptcy_and_purchase_price(
        immutable_maker_account,
        symbol,
        maker_is_isolated,
        immutable_perpetual_table,
        immutable_assets_table,
    );

    // apply margining maths to maker

    let (
        _,
        _,
        _,
        updated_maker_position,
        maker_assets,
        _,
        _,
    ) = margining_engine::apply_maths(
        ids,
        symbol,
        maker,
        bankruptcy_price,
        quantity,
        maker_leverage,
        !maker_is_long,
        maker_is_isolated,
        true,
        constants::action_deleverage(),
        option::none<Number>(),
        option::none<bool>(),
    );

    let (
        _,
        _,
        _,
        updated_taker_position,
        taker_assets,
        _,
        _,
    ) = margining_engine::apply_maths(
        ids,
        symbol,
        taker,
        bankruptcy_price,
        quantity,
        taker_leverage,
        !taker_is_long,
        taker_is_isolated,
        false,
        constants::action_deleverage(),
        option::none<Number>(),
        option::none<bool>(),
    );

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit adl event
    events::emit_adl_executed_event(
        symbol,
        hash,
        maker,
        taker,
        updated_maker_position,
        updated_taker_position,
        maker_assets,
        taker_assets,
        quantity,
        bankruptcy_price,
        mark_price,
        !taker_is_long,
        sequence_hash,
        sequence_number,
    );
}

/// Allows sequencer to execute the close position request for markets that have been delisted
///
/// Parameters:
/// - ids: Mutable reference to internal data store
/// - payload: The bcs serialized bytes of close position payload
/// - signature: The signature of the account or one of its authorized account
/// - perpetuals: vector of perpetual symbols for which oracle prices are to be updated
/// - oracle_prices: vector of new oracle prices for provided perpetuals
/// - sequence_hash: The expected sequence hash to be computed after the adl
/// - timestamp: time in milliseconds - This is the timestamp at which adl was executed off-chain
entry fun close_position(
    ids: &mut InternalDataStore,
    payload: vector<u8>,
    signature: vector<u8>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    // Ensure that the deleveraging request is unique and is never executed before.
    let hash = data_store::validate_tx_replay(ids, payload, timestamp);

    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        target_ids,
        account,
        symbol,
        isolated,
        _,
        signed_at,
    ) = bcs_handler::dec_close_position(payload);

    // get user account
    let immutable_account = data_store::get_immutable_account_from_ids(ids, account);

    // validate that the signer is itself the liquidator or an authorized account by liquidator
    let signatory = signature::verify(
        payload,
        signature,
        b"Bluefin Pro Close Position For Delisted Market",
    );

    assert!(
        signatory == @0 || account::has_permission(immutable_account, signatory),
        errors::invalid_permission(),
    );

    let perpetual = data_store::get_immutable_perpetual_from_ids(ids, symbol);

    // perpetual must be delisted
    assert!(perpetual::get_delist_status(perpetual), errors::not_delisted());

    // trading must not be paused
    assert!(perpetual::get_trading_status(perpetual), errors::trading_not_permitted());

    // Ensure that the payload is authorized to be executed on the provided ids
    assert!(
        target_ids == data_store::get_ids_address(ids),
        errors::invalid_internal_data_store(),
    );

    // Ensure that liquidation is signed with in last N months
    assert!(signed_at >= (timestamp - constants::lifespan()), errors::exceeds_lifespan());

    let position = account::get_position(immutable_account, symbol, isolated);

    let (_, size, _, is_long, leverage, _, _, _) = account::get_position_values(
        &position,
    );

    let delisting_price = perpetual::get_oracle_price(perpetual);

    let (_, _, _, updated_position, updated_assets, bad_debt, _) = margining_engine::apply_maths(
        ids,
        symbol,
        account,
        delisting_price,
        size,
        leverage,
        !is_long,
        isolated,
        true,
        constants::action_close_position(),
        option::none<Number>(),
        option::none<bool>(),
    );

    assert!(bad_debt == 0, errors::bad_debt());

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, signature, sequence_hash);

    // emit position close event
    events::emit_delisted_market_position_closed_event(
        symbol,
        hash,
        account,
        updated_position,
        updated_assets,
        delisting_price,
        sequence_hash,
        sequence_number,
    );
}

//===============================================================//
//                          Helper Methods                       //
//===============================================================//

/// Internal batch trade function that takes as input a batch of maker/taker orders and executes them
/// Pramaeters:
/// - ids: Mutable reference to internal data store
/// - makers_target_ids: vector of target ids for the makers
/// - makers_address: vector of maker addresses
/// - makers_perpetual: vector of perpetual symbols for the makers
/// - makers_price: vector of maker prices
/// - makers_quantity: vector of maker quantities
/// - makers_leverage: vector of maker leverages
/// - makers_is_long: vector of maker is long
/// - makers_is_isolated: vector of maker is isolated
/// - makers_expiry: vector of maker expiry
/// - makers_signed_at: vector of maker signed at
/// - makers_signature: vector of maker signatures
/// - makers_hash: vector of maker hashes
/// - takers_target_ids: vector of target ids for the takers
/// - takers_address: vector of taker addresses
/// - takers_perpetual: vector of perpetual symbols for the takers
/// - takers_price: vector of taker prices
/// - takers_quantity: vector of taker quantities
/// - takers_leverage: vector of taker leverages
/// - takers_is_long: vector of taker is long
/// - takers_is_isolated: vector of taker is isolated
/// - takers_expiry: vector of taker expiry
/// - takers_signed_at: vector of taker signed at
/// - takers_signature: vector of taker signatures
/// - takers_hash: vector of taker hashes
/// - fills: vector of fills
/// - perpetuals: vector of perpetual symbols
/// - oracle_prices: vector of oracle prices
/// - gas_fee: optional gas fee to be used for the entire batch
/// - batch_hash: vector of batch hash
/// - sequence_hash: vector of sequence hash
/// - timestamp: timestamp
fun batch_trade_internal(
    ids: &mut InternalDataStore,
    makers_target_ids: vector<address>,
    makers_address: vector<address>,
    makers_perpetual: vector<String>,
    makers_price: vector<u64>,
    makers_quantity: vector<u64>,
    makers_leverage: vector<u64>,
    makers_is_long: vector<bool>,
    makers_is_isolated: vector<bool>,
    makers_expiry: vector<u64>,
    makers_signed_at: vector<u64>,
    makers_signature: vector<vector<u8>>,
    makers_hash: vector<vector<u8>>,
    takers_target_ids: vector<address>,
    takers_address: vector<address>,
    takers_perpetual: vector<String>,
    takers_price: vector<u64>,
    takers_quantity: vector<u64>,
    takers_leverage: vector<u64>,
    takers_is_long: vector<bool>,
    takers_is_isolated: vector<bool>,
    takers_expiry: vector<u64>,
    takers_signed_at: vector<u64>,
    takers_signature: vector<vector<u8>>,
    takers_hash: vector<vector<u8>>,
    fills: vector<u64>,
    perpetuals: vector<String>,
    oracle_prices: vector<u64>,
    gas_fee: Option<u64>,
    batch_hash: vector<u8>,
    sequence_hash: vector<u8>,
    timestamp: u64,
) {
    // Ensure version of the internal stores match the package version
    assert!(
        data_store::get_ids_version(ids) == constants::get_version(),
        errors::version_mismatch(),
    );

    data_store::validate_tx_replay(ids, batch_hash, timestamp);

    let sequence_number = data_store::ids_increment_sequence_number(ids);

    // Update oracle prices of all the perpetuals involved in the trade
    data_store::update_oracle_prices(ids, perpetuals, oracle_prices);

    let (
        order_fills_table,
        accounts_table,
        perpetuals_table,
        supported_assets_table,
        gas_pool_address,
        ids_address,
        default_gas_fee,
    ) = data_store::get_tables_from_ids(ids);

    let gas_fee = option::get_with_default(&gas_fee, default_gas_fee);

    let accrued_gas_fee = 0;

    // iterate over each pair of orders
    let total_trades = vector::length(&makers_target_ids);
    let i = 0;
    while (i < total_trades) {
        let maker_hash = *vector::borrow(&makers_hash, i);
        let _ = *vector::borrow(&makers_signature, i);
        let maker_target_ids = *vector::borrow(&makers_target_ids, i);
        let maker_address = *vector::borrow(&makers_address, i);
        let maker_perpetual = *vector::borrow(&makers_perpetual, i);
        let maker_price = *vector::borrow(&makers_price, i);
        let maker_quantity = *vector::borrow(&makers_quantity, i);
        let maker_leverage = *vector::borrow(&makers_leverage, i);
        let maker_is_long = *vector::borrow(&makers_is_long, i);
        let maker_is_isolated = *vector::borrow(&makers_is_isolated, i);
        let maker_expiry = *vector::borrow(&makers_expiry, i);
        let maker_signed_at = *vector::borrow(&makers_signed_at, i);

        let taker_hash = *vector::borrow(&takers_hash, i);
        let _ = *vector::borrow(&takers_signature, i);
        let taker_target_ids = *vector::borrow(&takers_target_ids, i);
        let taker_address = *vector::borrow(&takers_address, i);
        let taker_perpetual = *vector::borrow(&takers_perpetual, i);
        let taker_price = *vector::borrow(&takers_price, i);
        let taker_quantity = *vector::borrow(&takers_quantity, i);
        let taker_leverage = *vector::borrow(&takers_leverage, i);
        let taker_is_long = *vector::borrow(&takers_is_long, i);
        let taker_is_isolated = *vector::borrow(&takers_is_isolated, i);
        let taker_expiry = *vector::borrow(&takers_expiry, i);
        let taker_signed_at = *vector::borrow(&takers_signed_at, i);

        let quantity = *vector::borrow(&fills, i);

        // Revert if self trade
        assert!(maker_address != taker_address, errors::self_trade());

        // Revert if the target perps for both markets are not same
        assert!(maker_perpetual == taker_perpetual, errors::perpetuals_mismatch());

        // Revert if both orders are of the same side
        assert!(maker_is_long != taker_is_long, errors::orders_must_be_opposite());

        // Revert if the perpetual being traded on is not supported
        assert!(
            data_store::check_if_perp_exists(perpetuals_table, maker_perpetual),
            errors::perpetual_does_not_exists(),
        );

        // Ensure that the payload is authorized to be executed on the provided ids
        assert!(
            taker_target_ids == maker_target_ids 
                && taker_target_ids == ids_address,
            errors::invalid_internal_data_store(),
        );

        // get the perpetual details
        let perpetual = data_store::get_immutable_perpetual_from_table(
            perpetuals_table,
            maker_perpetual,
        );
        let max_notion_at_open = perpetual::max_allowed_oi_open(perpetual);
        let mark_price = perpetual::get_oracle_price(perpetual);
        let fee_pool_address = perpetual::get_fee_pool_address(perpetual);

        let immutable_maker_account = data_store::get_immutable_account_from_accounts_table(
            accounts_table,
            maker_address,
        );

        let immutable_taker_account = data_store::get_immutable_account_from_accounts_table(
            accounts_table,
            taker_address,
        );

        let maker_filled_order_quantity = data_store::filled_order_quantity_from_table(
            order_fills_table,
            maker_hash,
        );
        let taker_filled_order_quantity = data_store::filled_order_quantity_from_table(
            order_fills_table,
            taker_hash,
        );

        // perform pre-trade checks for maker
        pre_trade_checks(
            perpetuals_table,
            supported_assets_table,
            immutable_maker_account,
            perpetual,
            maker_is_isolated,
            maker_is_long,
            quantity,
        );

        // perform pre-trade checks for taker
        pre_trade_checks(
            perpetuals_table,
            supported_assets_table,
            immutable_taker_account,
            perpetual,
            taker_is_isolated,
            taker_is_long,
            quantity,
        );

        // validate the maker order
        validate_order(
            immutable_maker_account,
            maker_is_isolated,
            maker_is_long,
            false,
            maker_price,
            maker_quantity,
            maker_expiry,
            maker_signed_at,
            quantity,
            maker_price,
            maker_leverage,
            timestamp,
            option::none<vector<u8>>(),
            option::none<vector<u8>>(),
            maker_filled_order_quantity,
            perpetual,
        );

        // validate the taker order
        validate_order(
            immutable_taker_account,
            taker_is_isolated,
            taker_is_long,
            true,
            taker_price,
            taker_quantity,
            taker_expiry,
            taker_signed_at,
            quantity,
            maker_price,
            taker_leverage,
            timestamp,
            option::none<vector<u8>>(),
            option::none<vector<u8>>(),
            taker_filled_order_quantity,
            perpetual,
        );

        let is_first_fill = data_store::is_first_fill_in_table(
            order_fills_table,
            taker_hash,
        );

        let (
            maker_fee,
            maker_fee_token_qty,
            maker_fee_token,
            maker_positions,
            maker_updated_position_index,
            maker_position,
            maker_assets,
            _,
            _,
        ) = margining_engine::apply_maths_internal(
            perpetuals_table,
            supported_assets_table,
            perpetual,
            immutable_maker_account,
            maker_price,
            quantity,
            maker_leverage,
            maker_is_long,
            maker_is_isolated,
            true,
            constants::action_trade(),
            option::none<Number>(),
            option::none<bool>(),
            gas_fee,
        );

        let (
            taker_fee,
            taker_fee_token_qty,
            taker_fee_token,
            taker_positions,
            taker_updated_position_index,
            taker_position,
            taker_assets,
            _,
            taker_gas_fee,
        ) = margining_engine::apply_maths_internal(
            perpetuals_table,
            supported_assets_table,
            perpetual,
            immutable_taker_account,
            maker_price,
            quantity,
            taker_leverage,
            taker_is_long,
            taker_is_isolated,
            false,
            constants::action_trade(),
            option::none<Number>(),
            option::some(is_first_fill),
            gas_fee,
        );

        // verify the max allowed oi open still holds for both maker and taker
        verify_notion(&maker_position, mark_price, max_notion_at_open, account::is_institution(immutable_maker_account));
        verify_notion(&taker_position, mark_price, max_notion_at_open, account::is_institution(immutable_taker_account));

        let mutable_maker_account = data_store::get_mutable_account_from_accounts_table(
            accounts_table,
            maker_address,
        );

        account::update_account(
            mutable_maker_account,
            &maker_assets,
            &maker_positions,
            maker_updated_position_index,
            maker_is_isolated,
        );

        let mutable_taker_account = data_store::get_mutable_account_from_accounts_table(
            accounts_table,
            taker_address,
        );

        account::update_account(
            mutable_taker_account,
            &taker_assets,
            &taker_positions,
            taker_updated_position_index,
            taker_is_isolated,
        );

        let mutable_fee_pool_account = data_store::get_mutable_account_from_accounts_table(
            accounts_table,
            fee_pool_address,
        );

        // if the maker fee is > 0 add maker fee token quantity to the fee pool account
        if (maker_fee > 0) {
            account::add_margin(
                mutable_fee_pool_account,
                maker_fee_token,
                maker_fee_token_qty,
            );
        };

        if (taker_fee > 0) {
            account::add_margin(
                mutable_fee_pool_account,
                taker_fee_token,
                taker_fee_token_qty,
            );
        };

        accrued_gas_fee = accrued_gas_fee + taker_gas_fee;

        // update order fills
        data_store::update_order_fill_internal(
            order_fills_table,
            maker_hash,
            quantity,
            maker_signed_at,
        );
        data_store::update_order_fill_internal(
            order_fills_table,
            taker_hash,
            quantity,
            taker_signed_at,
        );

        // emit trade event
        events::emit_trade_executed_event(
            maker_perpetual,
            maker_address,
            taker_address,
            maker_hash,
            taker_hash,
            maker_position,
            taker_position,
            maker_assets,
            taker_assets,
            maker_fee,
            taker_fee,
            maker_fee_token_qty,
            taker_fee_token_qty,
            maker_fee_token,
            taker_fee_token,
            quantity,
            maker_price,
            taker_is_long,
            taker_gas_fee,
            sequence_hash,
            sequence_number,
        );

        i = i+1;
    };

    // Transfer any accrued gas fee to gas pool
    let mutable_gas_pool_account = data_store::get_mutable_account_from_accounts_table(
        accounts_table,
        gas_pool_address,
    );

    if (accrued_gas_fee > 0) {
        account::add_margin(
            mutable_gas_pool_account,
            constants::usdc_token_symbol(),
            accrued_gas_fee,
        );
    };

    // update data storage with new sequence hash
    // this will revert if the new sequence hash does not
    // matches the off-chain sequence hash
    data_store::compute_and_update_sequence_hash(ids, batch_hash, sequence_hash);
}

/// Used to validate the correctness of the order
/// Performs the following checks:
/// 0) The order has not exceeded its lifespan
/// 1) Trading is permitted on the perpetual/market of the order
/// 2) Perpetual is not delisted
/// 3) The fill quantity conforms to perpetual step size and is within acceptable trade quantity range
/// 4) The fill price conforms to perpetual tick size and is within acceptable trade price range
/// 5) The fill price does not breach the market take bounds
/// 6) The order was not expired off-chain at the time of execution
/// 7) Order signature is valid and the signer has permission to trade on account's behalf
/// 8) The fill price is valid for the order
/// 9) The order is not being overfilled
/// 10) The order type (cross) is supported by the market
/// 11) The order must have valid leverage
fun validate_order(
    account_state: &Account,
    is_isolated: bool,
    is_long: bool,
    is_taker: bool,
    order_price: u64,
    order_quantity: u64,
    expiry: u64,
    signed_at: u64,
    fill_quantity: u64,
    fill_price: u64,
    leverage: u64,
    timestamp: u64,
    serialized_order: Option<vector<u8>>,
    serialized_signature: Option<vector<u8>>,
    filled_order_quantity: u64,
    perpetual: &Perpetual,
) {
    assert!(signed_at >= timestamp - constants::lifespan(), errors::exceeds_lifespan());

    assert_user_only_has_isolated_or_cross_position(
        account_state,
        perpetual::get_symbol(perpetual),
        is_isolated,
    );

    // Decompress the perpetual
    let (
        _,
        _,
        _,
        _,
        step_size,
        tick_size,
        min_trade_qty,
        max_trade_qty,
        min_trade_price,
        max_trade_price,
        _,
        mtb_long,
        mtb_short,
        _,
        _,
        _,
        _,
        _,
        _,
        trading_start_time,
        delist,
        trading_status,
        oracle_price,
        _,
        isolated_only,
    ) = perpetual::perpetual_values(perpetual);

    // 1. Ensure that the trading is started on the perpetual and that is permitted
    assert!(
        timestamp >= trading_start_time && trading_status,
        errors::trading_not_permitted(),
    );

    // 2. Ensure that the perpetual is not delisted
    assert!(!delist, errors::perpetual_delisted());

    // 3. Ensure fill quantity is within trade quantity range and conforms to step size
    assert!(
        fill_quantity >= min_trade_qty && fill_quantity <= max_trade_qty && fill_quantity
                % step_size == 0,
        errors::invalid_quantity(),
    );

    // 4. Ensure fill price is within trade price range and conforms to tick size
    assert!(
        fill_price >= min_trade_price && fill_price <= max_trade_price && fill_price %
                tick_size == 0,
        errors::invalid_trade_price(),
    );

    // 5. Ensure the fill price is within market take bound range
    // The MTB is only applied to taker order
    let bound = if (is_long) {
        oracle_price + utils::base_mul(oracle_price, mtb_long)
    } else {
        oracle_price - utils::base_mul(oracle_price, mtb_short)
    };

    bound = utils::round_to_tick_size_based_on_direction(bound, tick_size, is_long);

    assert!(
        !is_taker || 
            if (is_long) {
                fill_price <= bound
            } else {
                fill_price >= bound
            },
        errors::mtb_breached(),
    );

    // 6. Ensure order is not expired by the time it was executed off-chain
    assert!(expiry >= timestamp, errors::expired());

    // 7. Ensure that the payload is authorized to be
    if (
        option::is_some<vector<u8>>(&serialized_order) && 
            option::is_some<vector<u8>>(&serialized_signature)
    ) {
        let payload = option::extract(&mut serialized_order);
        let signature = option::extract(&mut serialized_signature);

        // 7. Validate order signature
        let signatory = signature::verify(
            payload,
            signature,
            b"Bluefin Pro Order",
        );

        assert!(
            signatory == @0 || account::has_permission(account_state, signatory),
            errors::invalid_permission(),
        );
    };

    // 8. Ensure order is being filled at the specified or better price
    // For long/buy orders, the fill price must be equal or lower
    // For short/sell orders, the fill price must be equal or higher
    // ignore the price check if the order price is zero i.e. order is market order
    assert!(
        order_price == 0 || if (is_long) {fill_price <= order_price} else {fill_price >= order_price},
        errors::invalid_fill_price(),
    );

    // 9. Ensure order is not being overfilled
    assert!(
        filled_order_quantity + fill_quantity <= order_quantity,
        errors::order_overfill(),
    );

    // 10. Check if the market allows both isolated and cross positions.
    // If the market only allows isolated positions then the order must be for isolated position
    assert!(!isolated_only || is_isolated == true, errors::isolated_only_market());

    // 11. For isolated orders leverage must be non-zero and a whole number 1,2,3....N
    assert!(
        !is_isolated || (
                leverage > 0 && leverage % constants::base_uint() == 0
            ),
        errors::invalid_leverage(),
    );
}

/// Verifies the position conforms to max allowed oi open for the selected leverage
fun verify_notion(position: &Position, mark_price: u64, max_notion_at_open: vector<u64>, is_institution: bool) {
    let (_, size, _, _, _, _, is_isolated, _) = account::get_position_values(position);

    let notional_value = utils::base_mul(
        size,
        mark_price,
    );

    // admin defines a `max_notion_at_open` value for each leverage supported by the market
    let max_leverage_index = vector::length(&max_notion_at_open);

    // get the effective leverage of the position
    let effective_leverage = account::calculate_effective_leverage(
        position,
        option::none<u64>(),
    );

    // round the effective leverage up/down to closest integer
    let rounded_effective_leverage = utils::round(
        effective_leverage,
        constants::base_uint(),
    );

    if (rounded_effective_leverage == 0) {
        rounded_effective_leverage = constants::base_uint(); // 1e9
    };

    // convert e9 leverage to base number 1,2,3....20.
    rounded_effective_leverage = rounded_effective_leverage / constants::base_uint();

    // if the effective leverage > max allowed leverage (index) on the market, use the max allowed leverage's oi limit
    // if effective leverage is 22 and max allowed leverage is 20x, the market only has limits upto 20x, we use the 20x leverage
    // max allowed oi open for 22x leverage
    if (rounded_effective_leverage > max_leverage_index) {
        rounded_effective_leverage = max_leverage_index;
    };

    // subtract one from the leverage to get its oi limit index
    //
    // We've checked above that the rounded effective leverage is nonzero, so
    // we know it can be safely decremented. However, the safety of decrementing
    // the max leverage index relies on `max_notion_at_open` never being empty.
    let index = if (is_isolated) { rounded_effective_leverage - 1 } else {
        // For institutional accounts, we return the least notional value cap,
        // rather than the greatest, so those accounts can open large positions.
        if (is_institution) {
            0
        } else {
            max_leverage_index - 1
        }
    };

    // if the position's notional value is > max allowed notional value at the specified leverage index, revert
    assert!(
        notional_value <= *vector::borrow(&max_notion_at_open, index),
        errors::max_allowed_oi_open(),
    );
}

/// Performs pre-trade checks on the given account
/// 1. Ensures accounts maintenance health is >= 0
/// 2. Ensures accounts value is >= 0
/// 3. Ensures account has no bad debt
fun pre_trade_checks(
    perpetuals_table: &Table<String, Perpetual>,
    supported_assets_table: &Table<String, Asset>,
    account: &Account,
    perpetual: &Perpetual,
    is_isolated: bool,
    trade_direction: bool,
    trade_quantity: u64,
) {
    let fetch_for = if (is_isolated) { perpetual::get_symbol(perpetual) } else {
        constants::empty_string()
    };
    let positions = account::get_positions_vector(account, fetch_for);
    let current_assets = account::get_assets_vector(account, fetch_for);

    let account_value = account::get_account_value(
        &current_assets,
        &positions,
        perpetuals_table,
        supported_assets_table,
    );

    let maintenance_margin_required = account::get_total_margin_required(
        &positions,
        perpetuals_table,
        constants::mmr_threshold(),
    );
    let initial_margin_required = account::get_total_margin_required(
        &positions,
        perpetuals_table,
        constants::imr_threshold(),
    );

    let initial_health = signed_number::sub_uint(account_value, initial_margin_required);
    let maintenance_health = signed_number::sub_uint(
        account_value,
        maintenance_margin_required,
    );


    // if user in margin call then flipping/increasing position is not allowed
    if (signed_number::lt_uint(initial_health, 0)) {
        let symbol = perpetual::get_symbol(perpetual);
        let (is_open, index) = account::has_open_position(&positions, symbol);

        if (is_open) {
            let position = vector::borrow(&positions, index);
            let (_, size, _, direction, _, _, _, _) = account::get_position_values(
                position,
            );
            // can not be increasing or flipping trade
            assert!(
                utils::is_reducing_trade(
                    direction,
                    size,
                    trade_direction,
                    trade_quantity,
                ),
                errors::health_check_failed(1),
            );


        } else {
            // if the user does not have a position open, they are trying to open a new position when below imr
            abort errors::health_check_failed(1)
        };
    };

    assert!(
        signed_number::gte_uint(maintenance_health, 0),
        errors::health_check_failed(3),
    );
    assert!(signed_number::gte_uint(account_value, 0), errors::health_check_failed(4));
}

/// Asserts if the user has cross/isolated position of given perpetual open. If a user is trying to open
/// an isolated position, this method ensures that user does not have a cross position for the same market
/// or vice-versa
fun assert_user_only_has_isolated_or_cross_position(
    account_immutable: &Account,
    perpetual: String,
    isolated: bool,
) {
    let positions = if (isolated) {
        account::get_cross_positions(account_immutable)
    } else {
        account::get_isolated_positions(account_immutable)
    };

    let (open, _) = account::has_open_position(&positions, perpetual);

    assert!(!open, errors::opening_both_isolated_cross_positions_not_allowed());
}

}
