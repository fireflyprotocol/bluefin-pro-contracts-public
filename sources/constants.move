/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::constants {
    use std::string::{Self, String};
    use std::vector;

    //===========================================================//
    //                          Constants                        //
    //===========================================================//

    /// Tracks the current version of the package. Every time a breaking change is pushed, 
    /// increment the version on the new package, making any old version of the package 
    /// unable to be used
    const VERSION: u64 = 1;

    /// Indicates that the request type was deposit 
    const TYPE_DEPOSIT: u8 = 0;
    
    /// Indicates that the request typ was withdraw
    const TYPE_WITHDRAW: u8 = 1;

    /// The number of decimals protocol uses to represent values
    const PROTOCOL_DECIMALS: u8 = 9;

    /// The basic unit (one in 1e9 decimals) Every thing on the protocol is represent in 9 decimal places
    const BASE_UINT : u64 = 1000000000;

    /// The ED25519 wallet identifier
    const ED25519_WALLET_SCHEME: u8 = 0;

    /// The SECP wallet identifier
    const SECP_256K1_WALLET_SCHEME: u8 = 1;

    /// IMR threshold value
    const IMR_THRESHOLD: u8 = 0;

    /// MMR threshold value
    const MMR_THRESHOLD: u8 = 1;
    
    /// Action types
    const ACTION_TRADE: u8 = 1;
    const ACTION_LIQUIDATE: u8 = 2;
    const ACTION_DELEVERAGE: u8 = 3;
    const ACTION_WITHDRAW: u8 = 4;
    const ACTION_ADD_MARGIN: u8 = 5;
    const ACTION_REMOVE_MARGIN: u8 = 6;
    const ACTION_ADJUST_LEVERAGE: u8 = 7;
    const ACTION_CLOSE_POSITION: u8 = 8;
    /// This action is only used for verifying health of a cross account
    /// during execution of an isolated trade
    const ACTION_ISOLATED_TRADE: u8 = 9;


    /// Prune Table 
    const PRUNE_HISTORY: u8 = 1;
    const PRUNE_ORDER_FILLS: u8 = 2;


    /// Timestamp (ms) after which pruning an entry of a table is allowed
    const LIFESPAN: u64 = 7776000000; // 3 months

    const MAX_VALUE_U64: u64 = 0xFFFF_FFFF_FFFF_FFFF;


    /// Payload types
    const PAYLOAD_TYPE_LIQUIDATE: vector<u8> = b"Bluefin Pro Liquidation";
    const PAYLOAD_TYPE_SETTING_FUNDING_RATE: vector<u8> = b"Bluefin Pro Setting Funding Rate";
    const PAYLOAD_TYPE_PRUNING_TABLE: vector<u8> = b"Bluefin Pro Pruning Table";
    const PAYLOAD_TYPE_AUTHORIZING_LIQUIDATOR: vector<u8> = b"Bluefin Pro Authorizing Liquidator";
    const PAYLOAD_TYPE_SETTING_ACCOUNT_FEE_TIER: vector<u8> = b"Bluefin Pro Setting Account Fee Tier";
    const PAYLOAD_TYPE_SETTING_ACCOUNT_TYPE: vector<u8> = b"Bluefin Pro Setting Account type";
    const PAYLOAD_TYPE_SETTING_GAS_FEE: vector<u8> = b"Bluefin Pro Setting Gas Fee";
    const PAYLOAD_TYPE_SETTING_GAS_POOL: vector<u8> = b"Bluefin Pro Setting Gas Pool";
    const PAYLOAD_TYPE_ADL: vector<u8> = b"Bluefin Pro ADL";
            
    //===========================================================//
    //                        Getter Methods                     //
    //===========================================================//

    public fun get_version(): u64 {
        VERSION
    }

    public fun deposit_type(): u8 {
        TYPE_DEPOSIT
    }

    public fun withdraw_type(): u8 {
        TYPE_WITHDRAW
    }

    public fun protocol_decimals() : u8 {
        PROTOCOL_DECIMALS
    }

    public fun base_uint() : u64 {
        BASE_UINT
    }

    public fun secp256k1_scheme() : u8 {
        SECP_256K1_WALLET_SCHEME
    }

    public fun ed25519_scheme() : u8 {
        ED25519_WALLET_SCHEME
    }

    public fun imr_threshold() : u8 {
        IMR_THRESHOLD
    }

    public fun mmr_threshold() : u8 {
        MMR_THRESHOLD
    }

    public fun position_long(): String {
        string::utf8(b"LONG")
    }

    public fun position_short(): String {
        string::utf8(b"SHORT")
    }

    public fun position_isolated(): String {
        string::utf8(b"ISOLATED")
    }

    public fun position_cross(): String {
        string::utf8(b"CROSS")
    }

    public fun action_trade(): u8 {
        ACTION_TRADE
    }

    public fun action_liquidate(): u8 {
        ACTION_LIQUIDATE
    }

    public fun action_deleverage(): u8 {
        ACTION_DELEVERAGE
    }

    public fun action_withdraw(): u8 {
        ACTION_WITHDRAW
    }

    public fun action_add_margin(): u8 {
        ACTION_ADD_MARGIN
    }

    public fun action_remove_margin(): u8 {
        ACTION_REMOVE_MARGIN
    }

    public fun action_adjust_leverage(): u8 {
        ACTION_ADJUST_LEVERAGE
    }

    public fun action_close_position(): u8 {
        ACTION_CLOSE_POSITION
    }

    public fun action_isolated_trade(): u8 {
        ACTION_ISOLATED_TRADE
    }


    public fun empty_string(): String {
        string::utf8(b"")
    }

    public fun get_supported_operators(): vector<String> {

        let types = vector::empty<String>();

        vector::push_back(&mut types, string::utf8(b"funding"));
        vector::push_back(&mut types, string::utf8(b"fee"));
        vector::push_back(&mut types, string::utf8(b"guardian"));
        vector::push_back(&mut types, string::utf8(b"adl"));

        types
    }


    public fun history_table(): u8 {
        PRUNE_HISTORY
    }

    public fun fills_table(): u8 {
        PRUNE_ORDER_FILLS
    }

    public fun lifespan(): u64 {
        LIFESPAN
    }

    public fun usdc_token_symbol(): String {
        string::utf8(b"USDC")
    }
    
    public fun max_value_u64(): u64 {
        MAX_VALUE_U64
    }

    public fun payload_type_liquidate(): vector<u8> {
        PAYLOAD_TYPE_LIQUIDATE
    }

    public fun payload_type_setting_funding_rate(): vector<u8> {
        PAYLOAD_TYPE_SETTING_FUNDING_RATE
    }

    public fun payload_type_pruning_table(): vector<u8> {
        PAYLOAD_TYPE_PRUNING_TABLE
    }

    public fun payload_type_authorizing_liquidator(): vector<u8> {
        PAYLOAD_TYPE_AUTHORIZING_LIQUIDATOR
    }

    public fun payload_type_setting_account_fee_tier(): vector<u8> {
        PAYLOAD_TYPE_SETTING_ACCOUNT_FEE_TIER
    }

    public fun payload_type_setting_account_type(): vector<u8> {
        PAYLOAD_TYPE_SETTING_ACCOUNT_TYPE
    }
    
    public fun payload_type_setting_gas_fee(): vector<u8> {
        PAYLOAD_TYPE_SETTING_GAS_FEE
    }

    public fun payload_type_setting_gas_pool(): vector<u8> {
        PAYLOAD_TYPE_SETTING_GAS_POOL
    }

    public fun payload_type_adl(): vector<u8> {
        PAYLOAD_TYPE_ADL
    }

}
