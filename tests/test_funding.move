module bluefin_cross_margin_dex::test_funding {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::test_trade;
    use bluefin_cross_margin_dex::exchange;
    use std::string::{Self, String};
    use sui::bcs;
    use std::vector;
    use std::option;

    struct ApplyFundingRatePayload has copy, drop {
         ids: address,
         timestamp: u64,
         accounts: vector<address>,
         salt: u64,
         signed_at: u64,
         market: String
    }

    #[test_only]
    public fun set_funding_rate(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        timestamp: u64,
    ) {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);

            exchange::set_funding_rate(&mut ids, payload, signature, sequence_hash, timestamp);

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        }
    }

   
    #[test_only]
    public fun apply_funding_rate_payload(): ApplyFundingRatePayload {
        ApplyFundingRatePayload {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            timestamp: 1735714800002,
            accounts: vector[test_utils::maker(), test_utils::taker()],
            salt: 1,
            signed_at: 1735714800002,
            market: string::utf8(b"ETH-PERP")
        }
    }


    #[test]
    public fun should_successfully_set_funding_rate() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975805626a499010000011a084554482d5045525040420f00000000000100204aa9d10100002d4de4a3990100002229f7a399010000";
        let signature = x"007b2a252c20ba0acd470dd04d6d3e8e2f5c5cccb1a8b1ca002d664abe911c94b7f32767082b9e8e6465fdf434f7e8bfa12eb76c87d78094492e7503299ec8b30ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735714800002;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1039, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_funding_rate_for_non_hourly_timestamp() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397502f0e02094010000011a084554482d5045525040420f00000000000100204aa9d1010000277eefa3990100002cb305a499010000";
        let signature = x"0001a298ba31e83577a9f0932e5cbb91f0b1c03cced9a5ade1f142cf0013fe21f9c8c03df04f25b01abe9c1fec23474c9ac5d007b60eeaccedac8fc62eab12450bd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735714800002;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_apply_funding_rate() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975103fde68000000000280c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29e894eaa399010000f373faa39901000000";
            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        let (_, _, _, _, _, margin, _, _, _) = test_utils::get_position_values(&mut scenario, test_utils::taker(), string::utf8(b"ETH-PERP"), true);
        assert!(margin == 10020000000, 1);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_do_nothing_when_funding_for_the_hour_is_already_applied() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975103fde68000000000280c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29e894eaa399010000f373faa39901000000";
            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );

            let apply_funding_payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975103fde68000000000280c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29e894eaa399010000f373faa3990100000002";
            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );


            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        let (_, _, _, _, _, margin, _, _, _) = test_utils::get_position_values(&mut scenario, test_utils::taker(), string::utf8(b"ETH-PERP"), true);
        assert!(margin == 10020000000, 1);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_apply_funding_rate_as_ids_version_is_not_the_same() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975103fde68000000000280c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29e894eaa399010000f373faa39901000000";
            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_apply_funding_rate_as_target_ids_is_not_the_same() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            apply_funding_data.ids = @0x1;
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_apply_funding_rate_as_payload_lifespan_is_greater_than_max_allowed() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            apply_funding_data.signed_at = 100000;
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_apply_funding_rate_for_all_markets() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            apply_funding_data.market = string::utf8(b"");
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1016, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_apply_funding_rate_to_a_non_existent_account() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            vector::push_back(&mut apply_funding_data.accounts, @0x96a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084);
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_apply_funding_rate_for_eth_perp_markets() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_do_nothing_when_applying_funding_rate_for_btc_and_user_has_no_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        test_trade::execute_trade(&mut scenario);
        
        
        let payload = x"20426c756566696e2050726f2053657474696e672046756e64696e67205261746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500f0e02094010000011a084554482d5045525040420f00000000000100204aa9d10100005a3befa39901000060dc01a499010000";
        let signature = x"002b8cb60fa974cbb3756386a3257ce47a445fce7a3b43fadc09422b239aa294f324c44c90084f14df2affb4671c524175cacce1075c07cca5374eca4a9e21460ad6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735718400001;

        set_funding_rate(&mut scenario, payload, signature, timestamp);


        test_utils::create_perpetual(
            &mut scenario,
             option::some<String>(string::utf8(b"BTC-PERP")),
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


        test_utils::sync_perpetual(&mut scenario, b"BTC-PERP");


        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());            

            let apply_funding_data = apply_funding_rate_payload();
            let apply_funding_payload = bcs::to_bytes<ApplyFundingRatePayload>(&apply_funding_data);
            apply_funding_data.market = string::utf8(b"BTC-PERP");

            let sequence_hash = data_store::get_next_sequence_hash(&ids, apply_funding_payload);

            exchange::apply_funding_rate(
                &mut ids, 
                apply_funding_payload,  
                sequence_hash, 
                timestamp + 1
            );
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        };

        test_scenario::end(scenario);
    }

    
}