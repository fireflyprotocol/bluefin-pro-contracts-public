module bluefin_cross_margin_dex::test_close_position {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::test_trade;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::exchange;
    use std::string;
    use sui::bcs;


    #[test_only]
    public fun close_position(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        timestamp: u64,
    ) {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());
            
            let perpetuals = vector[];
            let oracle_prices = vector[];

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            
            exchange::close_position(&mut ids, payload, signature, perpetuals, oracle_prices, sequence_hash, timestamp);

           test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
 
        }
    }

    #[test_only]
    public fun setup_scenario(scenario: &mut Scenario) {

        test_utils::init_package_for_testing(scenario);

        // open trade between a maker/taker
        test_trade::execute_trade(scenario);
    
        // the market to be delisted
        let perp_bytes = b"ETH-PERP";
        // delist the market
        test_utils::update_perpetual(
            scenario, 
            perp_bytes, 
            b"delist", 
            bcs::to_bytes<u64>(&2000000000000));

        test_utils::sync_perpetual(scenario, perp_bytes);

    }

    #[test]
    public fun should_successfully_close_position_after_delisting() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500102ec3fa499010000372f5ba499010000";
        let signature = x"01ab434871cd0408e6fbd9b3a97b1ba2544a8c83fa4c5a5547e56b2869aa2f11b6146b05d84667dc44ce754a3a246fd0d7384f72a784f1e571216d2601f9672d2c02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_due_to_ids_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500102ec3fa499010000372f5ba499010000";
        let signature = x"01ab434871cd0408e6fbd9b3a97b1ba2544a8c83fa4c5a5547e56b2869aa2f11b6146b05d84667dc44ce754a3a246fd0d7384f72a784f1e571216d2601f9672d2c02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1014, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_as_signer_does_not_have_permission() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525001c2ab50a499010000db3762a499010000";
        let signature = x"01a86a652a0995d9b88ec1e947f504c0c03bf018c25efbd859ccb6e156e9dac80c3791da9f6e9003fa9f7f937ff07ad70eb0612f6fbd7c63f995c38b3605cb832502d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1056, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_as_perpetual_is_not_delisted() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        // open trade between a maker/taker
        test_trade::execute_trade(&mut scenario);
        
        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500102ec3fa499010000372f5ba499010000";
        let signature = x"01ab434871cd0408e6fbd9b3a97b1ba2544a8c83fa4c5a5547e56b2869aa2f11b6146b05d84667dc44ce754a3a246fd0d7384f72a784f1e571216d2601f9672d2c02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1024, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_as_trading_is_not_permitted() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        let perp_bytes = b"ETH-PERP";

        test_utils::update_perpetual(
            &mut scenario, 
            perp_bytes, 
            b"trading_status", 
            bcs::to_bytes<bool>(&false));

        test_utils::sync_perpetual(&mut scenario, perp_bytes);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500102ec3fa499010000372f5ba499010000";
        let signature = x"01ab434871cd0408e6fbd9b3a97b1ba2544a8c83fa4c5a5547e56b2869aa2f11b6146b05d84667dc44ce754a3a246fd0d7384f72a784f1e571216d2601f9672d2c02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);

    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_as_target_ids_do_not_match_with_ids() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"6339a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500128fa4ca499010000fffd65a499010000";
        let signature = x"0184584e1de6c4ca1fc1a1677065cdacf43ec985229b3fbb4894169f3338e0d3a129ff01791a2fcc7fc49e6b128f8a1c92bd31f12b3a6c7dcaadb4de2fe08dafc102d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_close_position_as_signed_at_is_not_in_last_n_months() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // we will close the taker position
        let account_address = test_utils::taker();

        let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d504552500129a061a4990100001027000000000000";
        let signature = x"01b0c412210da5db6c34c569ea017165d2ce60c27293b85229f5974e06cde86e0c36d202897a7cf1727c9ff59fde6d56ab01099744f27ce7f3dfea138fbb8cad5602d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        close_position(&mut scenario, payload, signature, 1735718400002);

        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }



}