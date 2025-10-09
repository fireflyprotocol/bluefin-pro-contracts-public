module bluefin_cross_margin_dex::test_data_store {
    use sui::test_scenario::{Self};
    use bluefin_cross_margin_dex::test_utils::{Self, USDC};
    use bluefin_cross_margin_dex::admin::{Self,AdminCap};
    use bluefin_cross_margin_dex::data_store::{Self, ExternalDataStore, InternalDataStore};
    use std::option::{Self};
    use std::string::{Self,String};
    use std::bcs;
    use std::vector;

    #[test]
    public fun should_initialize_data_store_module(){

        let scenario = test_scenario::begin(test_utils::protocol_admin());
        data_store::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_support_asset(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                1000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_revert_when_supporting_asset_when_eds_version_is_not_matching(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::set_eds_version(&mut eds, 0);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                1000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1041, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_asset_already_supported(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            // First, add USDC as a supported asset
            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                1000000000000);

            // Then try to add USDC again - this should fail with EAssetAlreadySupported
            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                1000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_scenario::end(scenario);
    }



    #[test]
    #[expected_failure(abort_code=1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_min_deposit_is_zero_when_supporting_asset(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                0, 
                1000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_min_deposit_is_greater_than_max_deposit_when_supporting_asset(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDC"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000000, 
                100000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_create_internal_data_store(){
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::create_internal_data_store(&admin_cap, &mut eds, protocol_sequencer, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1004, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_create_internal_data_store_if_sequencer_is_zero_address(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::create_internal_data_store(&admin_cap, &mut eds, @0, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_create_internal_data_store_if_eds_version_is_not_matching(){
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::set_eds_version(&mut eds, 0);

            data_store::create_internal_data_store(&admin_cap, &mut eds, protocol_sequencer, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_allow_sequencer_to_transfer_ids(){
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::transfer_ids(ids, protocol_sequencer);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_increment_internal_data_store_version(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::set_ids_version(&mut ids, 0);

            data_store::increment_internal_data_store_version(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1061, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_increment_internal_data_store_version_if_version_is_greater_than_package_version(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            
            data_store::increment_internal_data_store_version(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }



    #[test]
    public fun should_increment_external_data_store_version(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::set_eds_version(&mut eds, 0);

            data_store::increment_external_data_store_version(&admin_cap, &mut eds);

            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1061, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_increment_external_data_store_version_if_version_is_greater_than_package_version(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);

            
            data_store::increment_external_data_store_version(&admin_cap, &mut eds);

            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_create_perpetual(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
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

        test_scenario::end(scenario);

    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]   
    public fun should_fail_to_create_perpetual_when_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);

        
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

        test_scenario::end(scenario);

    }


    #[test]
    #[expected_failure(abort_code=1018, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_create_perpetual_when_perpetual_already_exists(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::create_perpetual(
            &mut scenario,
             option::some<String>(string::utf8(b"ETH-PERP")),
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

        test_scenario::end(scenario);
    }
    

    #[test]
    public fun should_sync_perpetual(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

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

            test_utils::sync_perpetual(
                &mut scenario,
                b"BTC-PERP",
            );            
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_perpetual_when_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);

        test_utils::sync_perpetual(
            &mut scenario,
            b"ETH-PERP",
            );            
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_perpetual_when_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        test_utils::sync_perpetual(
            &mut scenario,
            b"ETH-PERP",
            );            
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1006, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_perpetual_when_ids_id_on_eds_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_ids_id_on_eds(&mut scenario, @0x1);

        test_utils::sync_perpetual(
            &mut scenario,
            b"ETH-PERP",
            );            

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1009, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_perpetual_when_perpetual_does_not_exist_on_eds(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::sync_perpetual(
            &mut scenario,
            b"TEST-PERP",
            );            

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1020, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_perpetual_when_perpetual_has_no_pending_sync(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::sync_perpetual(
            &mut scenario,
            b"ETH-PERP",
            );            

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_update_perpetual_when_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_eds_version(&mut scenario, 0);

        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"step_size",
            b"1000000000",
        );    
        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_tick_size(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"tick_size",
            bcs::to_bytes<u64>(&100000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1010, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_update_perpetual_tick_size_when_there_is_a_pending_sync(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"tick_size",
            bcs::to_bytes<u64>(&100000),
        );

          test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"tick_size",
            bcs::to_bytes<u64>(&100000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_step_size(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"step_size",
            bcs::to_bytes<u64>(&100000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_min_trade_quantity(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"min_trade_quantity",
            bcs::to_bytes<u64>(&100000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_max_limit_order_quantity(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_limit_order_quantity",
            bcs::to_bytes<u64>(&1000000000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_perpetual_max_market_order_quantity(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_market_order_quantity",
            bcs::to_bytes<u64>(&100000000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_max_trade_quantity(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_trade_quantity",
            bcs::to_bytes<u64>(&1000000000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_initial_margin_required(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"initial_margin_required",
            bcs::to_bytes<u64>(&44000000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_maintenance_margin_required(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"maintenance_margin_required",
            bcs::to_bytes<u64>(&30000001),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_min_trade_price(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"min_trade_price",
            bcs::to_bytes<u64>(&50000000000),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_perpetual_max_trade_price(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_trade_price",
            bcs::to_bytes<u64>(&5000000000000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_perpetual_mtb_long(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"mtb_long",
            bcs::to_bytes<u64>(&50000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
     public fun should_update_perpetual_mtb_short(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"mtb_short",
            bcs::to_bytes<u64>(&50000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_perpetual_maker_fee(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"maker_fee",
            bcs::to_bytes<u64>(&160000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_perpetual_taker_fee(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"taker_fee",
            bcs::to_bytes<u64>(&260000),
        );

        test_scenario::end(scenario);
    }



    #[test]
    public fun should_update_perpetual_max_funding_rate(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_funding_rate",
            bcs::to_bytes<u64>(&10000000),
        );

        test_scenario::end(scenario);
    }

    #[test]
     public fun should_update_insurance_pool_address(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"insurance_pool_address",
            bcs::to_bytes<address>(&@0x1),
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_update_fee_pool_address(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"fee_pool_address",
            bcs::to_bytes<address>(&@0x1),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_insurance_pool_ratio(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"insurance_pool_ratio",
            bcs::to_bytes<u64>(&45000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
     public fun should_update_isolated_only(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"isolated_only",
            bcs::to_bytes<bool>(&true),
        );

        test_scenario::end(scenario);
    }

    #[test]
     public fun should_update_trading_status(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"trading_status",
            bcs::to_bytes<bool>(&false),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_mark_perpetual_as_delisted(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"delist",
            bcs::to_bytes<u64>(&50000000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_update_max_allowed_oi_open(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
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
            vector::push_back(&mut notion, 1000000000000000);
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"max_allowed_oi_open",
            bcs::to_bytes<vector<u64>>(&notion),
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1054, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_update_an_invalid_perpetual_field(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        
        test_utils::update_perpetual(
            &mut scenario,
            b"ETH-PERP",
            b"invalid_field",
            bcs::to_bytes<u64>(&1000000000000000),
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_set_operator_when_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);
        
        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1037, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_set_operator_when_operator_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_operator(&mut scenario, b"xyz", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1004, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_set_operator_when_new_operator_is_zero_address(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_operator(&mut scenario, b"funding", @0x0);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_set_operator(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1038, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_set_operator_when_new_operator_is_same_as_existing_one(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_operator(&mut scenario, b"funding", @0x1);
        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_sync_supported_asset(){

        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::support_asset<USDC>(
                &admin_cap,
                &mut eds, 
                string::utf8(b"USDT"), 
                6, 
                1000000000, 
                1000000000, 
                true, 
                1000000000, 
                1000000000000);

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);

        };

        test_utils::sync_supported_asset(&mut scenario, b"USDT");

        test_scenario::end(scenario);

    }

    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_supported_asset_when_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_eds_version(&mut scenario, 0);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1001, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_supported_asset_when_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        
        test_utils::set_ids_version(&mut scenario, 0);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code=1006, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_supported_when_ids_set_on_eds_is_different_from_the_one_provided(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);


        test_utils::set_ids_id_on_eds(&mut scenario, @0x1);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1020, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_supported_when_asset_is_already_synced(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1037, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_operator_when_operator_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        let new_operator = @0x1;
        
        test_utils::sync_operator(&mut scenario, b"invalid", new_operator);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=1032, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_sync_operator_when_there_is_nothing_to_sync(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        let new_operator = @0x1;
        
        test_utils::sync_operator(&mut scenario, b"funding", new_operator);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_get_asset_from_data_store(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::get_asset(&ids, string::utf8(b"USDC"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 


    #[test]
    #[expected_failure(abort_code=1036, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_get_asset_from_data_store_as_asset_is_not_supported(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::get_asset(&ids, string::utf8(b"XYZ"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 


    #[test]
    public fun should_get_mutable_order_fills_table_from_data_store(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::get_mutable_order_fills_table_from_ids(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 

    #[test]
    public fun should_return_first_fill_as_true(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::is_first_fill(&ids, x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 


    #[test]
    #[expected_failure(abort_code=1037, location = bluefin_cross_margin_dex::data_store)]
    public fun should_revert_when_trying_to_fetch_invalid_operator(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::get_operator_address(&ids, x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 

    #[test]
    public fun should_return_filled_quantity_as_zero_for_a_non_existent_order(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            assert!(data_store::filled_order_quantity(&ids, x"12") == 0, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 

    #[test]
    #[expected_failure(abort_code=1009, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_fetch_unsupported_perpetual_from_table(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(&ids);
            data_store::get_immutable_perpetual_from_table(immutable_perpetual_table, string::utf8(b"XYZ"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 

    #[test]
    #[expected_failure(abort_code=1009, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_fetch_unsupported_perpetual_from_ids(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::get_immutable_perpetual_from_ids(&ids, string::utf8(b"XYZ"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    } 


     #[test]
    #[expected_failure(abort_code=1005, location = bluefin_cross_margin_dex::data_store)]
    public fun should_get_invalid_compute_and_update_sequence_hash(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            data_store::compute_and_update_sequence_hash(&mut ids, x"12", x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }
    

}