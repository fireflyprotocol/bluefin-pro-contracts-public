/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::events {
    use sui::object::ID;
    use sui::event::emit;
    use std::string::{String};

    use bluefin_cross_margin_dex::perpetual::{Perpetual, FundingRate};
    use bluefin_cross_margin_dex::account::{DepositedAsset, Position};
    use bluefin_cross_margin_dex::signed_number::{Self, Number};
    use bluefin_cross_margin_dex::bank::{Asset};
    use bluefin_cross_margin_dex::constants;

    friend bluefin_cross_margin_dex::admin;
    friend bluefin_cross_margin_dex::data_store;
    friend bluefin_cross_margin_dex::exchange;
    friend bluefin_cross_margin_dex::margining_engine;

    //===========================================================//
    //                           Structs                         //
    //===========================================================//


    struct AdminCapTransferred has copy, drop {
        admin: address
    } 

    struct AssetSupported has copy, drop {
        eds_id: ID,
        asset: Asset,
        sequence_number: u128
    } 

    struct AssetSynced has copy, drop {
        eds_id: ID, 
        ids_id: ID,
        asset_symbol: String,
        sequence_number: u128,
    }

    struct InternalDataStoreCreated has copy, drop {
        id: ID,
        sequencer: address,
        sequence_number: u128
    } 

    struct AssetBankDeposit has copy, drop {
        eds_id: ID,
        asset:String,
        from: address,
        to: address,
        amount: u64,
        nonce: u128,
        sequence_number: u128
    }


    struct Deposit has copy, drop {
        eds: ID,
        ids: ID,
        account: address,
        asset: String,
        amount: u64,
        assets: vector<DepositedAsset>,
        sequence_hash: vector<u8>,
        nonce: u128,
        eds_sequence_number: u128,
        ids_sequence_number: u128,
    } 

    struct TaintedAssetRemoved has copy, drop {
        eds: ID,
        ids: ID,
        from: address,
        to: address,
        asset: String,
        amount: u64,
        nonce: u128,
        sequence_hash: vector<u8>,
        eds_sequence_number: u128,
        ids_sequence_number: u128,
    } 

    struct Withdraw has copy, drop {
        eds: ID,
        ids: ID,
        account: address,
        asset: String,
        amount: u64,
        assets: vector<DepositedAsset>,
        sequence_hash: vector<u8>,
        eds_sequence_number: u128,
        ids_sequence_number: u128,
    } 

    struct PerpetualUpdate has copy, drop {
        eds_id: ID,
        perpetual: Perpetual,
        sequence_number: u128
    }

    struct PerpetualSynced has copy, drop {
        ids_id: ID,
        perpetual: Perpetual,
        sequence_number: u128
    }

    struct UserAuthorized has copy, drop{
        account: address,
        user: address,
        authorized: bool,
        sequence_number: u128
    }

    struct AuthorizedAccountsUpdated has copy, drop{
        account: address,
        previous_authorized_accounts: vector<address>,
        current_authorized_accounts: vector<address>,
        sequence_number: u128
    }

    struct OraclePriceUpdate has copy, drop {
        perpetuals: vector<String>,
        prices: vector<u64>,
        sequence_number: u128
    }

    struct Trader has store, copy, drop {
        address: address,
        order_hash: vector<u8>,
        position: Position,
        assets: vector<DepositedAsset>,
        fee_asset: String,
        fee_usd_qty: u64,
        fee_token_qty: u64,        
    }

    struct TradeExecuted has copy, drop {
        market: String,
        maker: Trader,
        taker: Trader,
        fill_quantity: u64,
        fill_price: u64,
        taker_side: String,
        taker_gas_fee: u64,
        sequence_hash: vector<u8>,
        sequence_number: u128
    }

    struct LiquidationExecuted has copy, drop {
        market: String,
        hash: vector<u8>,
        liquidatee_address: address,
        liquidator_address: address,
        liquidatee_position: Position,
        liquidator_position: Position,
        liquidatee_assets: vector<DepositedAsset>,
        liquidator_assets: vector<DepositedAsset>,
        quantity: u64,
        liq_purchase_price: u64,
        bankruptcy_price: u64,
        oracle_price: u64,
        liquidator_side: String,
        premium_or_debt: Number,
        insurance_pool_premium_portion: u64,
        sequence_hash: vector<u8>,
        sequence_number: u128
    }

    struct MarginAdjusted has copy, drop {
        account: address,
        amount: u64,
        added: bool,
        position: Position,
        assets: vector<DepositedAsset>,        
        sequence_hash: vector<u8>,
        sequence_number: u128
    }

    struct LeverageAdjusted has copy, drop {
        account: address,
        position: Position,
        assets: vector<DepositedAsset>,
        sequence_hash: vector<u8>,
        sequence_number: u128
    }

    struct EDSOperatorUpdated has copy, drop {
        store: ID,
        operator_type: String,
        previous_operator: address,
        new_operator: address,
        sequence_number: u128
    }

    struct OperatorSynced has copy, drop {
        store: ID,
        operator_type: String,
        previous_operator: address,
        new_operator: address,
        sequence_number: u128
    }

    struct FundingRateUpdated has copy, drop {
        market: String,
        timestamp: u64,
        rate: Number,
        sequence_number: u128
    }

    struct TablePruned has copy, drop {
        type: u8,
        sequence_number: u128
    }

    struct BankruptLiquidatorAuthorizedEvent has copy, drop {
        account: address,
        authorized: bool,
        sequence_number: u128
    }

    struct FeeTierUpdatedEvent has copy, drop {
        account: address,
        maker: u64,
        taker: u64,
        applied: bool,
        sequence_number: u128
    }

    struct AccountTypeUpdatedEvent has copy, drop {
        account: address,
        is_institution: bool,
        sequence_number: u128
    }

    struct GasFeeUpdatedEvent has copy, drop {
        ids: ID,
        gas_fee: u64,
        sequence_number: u128,
    }

    struct GasPoolUpdatedEvent has copy, drop {
        ids: ID,
        previous_gas_pool: address,
        current_gas_pool: address,
        sequence_number: u128,
    }

    struct ADLExecuted has copy, drop {
        market: String, 
        hash: vector<u8>, 
        maker_address: address,
        taker_address: address,
        maker_position: Position, 
        taker_position: Position, 
        maker_assets: vector<DepositedAsset>, 
        taker_assets: vector<DepositedAsset>, 
        quantity: u64, 
        bankruptcy_price: u64, 
        oracle_price: u64, 
        taker_side: String, 
        sequence_hash: vector<u8>, 
        sequence_number: u128
    }

    struct PositionClosed has copy, drop {
        market: String, 
        account: address,
        hash: vector<u8>, 
        position: Position, 
        assets: vector<DepositedAsset>, 
        delisting_price: u64, 
        sequence_hash: vector<u8>, 
        sequence_number: u128
    }

    struct FundingRateApplied has copy, drop {
        account: address,
        position: Position,
        assets: vector<DepositedAsset>,
        funding_rate: FundingRate,
        funding_amount: Number,
        sequence_number: u128
    }

    //===============================================================//
    //               Friend Methods To Emit Events                   //
    //===============================================================//

    public(friend) fun emit_admin_cap_transfer_event(admin:address){
        emit(
            AdminCapTransferred {
                admin
            }
        );
    }

    public(friend) fun emit_asset_supported_event(eds_id: ID, asset:Asset, sequence_number: u128){

        emit(
            AssetSupported {
                eds_id,
                asset,
                sequence_number
            }
        );
    }


    public(friend) fun emit_internal_exchange_created_event(id:ID, sequencer: address, sequence_number: u128){
        emit(
            InternalDataStoreCreated {
                id,
                sequencer,
                sequence_number
            }
        );
    }


    public(friend) fun emit_asset_bank_deposit_event(eds_id:ID, asset: String, from:address, to:address, amount: u64, nonce: u128, sequence_number: u128){
        emit(
            AssetBankDeposit {
                eds_id,
                asset,
                from,
                to,
                amount,
                nonce,
                sequence_number
            }
        );
    }

    public(friend) fun emit_deposit_event(eds: ID, ids: ID, account:address, asset: String, amount: u64, assets:vector<DepositedAsset>, sequence_hash:vector<u8>, nonce: u128, eds_sequence_number: u128, ids_sequence_number: u128){
        emit(
            Deposit {
                eds,
                ids,
                account,
                asset,
                amount,
                assets,
                sequence_hash,
                nonce,
                eds_sequence_number,
                ids_sequence_number
            }
        );
    }   

    public(friend) fun emit_withdraw_event(eds: ID, ids: ID, account:address, asset: String, amount: u64, assets:vector<DepositedAsset>, sequence_hash:vector<u8>, eds_sequence_number: u128, ids_sequence_number: u128){
        emit(
            Withdraw {
                eds,
                ids,
                account,
                asset,
                amount,
                assets,
                sequence_hash,
                eds_sequence_number,
                ids_sequence_number
            }
        );
    } 


    public(friend) fun emit_perpetual_update_event(eds_id:ID, perpetual: Perpetual, sequence_number: u128){
        emit(
            PerpetualUpdate {
                eds_id,
                perpetual,
                sequence_number
            }
        );
    } 


    public(friend) fun emit_user_authorized_event(account: address, user:address, authorized:bool, sequence_number: u128){
        emit(
            UserAuthorized {
                account,
                user,
                authorized,
                sequence_number
            }
        );
    }

    public(friend) fun emit_oracle_price_update_event(perpetuals: vector<String>, prices: vector<u64>, sequence_number: u128){
        emit(
            OraclePriceUpdate {
                perpetuals,
                prices,
                sequence_number
            }
        );
    }

    public (friend) fun emit_trade_executed_event(
        market: String, 
        maker_address: address, 
        taker_address: address, 
        maker_hash: vector<u8>, 
        taker_hash: vector<u8>, 
        maker_position: Position, 
        taker_position: Position, 
        maker_assets: vector<DepositedAsset>, 
        taker_assets: vector<DepositedAsset>,
        maker_fee: u64,
        taker_fee: u64, 
        maker_fee_token_qty: u64,
        taker_fee_token_qty: u64,
        taker_fee_asset: String, 
        maker_fee_asset: String, 
        fill_quantity: u64, 
        fill_price: u64, 
        taker_is_long: bool, 
        taker_gas_fee: u64, 
        sequence_hash: vector<u8>, 
        sequence_number: u128){

        let maker = Trader {
            address: maker_address,
            order_hash: maker_hash,
            position: maker_position,
            assets: maker_assets,
            fee_asset: maker_fee_asset,
            fee_usd_qty: maker_fee,
            fee_token_qty: maker_fee_token_qty,
        };

        let taker = Trader {
            address: taker_address,
            order_hash: taker_hash,
            position: taker_position,
            assets: taker_assets,
            fee_asset: taker_fee_asset,
            fee_usd_qty: taker_fee,
            fee_token_qty: taker_fee_token_qty,
        };

        emit(
            TradeExecuted {
                market,
                maker,
                taker,
                fill_quantity,
                fill_price,
                taker_side: if (taker_is_long) { constants::position_long()} else { constants::position_short()},
                taker_gas_fee,
                sequence_hash,
                sequence_number
            }
        );
    }

    public (friend) fun emit_liquidation_executed_event(
        market: String, 
        hash: vector<u8>, 
        liquidatee_address: address,
        liquidator_address: address,
        liquidatee_position: Position, 
        liquidator_position: Position, 
        liquidatee_assets: vector<DepositedAsset>, 
        liquidator_assets: vector<DepositedAsset>, 
        quantity: u64, 
        liq_purchase_price: u64, 
        bankruptcy_price: u64, 
        oracle_price: u64, 
        liquidator_is_long: bool, 
        premium_or_debt: Number, 
        insurance_pool_premium_portion: u64, 
        sequence_hash: vector<u8>, 
        sequence_number: u128){

        emit(
            LiquidationExecuted {
                market,
                hash,
                liquidatee_address,
                liquidator_address,
                liquidatee_position,
                liquidator_position,
                liquidatee_assets,
                liquidator_assets,
                quantity,
                liq_purchase_price,
                bankruptcy_price,
                oracle_price,
                liquidator_side: if (liquidator_is_long) { constants::position_long() } else { constants::position_short()},
                premium_or_debt,
                insurance_pool_premium_portion,
                sequence_hash,
                sequence_number
            }
        );
    }

    public (friend) fun emit_margin_adjusted_event(account: address, amount: u64, added: bool, position: Position, assets: vector<DepositedAsset>, sequence_hash: vector<u8>, sequence_number: u128){

        emit (
            MarginAdjusted { 
                account,
                amount,
                added,
                position,
                assets,        
                sequence_hash,
                sequence_number
            }
        ); 
    }

    public (friend) fun emit_leverage_adjusted_event(account: address, position: Position,  assets: vector<DepositedAsset>, sequence_hash:vector<u8>, sequence_number: u128){

         emit (
            LeverageAdjusted { 
                account,
                position,
                assets,
                sequence_hash,
                sequence_number
            }
        ); 
    }

    public(friend) fun emit_eds_operator_update(store:ID, operator_type: String, previous_operator: address, new_operator: address, sequence_number: u128){
        emit(
            EDSOperatorUpdated {
                store,
                operator_type,
                previous_operator,
                new_operator,
                sequence_number
            }
        );
    } 


    public(friend) fun emit_operator_synced_event(store:ID, operator_type: String, previous_operator: address, new_operator: address, sequence_number: u128){
        emit(
            OperatorSynced {
                store,
                operator_type,
                previous_operator,
                new_operator,
                sequence_number
            }
        );
    } 

     public(friend) fun emit_perpetual_synced_event(ids_id:ID, perpetual: Perpetual, sequence_number: u128){
        emit(
        PerpetualSynced {
                ids_id,
                perpetual,
                sequence_number
            }
        );
    } 

    public(friend) fun emit_funding_rate_update_event(market: String, value: u64, sign: bool, timestamp: u64, sequence_number: u128) {

        emit(
            FundingRateUpdated{
                market,
                timestamp,
                rate: signed_number::from(value, sign),
                sequence_number
            }
        )
    }

    public(friend) fun emit_table_pruned_event(type: u8, sequence_number: u128){
        emit(
            TablePruned{
                type,
                sequence_number
            }
        )
    }

    public(friend) fun emit_asset_synced_event(eds_id: ID, ids_id: ID, asset_symbol: String, sequence_number: u128){
        emit(
            AssetSynced{
                eds_id,
                ids_id,
                asset_symbol,
                sequence_number
            }
        )
    }

    public(friend) fun emit_bankrupt_liquidator_authorized_event(account: address, authorized: bool, sequence_number: u128){
        emit(
            BankruptLiquidatorAuthorizedEvent {
                account,
                authorized,
                sequence_number,
            }
        )
    }


    public(friend) fun emit_fee_tier_updated_event(account: address, maker:u64, taker: u64, applied: bool, sequence_number: u128){
        emit(
            FeeTierUpdatedEvent {
                account,
                maker,
                taker,
                applied,
                sequence_number,
            }
        )
    }


    public(friend) fun emit_account_type_updated_event(account: address, is_institution: bool, sequence_number: u128){
        emit(
            AccountTypeUpdatedEvent {
                account,
                is_institution,
                sequence_number,
            }
        )
    }

    public(friend) fun emit_gas_fee_updated_event(ids: ID, gas_fee: u64, sequence_number: u128){
        emit(
            GasFeeUpdatedEvent {
                ids,
                gas_fee,
                sequence_number,
            }
        )
    }

    public(friend) fun emit_gas_pool_updated_event(ids: ID, previous_gas_pool: address,  current_gas_pool: address, sequence_number: u128){
        emit(
            GasPoolUpdatedEvent {
                ids,
                previous_gas_pool,
                current_gas_pool,
                sequence_number,
            }
        )
    }


    public (friend) fun emit_adl_executed_event(
        market: String, 
        hash: vector<u8>, 
        maker_address: address,
        taker_address: address,
        maker_position: Position, 
        taker_position: Position, 
        maker_assets: vector<DepositedAsset>, 
        taker_assets: vector<DepositedAsset>, 
        quantity: u64, 
        bankruptcy_price: u64, 
        oracle_price: u64, 
        taker_is_long: bool, 
        sequence_hash: vector<u8>, 
        sequence_number: u128){

        emit(
            ADLExecuted {
                market,
                hash,
                maker_address,
                taker_address,
                maker_position,
                taker_position,
                maker_assets,
                taker_assets,
                quantity,
                bankruptcy_price,
                oracle_price,
                taker_side: if (taker_is_long) { constants::position_long() } else { constants::position_short()},
                sequence_hash,
                sequence_number
            }
        );
    }


    public (friend) fun emit_delisted_market_position_closed_event(
        market: String, 
        hash: vector<u8>,
        account: address, 
        position: Position, 
        assets: vector<DepositedAsset>, 
        delisting_price: u64, 
        sequence_hash: vector<u8>, 
        sequence_number: u128){

            emit(
            PositionClosed {
                market,
                account,
                hash,
                position,
                assets,
                delisting_price,
                sequence_hash,
                sequence_number
            }
        );
    }

    public (friend) fun emit_funding_rate_applied_event(
        account: address,
        position: Position,
        assets: vector<DepositedAsset>,
        funding_rate: FundingRate,
        funding_amount: Number,
        sequence_number: u128
    ) {

        emit (FundingRateApplied {
                account,
                position,
                assets,
                funding_rate,
                funding_amount,
                sequence_number
            }
        );
    }

    public (friend) fun emit_removed_tainted_deposit_event(
        eds: ID,
        ids: ID,
        from: address,
        to: address,
        asset: String,
        amount: u64,
        nonce: u128,
        sequence_hash: vector<u8>,
        eds_sequence_number: u128,
        ids_sequence_number: u128,
    ) {
        emit (TaintedAssetRemoved {
                eds,
                ids,
                from,
                to,
                asset,
                amount,
                nonce,
                sequence_hash,
                eds_sequence_number,
                ids_sequence_number
            }
        );

    }

    public(friend) fun emit_authorized_accounts_updated_event(
        account: address,
        previous_authorized_accounts: vector<address>,
        current_authorized_accounts: vector<address>,
        sequence_number: u128 
    ){  

        emit(AuthorizedAccountsUpdated {
            account,
            previous_authorized_accounts,
            current_authorized_accounts,
            sequence_number
        })
    }
}   