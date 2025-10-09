module bluefin_cross_margin_dex::test_misc {
    use sui::test_scenario;
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::data_store::InternalDataStore;
    use bluefin_cross_margin_dex::margining_engine;
    use bluefin_cross_margin_dex::signature;
    use bluefin_cross_margin_dex::test_trade;

    #[test]
    #[expected_failure(abort_code = 1063, location = bluefin_cross_margin_dex::margining_engine)]
    public fun should_revert_as_calculate_effective_leverage_is_deprecated(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        margining_engine::calculate_effective_leverage(true, 1000000000, 1000000000, 1000000000, 1000000000);

        test_scenario::end(scenario);
    
    }


    #[test]
    #[expected_failure(abort_code = 1063, location = bluefin_cross_margin_dex::signature)]
    public fun should_revert_as_verify_liquidation_signature_is_deprecated(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        signature::verify_liquidation_signature(x"", x"", x"");

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_return_withdrawable_assets_of_the_user(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        test_trade::execute_trade(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let withdrawable_assets = margining_engine::get_withdrawable_assets(&ids, test_utils::taker(), b"USDC");
            assert!(withdrawable_assets == 989959000000, 0);
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

}
 