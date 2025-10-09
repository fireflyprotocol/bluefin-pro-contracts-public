module bluefin_cross_margin_dex::test_margin_leverage_adjustment {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::test_trade;
    use bluefin_cross_margin_dex::exchange;
    use std::string::{Self, String};


    #[test_only]
    public fun execute_margin_adjustment(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        perpetuals: vector<String>,
        oracle_prices: vector<u64>,
        timestamp: u64,
    ) {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);

            exchange::adjust_margin(
                &mut ids,
                payload,
                signature,
                perpetuals,
                oracle_prices,
                sequence_hash,
                timestamp,
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        }
    }


    #[test_only]
    public fun execute_leverage_adjustment(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        perpetuals: vector<String>,
        oracle_prices: vector<u64>,
        timestamp: u64,
    ) {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);

            exchange::adjust_leverage(
                &mut ids,
                payload,
                signature,
                perpetuals,
                oracle_prices,
                sequence_hash,
                timestamp,
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        }
    }

    #[test]
    public fun should_add_margin_to_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        let (_, _, _, _, _, initial_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        
        assert!(initial_margin == 10000000000, 1);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500100ca9a3b000000000551aaa399010000f399b5a399010000";
        let signature = x"011ded2a315ed21b1cdfd8487d3131c01425337b10a2962e623ab0f3048f30d4103650f7e4f952c2528ad07be9ce8ed3001ee0abc5dec97ed27c395d0e073d5cbf02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_margin_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        let (_, _, _, _, _, final_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        assert!(final_margin == 11000000000, 2);

        test_scenario::end(scenario);
    }


     #[test]
    public fun should_add_margin_to_position_with_pending_funding_payment() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        // set pending funding payment to 3 cents
        test_utils::set_pending_funding_payment(
            &mut scenario, 
            account_address, 
            perpetual, 
            true, 
            300000000
        );

        let (_, _, _, _, _, 
        initial_margin, _, 
        pending_funding_payment, 
        _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);

        assert!(initial_margin == 10000000000, 1);
        assert!(pending_funding_payment == 300000000, 2);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500100ca9a3b000000000551aaa399010000f399b5a399010000";
        let signature = x"011ded2a315ed21b1cdfd8487d3131c01425337b10a2962e623ab0f3048f30d4103650f7e4f952c2528ad07be9ce8ed3001ee0abc5dec97ed27c395d0e073d5cbf02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_margin_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        let (_, _, _, _, _, final_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        
        // should have 3 cents less
        assert!(final_margin == 10700000000, 3);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1017, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_reduce_margin_from_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        let (_, _, _, _, _, initial_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);

        assert!(initial_margin == 10000000000, 1);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[1000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500040420f000000000029d7a8a3990100000793caa399010000";
        let signature = x"01130101259645493e1e38710b22b09f6c0347f0adeed12793fc7709395bfba63c4fb851d761ae170b127ef3d643523a96bc473f19fa497c0dc6051e1c6cad764502d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_margin_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_reduce_margin_from_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        let (_, _, _, _, _, initial_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        
        assert!(initial_margin == 10000000000, 1);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500100ca9a3b000000000551aaa399010000f399b5a399010000";
        let signature = x"011ded2a315ed21b1cdfd8487d3131c01425337b10a2962e623ab0f3048f30d4103650f7e4f952c2528ad07be9ce8ed3001ee0abc5dec97ed27c395d0e073d5cbf02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_margin_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);
        


        // Removing 1$ from the position
        let payload_reduce = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d50455250000065cd1d000000000154afa399010000e13dcea399010000";
        let signature_reduce = x"016724c9a0a0186eea71a10014b95221623517f4d6fe5703c3f170a247f7d512512a0cc566cfa94d5f3532bc33a2af47ec4d2ff1d6459584e42885184bb7926d0d02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_margin_adjustment(&mut scenario, payload_reduce, signature_reduce, perpetuals, oracle_prices, timestamp);

        let (_, _, _, _, _, final_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        assert!(final_margin == 10500000000, 2);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_increase_leverage_of_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        let (_, _, _, _, initial_leverage, initial_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        
        assert!(initial_leverage == 2000000000, 1);
        assert!(initial_margin == 10000000000, 2);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000286bee000000004183bfa39901000016c2d5a399010000";
        let signature = x"019e19e795e7ae60e27c67b1971ddf701c9315d52a0018f1ebd114b7bead20143d7b7f506f3f75a64de17c42d2ea75a67dc2bac0ed15648c5c0d15e8bb5c78eb5d02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_leverage_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        let (_, _, _, _, final_leverage, final_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        assert!(final_leverage == 4000000000, 3);
        assert!(final_margin == 5000000000, 4);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_reduce_leverage_of_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_trade::execute_trade(&mut scenario);

        let account_address = test_utils::taker();
        let perpetual = string::utf8(b"ETH-PERP");

        let (_, _, _, _, initial_leverage, initial_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        
        assert!(initial_leverage == 2000000000, 1);
        assert!(initial_margin == 10000000000, 2);
        
        // Adding 1$ to the position
        let perpetuals = vector[perpetual];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000ca9a3b00000000facdbea3990100000172d6a399010000";
        let signature = x"01672091c650d7e6be0aeda81239ec9dfc56b26e5ca6caa0b58518195156837df81ab24398a32e6ee35bd9fbb87b7aff346f63dab6da9290aa9d521df520649c3102d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";
        execute_leverage_adjustment(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        let (_, _, _, _, final_leverage, final_margin, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, perpetual, true);
        assert!(final_leverage == 1000000000, 3);
        assert!(final_margin == 20000000000, 4);

        test_scenario::end(scenario);
    }


}