module bluefin_cross_margin_dex::test_constants {
    use std::string::Self;
    use std::vector;
    use sui::test_scenario;
    use bluefin_cross_margin_dex::constants;
    use bluefin_cross_margin_dex::test_utils;

    // Test constants for validation
    const EXPECTED_VERSION: u64 = 1;
    const EXPECTED_TYPE_DEPOSIT: u8 = 0;
    const EXPECTED_TYPE_WITHDRAW: u8 = 1;
    const EXPECTED_PROTOCOL_DECIMALS: u8 = 9;
    const EXPECTED_BASE_UINT: u64 = 1000000000;
    const EXPECTED_ED25519_WALLET_SCHEME: u8 = 0;
    const EXPECTED_SECP_256K1_WALLET_SCHEME: u8 = 1;
    const EXPECTED_IMR_THRESHOLD: u8 = 0;
    const EXPECTED_MMR_THRESHOLD: u8 = 1;
    const EXPECTED_ACTION_TRADE: u8 = 1;
    const EXPECTED_ACTION_LIQUIDATE: u8 = 2;
    const EXPECTED_ACTION_DELEVERAGE: u8 = 3;
    const EXPECTED_ACTION_WITHDRAW: u8 = 4;
    const EXPECTED_ACTION_ADD_MARGIN: u8 = 5;
    const EXPECTED_ACTION_REMOVE_MARGIN: u8 = 6;
    const EXPECTED_ACTION_ADJUST_LEVERAGE: u8 = 7;
    const EXPECTED_ACTION_CLOSE_POSITION: u8 = 8;
    const EXPECTED_ACTION_ISOLATED_TRADE: u8 = 9;
    const EXPECTED_PRUNE_HISTORY: u8 = 1;
    const EXPECTED_PRUNE_ORDER_FILLS: u8 = 2;
    const EXPECTED_LIFESPAN: u64 = 7776000000; // 3 months
    const EXPECTED_MAX_VALUE_U64: u64 = 0xFFFF_FFFF_FFFF_FFFF;

    // Expected string constants
    const EXPECTED_POSITION_LONG: vector<u8> = b"LONG";
    const EXPECTED_POSITION_SHORT: vector<u8> = b"SHORT";
    const EXPECTED_POSITION_ISOLATED: vector<u8> = b"ISOLATED";
    const EXPECTED_POSITION_CROSS: vector<u8> = b"CROSS";
    const EXPECTED_EMPTY_STRING: vector<u8> = b"";
    const EXPECTED_USDC_TOKEN_SYMBOL: vector<u8> = b"USDC";

    // Expected payload types
    const EXPECTED_PAYLOAD_TYPE_LIQUIDATE: vector<u8> = b"Bluefin Pro Liquidation";
    const EXPECTED_PAYLOAD_TYPE_SETTING_FUNDING_RATE: vector<u8> = b"Bluefin Pro Setting Funding Rate";
    const EXPECTED_PAYLOAD_TYPE_PRUNING_TABLE: vector<u8> = b"Bluefin Pro Pruning Table";
    const EXPECTED_PAYLOAD_TYPE_AUTHORIZING_LIQUIDATOR: vector<u8> = b"Bluefin Pro Authorizing Liquidator";
    const EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_FEE_TIER: vector<u8> = b"Bluefin Pro Setting Account Fee Tier";
    const EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_TYPE: vector<u8> = b"Bluefin Pro Setting Account type";
    const EXPECTED_PAYLOAD_TYPE_SETTING_GAS_FEE: vector<u8> = b"Bluefin Pro Setting Gas Fee";
    const EXPECTED_PAYLOAD_TYPE_SETTING_GAS_POOL: vector<u8> = b"Bluefin Pro Setting Gas Pool";
    const EXPECTED_PAYLOAD_TYPE_ADL: vector<u8> = b"Bluefin Pro ADL";

    // Expected supported operators (individual constants to avoid implicit copy warnings)
    const EXPECTED_OPERATOR_0: vector<u8> = b"funding";
    const EXPECTED_OPERATOR_1: vector<u8> = b"fee";
    const EXPECTED_OPERATOR_2: vector<u8> = b"guardian";
    const EXPECTED_OPERATOR_3: vector<u8> = b"adl";

    // === Basic Constants Tests ===

    #[test]
    fun test_get_version() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let version = constants::get_version();
        assert!(version == EXPECTED_VERSION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_deposit_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let deposit_type = constants::deposit_type();
        assert!(deposit_type == EXPECTED_TYPE_DEPOSIT, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_withdraw_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let withdraw_type = constants::withdraw_type();
        assert!(withdraw_type == EXPECTED_TYPE_WITHDRAW, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_protocol_decimals() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let decimals = constants::protocol_decimals();
        assert!(decimals == EXPECTED_PROTOCOL_DECIMALS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_base_uint() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let base_uint = constants::base_uint();
        assert!(base_uint == EXPECTED_BASE_UINT, 0);
        
        test_scenario::end(scenario);
    }

    // === Wallet Scheme Tests ===

    #[test]
    fun test_ed25519_scheme() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let scheme = constants::ed25519_scheme();
        assert!(scheme == EXPECTED_ED25519_WALLET_SCHEME, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_secp256k1_scheme() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let scheme = constants::secp256k1_scheme();
        assert!(scheme == EXPECTED_SECP_256K1_WALLET_SCHEME, 0);
        
        test_scenario::end(scenario);
    }

    // === Threshold Tests ===

    #[test]
    fun test_imr_threshold() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let threshold = constants::imr_threshold();
        assert!(threshold == EXPECTED_IMR_THRESHOLD, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mmr_threshold() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let threshold = constants::mmr_threshold();
        assert!(threshold == EXPECTED_MMR_THRESHOLD, 0);
        
        test_scenario::end(scenario);
    }

    // === Position Type Tests ===

    #[test]
    fun test_position_long() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let position = constants::position_long();
        let expected = string::utf8(EXPECTED_POSITION_LONG);
        assert!(position == expected, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_position_short() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let position = constants::position_short();
        let expected = string::utf8(EXPECTED_POSITION_SHORT);
        assert!(position == expected, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_position_isolated() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let position = constants::position_isolated();
        let expected = string::utf8(EXPECTED_POSITION_ISOLATED);
        assert!(position == expected, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_position_cross() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let position = constants::position_cross();
        let expected = string::utf8(EXPECTED_POSITION_CROSS);
        assert!(position == expected, 0);
        
        test_scenario::end(scenario);
    }

    // === Action Type Tests ===

    #[test]
    fun test_action_trade() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_trade();
        assert!(action == EXPECTED_ACTION_TRADE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_liquidate() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_liquidate();
        assert!(action == EXPECTED_ACTION_LIQUIDATE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_deleverage() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_deleverage();
        assert!(action == EXPECTED_ACTION_DELEVERAGE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_withdraw() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_withdraw();
        assert!(action == EXPECTED_ACTION_WITHDRAW, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_add_margin() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_add_margin();
        assert!(action == EXPECTED_ACTION_ADD_MARGIN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_remove_margin() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_remove_margin();
        assert!(action == EXPECTED_ACTION_REMOVE_MARGIN, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_adjust_leverage() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_adjust_leverage();
        assert!(action == EXPECTED_ACTION_ADJUST_LEVERAGE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_close_position() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_close_position();
        assert!(action == EXPECTED_ACTION_CLOSE_POSITION, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_action_isolated_trade() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let action = constants::action_isolated_trade();
        assert!(action == EXPECTED_ACTION_ISOLATED_TRADE, 0);
        
        test_scenario::end(scenario);
    }

    // === String Constants Tests ===

    #[test]
    fun test_empty_string() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let empty = constants::empty_string();
        let expected = string::utf8(EXPECTED_EMPTY_STRING);
        assert!(empty == expected, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_usdc_token_symbol() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let symbol = constants::usdc_token_symbol();
        let expected = string::utf8(EXPECTED_USDC_TOKEN_SYMBOL);
        assert!(symbol == expected, 0);
        
        test_scenario::end(scenario);
    }

    // === Supported Operators Test ===

    #[test]
    fun test_get_supported_operators() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let operators = constants::get_supported_operators();
        assert!(vector::length(&operators) == 4, 0);
        
        // Check each operator
        assert!(*vector::borrow(&operators, 0) == string::utf8(EXPECTED_OPERATOR_0), 1);
        assert!(*vector::borrow(&operators, 1) == string::utf8(EXPECTED_OPERATOR_1), 2);
        assert!(*vector::borrow(&operators, 2) == string::utf8(EXPECTED_OPERATOR_2), 3);
        assert!(*vector::borrow(&operators, 3) == string::utf8(EXPECTED_OPERATOR_3), 4);
        
        test_scenario::end(scenario);
    }

    // === Prune Table Tests ===

    #[test]
    fun test_history_table() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let table = constants::history_table();
        assert!(table == EXPECTED_PRUNE_HISTORY, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_fills_table() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let table = constants::fills_table();
        assert!(table == EXPECTED_PRUNE_ORDER_FILLS, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lifespan() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let lifespan = constants::lifespan();
        assert!(lifespan == EXPECTED_LIFESPAN, 0);
        
        test_scenario::end(scenario);
    }

    // === Max Value Test ===

    #[test]
    fun test_max_value_u64() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let max_value = constants::max_value_u64();
        assert!(max_value == EXPECTED_MAX_VALUE_U64, 0);
        
        test_scenario::end(scenario);
    }

    // === Payload Type Tests ===

    #[test]
    fun test_payload_type_liquidate() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_liquidate();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_LIQUIDATE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_setting_funding_rate() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_setting_funding_rate();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_SETTING_FUNDING_RATE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_pruning_table() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_pruning_table();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_PRUNING_TABLE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_authorizing_liquidator() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_authorizing_liquidator();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_AUTHORIZING_LIQUIDATOR, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_setting_account_fee_tier() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_setting_account_fee_tier();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_FEE_TIER, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_setting_account_type() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_setting_account_type();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_TYPE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_setting_gas_fee() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_setting_gas_fee();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_SETTING_GAS_FEE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_setting_gas_pool() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_setting_gas_pool();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_SETTING_GAS_POOL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_type_adl() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        let payload = constants::payload_type_adl();
        assert!(payload == EXPECTED_PAYLOAD_TYPE_ADL, 0);
        
        test_scenario::end(scenario);
    }

    // === Comprehensive Integration Test ===

    #[test]
    fun test_all_constants_integration() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test all basic constants
        assert!(constants::get_version() == EXPECTED_VERSION, 0);
        assert!(constants::deposit_type() == EXPECTED_TYPE_DEPOSIT, 1);
        assert!(constants::withdraw_type() == EXPECTED_TYPE_WITHDRAW, 2);
        assert!(constants::protocol_decimals() == EXPECTED_PROTOCOL_DECIMALS, 3);
        assert!(constants::base_uint() == EXPECTED_BASE_UINT, 4);
        
        // Test wallet schemes
        assert!(constants::ed25519_scheme() == EXPECTED_ED25519_WALLET_SCHEME, 5);
        assert!(constants::secp256k1_scheme() == EXPECTED_SECP_256K1_WALLET_SCHEME, 6);
        
        // Test thresholds
        assert!(constants::imr_threshold() == EXPECTED_IMR_THRESHOLD, 7);
        assert!(constants::mmr_threshold() == EXPECTED_MMR_THRESHOLD, 8);
        
        // Test position types
        assert!(constants::position_long() == string::utf8(EXPECTED_POSITION_LONG), 9);
        assert!(constants::position_short() == string::utf8(EXPECTED_POSITION_SHORT), 10);
        assert!(constants::position_isolated() == string::utf8(EXPECTED_POSITION_ISOLATED), 11);
        assert!(constants::position_cross() == string::utf8(EXPECTED_POSITION_CROSS), 12);
        
        // Test action types
        assert!(constants::action_trade() == EXPECTED_ACTION_TRADE, 13);
        assert!(constants::action_liquidate() == EXPECTED_ACTION_LIQUIDATE, 14);
        assert!(constants::action_deleverage() == EXPECTED_ACTION_DELEVERAGE, 15);
        assert!(constants::action_withdraw() == EXPECTED_ACTION_WITHDRAW, 16);
        assert!(constants::action_add_margin() == EXPECTED_ACTION_ADD_MARGIN, 17);
        assert!(constants::action_remove_margin() == EXPECTED_ACTION_REMOVE_MARGIN, 18);
        assert!(constants::action_adjust_leverage() == EXPECTED_ACTION_ADJUST_LEVERAGE, 19);
        assert!(constants::action_close_position() == EXPECTED_ACTION_CLOSE_POSITION, 20);
        assert!(constants::action_isolated_trade() == EXPECTED_ACTION_ISOLATED_TRADE, 21);
        
        // Test string constants
        assert!(constants::empty_string() == string::utf8(EXPECTED_EMPTY_STRING), 22);
        assert!(constants::usdc_token_symbol() == string::utf8(EXPECTED_USDC_TOKEN_SYMBOL), 23);
        
        // Test prune tables
        assert!(constants::history_table() == EXPECTED_PRUNE_HISTORY, 24);
        assert!(constants::fills_table() == EXPECTED_PRUNE_ORDER_FILLS, 25);
        assert!(constants::lifespan() == EXPECTED_LIFESPAN, 26);
        
        // Test max value
        assert!(constants::max_value_u64() == EXPECTED_MAX_VALUE_U64, 27);
        
        // Test payload types
        assert!(constants::payload_type_liquidate() == EXPECTED_PAYLOAD_TYPE_LIQUIDATE, 28);
        assert!(constants::payload_type_setting_funding_rate() == EXPECTED_PAYLOAD_TYPE_SETTING_FUNDING_RATE, 29);
        assert!(constants::payload_type_pruning_table() == EXPECTED_PAYLOAD_TYPE_PRUNING_TABLE, 30);
        assert!(constants::payload_type_authorizing_liquidator() == EXPECTED_PAYLOAD_TYPE_AUTHORIZING_LIQUIDATOR, 31);
        assert!(constants::payload_type_setting_account_fee_tier() == EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_FEE_TIER, 32);
        assert!(constants::payload_type_setting_account_type() == EXPECTED_PAYLOAD_TYPE_SETTING_ACCOUNT_TYPE, 33);
        assert!(constants::payload_type_setting_gas_fee() == EXPECTED_PAYLOAD_TYPE_SETTING_GAS_FEE, 34);
        assert!(constants::payload_type_setting_gas_pool() == EXPECTED_PAYLOAD_TYPE_SETTING_GAS_POOL, 35);
        assert!(constants::payload_type_adl() == EXPECTED_PAYLOAD_TYPE_ADL, 36);
        
        // Test supported operators
        let operators = constants::get_supported_operators();
        assert!(vector::length(&operators) == 4, 41);
        
        assert!(*vector::borrow(&operators, 0) == string::utf8(EXPECTED_OPERATOR_0), 42);
        assert!(*vector::borrow(&operators, 1) == string::utf8(EXPECTED_OPERATOR_1), 43);
        assert!(*vector::borrow(&operators, 2) == string::utf8(EXPECTED_OPERATOR_2), 44);
        assert!(*vector::borrow(&operators, 3) == string::utf8(EXPECTED_OPERATOR_3), 45);
        
        test_scenario::end(scenario);
    }

    // === Edge Cases and Boundary Tests ===

    #[test]
    fun test_constants_consistency() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that deposit and withdraw types are different
        assert!(constants::deposit_type() != constants::withdraw_type(), 0);
        
        // Test that wallet schemes are different
        assert!(constants::ed25519_scheme() != constants::secp256k1_scheme(), 1);
        
        // Test that IMR and MMR thresholds are different
        assert!(constants::imr_threshold() != constants::mmr_threshold(), 2);
        
        // Test that all action types are unique
        let actions = vector::empty<u8>();
        vector::push_back(&mut actions, constants::action_trade());
        vector::push_back(&mut actions, constants::action_liquidate());
        vector::push_back(&mut actions, constants::action_deleverage());
        vector::push_back(&mut actions, constants::action_withdraw());
        vector::push_back(&mut actions, constants::action_add_margin());
        vector::push_back(&mut actions, constants::action_remove_margin());
        vector::push_back(&mut actions, constants::action_adjust_leverage());
        vector::push_back(&mut actions, constants::action_close_position());
        vector::push_back(&mut actions, constants::action_isolated_trade());
        
        // Check that all action values are unique
        let i = 0;
        while (i < vector::length(&actions)) {
            let j = i + 1;
            while (j < vector::length(&actions)) {
                assert!(*vector::borrow(&actions, i) != *vector::borrow(&actions, j), 3);
                j = j + 1;
            };
            i = i + 1;
        };
        
        // Test that prune table types are different
        assert!(constants::history_table() != constants::fills_table(), 4);
        
        // Test that position types are different
        assert!(constants::position_long() != constants::position_short(), 5);
        assert!(constants::position_isolated() != constants::position_cross(), 6);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_string_constants_properties() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that empty string is actually empty
        let empty = constants::empty_string();
        assert!(string::as_bytes(&empty) == &b"", 0);
        
        // Test that position strings are not empty
        assert!(string::as_bytes(&constants::position_long()) != &b"", 1);
        assert!(string::as_bytes(&constants::position_short()) != &b"", 2);
        assert!(string::as_bytes(&constants::position_isolated()) != &b"", 3);
        assert!(string::as_bytes(&constants::position_cross()) != &b"", 4);
        
        // Test that USDC symbol is not empty
        assert!(string::as_bytes(&constants::usdc_token_symbol()) != &b"", 5);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_payload_types_properties() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that all payload types start with "Bluefin Pro"
        let liquidate = constants::payload_type_liquidate();
        let funding_rate = constants::payload_type_setting_funding_rate();
        let pruning = constants::payload_type_pruning_table();
        
        // Check that they contain expected prefixes
        assert!(liquidate == EXPECTED_PAYLOAD_TYPE_LIQUIDATE, 0);
        assert!(funding_rate == EXPECTED_PAYLOAD_TYPE_SETTING_FUNDING_RATE, 1);
        assert!(pruning == EXPECTED_PAYLOAD_TYPE_PRUNING_TABLE, 2);
        
        // Test that payload types are not empty
        assert!(vector::length(&liquidate) > 0, 3);
        assert!(vector::length(&funding_rate) > 0, 4);
        assert!(vector::length(&pruning) > 0, 5);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_numeric_constants_properties() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        
        // Test that version is positive
        assert!(constants::get_version() > 0, 0);
        
        // Test that protocol decimals is reasonable
        assert!(constants::protocol_decimals() > 0 && constants::protocol_decimals() <= 18, 1);
        
        // Test that base uint is 10^protocol_decimals
        let expected_base = 1;
        let i = 0;
        while (i < constants::protocol_decimals()) {
            expected_base = expected_base * 10;
            i = i + 1;
        };
        assert!(constants::base_uint() == expected_base, 2);
        
        // Test that lifespan is reasonable (3 months in milliseconds)
        assert!(constants::lifespan() > 0, 3);
        
        // Test that max value is the maximum u64 value
        assert!(constants::max_value_u64() == 0xFFFF_FFFF_FFFF_FFFF, 4);
        
        test_scenario::end(scenario);
    }
}
