/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::errors {

    //===========================================================//
    //                          Constants                        //
    //===========================================================//

    /// Triggered when object version does not match the package version
    const EVersionMismatch: u64 = 1001;

    /// Triggered when the coin object does not have enough amount to deposit
    const EInsufficientCoinAmount: u64 = 1002;

    /// Triggered when the provided nonce is invalid
    const EInvalidNonce: u64 = 1003;

    /// Triggered when address provided is zero
    const EZeroAddress: u64 = 1004;

    /// Triggered when the sequence hash computed does not match the off-chain (expected) sequence hash
    const EInvalidSequenceHash: u64 = 1005;

    /// Triggered when invalid internal data store is passed as argument
    const EInvalidIDS: u64 = 1006;

    /// Triggered when the input is zero
    const EZeroValue: u64 = 1008;

    /// Triggered when the provided perpetual does not exists
    const EInvalidPerpetualSymbol: u64 = 1009;

    /// Triggered when EDS has some perpetual changes which are not synced with IDS
    const EPendingSync: u64 = 1010;

    /// Triggered when there is a transaction replay
    const ETxReplay: u64 = 1011;

    /// Triggered when the maker account being deleveraged is not bankrupt
    const ENotBankrupt: u64 = 1012;

    /// Triggered when the max allowed oi open is breached
    const EMaxAllowedOIOpen: u64 = 1013;

    /// Triggered when the signer of payload does not have permission for the account
    const EInvalidPermission: u64 = 1014;

    /// Triggered when eds id provided in withdrawal payload is invalid
    const EInvalidEDS: u64 = 1015;

    /// Triggered when an account being fetched does not exist
    const EAccountDoesNotExist: u64 = 1016;

    /// Triggered when an account has insufficient margin
    const EInsufficientMargin: u64 = 1017;

    /// Triggered trying to create another perpetual with same symbol
    const EPerpetualAlreadyExists: u64 = 1018;

    /// Triggered when the oracle price provided is invalid
    const EInvalidOraclePrice: u64 = 1019;

    /// Triggered when ids is already synced with eds
    const EAlreadySynced: u64 = 1020;

    /// Triggered the perpetuals/markets of the orders do not match
    const EPerpetualsMismatch: u64 = 1021;

    /// Triggered when a non-zero leverage is provided for cross order or invalid leverage is provided for isolated order
    const EInvalidLeverage: u64 = 1022;

    /// Triggered when trying to trade on a de-listed perpetual
    const EDelistedPerpetual: u64 = 1023;

    /// Triggered when trading is not yet started or paused on a perp
    const ETradingNotPermitted: u64 = 1024;

    /// Triggered when both orders are of the same side
    const ESameSideOrders: u64 = 1025;

    /// Triggered when fill price is invalid
    const EInvalidFillPrice: u64 = 1026;

    /// Triggered when order/liquidation is expired
    const EExpired: u64 = 1027;

    /// Triggered when an order is getting overfilled
    const EOverFill: u64 = 1028;

    /// Triggered when the trade price is not with in acceptable range or does not conform to tick size
    const EInvalidTradePrice: u64 = 1029;

    /// Triggered when the trade/liquidation quantity is not with in acceptable range or does not conform to step size
    /// or the new value being set for a perpetual config is invalid
    const EInvalidQuantity: u64 = 1030;

    /// Triggered when a trade fill price breaches the market take bound on either side
    const EMTBBreached: u64 = 1031;

    /// Triggered when trying to sync an asset/perpetual that doesn't exist
    const ENothingToSync: u64 = 1032;

    /// Triggered when trying to execute a cross trade on isolated only perpetual
    const ECrossNotSupported: u64 = 1034;

    /// Triggered when trying to adjust margin of a position that doesn't exist
    const ENoPosition: u64 = 1035;

    /// Triggered when the asset being passed in params is not supported
    const EAssetNotSupported: u64 = 1036;

    /// Triggered when the operator type provided is invalid
    const EInvalidOperatorType: u64 = 1037;

    /// Triggered when the new operator address is same as existing one
    const EOperatorAlreadySet: u64 = 1038;

    /// Triggered when the funding timestamp is invalid (not hourly or < last timestamp)
    const EInvalidFundingTimestamp: u64 = 1039;

    /// Triggered when the funding value >= max allowed funding rate by a market
    const EFundingRateExceedsLimit: u64 = 1040;

    /// Triggered when asset bank for the provided asset symbol already exists
    const EAssetAlreadySupported: u64 = 1041;

    /// Triggered when the account being liquidated is not undercollat/under water
    const ENotLiquidateable: u64 = 1042;

    /// Triggered when `allOrNothing` flag is true and liquidatee's position is not
    /// enough to satisfy the constraint
    const EAllOrNothing: u64 = 1043;

    /// Triggered when providing invalid table index to prune
    const EInvalidTable: u64 = 1044;

    /// Triggered when trying to prune a non-existent hash
    const EInvalidHashEntry: u64 = 1045;

    /// Triggered when a request being processed has a `signed_at` field < current time - signature_lifespan
    const EExceedsLifeSpan: u64 = 1046;

    /// Triggered when the provided `T` type and asset symbol do not match
    const EAssetTypeAndSymbolMismatch: u64 = 1047;

    /// Triggered when margining_engine::apply_maths is not provided premium/debt value for
    /// taker side of liquidation trade. It should only be passed as `Some` when
    /// Liquidation trade is being performed And maths is being applied on the taker/liquidator
    /// OR the first fill flag for the maker of trade
    const EMissingPremiumDebtParam: u64 = 1048;

    /// Triggered when the position passed for liquidations is not the one with most
    /// positive PNL. When taking over an account, its most positive PNL position
    /// must be liquidated first
    const EInvalidLiquidationPosition: u64 = 1049;


    /// Triggered when an account is not a whitelisted liquidator
    const EUnauthorizedLiquidator: u64 = 1050;

    /// Triggered when the taker of deleverage call is itself under water (liquidateable)
    const EUnderWater: u64 = 1051;

    /// Triggered when trying to deleverage quantity >= maker's or taker's position size
    const EInsufficientPositionSize: u64 = 1052;

    /// Triggered when the taker position does not have a positive Pnl during ADL trade
    const ENotPositivePnl: u64 = 1053;

    /// Triggered when the perpetual field being updated is invalid/non-existent
    const EInvalidPerpetualField: u64 = 1054;

    /// Triggered when a perpetual is already delisted
    const EAlreadyDelisted: u64 = 1055;

    /// Triggered when trying to close position for a market that is not delisted
    const ENotDelisted: u64 = 1056;
    
    /// Triggered when their exists no max oi open limit for the selected user leverage
    const ENoMaxOIOpen: u64 = 1057;

    /// Triggered when a self trade, liquidation or ADL is being performed
    const ESelfTrade: u64 = 1058;

    /// Triggered when a user tries to open an isolated position 
    /// for a market for which they already have a cross position open
    /// or vice-versa
    const EOpeningBothPositionTypesNotAllowed: u64 = 1059;

    /// Triggered when trying to set a value for a 
    /// perpetual/market config that is not permissible
    const EOutOfConfigBounds: u64 = 1060;

    /// Triggered when trying to update EDS/IDS version beyond current supported contract version
    const ELatestVersion: u64 = 1061;

    /// Triggered when trading start time is invalid
    const EInvalidStartTime: u64 = 1062;

    /// Triggered when invoking a deprecated function
    const EDeprecatedFunction: u64 = 1063;

    /// Triggered when a user tries to close their position after delist that has a bad debt
    const EBadDebt: u64 = 1064;

    /// Triggered when there is insufficient funds to withdraw
    const EInsufficientFunds: u64 = 1065;

    /// Triggered when the payload type is invalid
    const EInvalidPayloadType: u64 = 1066;

    /// Triggered when a health check fails
    /// Case 1: 4001 Case 2: 4002, Case 3: 4003 and Case 4: 4004 
    const EHealthCheckFailed: u64 = 4000;




    //===========================================================//
    //                        Getter Methods                     //
    //===========================================================//

    public fun version_mismatch(): u64 {
        EVersionMismatch
    }

    public fun coin_does_not_have_enough_amount(): u64 {
        EInsufficientCoinAmount
    }

    public fun invalid_nonce(): u64 {
        EInvalidNonce
    }

    public fun can_not_be_zero_address(): u64 {
        EZeroAddress
    }

    public fun invalid_sequence_hash(): u64 {
        EInvalidSequenceHash
    }

    public fun invalid_internal_data_store(): u64 {
        EInvalidIDS
    }

    public fun can_not_be_zero(): u64 {
        EZeroValue
    }

    public fun perpetual_does_not_exists(): u64 {
        EInvalidPerpetualSymbol
    }

    public fun sync_already_pending(): u64 {
        EPendingSync
    }

    public fun transaction_replay(): u64 {
        ETxReplay
    }

    public fun not_bankrupt(): u64 {
        ENotBankrupt
    }


    public fun invalid_permission(): u64 {
        EInvalidPermission
    }

    public fun invalid_eds(): u64 {
        EInvalidEDS
    }

    public fun account_does_not_exist(): u64 {
        EAccountDoesNotExist
    }

    public fun insufficient_margin(): u64 {
        EInsufficientMargin
    }

    public fun perpetual_already_exists(): u64 {
        EPerpetualAlreadyExists
    }

    public fun invalid_oracle_price(): u64 {
        EInvalidOraclePrice
    }
    
    public fun already_synced(): u64 {
        EAlreadySynced
    }

    public fun perpetuals_mismatch(): u64 {
        EPerpetualsMismatch
    }

    public fun perpetual_delisted(): u64 {
        EDelistedPerpetual
    }

    public fun trading_not_permitted(): u64 {
        ETradingNotPermitted
    }

    public fun orders_must_be_opposite(): u64 {
        ESameSideOrders
    }

    public fun invalid_fill_price(): u64 {
        EInvalidFillPrice
    }

    public fun expired(): u64 {
        EExpired
    }

    public fun order_overfill(): u64 {
        EOverFill
    }

    public fun invalid_trade_price(): u64 {
        EInvalidTradePrice
    }

    public fun invalid_quantity(): u64 {
        EInvalidQuantity
    }

    public fun mtb_breached(): u64 {
        EMTBBreached
    }

    public fun invalid_leverage(): u64 {
        EInvalidLeverage
    }

    public fun nothing_to_sync(): u64 {
        ENothingToSync
    }

    public fun isolated_only_market(): u64 {
        ECrossNotSupported
    }

    public fun position_does_not_exist(): u64 {
        ENoPosition
    }

    public fun asset_not_supported(): u64 {
        EAssetNotSupported
    }

    public fun invalid_operator_type(): u64 {
        EInvalidOperatorType
    }

    public fun operator_already_set(): u64 {
        EOperatorAlreadySet
    }


    public fun invalid_funding_time(): u64 {
        EInvalidFundingTimestamp
    }

    public fun funding_rate_exceeds_max_allowed_limit(): u64 {
        EFundingRateExceedsLimit
    }

    public fun asset_already_supported(): u64 {
        EAssetAlreadySupported
    }

    public fun not_liquidateable(): u64 {
        ENotLiquidateable
    }

    public fun all_or_nothing(): u64 {
        EAllOrNothing
    }

    public fun invalid_table_type(): u64 {
        EInvalidTable
    }

    public fun trying_to_prune_non_existent_entry(): u64 {
        EInvalidHashEntry
    }

    public fun exceeds_lifespan(): u64 {
        EExceedsLifeSpan
    }

    public fun asset_type_and_symbol_mismatch(): u64 {
        EAssetTypeAndSymbolMismatch
    }

    public fun missing_optional_param(): u64 {
        EMissingPremiumDebtParam
    }

    public fun invalid_position_for_liquidation(): u64 {
        EInvalidLiquidationPosition
    }

    public fun unauthorized_liquidator(): u64 {
        EUnauthorizedLiquidator
    }

    public fun under_water(): u64 {
        EUnderWater
    }

    public fun insufficient_position_size(): u64 {
        EInsufficientPositionSize
    }

    public fun negative_pnl(): u64 {
        ENotPositivePnl
    }

    public fun invalid_perpetual_config(): u64 {
        EInvalidPerpetualField
    }

    public fun already_delisted(): u64 {
        EAlreadyDelisted
    }

    public fun not_delisted(): u64 {
        ENotDelisted
    }

    public fun max_allowed_oi_open(): u64 {
        EMaxAllowedOIOpen
    }

    public fun no_max_allowed_oi_open_for_selected_leverage(): u64 {
        ENoMaxOIOpen
    }

    public fun self_trade(): u64 {
        ESelfTrade
    }

    public fun opening_both_isolated_cross_positions_not_allowed(): u64 {
        EOpeningBothPositionTypesNotAllowed
    }

    public fun out_of_config_value_bounds(): u64 {
        EOutOfConfigBounds
    }

    public fun latest_supported_contract_version(): u64 {
        ELatestVersion
    }

    public fun invalid_trade_start_time(): u64 {
        EInvalidStartTime
    }

    public fun deprecated_function(): u64 {
        EDeprecatedFunction
    }

    public fun health_check_failed(case: u64): u64 {
        EHealthCheckFailed + case
    }

    public fun bad_debt(): u64 {
        EBadDebt
    }

    public fun insufficient_funds(): u64 {
        EInsufficientFunds
    }

    public fun invalid_payload_type(): u64 {
        EInvalidPayloadType
    }

}
