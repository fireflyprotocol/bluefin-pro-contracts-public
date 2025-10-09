module bluefin_cross_margin_dex::test_utils {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::admin::{Self,AdminCap};
    use bluefin_cross_margin_dex::data_store::{Self,ExternalDataStore, InternalDataStore};
    use bluefin_cross_margin_dex::bank::{Self,Asset};
    use bluefin_cross_margin_dex::utils;
    use bluefin_cross_margin_dex::bcs_handler;
    use bluefin_cross_margin_dex::exchange;
    use bluefin_cross_margin_dex::account;
    use bluefin_cross_margin_dex::perpetual::FundingRate;
    use std::option::{Self,Option};
    use std::string::{Self,String};
    use std::vector;
    use std::bcs;
    use sui::coin;

    
    const PROTOCOL_ADMIN: address = @0x1;
    const PROTOCOL_GUARDIAN: address = @0x3a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e;
    const PROTOCOL_SEQUENCER: address = @0x3;
    const FEE_POOL: address = @0x4;
    const INSURANCE_POOL: address = @0x5;
    const MAKER: address = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
    const TAKER: address = @0x2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29;

    const TRADE_START_TIME: u64 = 1735714800001;


    struct USDC {}
    struct SUI {}

    public fun protocol_admin(): address {
        PROTOCOL_ADMIN
    }

    public fun protocol_guardian(): address {
        PROTOCOL_GUARDIAN
    }

    public fun protocol_sequencer(): address {
        PROTOCOL_SEQUENCER
    }

    public fun trade_start_time(): u64 {
        TRADE_START_TIME
    }

    public fun fee_pool(): address {
        FEE_POOL
    }

    public fun insurance_pool(): address {
        INSURANCE_POOL
    }

    public fun maker(): address {
        MAKER
    }

    public fun taker(): address {
        TAKER
    }

    #[test]
    public fun should_round_down_the_number() {

        let number = 1200000000;
        let scale = 1000000000;

        let rounded_number = utils::round(number, scale);
        assert!(rounded_number == 1000000000, 0);
    }

    #[test]
    public fun should_round_down_the_number_2() {

        let number = 1500000000;
        let scale = 1000000000;

        let rounded_number = utils::round(number, scale);
        assert!(rounded_number == 1000000000, 0);
    }

    #[test]
    public fun should_round_up_the_number_2() {

        let number = 1500000001;
        let scale = 1000000000;

        let rounded_number = utils::round(number, scale);
        assert!(rounded_number == 2000000000, 0);
    }


    #[test]
    fun test_round_up_to_tick_size() {
        assert!(utils::round_up_to_tick_size(123, 10) == 130, 0);
        assert!(utils::round_up_to_tick_size(120, 10) == 120, 1);
        assert!(utils::round_up_to_tick_size(0, 10) == 0, 2);
        assert!(utils::round_up_to_tick_size(5, 0) == 5, 3);
        assert!(utils::round_up_to_tick_size(123, 100) == 200, 4);
    }

    /// Round down a value to the nearest tick size
    /// Example: if tick_size is 10 and value is 123, it will return 120
    /// @param value: The value to round down
    /// @param tick_size: The tick size to round down to
    /// @return The rounded down value


    #[test]
    fun test_round_down_to_tick_size() {
        assert!(utils::round_down_to_tick_size(123, 10) == 120, 0);
        assert!(utils::round_down_to_tick_size(120, 10) == 120, 1);
        assert!(utils::round_down_to_tick_size(0, 10) == 0, 2);
        assert!(utils::round_down_to_tick_size(5, 0) == 5, 3);
        assert!(utils::round_down_to_tick_size(123, 100) == 100, 4);
    }

    #[test]
    fun test_round_to_tick_size_based_on_direction() {

        // Long side cases (rounds up)
        assert!(utils::round_to_tick_size_based_on_direction(123, 10, true) == 130, 1);
        assert!(utils::round_to_tick_size_based_on_direction(120, 10, true) == 120, 2);
        assert!(utils::round_to_tick_size_based_on_direction(0, 10, true) == 0, 3);
        assert!(utils::round_to_tick_size_based_on_direction(999, 100, true) == 1000, 4);
        assert!(utils::round_to_tick_size_based_on_direction(7_777_777_777, 10_000_000, true) == 7_780_000_000, 5);

        // Short side cases (rounds down)
        assert!(utils::round_to_tick_size_based_on_direction(123, 10, false) == 120, 6);
        assert!(utils::round_to_tick_size_based_on_direction(120, 10, false) == 120, 7);
        assert!(utils::round_to_tick_size_based_on_direction(0, 10, false) == 0, 8);
        assert!(utils::round_to_tick_size_based_on_direction(999, 100, false) == 900, 9);
        assert!(utils::round_to_tick_size_based_on_direction(7_777_777_777, 10_000_000, false) == 7_770_000_000, 10);


        // Edge cases for both sides
        assert!(utils::round_to_tick_size_based_on_direction(1, 1, true) == 1, 11);
        assert!(utils::round_to_tick_size_based_on_direction(1, 1, false) == 1, 12);


        let max_u64: u64 = 0xffffffffffffffff;

        assert!(utils::round_to_tick_size_based_on_direction(max_u64 - 5, 10, true) == max_u64 - (max_u64 % 10), 13);
        assert!(utils::round_to_tick_size_based_on_direction(max_u64 - 5, 10, false) == max_u64 - (max_u64 % 10), 14);


        // Zero precision cases (should return original value)
        assert!(utils::round_to_tick_size_based_on_direction(123, 0, true) == 123, 15);
        assert!(utils::round_to_tick_size_based_on_direction(123, 0, false) == 123, 16);
    }


    // === Decimal Conversion Tests ===

    #[test]
    fun test_convert_to_protocol_decimals_higher_to_lower() {
        // Convert from 18 decimals to 9 decimals (protocol)
        let value = 1000000000000000000; // 1.0 in 18 decimals
        let result = utils::convert_to_protocol_decimals(value, 18);
        assert!(result == 1000000000, 0); // Should be 1.0 in 9 decimals

        // Convert from 12 decimals to 9 decimals
        let value2 = 123456789000; // 123.456789 in 12 decimals
        let result2 = utils::convert_to_protocol_decimals(value2, 12);
        assert!(result2 == 123456789, 1); // Should be 123.456789 in 9 decimals

        // Test with very large number
        let value3 = 999999999999999999; // 0.999999999999999999 in 18 decimals
        let result3 = utils::convert_to_protocol_decimals(value3, 18);
        assert!(result3 == 999999999, 2); // Should be 0.999999999 in 9 decimals
    }

    #[test]
    fun test_convert_to_protocol_decimals_lower_to_higher() {
        // Convert from 6 decimals (USDC) to 9 decimals (protocol)
        let value = 1000000; // 1.0 in 6 decimals
        let result = utils::convert_to_protocol_decimals(value, 6);
        assert!(result == 1000000000, 0); // Should be 1.0 in 9 decimals

        // Convert from 2 decimals to 9 decimals
        let value2 = 12345; // 123.45 in 2 decimals
        let result2 = utils::convert_to_protocol_decimals(value2, 2);
        assert!(result2 == 123450000000, 1); // Should be 123.45 in 9 decimals

        // Test with zero
        let value3 = 0;
        let result3 = utils::convert_to_protocol_decimals(value3, 6);
        assert!(result3 == 0, 2);
    }

    #[test]
    fun test_convert_to_protocol_decimals_equal_decimals() {
        // Convert from 9 decimals to 9 decimals (no change)
        let value = 1234567890; // 1.234567890 in 9 decimals
        let result = utils::convert_to_protocol_decimals(value, 9);
        assert!(result == 1234567890, 0); // Should remain the same

        // Test with zero
        let value2 = 0;
        let result2 = utils::convert_to_protocol_decimals(value2, 9);
        assert!(result2 == 0, 1);
    }

    #[test]
    fun test_convert_to_provided_decimals_lower_decimals() {
        // Convert from protocol (9 decimals) to 6 decimals (USDC)
        let value = 1000000000; // 1.0 in 9 decimals
        let result = utils::convert_to_provided_decimals(value, 6);
        assert!(result == 1000000, 0); // Should be 1.0 in 6 decimals

        // Convert to 2 decimals
        let value2 = 123450000000; // 123.45 in 9 decimals
        let result2 = utils::convert_to_provided_decimals(value2, 2);
        assert!(result2 == 12345, 1); // Should be 123.45 in 2 decimals
    }

    #[test]
    fun test_convert_to_provided_decimals_higher_decimals() {
        // Convert from protocol (9 decimals) to 18 decimals
        let value = 1000000000; // 1.0 in 9 decimals
        let result = utils::convert_to_provided_decimals(value, 18);
        assert!(result == 1000000000000000000, 0); // Should be 1.0 in 18 decimals

        // Convert to 12 decimals
        let value2 = 123456789; // 0.123456789 in 9 decimals
        let result2 = utils::convert_to_provided_decimals(value2, 12);
        assert!(result2 == 123456789000, 1); // Should be 0.123456789 in 12 decimals
    }

    #[test]
    fun test_convert_to_provided_decimals_equal_decimals() {
        // Convert from 9 decimals to 9 decimals (no change)
        let value = 1234567890; // 1.234567890 in 9 decimals
        let result = utils::convert_to_provided_decimals(value, 9);
        assert!(result == 1234567890, 0); // Should remain the same
    }

    // === Base Arithmetic Tests ===

    #[test]
    fun test_base_mul() {
        let base = 1000000000; // constants::base_uint()
        
        // Test 1.0 * 1.0 = 1.0
        let result1 = utils::base_mul(base, base);
        assert!(result1 == base, 0);

        // Test 2.0 * 3.0 = 6.0
        let result2 = utils::base_mul(2 * base, 3 * base);
        assert!(result2 == 6 * base, 1);

        // Test 0.5 * 2.0 = 1.0
        let result3 = utils::base_mul(base / 2, 2 * base);
        assert!(result3 == base, 2);

        // Test with zero
        let result4 = utils::base_mul(0, base);
        assert!(result4 == 0, 3);

        // Test fractional multiplication: 0.1 * 0.1 = 0.01
        let result5 = utils::base_mul(base / 10, base / 10);
        assert!(result5 == base / 100, 4);
    }

    #[test]
    fun test_base_div() {
        let base = 1000000000; // constants::base_uint()
        
        // Test 1.0 / 1.0 = 1.0
        let result1 = utils::base_div(base, base);
        assert!(result1 == base, 0);

        // Test 6.0 / 2.0 = 3.0
        let result2 = utils::base_div(6 * base, 2 * base);
        assert!(result2 == 3 * base, 1);

        // Test 1.0 / 2.0 = 0.5
        let result3 = utils::base_div(base, 2 * base);
        assert!(result3 == base / 2, 2);

        // Test 0 / anything = 0
        let result4 = utils::base_div(0, base);
        assert!(result4 == 0, 3);

        // Test 1.0 / 0.1 = 10.0
        let result5 = utils::base_div(base, base / 10);
        assert!(result5 == 10 * base, 4);
    }

    #[test]
    fun test_mul_div_uint() {
        // Test (10 * 20) / 4 = 50
        let result1 = utils::mul_div_uint(10, 20, 4);
        assert!(result1 == 50, 0);

        // Test (100 * 200) / 50 = 400
        let result2 = utils::mul_div_uint(100, 200, 50);
        assert!(result2 == 400, 1);

        // Test with zero multiplication
        let result3 = utils::mul_div_uint(0, 100, 10);
        assert!(result3 == 0, 2);

        // Test (1000000 * 1000000) / 1000000 = 1000000
        let result4 = utils::mul_div_uint(1000000, 1000000, 1000000);
        assert!(result4 == 1000000, 3);

        // Test precision with large numbers
        let result5 = utils::mul_div_uint(999999999999, 999999999999, 999999999999);
        assert!(result5 == 999999999999, 4);
    }

    // === String Utility Tests ===

    #[test]
    fun test_is_empty_string() {
        // Test empty string
        let empty_str = string::utf8(b"");
        assert!(utils::is_empty_string(empty_str) == true, 0);

        // Test non-empty string
        let non_empty_str = string::utf8(b"hello");
        assert!(utils::is_empty_string(non_empty_str) == false, 1);

        // Test single character string
        let single_char = string::utf8(b"a");
        assert!(utils::is_empty_string(single_char) == false, 2);

        // Test string with space
        let space_str = string::utf8(b" ");
        assert!(utils::is_empty_string(space_str) == false, 3);
    }

    // === Trading Logic Tests ===

    #[test]
    fun test_is_reducing_trade_same_direction() {
        // Same direction trades are not reducing
        // Long position, long trade
        assert!(utils::is_reducing_trade(true, 100, true, 50) == false, 0);
        
        // Short position, short trade
        assert!(utils::is_reducing_trade(false, 100, false, 50) == false, 1);
    }

    #[test]
    fun test_is_reducing_trade_opposite_direction_reducing() {
        // Opposite direction with trade size <= position size (reducing)
        // Long position, short trade that reduces
        assert!(utils::is_reducing_trade(true, 100, false, 50) == true, 0);
        assert!(utils::is_reducing_trade(true, 100, false, 100) == true, 1);
        
        // Short position, long trade that reduces
        assert!(utils::is_reducing_trade(false, 100, true, 50) == true, 2);
        assert!(utils::is_reducing_trade(false, 100, true, 100) == true, 3);
    }

    #[test]
    fun test_is_reducing_trade_opposite_direction_expanding() {
        // Opposite direction with trade size > position size (expanding/flipping)
        // Long position, short trade that exceeds position
        assert!(utils::is_reducing_trade(true, 100, false, 150) == false, 0);
        
        // Short position, long trade that exceeds position
        assert!(utils::is_reducing_trade(false, 100, true, 150) == false, 1);
    }

    #[test]
    fun test_is_reducing_trade_edge_cases() {
        // Zero position size
        assert!(utils::is_reducing_trade(true, 0, false, 50) == false, 0);
        assert!(utils::is_reducing_trade(false, 0, true, 50) == false, 1);
        
        // Zero trade size
        assert!(utils::is_reducing_trade(true, 100, false, 0) == true, 2);
        assert!(utils::is_reducing_trade(false, 100, true, 0) == true, 3);
        
        // Both zero with different directions (technically reducing)
        assert!(utils::is_reducing_trade(true, 0, false, 0) == true, 4);
    }

    // === Precision and Edge Case Tests ===

    #[test]
    fun test_base_arithmetic_precision() {
        let base = 1000000000;
        
        // Test that (a * b) / b ≈ a (within rounding error)
        let a = 123456789;
        let b = 987654321;
        let product = utils::base_mul(a, b);
        let result = utils::base_div(product, b);
        // Allow for small rounding error
        assert!(result >= a - 1 && result <= a + 1, 0);
        
        // Test chain operations
        let intermediate = utils::base_mul(base, 5);  // 5.0
        let final_result = utils::base_div(intermediate, 5); // Should be ~1.0
        assert!(final_result == base, 1);
    }

    #[test]
    fun test_decimal_conversion_roundtrip() {
        // Test that converting to protocol decimals and back preserves value
        let original = 1234567; // 1.234567 in 6 decimals
        let protocol_value = utils::convert_to_protocol_decimals(original, 6);
        let back_to_original = utils::convert_to_provided_decimals(protocol_value, 6);
        assert!(back_to_original == original, 0);
        
        // Test with 18 decimals (use value that preserves precision)
        let original18 = 1234567890000000000; // Value that converts cleanly
        let protocol_value18 = utils::convert_to_protocol_decimals(original18, 18);
        let back_to_original18 = utils::convert_to_provided_decimals(protocol_value18, 18);
        assert!(back_to_original18 == original18, 1);
    }

    #[test]
    fun test_large_number_handling() {
        // Test with very large numbers (near u64 max)
        let large_num = 18446744073709551615; // u64::MAX
        
        // Test mul_div_uint with large numbers
        let result = utils::mul_div_uint(large_num / 1000, 500, 1000);
        assert!(result == large_num / 2000, 0);
        
        // Test base operations don't overflow
        let base = 1000000000;
        let large_base_num = large_num / base; // Convert to base units
        let mul_result = utils::base_mul(large_base_num, base / 1000); // Small multiplier
        assert!(mul_result < large_num, 1); // Should not overflow
    }



        #[test_only]
    public fun init_package_for_testing(scenario: &mut Scenario){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            admin::test_init(test_scenario::ctx(scenario));
            data_store::test_init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, PROTOCOL_ADMIN);
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                10000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(PROTOCOL_ADMIN, admin_cap);
        };

        sync_supported_asset(scenario, b"USDC");

        create_perpetual(
            scenario,
             option::none<String>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<vector<u64>>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<address>(),
             option::none<address>(),
             option::none<bool>(),
             option::none<vector<u8>>(),
             option::none<vector<u8>>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             option::none<u64>(),
             );


        sync_perpetual(scenario, b"ETH-PERP");

        set_operator(scenario, b"guardian", PROTOCOL_GUARDIAN);
        sync_operator(scenario, b"guardian", PROTOCOL_GUARDIAN);

        set_operator(scenario, b"fee", PROTOCOL_GUARDIAN);
        sync_operator(scenario, b"fee", PROTOCOL_GUARDIAN);

        set_operator(scenario, b"funding", PROTOCOL_GUARDIAN);
        sync_operator(scenario, b"funding", PROTOCOL_GUARDIAN);

        set_operator(scenario, b"adl", PROTOCOL_GUARDIAN);
        sync_operator(scenario, b"adl", PROTOCOL_GUARDIAN);

    }


    #[test_only]
    public fun create_perpetual(scenario: &mut Scenario, symbol: Option<String>, imr: Option<u64>, mmr: Option<u64>, step_size: Option<u64>, tick_size: Option<u64>, min_trade_qty: Option<u64>, max_trade_qty: Option<u64>, min_trade_price: Option<u64>, max_trade_price: Option<u64>, max_notional_at_open: Option<vector<u64>>, mtb_long: Option<u64>, mtb_short: Option<u64>, maker_fee: Option<u64>, taker_fee: Option<u64>, max_funding_rate: Option<u64>, insurance_pool_ratio: Option<u64>, trading_start_time: Option<u64>, insurance_pool: Option<address>, fee_pool: Option<address>, isolated_only: Option<bool>, base_asset_symbol: Option<vector<u8>>, base_asset_name: Option<vector<u8>>, base_asset_decimals: Option<u64>, max_limit_order_quantity: Option<u64>, max_market_order_quantity: Option<u64>, default_leverage: Option<u64>){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, PROTOCOL_ADMIN);
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            let notion = vector::empty<u64>();
            vector::push_back(&mut notion, 5000000000000000);
            vector::push_back(&mut notion, 5000000000000000);
            vector::push_back(&mut notion, 2500000000000000);
            vector::push_back(&mut notion, 2500000000000000);
            vector::push_back(&mut notion, 2500000000000000);
            vector::push_back(&mut notion, 2500000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);   
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);
            vector::push_back(&mut notion, 1000000000000000);

            let symbol = option::get_with_default(&symbol, string::utf8(b"ETH-PERP"));
            
            let imr = option::get_with_default(&imr, 45000000);
            let mmr = option::get_with_default(&mmr, 30000000);
            let step_size = option::get_with_default(&step_size, 10000000);
            let tick_size = option::get_with_default(&tick_size, 10000000);
            let min_trade_qty = option::get_with_default(&min_trade_qty, 10000000);
            let max_trade_qty = option::get_with_default(&max_trade_qty, 100000000000);
            let min_trade_price = option::get_with_default(&min_trade_price, 50000000000);
            let max_trade_price = option::get_with_default(&max_trade_price, 50000000000000);
            let max_notional_at_open = option::get_with_default(&max_notional_at_open, notion);
            let mtb_long = option::get_with_default(&mtb_long, 20000000);
            let mtb_short = option::get_with_default(&mtb_short, 20000000);
            let maker_fee = option::get_with_default(&maker_fee, 150000);
            let taker_fee = option::get_with_default(&taker_fee, 550000);
            let max_funding_rate = option::get_with_default(&max_funding_rate, 1000000);
            let insurance_pool_ratio = option::get_with_default(&insurance_pool_ratio, 300000000);
            let trading_start_time = option::get_with_default(&trading_start_time, TRADE_START_TIME);
            let insurance_pool = option::get_with_default(&insurance_pool, INSURANCE_POOL);
            let fee_pool = option::get_with_default(&fee_pool, FEE_POOL);

            let isolated_only = option::get_with_default(&isolated_only, false);
            let base_asset_symbol = option::get_with_default(&base_asset_symbol, b"ETH");
            let base_asset_name = option::get_with_default(&base_asset_name, b"Ethereum");
            let base_asset_decimals = option::get_with_default(&base_asset_decimals, 1000000000);
            let max_limit_order_quantity = option::get_with_default(&max_limit_order_quantity, 1000000000000);
            let max_market_order_quantity = option::get_with_default(&max_market_order_quantity, 100000000000);
            let default_leverage = option::get_with_default(&default_leverage, 3000000000);



            data_store::create_perpetual(
                &admin_cap,
                &mut eds,
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
                fee_pool,
                isolated_only,
                base_asset_symbol,
                base_asset_name,
                base_asset_decimals,
                max_limit_order_quantity,
                max_market_order_quantity,
                default_leverage,
                test_scenario::ctx(scenario)
                );


            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(PROTOCOL_ADMIN, admin_cap);
        };
    }


    #[test_only]
    public fun set_eds_version(scenario: &mut Scenario, version: u64){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, PROTOCOL_ADMIN);
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            data_store::set_eds_version(&mut eds, version);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(PROTOCOL_ADMIN, admin_cap);
        };
    }

     #[test_only]
    public fun set_ids_version(scenario: &mut Scenario, version: u64){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);
            data_store::set_ids_version(&mut ids, version);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
        };
    }

    #[test_only]
    public fun update_perpetual(scenario: &mut Scenario, perpetual: vector<u8>, field: vector<u8>, value: vector<u8>){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, PROTOCOL_ADMIN);
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            data_store::update_perpetual(&admin_cap, &mut eds, string::utf8(perpetual), field, value);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(PROTOCOL_ADMIN, admin_cap);
        }
    }

    #[test_only]
    public fun sync_perpetual(scenario: &mut Scenario, perpetual: vector<u8>){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, data_store::get_eds_perp_bytes(&mut eds, perpetual));

            data_store::sync_perpetual(
                &mut ids, 
                &mut eds, 
                string::utf8(perpetual), 
                sequence_hash
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);

        }
    }

     #[test_only]
    public fun sync_supported_asset(scenario: &mut Scenario, asset_symbol: vector<u8>){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);

            let bank = data_store::get_asset_bank_from_eds(&mut eds);

            let asset = bank::get_supported_asset(bank, string::utf8(asset_symbol));

            let sequence_hash = data_store::get_next_sequence_hash(&ids, bcs::to_bytes<Asset>(&asset));

            data_store::sync_supported_asset(
                &mut ids, 
                &mut eds, 
                string::utf8(asset_symbol), 
                sequence_hash
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);

        }
    }

    #[test_only]
    public fun set_operator(scenario: &mut Scenario, operator_type: vector<u8>, operator: address){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, PROTOCOL_ADMIN);
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            data_store::set_operator(&admin_cap, &mut eds, operator_type, operator);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(PROTOCOL_ADMIN, admin_cap);

        }

    }

    #[test_only]
    public fun set_ids_id_on_eds(scenario: &mut Scenario, ids_id: address){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            data_store::set_ids_id_on_eds(&mut eds, ids_id);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };
    }

    #[test_only]
    public fun sync_operator(scenario: &mut Scenario, operator_type: vector<u8>, operator: address){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);

            let bytes = bcs_handler::enc_operator_update(string::utf8(operator_type), @0, operator);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, bytes);

            data_store::sync_operator(
                &mut ids, 
                &mut eds, 
                operator_type, 
                sequence_hash
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);

        }
    }

    #[test_only]
    public fun set_tx_replay_hash(scenario: &mut Scenario, payload: vector<u8>, timestamp: u64){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);
            data_store::set_tx_replay_hash(&mut ids, payload, timestamp);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
        };
    }


    #[test_only]
    public fun deposit_to_asset_bank(scenario: &mut Scenario, asset_symbol: vector<u8>, account: address, amount: u64): u128{
        let nonce;
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);

            let coin = coin::mint_for_testing<USDC>(amount, test_scenario::ctx(scenario));

            exchange::deposit_to_asset_bank<USDC>(
                &mut eds, 
                string::utf8(asset_symbol), 
                account, 
                amount, 
                &mut coin,
                test_scenario::ctx(scenario)
            );

            let bank = data_store::get_asset_bank(&mut eds);
            nonce = bank::get_bank_nonce(bank);


            coin::burn_for_testing<USDC>(coin);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        nonce
    }

    #[test_only]
    public fun get_deposit_bytes(eds: &mut ExternalDataStore, nonce: u128, tainted: bool): vector<u8>{
        let eds_address = data_store::get_eds_address(eds);
        let bank = data_store::get_asset_bank(eds);

        let (from, account, amount, symbol) = bank::get_deposit_values(bank, nonce);
        let bytes = bcs_handler::enc_deposit(
            eds_address,
            symbol,
            from,
            account,
            amount,
            nonce,
            tainted
        );

        bytes

    }


    #[test_only]
    public fun deposit_to_internal_bank(scenario: &mut Scenario, nonce: u128){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);

            let bytes = get_deposit_bytes(&mut eds, nonce, false);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, bytes);

            exchange::deposit_to_internal_bank<USDC>(
                &mut ids, 
                &mut eds, 
                nonce,
                sequence_hash
            );

            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };
    }

    #[test_only]
    public fun deposit(scenario: &mut Scenario, account: address, amount: u64){        
        let nonce = deposit_to_asset_bank(scenario, b"USDC", account, amount);
        deposit_to_internal_bank(scenario, nonce);
    }

    #[test_only]
    public fun withdraw_from_bank(
        scenario: &mut Scenario, 
        payload: vector<u8>, 
        signature: vector<u8>,
        perpetuals: vector<String>,
        oracle_prices: vector<u64>,
        timestamp: u64,
        ){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);

            exchange::withdraw_from_bank<USDC>(
                &mut ids, 
                &mut eds, 
                payload, 
                signature, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };
    }

    #[test_only]
    public fun get_position_values(scenario: &mut Scenario, account: address, perpetual: String, isolated: bool):(String, u64, u64, bool, u64, u64, bool, u64, FundingRate){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);
        let account_state = data_store::get_immutable_account_from_ids(&ids, account);
        let position = account::get_position(account_state, perpetual, isolated);
        test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);

        let (perpetual, size, average_entry_price, is_long, leverage, margin, is_isolated, pending_funding_payment, funding) = account::get_position_values_including_funding(&position);
        (perpetual, size, average_entry_price, is_long, leverage, margin, is_isolated, pending_funding_payment, funding)
    }

    #[test_only]
    public fun set_pending_funding_payment(scenario: &mut Scenario, account: address, perpetual: String, isolated: bool, amount: u64){
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);
            let account_state = data_store::get_mutable_account_from_ids(&mut ids, account);
            account::set_pending_funding_payment(account_state, perpetual, isolated, amount);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
        };
    }

    #[test_only]
    public fun get_account_usdc_amount(scenario: &mut Scenario, account: address): u64 {
        let usdc_amount;
        test_scenario::next_tx(scenario, PROTOCOL_ADMIN);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, PROTOCOL_ADMIN);
            let account_state = data_store::get_immutable_account_from_ids(&ids, account);  
            usdc_amount = account::get_usdc_amount(account_state);
            test_scenario::return_to_address<InternalDataStore>(PROTOCOL_ADMIN, ids);
        };
        usdc_amount
    }
}