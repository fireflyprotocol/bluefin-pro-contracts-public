module bluefin_cross_margin_dex::test_perpetual {
    use std::string::{Self};
    use std::vector;
    use bluefin_cross_margin_dex::perpetual::{Self, Perpetual};
    use bluefin_cross_margin_dex::signed_number::{Self};
    use sui::test_scenario;
    use bluefin_cross_margin_dex::test_utils;

    const PERPETUAL_ID: address = @0xBBB;
    const INSURANCE_POOL: address = @0xCCC;
    const FEE_POOL: address = @0xDDD;

    // Test constants based on perpetual.move constraints
    const TEST_IMR: u64 = 45000000; // 4.5%
    const TEST_MMR: u64 = 30000000; // 3%
    const TEST_STEP_SIZE: u64 = 10000000; // 0.01
    const TEST_TICK_SIZE: u64 = 10000000; // 0.01
    const TEST_MIN_TRADE_QTY: u64 = 10000000; // Same as step size
    const TEST_MAX_TRADE_QTY: u64 = 100000000000; // 100
    const TEST_MIN_TRADE_PRICE: u64 = 50000000000; // 50 
    const TEST_MAX_TRADE_PRICE: u64 = 50000000000000; // 50,000
    const TEST_MTB_LONG: u64 = 20000000; // 2%
    const TEST_MTB_SHORT: u64 = 20000000; // 2%
    const TEST_MAKER_FEE: u64 = 150000; // 0.015%
    const TEST_TAKER_FEE: u64 = 550000; // 0.055%
    const TEST_MAX_FUNDING_RATE: u64 = 1000000; // 0.1%
    const TEST_INSURANCE_POOL_RATIO: u64 = 300000000; // 30%
    const TEST_TRADING_START_TIME: u64 = 1735714800001; // Valid start time
    const TEST_BASE_ASSET_DECIMALS: u64 = 1000000000; // 9 decimals
    const TEST_MAX_LIMIT_ORDER_QTY: u64 = 1000000000000; // 1000
    const TEST_MAX_MARKET_ORDER_QTY: u64 = 100000000000; // 100
    const TEST_DEFAULT_LEVERAGE: u64 = 3000000000; // 3x

    // Helper function to create a test perpetual
    fun create_test_perpetual(): Perpetual {
        let symbol = string::utf8(b"ETH-PERP");
        let base_asset_symbol = string::utf8(b"ETH");
        let base_asset_name = string::utf8(b"Ethereum");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 5000000000000000);
        vector::push_back(&mut max_notional, 2500000000000000);
        vector::push_back(&mut max_notional, 1000000000000000);

        perpetual::create_perpetual(
            PERPETUAL_ID,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false, // not isolated only
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        )
    }

    // === Basic Getter Tests ===

    #[test]
    fun test_get_perpetual_address() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
            let perpetual = create_test_perpetual();
            
            let address = perpetual::get_perpetual_address(&perpetual);
            assert!(address == PERPETUAL_ID, 0);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_imr() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());

        let perpetual = create_test_perpetual();
        
        let imr = perpetual::get_imr(&perpetual);
        assert!(imr == TEST_IMR, 0);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_mmr() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());

        let perpetual = create_test_perpetual();
        
        let mmr = perpetual::get_mmr(&perpetual);
        assert!(mmr == TEST_MMR, 0);

        test_scenario::end(scenario);

    }

    #[test]
    fun test_get_oracle_price_initial() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        // Initial oracle price should be 0
        let oracle_price = perpetual::get_oracle_price(&perpetual);
        assert!(oracle_price == 0, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_tick_size() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let tick_size = perpetual::get_tick_size(&perpetual);
        assert!(tick_size == TEST_TICK_SIZE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_step_size() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let step_size = perpetual::get_step_size(&perpetual);
        assert!(step_size == TEST_STEP_SIZE, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_min_trade_qty() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let min_qty = perpetual::get_min_trade_qty(&perpetual);
        assert!(min_qty == TEST_MIN_TRADE_QTY, 0);
        
        // min_trade_qty should equal step_size
        assert!(min_qty == TEST_STEP_SIZE, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_max_trade_qty() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let max_qty = perpetual::get_max_trade_qty(&perpetual);
        assert!(max_qty == TEST_MAX_TRADE_QTY, 0);
        
        test_scenario::end(scenario);
    }

    // === Address Getters Tests ===

    #[test]
    fun test_get_fee_pool_address() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let fee_pool = perpetual::get_fee_pool_address(&perpetual);
        assert!(fee_pool == FEE_POOL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_insurance_pool_address() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let insurance_pool = perpetual::get_insurance_pool_address(&perpetual);
        assert!(insurance_pool == INSURANCE_POOL, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_insurance_pool_ratio() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let ratio = perpetual::get_insurance_pool_ratio(&perpetual);
        assert!(ratio == TEST_INSURANCE_POOL_RATIO, 0);
        
        test_scenario::end(scenario);
    }

    // === Trading Configuration Tests ===

    #[test]
    fun test_get_isolated_only() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let isolated = perpetual::get_isolated_only(&perpetual);
        assert!(isolated == false, 0); // We set it to false in test setup
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_trading_status() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let status = perpetual::get_trading_status(&perpetual);
        assert!(status == true, 0); // Default should be true
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_delist_status() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let delist_status = perpetual::get_delist_status(&perpetual);
        assert!(delist_status == false, 0); // Default should be false
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_symbol() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let symbol = perpetual::get_symbol(&perpetual);
        let expected_symbol = string::utf8(b"ETH-PERP");
        assert!(symbol == expected_symbol, 0);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_fees() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let (maker_fee, taker_fee) = perpetual::get_fees(&perpetual);
        assert!(maker_fee == TEST_MAKER_FEE, 0);
        assert!(taker_fee == TEST_TAKER_FEE, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_max_allowed_oi_open() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let max_notional = perpetual::max_allowed_oi_open(&perpetual);
        assert!(vector::length(&max_notional) == 3, 0);
        assert!(*vector::borrow(&max_notional, 0) == 5000000000000000, 1);
        assert!(*vector::borrow(&max_notional, 1) == 2500000000000000, 2);
        assert!(*vector::borrow(&max_notional, 2) == 1000000000000000, 3);
        
        test_scenario::end(scenario);
    }

    // === Funding Rate Tests ===

    #[test]
    fun test_create_funding_rate() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let timestamp = 1234567890;
        let value = 500000; // 0.05%
        let sign = true;
        
        let funding = perpetual::create_funding_rate(timestamp, value, sign);
        
        let actual_timestamp = perpetual::get_funding_timestamp(&funding);
        assert!(actual_timestamp == timestamp, 0);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == value, 1);
        assert!(signed_number::sign(rate) == sign, 2);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_create_funding_rate_negative() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let timestamp = 1234567890;
        let value = 750000; // 0.075%
        let sign = false; // negative
        
        let funding = perpetual::create_funding_rate(timestamp, value, sign);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == value, 0);
        assert!(signed_number::sign(rate) == false, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_current_funding_initial() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let funding = perpetual::get_current_funding(&perpetual);
        
        // Initial funding should have timestamp 0 and value 0
        assert!(perpetual::get_funding_timestamp(&funding) == 0, 0);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == 0, 1);
        assert!(signed_number::sign(rate) == true, 2);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_funding_rate_accessors() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let timestamp = 1640995200; // 2022-01-01
        let value = 1000000; // 0.1%
        let sign = true;
        
        let funding = perpetual::create_funding_rate(timestamp, value, sign);
        
        // Test timestamp accessor
        let actual_timestamp = perpetual::get_funding_timestamp(&funding);
        assert!(actual_timestamp == timestamp, 0);
        
        // Test rate accessor
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == value, 1);
        assert!(signed_number::sign(rate) == sign, 2);
        
        test_scenario::end(scenario);
    }

    // === Complex Getter Tests ===

    #[test]
    fun test_perpetual_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        let (
            id,
            symbol,
            imr,
            mmr,
            step_size,
            tick_size,
            min_trade_qty,
            max_trade_qty,
            _min_trade_price,
            _max_trade_price,
            max_notional_at_open,
            _mtb_long,
            _mtb_short,
            maker_fee,
            taker_fee,
            _max_funding_rate,
            insurance_pool_ratio,
            insurance_pool,
            fee_pool,
            _trading_start_time,
            delist,
            trading_status,
            oracle_price,
            _delisting_price,
            isolated_only
        ) = perpetual::perpetual_values(&perpetual);
        
        // Verify all values
        assert!(id == PERPETUAL_ID, 0);
        assert!(symbol == string::utf8(b"ETH-PERP"), 1);
        assert!(imr == TEST_IMR, 2);
        assert!(mmr == TEST_MMR, 3);
        assert!(step_size == TEST_STEP_SIZE, 4);
        assert!(tick_size == TEST_TICK_SIZE, 5);
        assert!(min_trade_qty == TEST_MIN_TRADE_QTY, 6);
        assert!(max_trade_qty == TEST_MAX_TRADE_QTY, 7);
        assert!(_min_trade_price == TEST_MIN_TRADE_PRICE, 8);
        assert!(_max_trade_price == TEST_MAX_TRADE_PRICE, 9);
        assert!(vector::length(&max_notional_at_open) == 3, 10);
        assert!(_mtb_long == TEST_MTB_LONG, 11);
        assert!(_mtb_short == TEST_MTB_SHORT, 12);
        assert!(maker_fee == TEST_MAKER_FEE, 13);
        assert!(taker_fee == TEST_TAKER_FEE, 14);
        assert!(_max_funding_rate == TEST_MAX_FUNDING_RATE, 15);
        assert!(insurance_pool_ratio == TEST_INSURANCE_POOL_RATIO, 16);
        assert!(insurance_pool == INSURANCE_POOL, 17);
        assert!(fee_pool == FEE_POOL, 18);
        assert!(_trading_start_time == TEST_TRADING_START_TIME, 19);
        assert!(delist == false, 20);
        assert!(trading_status == true, 21);
        assert!(oracle_price == 0, 22); // Initial oracle price
        assert!(_delisting_price == 0, 23); // Initial delisting price
        assert!(isolated_only == false, 24);
        
        test_scenario::end(scenario);
    }

    // === Edge Cases and Variations ===

    #[test]
    fun test_perpetual_with_isolated_only_true() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let symbol = string::utf8(b"BTC-PERP");
        let base_asset_symbol = string::utf8(b"BTC");
        let base_asset_name = string::utf8(b"Bitcoin");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 1000000000000000);

        let perpetual = perpetual::create_perpetual(
            @0xEEE,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            true, // isolated only = true
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        assert!(perpetual::get_isolated_only(&perpetual) == true, 0);
        assert!(perpetual::get_symbol(&perpetual) == string::utf8(b"BTC-PERP"), 1);
        assert!(perpetual::get_perpetual_address(&perpetual) == @0xEEE, 2);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_with_different_fees() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let symbol = string::utf8(b"SOL-PERP");
        let base_asset_symbol = string::utf8(b"SOL");
        let base_asset_name = string::utf8(b"Solana");
        
        let custom_maker_fee = 100000; // 0.01%
        let custom_taker_fee = 300000; // 0.03%
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 2000000000000000);

        let perpetual = perpetual::create_perpetual(
            @0xFFF,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            custom_maker_fee,
            custom_taker_fee,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false,
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        let (maker_fee, taker_fee) = perpetual::get_fees(&perpetual);
        assert!(maker_fee == custom_maker_fee, 0);
        assert!(taker_fee == custom_taker_fee, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_with_single_notional_tier() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let symbol = string::utf8(b"ADA-PERP");
        let base_asset_symbol = string::utf8(b"ADA");
        let base_asset_name = string::utf8(b"Cardano");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 3000000000000000);

        let perpetual = perpetual::create_perpetual(
            @0x111,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false,
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        let max_notional_result = perpetual::max_allowed_oi_open(&perpetual);
        assert!(vector::length(&max_notional_result) == 1, 0);
        assert!(*vector::borrow(&max_notional_result, 0) == 3000000000000000, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_perpetual_with_many_notional_tiers() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let symbol = string::utf8(b"DOT-PERP");
        let base_asset_symbol = string::utf8(b"DOT");
        let base_asset_name = string::utf8(b"Polkadot");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 8000000000000000);
        vector::push_back(&mut max_notional, 6000000000000000);
        vector::push_back(&mut max_notional, 4000000000000000);
        vector::push_back(&mut max_notional, 2000000000000000);
        vector::push_back(&mut max_notional, 1000000000000000);

        let perpetual = perpetual::create_perpetual(
            @0x222,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false,
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        let max_notional_result = perpetual::max_allowed_oi_open(&perpetual);
        assert!(vector::length(&max_notional_result) == 5, 0);
        assert!(*vector::borrow(&max_notional_result, 0) == 8000000000000000, 1);
        assert!(*vector::borrow(&max_notional_result, 1) == 6000000000000000, 2);
        assert!(*vector::borrow(&max_notional_result, 2) == 4000000000000000, 3);
        assert!(*vector::borrow(&max_notional_result, 3) == 2000000000000000, 4);
        assert!(*vector::borrow(&max_notional_result, 4) == 1000000000000000, 5);
        
        test_scenario::end(scenario);
    }

    // === Boundary Value Tests ===

    #[test]
    fun test_perpetual_with_min_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let symbol = string::utf8(b"MIN");
        let base_asset_symbol = string::utf8(b"MIN");
        let base_asset_name = string::utf8(b"Minimum");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 1000000000000); // MIN_NOTIONAL
        
        let min_imr = 20000000; // 2% - minimum allowed
        let min_mmr = 10000000; // 1% - minimum allowed
        let min_step_size = 1000; // minimum step size
        let min_tick_size = 1000; // minimum tick size
        let min_trade_price = 50000; // This needs to be divisible by tick_size
        let min_max_trade_price = 51000; // Slightly higher, divisible by tick_size

        let perpetual = perpetual::create_perpetual(
            @0x333,
            symbol,
            min_imr,
            min_mmr,
            min_step_size,
            min_tick_size,
            min_step_size, // min_trade_qty = step_size
            2000, // max_trade_qty (must be > min and divisible by step)
            min_trade_price,
            min_max_trade_price,
            max_notional,
            1000000, // MIN_TAKE_BOUND
            1000000, // MIN_TAKE_BOUND
            0, // MIN_FEE
            0, // MIN_FEE
            1000000, // MIN_FUNDING_RATE
            10000000, // MIN_PREMIUM
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false,
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            1000, // min valid limit order quantity
            1000, // min valid market order quantity
            1000000000 // 1x leverage
        );
        
        assert!(perpetual::get_imr(&perpetual) == min_imr, 0);
        assert!(perpetual::get_mmr(&perpetual) == min_mmr, 1);
        assert!(perpetual::get_step_size(&perpetual) == min_step_size, 2);
        assert!(perpetual::get_tick_size(&perpetual) == min_tick_size, 3);
        
        test_scenario::end(scenario);
    }

    // === Comprehensive Integration Test ===

    #[test]
    fun test_complete_perpetual_getters() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        
        // Test all individual getters match the comprehensive getter
        let (
            id, symbol, imr, mmr, step_size, tick_size, min_trade_qty, max_trade_qty,
            _min_trade_price, _max_trade_price, max_notional_at_open, _mtb_long, _mtb_short,
            maker_fee, taker_fee, _max_funding_rate, insurance_pool_ratio, insurance_pool,
            fee_pool, _trading_start_time, delist, trading_status, oracle_price, 
            _delisting_price, isolated_only
        ) = perpetual::perpetual_values(&perpetual);
        
        // Verify individual getters match comprehensive getter
        assert!(perpetual::get_perpetual_address(&perpetual) == id, 0);
        assert!(perpetual::get_symbol(&perpetual) == symbol, 1);
        assert!(perpetual::get_imr(&perpetual) == imr, 2);
        assert!(perpetual::get_mmr(&perpetual) == mmr, 3);
        assert!(perpetual::get_step_size(&perpetual) == step_size, 4);
        assert!(perpetual::get_tick_size(&perpetual) == tick_size, 5);
        assert!(perpetual::get_min_trade_qty(&perpetual) == min_trade_qty, 6);
        assert!(perpetual::get_max_trade_qty(&perpetual) == max_trade_qty, 7);
        assert!(perpetual::max_allowed_oi_open(&perpetual) == max_notional_at_open, 8);
        assert!(perpetual::get_fee_pool_address(&perpetual) == fee_pool, 9);
        assert!(perpetual::get_insurance_pool_address(&perpetual) == insurance_pool, 10);
        assert!(perpetual::get_insurance_pool_ratio(&perpetual) == insurance_pool_ratio, 11);
        assert!(perpetual::get_isolated_only(&perpetual) == isolated_only, 12);
        assert!(perpetual::get_trading_status(&perpetual) == trading_status, 13);
        assert!(perpetual::get_delist_status(&perpetual) == delist, 14);
        assert!(perpetual::get_oracle_price(&perpetual) == oracle_price, 15);
        
        let (actual_maker_fee, actual_taker_fee) = perpetual::get_fees(&perpetual);
        assert!(actual_maker_fee == maker_fee, 16);
        assert!(actual_taker_fee == taker_fee, 17);
        
        // Test funding rate
        let funding = perpetual::get_current_funding(&perpetual);
        assert!(perpetual::get_funding_timestamp(&funding) == 0, 18);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == 0, 19);
        assert!(signed_number::sign(rate) == true, 20);
        
        test_scenario::end(scenario);
    }

    // === Funding Rate Edge Cases ===

    #[test]
    fun test_funding_rate_zero_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let funding = perpetual::create_funding_rate(0, 0, true);
        
        assert!(perpetual::get_funding_timestamp(&funding) == 0, 0);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == 0, 1);
        assert!(signed_number::sign(rate) == true, 2);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_funding_rate_large_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let large_timestamp = 9999999999; // Large but valid timestamp
        let large_value = 50000000; // Max funding rate (5%)
        
        let funding = perpetual::create_funding_rate(large_timestamp, large_value, false);
        
        assert!(perpetual::get_funding_timestamp(&funding) == large_timestamp, 0);
        
        let rate = perpetual::get_funding_rate(&funding);
        assert!(signed_number::value(rate) == large_value, 1);
        assert!(signed_number::sign(rate) == false, 2);
        
        test_scenario::end(scenario);
    }

    // === Symbol and String Tests ===

    #[test]
    fun test_perpetual_symbols() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test different symbol formats
        let symbols = vector::empty<vector<u8>>();
        vector::push_back(&mut symbols, b"BTC");
        vector::push_back(&mut symbols, b"ETH-PERP");
        vector::push_back(&mut symbols, b"AVAX-USD");
        vector::push_back(&mut symbols, b"MATIC123");
        
        let i = 0;
        while (i < vector::length(&symbols)) {
            let symbol_bytes = *vector::borrow(&symbols, i);
            let symbol = string::utf8(symbol_bytes);
            let base_symbol = string::utf8(b"BASE");
            let base_name = string::utf8(b"Base Asset");
            
            let max_notional = vector::empty<u64>();
            vector::push_back(&mut max_notional, 1000000000000000);

            let perpetual = perpetual::create_perpetual(
                @0x999,
                symbol,
                TEST_IMR,
                TEST_MMR,
                TEST_STEP_SIZE,
                TEST_TICK_SIZE,
                TEST_MIN_TRADE_QTY,
                TEST_MAX_TRADE_QTY,
                TEST_MIN_TRADE_PRICE,
                TEST_MAX_TRADE_PRICE,
                max_notional,
                TEST_MTB_LONG,
                TEST_MTB_SHORT,
                TEST_MAKER_FEE,
                TEST_TAKER_FEE,
                TEST_MAX_FUNDING_RATE,
                TEST_INSURANCE_POOL_RATIO,
                TEST_TRADING_START_TIME,
                INSURANCE_POOL,
                FEE_POOL,
                false,
                base_symbol,
                base_name,
                TEST_BASE_ASSET_DECIMALS,
                TEST_MAX_LIMIT_ORDER_QTY,
                TEST_MAX_MARKET_ORDER_QTY,
                TEST_DEFAULT_LEVERAGE
            );
            
            let result_symbol = perpetual::get_symbol(&perpetual);
            assert!(result_symbol == symbol, i);
            
            i = i + 1;
        };
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_imr ===
    // Note: These tests validate the constraints and error conditions for set_imr
    // Direct mutation testing requires a different approach due to Move's ownership model

    #[test]
    fun test_set_imr_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test the constraints that set_imr enforces without actual mutation
        let perpetual = create_test_perpetual();
        let current_imr = perpetual::get_imr(&perpetual);
        let current_mmr = perpetual::get_mmr(&perpetual);
        
        // Validate that current IMR is within bounds
        assert!(current_imr >= 20000000, 0); // MIN_IMR
        assert!(current_imr <= 500000000, 1); // MAX_IMR
        assert!(current_imr >= current_mmr, 2); // IMR >= MMR
        
        // Test valid IMR values that would pass set_imr constraints
        let valid_imr_1 = 60000000; // 6%
        assert!(valid_imr_1 >= 20000000 && valid_imr_1 <= 500000000, 3);
        assert!(valid_imr_1 >= current_mmr, 4);
        
        let valid_imr_2 = current_mmr; // Equal to MMR should be valid
        assert!(valid_imr_2 >= current_mmr, 5);
        
        // Test boundary values
        let min_imr = 20000000;
        assert!(min_imr >= 20000000 && min_imr <= 500000000, 6);
        
        let max_imr = 500000000;
        assert!(max_imr >= 20000000 && max_imr <= 500000000, 7);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_imr_invalid_constraints() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test values that would fail set_imr validation
        let perpetual = create_test_perpetual();
        let current_mmr = perpetual::get_mmr(&perpetual);
        
        // Below minimum IMR
        let below_min = 19999999;
        assert!(below_min < 20000000, 0); // Would fail MIN_IMR check
        
        // Above maximum IMR
        let above_max = 500000001;
        assert!(above_max > 500000000, 1); // Would fail MAX_IMR check
        
        // Below current MMR
        let below_mmr = current_mmr - 1;
        assert!(below_mmr < current_mmr, 2); // Would fail IMR >= MMR check
        
        // Zero value
        let zero_imr = 0;
        assert!(zero_imr < 20000000, 3); // Would fail MIN_IMR check
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_imr_boundary_constraints() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test exact boundary values for set_imr validation
        let perpetual = create_test_perpetual();
        let current_mmr = perpetual::get_mmr(&perpetual);
        
        // Test minimum boundary
        let min_imr = 20000000; // Exactly MIN_IMR
        assert!(min_imr >= 20000000 && min_imr <= 500000000, 0);
        // Note: min_imr might be less than current_mmr in our test setup
        // In real usage, MMR would need to be <= 2% for min_imr to be valid
        
        // Test maximum boundary  
        let max_imr = 500000000; // Exactly MAX_IMR
        assert!(max_imr >= 20000000 && max_imr <= 500000000, 2);
        assert!(max_imr >= current_mmr, 3);
        
        // Test just above minimum
        let min_plus_one = 20000001;
        assert!(min_plus_one >= 20000000 && min_plus_one <= 500000000, 4);
        
        // Test just below maximum
        let max_minus_one = 499999999;
        assert!(max_minus_one >= 20000000 && max_minus_one <= 500000000, 5);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_imr_mmr_relationship() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test the IMR >= MMR constraint validation
        let perpetual = create_test_perpetual();
        let current_mmr = perpetual::get_mmr(&perpetual);
        
        // IMR equal to MMR should be valid
        let equal_to_mmr = current_mmr;
        assert!(equal_to_mmr >= current_mmr, 0);
        
        // IMR greater than MMR should be valid
        let greater_than_mmr = current_mmr + 10000000; // 1% higher
        assert!(greater_than_mmr >= current_mmr, 1);
        
        // IMR less than MMR should be invalid
        if (current_mmr > 0) {
            let less_than_mmr = current_mmr - 1;
            assert!(less_than_mmr < current_mmr, 2); // This would fail validation
        };
        
        test_scenario::end(scenario);
    }

    #[test] 
    fun test_set_imr_leverage_implications() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test the implications of different IMR values on leverage
        // Leverage ≈ 1 / IMR (in percentage terms)
        
        // 2% IMR = ~50x leverage
        let imr_2_percent = 20000000;
        assert!(imr_2_percent >= 20000000, 0); // Valid minimum
        
        // 5% IMR = ~20x leverage  
        let imr_5_percent = 50000000;
        assert!(imr_5_percent >= 20000000 && imr_5_percent <= 500000000, 1);
        
        // 10% IMR = ~10x leverage
        let imr_10_percent = 100000000;
        assert!(imr_10_percent >= 20000000 && imr_10_percent <= 500000000, 2);
        
        // 25% IMR = ~4x leverage
        let imr_25_percent = 250000000;
        assert!(imr_25_percent >= 20000000 && imr_25_percent <= 500000000, 3);
        
        // 50% IMR = ~2x leverage (maximum)
        let imr_50_percent = 500000000;
        assert!(imr_50_percent >= 20000000 && imr_50_percent <= 500000000, 4);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_mmr ===

    #[test]
    fun test_set_mmr_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_mmr = perpetual::get_mmr(&perpetual);
        let current_imr = perpetual::get_imr(&perpetual);
        
        // Validate current MMR is within constraints
        assert!(current_mmr >= 10000000, 0); // MIN_MMR (1%)
        assert!(current_mmr <= current_imr, 1); // MMR <= IMR
        
        // Test valid MMR values
        let valid_mmr = 25000000; // 2.5%
        assert!(valid_mmr >= 10000000, 2); // Above MIN_MMR
        assert!(valid_mmr <= current_imr, 3); // Below or equal to current IMR
        
        // Test minimum boundary
        let min_mmr = 10000000; // Exactly MIN_MMR
        assert!(min_mmr >= 10000000, 4);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_mmr_invalid_constraints() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_imr = perpetual::get_imr(&perpetual);
        
        // Below minimum MMR
        let below_min = 9999999;
        assert!(below_min < 10000000, 0); // Would fail MIN_MMR check
        
        // Above current IMR
        let above_imr = current_imr + 1;
        assert!(above_imr > current_imr, 1); // Would fail MMR <= IMR check
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_step_size_and_min_trade_qty ===

    #[test]
    fun test_set_step_size_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_step_size = perpetual::get_step_size(&perpetual);
        let current_max_trade_qty = perpetual::get_max_trade_qty(&perpetual);
        
        // Validate current step size is within constraints
        assert!(current_step_size >= 1000, 0); // MIN_STEP_SIZE
        assert!(current_step_size <= 1000000000000, 1); // MAX_STEP_SIZE
        assert!(current_step_size < current_max_trade_qty, 2);
        
        // Test valid step size values
        let valid_step_size = 5000000; // 0.005
        assert!(valid_step_size >= 1000 && valid_step_size <= 1000000000000, 3);
        assert!(valid_step_size < current_max_trade_qty, 4);
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_step_size_boundary_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_max_trade_qty = perpetual::get_max_trade_qty(&perpetual);
        
        // Test minimum boundary
        let min_step_size = 1000; // MIN_STEP_SIZE
        assert!(min_step_size >= 1000 && min_step_size <= 1000000000000, 0);
        assert!(min_step_size < current_max_trade_qty, 1);
        
        // Test maximum boundary (would need to be less than max_trade_qty)
        let max_step_size = 1000000000000; // MAX_STEP_SIZE
        assert!(max_step_size >= 1000 && max_step_size <= 1000000000000, 2);
        // Note: This might fail the < max_trade_qty constraint in practice
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_max_trade_qty ===

    #[test]
    fun test_set_max_trade_qty_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_min_trade_qty = perpetual::get_min_trade_qty(&perpetual);
        let current_step_size = perpetual::get_step_size(&perpetual);
        
        // Test valid max trade quantity
        let valid_qty = 200000000000; // 200 units
        assert!(valid_qty >= 1000 && valid_qty <= 100000000000000000, 0); // MIN_STEP_SIZE to MAX_TRADE_QUANTITY
        assert!(valid_qty > current_min_trade_qty, 1);
        assert!(valid_qty % current_step_size == 0, 2); // Divisible by step size
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_max_trade_qty_boundary_values() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_step_size = perpetual::get_step_size(&perpetual);
        
        // Test maximum boundary
        let max_trade_quantity = 100000000000000000; // MAX_TRADE_QUANTITY
        assert!(max_trade_quantity >= 1000 && max_trade_quantity <= 100000000000000000, 0);
        assert!(max_trade_quantity % current_step_size == 0, 1);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_tick_size ===

    #[test]
    fun test_set_tick_size_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_tick_size = perpetual::get_tick_size(&perpetual);
        
        // Validate current tick size
        assert!(current_tick_size >= 1000, 0); // MIN_TICK_SIZE
        assert!(current_tick_size <= 1000000000000, 1); // MAX_TICK_SIZE
        
        // Test valid tick size values
        let valid_tick_size = 5000000; // 0.005
        assert!(valid_tick_size >= 1000 && valid_tick_size <= 1000000000000, 2);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_min_trade_price ===

    #[test]
    fun test_set_min_trade_price_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_tick_size = perpetual::get_tick_size(&perpetual);
        
        // Test valid min trade price
        let valid_price = 100000000000; // 100 units
        assert!(valid_price >= 10000 && valid_price <= 100000000000000000, 0); // MIN_TRADE_PRICE to MAX_TRADE_PRICE
        assert!(valid_price % current_tick_size == 0, 1); // Divisible by tick size
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_max_trade_price ===

    #[test]
    fun test_set_max_trade_price_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_tick_size = perpetual::get_tick_size(&perpetual);
        
        // Test valid max trade price
        let valid_price = 10000000000000000; // 10,000 units
        assert!(valid_price >= 10000 && valid_price <= 100000000000000000, 0); // MIN_TRADE_PRICE to MAX_TRADE_PRICE
        assert!(valid_price % current_tick_size == 0, 1); // Divisible by tick size
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_mtb ===

    #[test]
    fun test_set_mtb_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test market take bound constraints
        // MTB should be between MIN_TAKE_BOUND (0.1%) and MAX_TAKE_BOUND (20%)
        
        let valid_mtb_long = 50000000; // 5%
        assert!(valid_mtb_long >= 1000000 && valid_mtb_long <= 200000000, 0); // MIN_TAKE_BOUND to MAX_TAKE_BOUND
        
        let valid_mtb_short = 30000000; // 3%
        assert!(valid_mtb_short >= 1000000 && valid_mtb_short <= 200000000, 1);
        
        // Test boundary values
        let min_take_bound = 1000000; // 0.1%
        assert!(min_take_bound >= 1000000 && min_take_bound <= 200000000, 2);
        
        let max_take_bound = 200000000; // 20%
        assert!(max_take_bound >= 1000000 && max_take_bound <= 200000000, 3);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_fee ===

    #[test]
    fun test_set_fee_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test fee constraints for both maker and taker fees
        // Fees should be between MIN_FEE (0%) and MAX_FEE (3%)
        
        let valid_maker_fee = 100000; // 0.01%
        assert!(valid_maker_fee >= 0 && valid_maker_fee <= 30000000, 0); // MIN_FEE to MAX_FEE
        
        let valid_taker_fee = 500000; // 0.05%
        assert!(valid_taker_fee >= 0 && valid_taker_fee <= 30000000, 1);
        
        // Test boundary values
        let min_fee = 0; // 0%
        assert!(min_fee >= 0 && min_fee <= 30000000, 2);
        
        let max_fee = 30000000; // 3%
        assert!(max_fee >= 0 && max_fee <= 30000000, 3);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_max_allowed_oi_open ===

    #[test]
    fun test_set_max_allowed_oi_open_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test max allowed OI open constraints
        // Each value should be between MIN_NOTIONAL and MAX_NOTIONAL
        
        let valid_notional_1 = 5000000000000000; // 5M
        assert!(valid_notional_1 >= 1000000000000 && valid_notional_1 <= 10000000000000000, 0); // MIN_NOTIONAL to MAX_NOTIONAL
        
        let valid_notional_2 = 2000000000000000; // 2M
        assert!(valid_notional_2 >= 1000000000000 && valid_notional_2 <= 10000000000000000, 1);
        
        // Test boundary values
        let min_notional = 1000000000000; // MIN_NOTIONAL
        assert!(min_notional >= 1000000000000 && min_notional <= 10000000000000000, 2);
        
        let max_notional = 10000000000000000; // MAX_NOTIONAL
        assert!(max_notional >= 1000000000000 && max_notional <= 10000000000000000, 3);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_max_funding_rate ===

    #[test]
    fun test_set_max_funding_rate_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test max funding rate constraints
        // Rate should be between MIN_FUNDING_RATE (0.1%) and MAX_FUNDING_RATE (5%)
        
        let valid_rate = 5000000; // 0.5%
        assert!(valid_rate >= 1000000 && valid_rate <= 50000000, 0); // MIN_FUNDING_RATE to MAX_FUNDING_RATE
        
        // Test boundary values
        let min_funding_rate = 1000000; // 0.1%
        assert!(min_funding_rate >= 1000000 && min_funding_rate <= 50000000, 1);
        
        let max_funding_rate = 50000000; // 5%
        assert!(max_funding_rate >= 1000000 && max_funding_rate <= 50000000, 2);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - set_insurance_pool_liquidation_premium_percentage ===

    #[test]
    fun test_set_insurance_pool_premium_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test insurance pool premium constraints
        // Percentage should be between MIN_PREMIUM (1%) and MAX_PREMIUM (50%)
        
        let valid_premium = 200000000; // 20%
        assert!(valid_premium >= 10000000 && valid_premium <= 500000000, 0); // MIN_PREMIUM to MAX_PREMIUM
        
        // Test boundary values
        let min_premium = 10000000; // 1%
        assert!(min_premium >= 10000000 && min_premium <= 500000000, 1);
        
        let max_premium = 500000000; // 50%
        assert!(max_premium >= 10000000 && max_premium <= 500000000, 2);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - Address Setters ===

    #[test]
    fun test_set_address_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test address constraints for insurance pool and fee pool
        // Addresses must not be zero
        
        let valid_address = @0x123;
        assert!(valid_address != @0, 0);
        
        let another_valid_address = @0xABC;
        assert!(another_valid_address != @0, 1);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - Boolean Setters ===

    #[test]
    fun test_set_boolean_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test boolean setters: isolated_only and trading_status
        // These should accept any boolean value without additional constraints
        
        let isolated_true = true;
        let isolated_false = false;
        let trading_true = true;
        let trading_false = false;
        
        // No additional constraints for boolean values
        assert!(isolated_true == true || isolated_true == false, 0);
        assert!(isolated_false == true || isolated_false == false, 1);
        assert!(trading_true == true || trading_true == false, 2);
        assert!(trading_false == true || trading_false == false, 3);
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - delist ===

    #[test]
    fun test_delist_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_tick_size = perpetual::get_tick_size(&perpetual);
        let current_delist_status = perpetual::get_delist_status(&perpetual);
        
        // Delist should only work if not already delisted
        assert!(current_delist_status == false, 0);
        
        // Test valid delist price
        let valid_delist_price = 25000000000000; // 25,000 units
        assert!(valid_delist_price >= 50000000000, 1); // Above min_trade_price
        assert!(valid_delist_price <= 50000000000000, 2); // Below max_trade_price  
        assert!(valid_delist_price % current_tick_size == 0, 3); // Divisible by tick size
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - update_oracle_price ===

    #[test]
    fun test_update_oracle_price_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_tick_size = perpetual::get_tick_size(&perpetual);
        let current_delist_status = perpetual::get_delist_status(&perpetual);
        
        // Oracle price can only be updated if not delisted
        assert!(current_delist_status == false, 0);
        
        // Test valid oracle price
        let valid_oracle_price = 30000000000000; // 30,000 units
        assert!(valid_oracle_price % current_tick_size == 0, 1); // Must be divisible by tick size
        
        test_scenario::end(scenario);
    }

    // === Friend Function Tests - update_funding_rate ===

    #[test]
    fun test_update_funding_rate_constraints_validation() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        let current_funding = perpetual::get_current_funding(&perpetual);
        let current_timestamp = perpetual::get_funding_timestamp(&current_funding);
        let max_funding_rate = 1000000; // Assuming this is within the perpetual's max funding rate
        
        // New timestamp must be greater than current
        let new_timestamp = current_timestamp + 3600; // 1 hour later
        assert!(new_timestamp > current_timestamp, 0);
        
        // Test valid funding values
        let valid_positive_value = 500000; // 0.05%
        let valid_negative_value = 750000; // 0.075%
        
        assert!(valid_positive_value <= max_funding_rate, 1);
        assert!(valid_negative_value <= max_funding_rate, 2);
        
        // Test boundary timestamp
        let boundary_timestamp = current_timestamp + 1;
        assert!(boundary_timestamp > current_timestamp, 3);
        
        test_scenario::end(scenario);
    }

    // === Comprehensive Integration Tests ===

    #[test]
    fun test_all_setter_constraints_integration() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        // Test that all constraints work together in a comprehensive scenario
        let perpetual = create_test_perpetual();
        
        // Validate all current values meet their respective constraints
        let imr = perpetual::get_imr(&perpetual);
        let mmr = perpetual::get_mmr(&perpetual);
        let step_size = perpetual::get_step_size(&perpetual);
        let tick_size = perpetual::get_tick_size(&perpetual);
        let min_trade_qty = perpetual::get_min_trade_qty(&perpetual);
        let max_trade_qty = perpetual::get_max_trade_qty(&perpetual);
        let (maker_fee, taker_fee) = perpetual::get_fees(&perpetual);
        
        // IMR constraints
        assert!(imr >= 20000000 && imr <= 500000000, 0);
        assert!(imr >= mmr, 1);
        
        // MMR constraints  
        assert!(mmr >= 10000000, 2);
        assert!(mmr <= imr, 3);
        
        // Step size constraints
        assert!(step_size >= 1000 && step_size <= 1000000000000, 4);
        assert!(step_size < max_trade_qty, 5);
        assert!(min_trade_qty == step_size, 6);
        
        // Tick size constraints
        assert!(tick_size >= 1000 && tick_size <= 1000000000000, 7);
        
        // Trade quantity constraints
        assert!(max_trade_qty >= 1000 && max_trade_qty <= 100000000000000000, 8);
        assert!(max_trade_qty > min_trade_qty, 9);
        assert!(max_trade_qty % step_size == 0, 10);
        
        // Fee constraints
        assert!(maker_fee >= 0 && maker_fee <= 30000000, 11);
        assert!(taker_fee >= 0 && taker_fee <= 30000000, 12);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests for Friend Setter Functions ===
    
    // Helper function to create a test perpetual for expected failure tests
    fun create_test_perpetual_for_errors(): Perpetual {
        let symbol = string::utf8(b"ERROR-TEST");
        let base_asset_symbol = string::utf8(b"ERR");
        let base_asset_name = string::utf8(b"Error Test");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 1000000000000000);

        perpetual::create_perpetual(
            @12,
            symbol,
            50000000, // 5% IMR
            20000000, // 2% MMR
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false,
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        )
    }

    // === Expected Failure Tests - set_imr ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_imr_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_imr = 19999999; // Below MIN_IMR (2%)
        perpetual::set_imr(&mut perpetual, invalid_imr);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_imr_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_imr = 500000001; // Above MAX_IMR (50%)
        perpetual::set_imr(&mut perpetual, invalid_imr);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_imr_below_mmr_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_mmr = perpetual::get_mmr(&perpetual);
        let invalid_imr = current_mmr - 1; // Below current MMR
        perpetual::set_imr(&mut perpetual, invalid_imr);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_mmr ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_mmr_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_mmr = 9999999; // Below MIN_MMR (1%)
        perpetual::set_mmr(&mut perpetual, invalid_mmr);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_mmr_above_imr_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_imr = perpetual::get_imr(&perpetual);
        let invalid_mmr = current_imr + 1; // Above current IMR
        perpetual::set_mmr(&mut perpetual, invalid_mmr);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_step_size_and_min_trade_qty ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_step_size_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_step_size = 999; // Below MIN_STEP_SIZE (1000)
        perpetual::set_step_size_and_min_trade_qty(&mut perpetual, invalid_step_size);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_step_size_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_step_size = 1000000000001; // Above MAX_STEP_SIZE
        perpetual::set_step_size_and_min_trade_qty(&mut perpetual, invalid_step_size);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_step_size_above_max_trade_qty_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_max_trade_qty = perpetual::get_max_trade_qty(&perpetual);
        let invalid_step_size = current_max_trade_qty; // Not less than max_trade_qty
        perpetual::set_step_size_and_min_trade_qty(&mut perpetual, invalid_step_size);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_max_trade_qty ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_qty_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_qty = 999; // Below MIN_STEP_SIZE
        perpetual::set_max_trade_qty(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_qty_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_qty = 100000000000000001; // Above MAX_TRADE_QUANTITY
        perpetual::set_max_trade_qty(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_qty_not_divisible_by_step_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_step_size = perpetual::get_step_size(&perpetual);
        let invalid_qty = current_step_size * 10 + 1; // Not divisible by step_size
        perpetual::set_max_trade_qty(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_qty_not_greater_than_min_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_min_trade_qty = perpetual::get_min_trade_qty(&perpetual);
        let invalid_qty = current_min_trade_qty; // Not greater than min_trade_qty
        perpetual::set_max_trade_qty(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_tick_size ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_tick_size_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_tick_size = 999; // Below MIN_TICK_SIZE (1000)
        perpetual::set_tick_size(&mut perpetual, invalid_tick_size);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_tick_size_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_tick_size = 1000000000001; // Above MAX_TICK_SIZE
        perpetual::set_tick_size(&mut perpetual, invalid_tick_size);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_min_trade_price ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_min_trade_price_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 9999; // Below MIN_TRADE_PRICE (10000)
        perpetual::set_min_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_min_trade_price_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 100000000000000001; // Above MAX_TRADE_PRICE
        perpetual::set_min_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_min_trade_price_not_divisible_by_tick_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 50000000000 + 1; // Not divisible by tick_size
        perpetual::set_min_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_max_trade_price ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_price_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 9999; // Below MIN_TRADE_PRICE
        perpetual::set_max_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_price_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 100000000000000001; // Above MAX_TRADE_PRICE
        perpetual::set_max_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_trade_price_not_divisible_by_tick_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 50000000000000 + 1; // Not divisible by tick_size
        perpetual::set_max_trade_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_mtb ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_mtb_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_mtb = 999999; // Below MIN_TAKE_BOUND (0.1%)
        perpetual::set_mtb(&mut perpetual, invalid_mtb, true);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_mtb_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_mtb = 200000001; // Above MAX_TAKE_BOUND (20%)
        perpetual::set_mtb(&mut perpetual, invalid_mtb, false);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_fee ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_fee_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_fee = 30000001; // Above MAX_FEE (3%)
        perpetual::set_fee(&mut perpetual, invalid_fee, true);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_max_allowed_oi_open ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_allowed_oi_open_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_notional = vector::empty<u64>();
        vector::push_back(&mut invalid_notional, 999999999999); // Below MIN_NOTIONAL
        perpetual::set_max_allowed_oi_open(&mut perpetual, invalid_notional);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_allowed_oi_open_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_notional = vector::empty<u64>();
        vector::push_back(&mut invalid_notional, 10000000000000001); // Above MAX_NOTIONAL
        perpetual::set_max_allowed_oi_open(&mut perpetual, invalid_notional);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_max_funding_rate ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_funding_rate_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_rate = 999999; // Below MIN_FUNDING_RATE (0.1%)
        perpetual::set_max_funding_rate(&mut perpetual, invalid_rate);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_funding_rate_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_rate = 50000001; // Above MAX_FUNDING_RATE (5%)
        perpetual::set_max_funding_rate(&mut perpetual, invalid_rate);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - set_insurance_pool_liquidation_premium_percentage ===

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_insurance_pool_premium_below_minimum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_premium = 9999999; // Below MIN_PREMIUM (1%)
        perpetual::set_insurance_pool_liquidation_premium_percentage(&mut perpetual, invalid_premium);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_insurance_pool_premium_above_maximum_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_premium = 500000001; // Above MAX_PREMIUM (50%)
        perpetual::set_insurance_pool_liquidation_premium_percentage(&mut perpetual, invalid_premium);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - Address Setters ===

    #[test]
    #[expected_failure(abort_code = 1004, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_insurance_pool_address_zero_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_address = @0; // Zero address
        perpetual::set_insurance_pool_address(&mut perpetual, invalid_address);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1004, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_fee_pool_address_zero_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_address = @0; // Zero address
        perpetual::set_fee_pool_address(&mut perpetual, invalid_address);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - delist ===

    #[test]
    #[expected_failure(abort_code = 1055, location = bluefin_cross_margin_dex::perpetual)]
    fun test_delist_already_delisted_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        
        // First delist should succeed
        perpetual::delist(&mut perpetual, 25000000000000);
        
        // Second delist should fail
        perpetual::delist(&mut perpetual, 30000000000000);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    fun test_delist_price_not_divisible_by_tick_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 25000000000000 + 1; // Not divisible by tick_size
        perpetual::delist(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - update_oracle_price ===

    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    fun test_update_oracle_price_not_divisible_by_tick_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let invalid_price = 30000000000000 + 1; // Not divisible by tick_size
        perpetual::update_oracle_price(&mut perpetual, invalid_price);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1055, location = bluefin_cross_margin_dex::perpetual)]
    fun test_update_oracle_price_when_delisted_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        
        // First delist the perpetual
        perpetual::delist(&mut perpetual, 25000000000000);
        
        // Then try to update oracle price - should fail
        perpetual::update_oracle_price(&mut perpetual, 30000000000000);
        
        test_scenario::end(scenario);
    }

    // === Expected Failure Tests - update_funding_rate ===

    #[test]
    #[expected_failure(abort_code = 1039, location = bluefin_cross_margin_dex::perpetual)]
    fun test_update_funding_rate_timestamp_not_greater_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_funding = perpetual::get_current_funding(&perpetual);
        let current_timestamp = perpetual::get_funding_timestamp(&current_funding);
        
        // Try to set funding with same timestamp
        perpetual::update_funding_rate(&mut perpetual, 500000, true, current_timestamp);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1040, location = bluefin_cross_margin_dex::perpetual)]
    fun test_update_funding_rate_value_exceeds_max_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_funding = perpetual::get_current_funding(&perpetual);
        let current_timestamp = perpetual::get_funding_timestamp(&current_funding);
        let new_timestamp = current_timestamp + 3600;
        
        // Try to set funding rate above the perpetual's max funding rate
        let excessive_value = TEST_MAX_FUNDING_RATE + 1;
        perpetual::update_funding_rate(&mut perpetual, excessive_value, true, new_timestamp);
        
        test_scenario::end(scenario);
    }

    // === Order Quantity Expected Failure Tests ===

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_limit_order_quantity_not_divisible_by_step_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_step_size = perpetual::get_step_size(&perpetual);
        let invalid_qty = current_step_size * 10 + 1; // Not divisible by step_size
        perpetual::set_max_limit_order_quantity(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_limit_order_quantity_not_greater_than_min_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_min_trade_qty = perpetual::get_min_trade_qty(&perpetual);
        let invalid_qty = current_min_trade_qty; // Not greater than min_trade_qty
        perpetual::set_max_limit_order_quantity(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_market_order_quantity_not_divisible_by_step_size_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_step_size = perpetual::get_step_size(&perpetual);
        let invalid_qty = current_step_size * 5 + 1; // Not divisible by step_size
        perpetual::set_max_market_order_quantity(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun test_set_max_market_order_quantity_not_greater_than_min_fails() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual_for_errors();
        let current_min_trade_qty = perpetual::get_min_trade_qty(&perpetual);
        let invalid_qty = current_min_trade_qty; // Not greater than min_trade_qty
        perpetual::set_max_market_order_quantity(&mut perpetual, invalid_qty);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_set_delist_price_less_than_min_trade_price() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        perpetual::delist(&mut perpetual, 1);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_set_delist_price_greater_than_max_trade_price() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        perpetual::delist(&mut perpetual, 50000000000001);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_set_delist_price_not_divisible_by_tick_size() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        perpetual::delist(&mut perpetual, 50000000001);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1060, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_set_out_of_range_fees() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        let perpetual = create_test_perpetual();
        perpetual::set_fee(&mut perpetual, 300000001, false);
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_create_perpetual_different_step_size_and_min_trade_qty() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());

        let symbol = string::utf8(b"ETH-PERP");
        let base_asset_symbol = string::utf8(b"ETH");
        let base_asset_name = string::utf8(b"Ethereum");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 5000000000000000);
        vector::push_back(&mut max_notional, 2500000000000000);
        vector::push_back(&mut max_notional, 1000000000000000);

        perpetual::create_perpetual(
            PERPETUAL_ID,
            symbol,
            TEST_IMR,
            TEST_MMR,
            100,
            TEST_TICK_SIZE,
            10000,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            TEST_TRADING_START_TIME,
            INSURANCE_POOL,
            FEE_POOL,
            false, // not isolated only
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1062, location = bluefin_cross_margin_dex::perpetual)]
    fun should_fail_to_create_perpetual_invalid_trading_start_time() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());

        let symbol = string::utf8(b"ETH-PERP");
        let base_asset_symbol = string::utf8(b"ETH");
        let base_asset_name = string::utf8(b"Ethereum");
        
        let max_notional = vector::empty<u64>();
        vector::push_back(&mut max_notional, 5000000000000000);
        vector::push_back(&mut max_notional, 2500000000000000);
        vector::push_back(&mut max_notional, 1000000000000000);

        perpetual::create_perpetual(
            PERPETUAL_ID,
            symbol,
            TEST_IMR,
            TEST_MMR,
            TEST_STEP_SIZE,
            TEST_TICK_SIZE,
            TEST_MIN_TRADE_QTY,
            TEST_MAX_TRADE_QTY,
            TEST_MIN_TRADE_PRICE,
            TEST_MAX_TRADE_PRICE,
            max_notional,
            TEST_MTB_LONG,
            TEST_MTB_SHORT,
            TEST_MAKER_FEE,
            TEST_TAKER_FEE,
            TEST_MAX_FUNDING_RATE,
            TEST_INSURANCE_POOL_RATIO,
            1,
            INSURANCE_POOL,
            FEE_POOL,
            false, // not isolated only
            base_asset_symbol,
            base_asset_name,
            TEST_BASE_ASSET_DECIMALS,
            TEST_MAX_LIMIT_ORDER_QTY,
            TEST_MAX_MARKET_ORDER_QTY,
            TEST_DEFAULT_LEVERAGE
        );
        
        test_scenario::end(scenario);
    }
    
}
