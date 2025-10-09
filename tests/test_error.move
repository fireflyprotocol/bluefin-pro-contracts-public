module bluefin_cross_margin_dex::test_error {
    use sui::test_scenario;
    use bluefin_cross_margin_dex::errors;
    use bluefin_cross_margin_dex::test_utils;

    // Expected error code values for validation
    const EXPECTED_VERSION_MISMATCH: u64 = 1001;
    const EXPECTED_INSUFFICIENT_COIN_AMOUNT: u64 = 1002;
    const EXPECTED_INVALID_NONCE: u64 = 1003;
    const EXPECTED_ZERO_ADDRESS: u64 = 1004;
    const EXPECTED_INVALID_SEQUENCE_HASH: u64 = 1005;
    const EXPECTED_INVALID_IDS: u64 = 1006;
    const EXPECTED_ZERO_VALUE: u64 = 1008;
    const EXPECTED_INVALID_PERPETUAL_SYMBOL: u64 = 1009;
    const EXPECTED_PENDING_SYNC: u64 = 1010;
    const EXPECTED_TX_REPLAY: u64 = 1011;
    const EXPECTED_NOT_BANKRUPT: u64 = 1012;
    const EXPECTED_MAX_ALLOWED_OI_OPEN: u64 = 1013;
    const EXPECTED_INVALID_PERMISSION: u64 = 1014;
    const EXPECTED_INVALID_EDS: u64 = 1015;
    const EXPECTED_ACCOUNT_DOES_NOT_EXIST: u64 = 1016;
    const EXPECTED_INSUFFICIENT_MARGIN: u64 = 1017;
    const EXPECTED_PERPETUAL_ALREADY_EXISTS: u64 = 1018;
    const EXPECTED_INVALID_ORACLE_PRICE: u64 = 1019;
    const EXPECTED_ALREADY_SYNCED: u64 = 1020;
    const EXPECTED_PERPETUALS_MISMATCH: u64 = 1021;
    const EXPECTED_INVALID_LEVERAGE: u64 = 1022;
    const EXPECTED_DELISTED_PERPETUAL: u64 = 1023;
    const EXPECTED_TRADING_NOT_PERMITTED: u64 = 1024;
    const EXPECTED_SAME_SIDE_ORDERS: u64 = 1025;
    const EXPECTED_INVALID_FILL_PRICE: u64 = 1026;
    const EXPECTED_EXPIRED: u64 = 1027;
    const EXPECTED_OVER_FILL: u64 = 1028;
    const EXPECTED_INVALID_TRADE_PRICE: u64 = 1029;
    const EXPECTED_INVALID_QUANTITY: u64 = 1030;
    const EXPECTED_MTB_BREACHED: u64 = 1031;
    const EXPECTED_NOTHING_TO_SYNC: u64 = 1032;
    const EXPECTED_CROSS_NOT_SUPPORTED: u64 = 1034;
    const EXPECTED_NO_POSITION: u64 = 1035;
    const EXPECTED_ASSET_NOT_SUPPORTED: u64 = 1036;
    const EXPECTED_INVALID_OPERATOR_TYPE: u64 = 1037;
    const EXPECTED_OPERATOR_ALREADY_SET: u64 = 1038;
    const EXPECTED_INVALID_FUNDING_TIMESTAMP: u64 = 1039;
    const EXPECTED_FUNDING_RATE_EXCEEDS_LIMIT: u64 = 1040;
    const EXPECTED_ASSET_ALREADY_SUPPORTED: u64 = 1041;
    const EXPECTED_NOT_LIQUIDATEABLE: u64 = 1042;
    const EXPECTED_ALL_OR_NOTHING: u64 = 1043;
    const EXPECTED_INVALID_TABLE: u64 = 1044;
    const EXPECTED_INVALID_HASH_ENTRY: u64 = 1045;
    const EXPECTED_EXCEEDS_LIFESPAN: u64 = 1046;
    const EXPECTED_ASSET_TYPE_AND_SYMBOL_MISMATCH: u64 = 1047;
    const EXPECTED_MISSING_PREMIUM_DEBT_PARAM: u64 = 1048;
    const EXPECTED_INVALID_LIQUIDATION_POSITION: u64 = 1049;
    const EXPECTED_UNAUTHORIZED_LIQUIDATOR: u64 = 1050;
    const EXPECTED_UNDER_WATER: u64 = 1051;
    const EXPECTED_INSUFFICIENT_POSITION_SIZE: u64 = 1052;
    const EXPECTED_NOT_POSITIVE_PNL: u64 = 1053;
    const EXPECTED_INVALID_PERPETUAL_FIELD: u64 = 1054;
    const EXPECTED_ALREADY_DELISTED: u64 = 1055;
    const EXPECTED_NOT_DELISTED: u64 = 1056;
    const EXPECTED_NO_MAX_OI_OPEN: u64 = 1057;
    const EXPECTED_SELF_TRADE: u64 = 1058;
    const EXPECTED_OPENING_BOTH_POSITION_TYPES_NOT_ALLOWED: u64 = 1059;
    const EXPECTED_OUT_OF_CONFIG_BOUNDS: u64 = 1060;
    const EXPECTED_LATEST_VERSION: u64 = 1061;
    const EXPECTED_INVALID_START_TIME: u64 = 1062;
    const EXPECTED_DEPRECATED_FUNCTION: u64 = 1063;
    const EXPECTED_BAD_DEBT: u64 = 1064;
    const EXPECTED_INSUFFICIENT_FUNDS: u64 = 1065;
    const EXPECTED_INVALID_PAYLOAD_TYPE: u64 = 1066;
    const EXPECTED_HEALTH_CHECK_FAILED: u64 = 4000;

    // === Basic Error Code Tests ===

    #[test]
    fun test_version_mismatch() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::version_mismatch();
        assert!(error_code == EXPECTED_VERSION_MISMATCH, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_coin_does_not_have_enough_amount() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::coin_does_not_have_enough_amount();
        assert!(error_code == EXPECTED_INSUFFICIENT_COIN_AMOUNT, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_nonce() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_nonce();
        assert!(error_code == EXPECTED_INVALID_NONCE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_can_not_be_zero_address() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::can_not_be_zero_address();
        assert!(error_code == EXPECTED_ZERO_ADDRESS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_sequence_hash() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_sequence_hash();
        assert!(error_code == EXPECTED_INVALID_SEQUENCE_HASH, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_internal_data_store() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_internal_data_store();
        assert!(error_code == EXPECTED_INVALID_IDS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_can_not_be_zero() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::can_not_be_zero();
        assert!(error_code == EXPECTED_ZERO_VALUE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_does_not_exists() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::perpetual_does_not_exists();
        assert!(error_code == EXPECTED_INVALID_PERPETUAL_SYMBOL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_sync_already_pending() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::sync_already_pending();
        assert!(error_code == EXPECTED_PENDING_SYNC, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transaction_replay() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::transaction_replay();
        assert!(error_code == EXPECTED_TX_REPLAY, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_not_bankrupt() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::not_bankrupt();
        assert!(error_code == EXPECTED_NOT_BANKRUPT, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_permission() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_permission();
        assert!(error_code == EXPECTED_INVALID_PERMISSION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_eds() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_eds();
        assert!(error_code == EXPECTED_INVALID_EDS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_account_does_not_exist() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::account_does_not_exist();
        assert!(error_code == EXPECTED_ACCOUNT_DOES_NOT_EXIST, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_insufficient_margin() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::insufficient_margin();
        assert!(error_code == EXPECTED_INSUFFICIENT_MARGIN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_already_exists() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::perpetual_already_exists();
        assert!(error_code == EXPECTED_PERPETUAL_ALREADY_EXISTS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_oracle_price() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_oracle_price();
        assert!(error_code == EXPECTED_INVALID_ORACLE_PRICE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_already_synced() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::already_synced();
        assert!(error_code == EXPECTED_ALREADY_SYNCED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetuals_mismatch() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::perpetuals_mismatch();
        assert!(error_code == EXPECTED_PERPETUALS_MISMATCH, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_delisted() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::perpetual_delisted();
        assert!(error_code == EXPECTED_DELISTED_PERPETUAL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_trading_not_permitted() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::trading_not_permitted();
        assert!(error_code == EXPECTED_TRADING_NOT_PERMITTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_orders_must_be_opposite() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::orders_must_be_opposite();
        assert!(error_code == EXPECTED_SAME_SIDE_ORDERS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_fill_price() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_fill_price();
        assert!(error_code == EXPECTED_INVALID_FILL_PRICE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_expired() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::expired();
        assert!(error_code == EXPECTED_EXPIRED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_order_overfill() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::order_overfill();
        assert!(error_code == EXPECTED_OVER_FILL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_trade_price() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_trade_price();
        assert!(error_code == EXPECTED_INVALID_TRADE_PRICE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_quantity() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_quantity();
        assert!(error_code == EXPECTED_INVALID_QUANTITY, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mtb_breached() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::mtb_breached();
        assert!(error_code == EXPECTED_MTB_BREACHED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_leverage() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_leverage();
        assert!(error_code == EXPECTED_INVALID_LEVERAGE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_nothing_to_sync() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::nothing_to_sync();
        assert!(error_code == EXPECTED_NOTHING_TO_SYNC, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_isolated_only_market() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::isolated_only_market();
        assert!(error_code == EXPECTED_CROSS_NOT_SUPPORTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_position_does_not_exist() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::position_does_not_exist();
        assert!(error_code == EXPECTED_NO_POSITION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_asset_not_supported() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::asset_not_supported();
        assert!(error_code == EXPECTED_ASSET_NOT_SUPPORTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_operator_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_operator_type();
        assert!(error_code == EXPECTED_INVALID_OPERATOR_TYPE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_operator_already_set() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::operator_already_set();
        assert!(error_code == EXPECTED_OPERATOR_ALREADY_SET, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_funding_time() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_funding_time();
        assert!(error_code == EXPECTED_INVALID_FUNDING_TIMESTAMP, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_funding_rate_exceeds_max_allowed_limit() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::funding_rate_exceeds_max_allowed_limit();
        assert!(error_code == EXPECTED_FUNDING_RATE_EXCEEDS_LIMIT, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_asset_already_supported() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::asset_already_supported();
        assert!(error_code == EXPECTED_ASSET_ALREADY_SUPPORTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_not_liquidateable() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::not_liquidateable();
        assert!(error_code == EXPECTED_NOT_LIQUIDATEABLE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_all_or_nothing() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::all_or_nothing();
        assert!(error_code == EXPECTED_ALL_OR_NOTHING, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_table_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_table_type();
        assert!(error_code == EXPECTED_INVALID_TABLE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_trying_to_prune_non_existent_entry() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::trying_to_prune_non_existent_entry();
        assert!(error_code == EXPECTED_INVALID_HASH_ENTRY, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_exceeds_lifespan() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::exceeds_lifespan();
        assert!(error_code == EXPECTED_EXCEEDS_LIFESPAN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_asset_type_and_symbol_mismatch() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::asset_type_and_symbol_mismatch();
        assert!(error_code == EXPECTED_ASSET_TYPE_AND_SYMBOL_MISMATCH, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_missing_optional_param() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::missing_optional_param();
        assert!(error_code == EXPECTED_MISSING_PREMIUM_DEBT_PARAM, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_position_for_liquidation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_position_for_liquidation();
        assert!(error_code == EXPECTED_INVALID_LIQUIDATION_POSITION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_unauthorized_liquidator() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::unauthorized_liquidator();
        assert!(error_code == EXPECTED_UNAUTHORIZED_LIQUIDATOR, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_under_water() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::under_water();
        assert!(error_code == EXPECTED_UNDER_WATER, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_insufficient_position_size() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::insufficient_position_size();
        assert!(error_code == EXPECTED_INSUFFICIENT_POSITION_SIZE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_negative_pnl() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::negative_pnl();
        assert!(error_code == EXPECTED_NOT_POSITIVE_PNL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_perpetual_config() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_perpetual_config();
        assert!(error_code == EXPECTED_INVALID_PERPETUAL_FIELD, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_already_delisted() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::already_delisted();
        assert!(error_code == EXPECTED_ALREADY_DELISTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_not_delisted() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::not_delisted();
        assert!(error_code == EXPECTED_NOT_DELISTED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_max_allowed_oi_open() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::max_allowed_oi_open();
        assert!(error_code == EXPECTED_MAX_ALLOWED_OI_OPEN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_no_max_allowed_oi_open_for_selected_leverage() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::no_max_allowed_oi_open_for_selected_leverage();
        assert!(error_code == EXPECTED_NO_MAX_OI_OPEN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_self_trade() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::self_trade();
        assert!(error_code == EXPECTED_SELF_TRADE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_opening_both_isolated_cross_positions_not_allowed() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::opening_both_isolated_cross_positions_not_allowed();
        assert!(error_code == EXPECTED_OPENING_BOTH_POSITION_TYPES_NOT_ALLOWED, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_out_of_config_value_bounds() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::out_of_config_value_bounds();
        assert!(error_code == EXPECTED_OUT_OF_CONFIG_BOUNDS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_latest_supported_contract_version() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::latest_supported_contract_version();
        assert!(error_code == EXPECTED_LATEST_VERSION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_trade_start_time() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_trade_start_time();
        assert!(error_code == EXPECTED_INVALID_START_TIME, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_deprecated_function() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::deprecated_function();
        assert!(error_code == EXPECTED_DEPRECATED_FUNCTION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_bad_debt() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::bad_debt();
        assert!(error_code == EXPECTED_BAD_DEBT, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_insufficient_funds() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::insufficient_funds();
        assert!(error_code == EXPECTED_INSUFFICIENT_FUNDS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_invalid_payload_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::invalid_payload_type();
        assert!(error_code == EXPECTED_INVALID_PAYLOAD_TYPE, 0);
        
        test_scenario::end(scenario);
    }

    // === Health Check Failed Tests ===

    #[test]
    fun test_health_check_failed_case_1() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::health_check_failed(1);
        assert!(error_code == EXPECTED_HEALTH_CHECK_FAILED + 1, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_health_check_failed_case_2() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::health_check_failed(2);
        assert!(error_code == EXPECTED_HEALTH_CHECK_FAILED + 2, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_health_check_failed_case_3() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::health_check_failed(3);
        assert!(error_code == EXPECTED_HEALTH_CHECK_FAILED + 3, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_health_check_failed_case_4() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::health_check_failed(4);
        assert!(error_code == EXPECTED_HEALTH_CHECK_FAILED + 4, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_health_check_failed_case_0() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let error_code = errors::health_check_failed(0);
        assert!(error_code == EXPECTED_HEALTH_CHECK_FAILED + 0, 0);
        
        test_scenario::end(scenario);
    }

    // === Comprehensive Integration Test ===

    #[test]
    fun test_all_error_codes_integration() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test all basic error codes
        assert!(errors::version_mismatch() == EXPECTED_VERSION_MISMATCH, 0);
        assert!(errors::coin_does_not_have_enough_amount() == EXPECTED_INSUFFICIENT_COIN_AMOUNT, 1);
        assert!(errors::invalid_nonce() == EXPECTED_INVALID_NONCE, 2);
        assert!(errors::can_not_be_zero_address() == EXPECTED_ZERO_ADDRESS, 3);
        assert!(errors::invalid_sequence_hash() == EXPECTED_INVALID_SEQUENCE_HASH, 4);
        assert!(errors::invalid_internal_data_store() == EXPECTED_INVALID_IDS, 5);
        assert!(errors::can_not_be_zero() == EXPECTED_ZERO_VALUE, 6);
        assert!(errors::perpetual_does_not_exists() == EXPECTED_INVALID_PERPETUAL_SYMBOL, 7);
        assert!(errors::sync_already_pending() == EXPECTED_PENDING_SYNC, 8);
        assert!(errors::transaction_replay() == EXPECTED_TX_REPLAY, 9);
        assert!(errors::not_bankrupt() == EXPECTED_NOT_BANKRUPT, 10);
        assert!(errors::invalid_permission() == EXPECTED_INVALID_PERMISSION, 11);
        assert!(errors::invalid_eds() == EXPECTED_INVALID_EDS, 12);
        assert!(errors::account_does_not_exist() == EXPECTED_ACCOUNT_DOES_NOT_EXIST, 13);
        assert!(errors::insufficient_margin() == EXPECTED_INSUFFICIENT_MARGIN, 14);
        assert!(errors::perpetual_already_exists() == EXPECTED_PERPETUAL_ALREADY_EXISTS, 15);
        assert!(errors::invalid_oracle_price() == EXPECTED_INVALID_ORACLE_PRICE, 16);
        assert!(errors::already_synced() == EXPECTED_ALREADY_SYNCED, 17);
        assert!(errors::perpetuals_mismatch() == EXPECTED_PERPETUALS_MISMATCH, 18);
        assert!(errors::perpetual_delisted() == EXPECTED_DELISTED_PERPETUAL, 19);
        assert!(errors::trading_not_permitted() == EXPECTED_TRADING_NOT_PERMITTED, 20);
        assert!(errors::orders_must_be_opposite() == EXPECTED_SAME_SIDE_ORDERS, 21);
        assert!(errors::invalid_fill_price() == EXPECTED_INVALID_FILL_PRICE, 22);
        assert!(errors::expired() == EXPECTED_EXPIRED, 23);
        assert!(errors::order_overfill() == EXPECTED_OVER_FILL, 24);
        assert!(errors::invalid_trade_price() == EXPECTED_INVALID_TRADE_PRICE, 25);
        assert!(errors::invalid_quantity() == EXPECTED_INVALID_QUANTITY, 26);
        assert!(errors::mtb_breached() == EXPECTED_MTB_BREACHED, 27);
        assert!(errors::invalid_leverage() == EXPECTED_INVALID_LEVERAGE, 28);
        assert!(errors::nothing_to_sync() == EXPECTED_NOTHING_TO_SYNC, 29);
        assert!(errors::isolated_only_market() == EXPECTED_CROSS_NOT_SUPPORTED, 30);
        assert!(errors::position_does_not_exist() == EXPECTED_NO_POSITION, 31);
        assert!(errors::asset_not_supported() == EXPECTED_ASSET_NOT_SUPPORTED, 32);
        assert!(errors::invalid_operator_type() == EXPECTED_INVALID_OPERATOR_TYPE, 33);
        assert!(errors::operator_already_set() == EXPECTED_OPERATOR_ALREADY_SET, 34);
        assert!(errors::invalid_funding_time() == EXPECTED_INVALID_FUNDING_TIMESTAMP, 35);
        assert!(errors::funding_rate_exceeds_max_allowed_limit() == EXPECTED_FUNDING_RATE_EXCEEDS_LIMIT, 36);
        assert!(errors::asset_already_supported() == EXPECTED_ASSET_ALREADY_SUPPORTED, 37);
        assert!(errors::not_liquidateable() == EXPECTED_NOT_LIQUIDATEABLE, 38);
        assert!(errors::all_or_nothing() == EXPECTED_ALL_OR_NOTHING, 39);
        assert!(errors::invalid_table_type() == EXPECTED_INVALID_TABLE, 40);
        assert!(errors::trying_to_prune_non_existent_entry() == EXPECTED_INVALID_HASH_ENTRY, 41);
        assert!(errors::exceeds_lifespan() == EXPECTED_EXCEEDS_LIFESPAN, 42);
        assert!(errors::asset_type_and_symbol_mismatch() == EXPECTED_ASSET_TYPE_AND_SYMBOL_MISMATCH, 43);
        assert!(errors::missing_optional_param() == EXPECTED_MISSING_PREMIUM_DEBT_PARAM, 44);
        assert!(errors::invalid_position_for_liquidation() == EXPECTED_INVALID_LIQUIDATION_POSITION, 45);
        assert!(errors::unauthorized_liquidator() == EXPECTED_UNAUTHORIZED_LIQUIDATOR, 46);
        assert!(errors::under_water() == EXPECTED_UNDER_WATER, 47);
        assert!(errors::insufficient_position_size() == EXPECTED_INSUFFICIENT_POSITION_SIZE, 48);
        assert!(errors::negative_pnl() == EXPECTED_NOT_POSITIVE_PNL, 49);
        assert!(errors::invalid_perpetual_config() == EXPECTED_INVALID_PERPETUAL_FIELD, 50);
        assert!(errors::already_delisted() == EXPECTED_ALREADY_DELISTED, 51);
        assert!(errors::not_delisted() == EXPECTED_NOT_DELISTED, 52);
        assert!(errors::max_allowed_oi_open() == EXPECTED_MAX_ALLOWED_OI_OPEN, 53);
        assert!(errors::no_max_allowed_oi_open_for_selected_leverage() == EXPECTED_NO_MAX_OI_OPEN, 54);
        assert!(errors::self_trade() == EXPECTED_SELF_TRADE, 55);
        assert!(errors::opening_both_isolated_cross_positions_not_allowed() == EXPECTED_OPENING_BOTH_POSITION_TYPES_NOT_ALLOWED, 56);
        assert!(errors::out_of_config_value_bounds() == EXPECTED_OUT_OF_CONFIG_BOUNDS, 57);
        assert!(errors::latest_supported_contract_version() == EXPECTED_LATEST_VERSION, 58);
        assert!(errors::invalid_trade_start_time() == EXPECTED_INVALID_START_TIME, 59);
        assert!(errors::deprecated_function() == EXPECTED_DEPRECATED_FUNCTION, 60);
        assert!(errors::bad_debt() == EXPECTED_BAD_DEBT, 61);
        assert!(errors::insufficient_funds() == EXPECTED_INSUFFICIENT_FUNDS, 62);
        assert!(errors::invalid_payload_type() == EXPECTED_INVALID_PAYLOAD_TYPE, 63);
        
        // Test health check failed with different cases
        assert!(errors::health_check_failed(0) == EXPECTED_HEALTH_CHECK_FAILED + 0, 64);
        assert!(errors::health_check_failed(1) == EXPECTED_HEALTH_CHECK_FAILED + 1, 65);
        assert!(errors::health_check_failed(2) == EXPECTED_HEALTH_CHECK_FAILED + 2, 66);
        assert!(errors::health_check_failed(3) == EXPECTED_HEALTH_CHECK_FAILED + 3, 67);
        assert!(errors::health_check_failed(4) == EXPECTED_HEALTH_CHECK_FAILED + 4, 68);
        
        test_scenario::end(scenario);
    }

    // === Error Code Range Tests ===

    #[test]
    fun test_error_code_ranges() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that error codes are in expected ranges
        assert!(errors::version_mismatch() >= 1000 && errors::version_mismatch() < 2000, 0); // 1000-1999 range
        assert!(errors::invalid_payload_type() >= 1000 && errors::invalid_payload_type() < 2000, 1); // 1000-1999 range
        assert!(errors::health_check_failed(0) >= 4000 && errors::health_check_failed(0) < 5000, 2); // 4000-4999 range
        
        // Test that error codes are unique within their ranges
        assert!(errors::version_mismatch() != errors::coin_does_not_have_enough_amount(), 3);
        assert!(errors::invalid_nonce() != errors::can_not_be_zero_address(), 4);
        assert!(errors::health_check_failed(1) != errors::health_check_failed(2), 5);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_error_code_consistency() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that error codes are consistent with their expected values
        assert!(errors::version_mismatch() == 1001, 0);
        assert!(errors::invalid_payload_type() == 1066, 1);
        assert!(errors::health_check_failed(0) == 4000, 2);
        assert!(errors::health_check_failed(4) == 4004, 3);
        
        // Test that all error codes are positive
        assert!(errors::version_mismatch() > 0, 4);
        assert!(errors::invalid_payload_type() > 0, 5);
        assert!(errors::health_check_failed(0) > 0, 6);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_health_check_failed_edge_cases() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test health check failed with various cases
        assert!(errors::health_check_failed(0) == 4000, 0);
        assert!(errors::health_check_failed(1) == 4001, 1);
        assert!(errors::health_check_failed(2) == 4002, 2);
        assert!(errors::health_check_failed(3) == 4003, 3);
        assert!(errors::health_check_failed(4) == 4004, 4);
        
        // Test that different cases produce different error codes
        assert!(errors::health_check_failed(0) != errors::health_check_failed(1), 5);
        assert!(errors::health_check_failed(1) != errors::health_check_failed(2), 6);
        assert!(errors::health_check_failed(2) != errors::health_check_failed(3), 7);
        assert!(errors::health_check_failed(3) != errors::health_check_failed(4), 8);
        
        test_scenario::end(scenario);
    }
}
