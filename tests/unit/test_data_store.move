module bluefin_cross_margin_dex::test_data_store {
    use bluefin_cross_margin_dex::{
        admin::{Self, AdminCap},
        data_store::{Self, ExternalDataStore, InternalDataStore},
        test_utils::{Self, USDC}
    };
    use std::{bcs, option, string::{Self, String}, vector};
    use sui::test_scenario;

    #[test]
    public fun should_initialize_data_store_module() {
        let scenario = test_scenario::begin(test_utils::protocol_admin());
        data_store::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_support_asset() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                1000000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_revert_when_supporting_asset_when_eds_version_is_not_matching() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                1000000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1041, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_asset_already_supported() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                1000000000000,
            );

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
                1000000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_min_deposit_is_zero_when_supporting_asset() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                1000000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_revert_if_min_deposit_is_greater_than_max_deposit_when_supporting_asset() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                100000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_create_internal_data_store() {
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::create_internal_data_store(
                &admin_cap,
                &mut eds,
                protocol_sequencer,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1004,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_create_internal_data_store_if_sequencer_is_zero_address() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::create_internal_data_store(
                &admin_cap,
                &mut eds,
                @0,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_create_internal_data_store_if_eds_version_is_not_matching() {
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::set_eds_version(&mut eds, 0);

            data_store::create_internal_data_store(
                &admin_cap,
                &mut eds,
                protocol_sequencer,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_allow_sequencer_to_transfer_ids() {
        let protocol_admin = test_utils::protocol_admin();
        let protocol_sequencer = test_utils::protocol_sequencer();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );

            data_store::transfer_ids(ids, protocol_sequencer);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_increment_internal_data_store_version() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );

            data_store::set_ids_version(&mut ids, 0);

            data_store::increment_internal_data_store_version(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1061,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_increment_internal_data_store_version_if_version_is_greater_than_package_version() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );

            data_store::increment_internal_data_store_version(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_increment_external_data_store_version() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);

            data_store::set_eds_version(&mut eds, 0);

            data_store::increment_external_data_store_version(&admin_cap, &mut eds);

            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1061,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_increment_external_data_store_version_if_version_is_greater_than_package_version() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );

            data_store::increment_external_data_store_version(&admin_cap, &mut eds);

            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_create_perpetual() {
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
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_create_perpetual_when_eds_version_mismatch() {
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
    #[
        expected_failure(
            abort_code = 1018,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_create_perpetual_when_perpetual_already_exists() {
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
    public fun should_sync_perpetual() {
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
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_perpetual_when_eds_version_mismatch() {
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
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_perpetual_when_ids_version_mismatch() {
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
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_perpetual_when_ids_id_on_eds_mismatch() {
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
    #[
        expected_failure(
            abort_code = 1009,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_perpetual_when_perpetual_does_not_exist_on_eds() {
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
    #[
        expected_failure(
            abort_code = 1020,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_perpetual_when_perpetual_has_no_pending_sync() {
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
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_update_perpetual_when_eds_version_mismatch() {
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
    public fun should_update_perpetual_tick_size() {
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
    #[
        expected_failure(
            abort_code = 1010,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_update_perpetual_tick_size_when_there_is_a_pending_sync() {
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
    public fun should_update_perpetual_step_size() {
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
    public fun should_update_perpetual_min_trade_quantity() {
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
    public fun should_update_perpetual_max_limit_order_quantity() {
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
    public fun should_update_perpetual_max_market_order_quantity() {
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
    public fun should_update_perpetual_max_trade_quantity() {
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
    public fun should_update_perpetual_initial_margin_required() {
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
    public fun should_update_perpetual_maintenance_margin_required() {
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
    public fun should_update_perpetual_min_trade_price() {
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
    public fun should_update_perpetual_max_trade_price() {
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
    public fun should_update_perpetual_mtb_long() {
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
    public fun should_update_perpetual_mtb_short() {
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
    public fun should_update_perpetual_maker_fee() {
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
    public fun should_update_perpetual_taker_fee() {
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
    public fun should_update_perpetual_max_funding_rate() {
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
    public fun should_update_insurance_pool_address() {
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
    public fun should_update_fee_pool_address() {
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
    public fun should_update_insurance_pool_ratio() {
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
    public fun should_update_isolated_only() {
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
    public fun should_update_trading_status() {
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
    public fun should_mark_perpetual_as_delisted() {
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
    public fun should_update_max_allowed_oi_open() {
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
    #[
        expected_failure(
            abort_code = 1054,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_update_an_invalid_perpetual_field() {
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
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_set_operator_when_eds_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);

        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1037,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_set_operator_when_operator_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_operator(&mut scenario, b"xyz", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1004,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_set_operator_when_new_operator_is_zero_address() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_operator(&mut scenario, b"funding", @0x0);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_set_operator() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1038,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_set_operator_when_new_operator_is_same_as_existing_one() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_operator(&mut scenario, b"funding", @0x1);
        test_utils::set_operator(&mut scenario, b"funding", @0x1);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_sync_supported_asset() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            admin::test_init(test_scenario::ctx(&mut scenario));
            data_store::test_init(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let admin_cap = test_scenario::take_from_address<AdminCap>(
                &scenario,
                protocol_admin,
            );
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
                1000000000000,
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
            test_scenario::return_to_address<AdminCap>(protocol_admin, admin_cap);
        };

        test_utils::sync_supported_asset(&mut scenario, b"USDT");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_supported_asset_when_eds_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1001,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_supported_asset_when_ids_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_supported_when_ids_set_on_eds_is_different_from_the_one_provided() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_id_on_eds(&mut scenario, @0x1);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1020,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_supported_when_asset_is_already_synced() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_utils::sync_supported_asset(&mut scenario, b"USDC");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1037,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_operator_when_operator_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        let new_operator = @0x1;

        test_utils::sync_operator(&mut scenario, b"invalid", new_operator);

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1032,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_sync_operator_when_there_is_nothing_to_sync() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);
        let new_operator = @0x1;

        test_utils::sync_operator(&mut scenario, b"funding", new_operator);

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1066,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_position_as_payload_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"2f426c756566696e2050726f20544545205573657220417574686f72697a6564204163636f756e74732055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e800000001010be4219d99010000b8632f9d99010000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"position");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_position_as_target_ids_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746543d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e80000000101cbf9269d990100004ab7359d99010000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"position");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1046,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_position_as_payload_lifespan_exceeds_max_allowed_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e8000000010197481d9d99010000e803000000000000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"position");

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2003, location = bluefin_cross_margin_dex::signature)]
    public fun should_fail_to_perform_tee_update_position_as_signature_is_invalid_ed25519() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e800000001011ac7219d9901000067453a9d99010000";
        let signature: vector<u8> =
            x"00c8bf6d5f9fd7a9c6121445192e53e7d87b3d200b6fa56179f9fe07706ebae88403e3c789bd5302a72df24748c2caf50193e2d4bfe220bf78a4dbec561aa03a0ed6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d074";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"position",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2003, location = bluefin_cross_margin_dex::signature)]
    public fun should_fail_to_perform_tee_update_position_as_signature_is_invalid_secp256k1() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e800000001011ac7219d9901000067453a9d99010000";
        let signature: vector<u8> =
            x"014817d144665fbf7501c54f8deebcabf5d75b8b5cca71e4e6929baffecb48f1712c98ce11ac11610ded0f0f6ad608f72d85bc10526c655f9252d5cb6f7ab607bb032e9ccc4eaabfb6054b71f6499fdb744e516b4ff811bb6c74796dd2b14c86a4ba";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"position",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1014,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_position_as_signer_is_not_the_guardian() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e80000000101493c2b9d990100003d213c9d99010000";
        let signature: vector<u8> =
            x"019817d144665fbf7501c54f8deebcabf5d75b8b5cca71e4e6929baffecb48f1712c98ce11ac11610ded0f0f6ad608f72d85bc10526c655f9252d5cb6f7ab607bb032e9ccc4eaabfb6054b71f6499fdb744e516b4ff811bb6c74796dd2b14c86a4ba";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"position",
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_tee_update_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f2054454520506f736974696f6e2055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004084554482d504552500010a5d4e80000000010a5d4e80000000010a5d4e80000000010a5d4e80000000101010010a5d4e8000000010010a5d4e8000000010010a5d4e800000001015e6e2e9d99010000d84e3e9d99010000";
        let signature: vector<u8> =
            x"000b282ba5777887158cd4e6d841cd56ba095dcd7078475898a5437bec2bf6341eb77bad3058a5abaa675b18ea166be3cef797326f8429805f71e9dac9df3c720cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"position",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1066,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_assets_as_payload_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f204c657665726167652041646a7573746d656e7463d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000404555344430010a5d4e8000000763c2d9d99010000e1454e9d99010000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"assets");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_assets_as_target_ids_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1c426c756566696e2050726f205445452041737365742055706461746564d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000404555344430010a5d4e80000005147379d990100004c404f9d99010000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"assets");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1046,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_assets_as_payload_lifespan_exceeds_max_allowed_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1c426c756566696e2050726f205445452041737365742055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000404555344430010a5d4e80000002cfb439d99010000e803000000000000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"assets");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1014,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_assets_as_signer_is_not_the_guardian() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1c426c756566696e2050726f205445452041737365742055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000404555344430010a5d4e80000000b43349d99010000b1a4509d99010000";
        let signature: vector<u8> =
            x"0154b076b8f6fffa0ef982669273a1320842f282ee925225be20a4f3265ba1e8646e3271e530d2207b9a0ea05656da65dcbbb65536021c9c84c488e341a0e05097032e9ccc4eaabfb6054b71f6499fdb744e516b4ff811bb6c74796dd2b14c86a4ba";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"assets",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1036,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_assets_as_only_usdc_token_is_supported() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1c426c756566696e2050726f205445452041737365742055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004034254430010a5d4e800000029073b9d99010000512f539d99010000";
        let signature: vector<u8> =
            x"0063af21d5f01edcd8ed9a96222b45ad0149e7e3a785f9c35f3a06e63f9743a78bacb895c8b3af0d933aeadf2ef5fc98e323249dded51b912b73bfbc8f1b42d904d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"assets",
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_tee_update_assets() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1c426c756566696e2050726f205445452041737365742055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000404555344430010a5d4e8000000a7c8399d99010000aacb519d99010000";
        let signature: vector<u8> =
            x"00af420580f2026cbd356baa95da60c4ec9cb5453be99a396e47cfaa706df89698a7926bfb53aaf0e3c7f2f36c138564b9e8c4241e35492092c6419e042724ab0cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"assets",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1066,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_authorized_accounts_as_payload_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f204c657665726167652041646a7573746d656e7463d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000262e62f9d99010000b775559d99010000";

        test_utils::tee_update(
            &mut scenario,
            payload,
            b"",
            1000000000000,
            b"authorized_account",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_authorized_accounts_as_target_ids_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"2f426c756566696e2050726f20544545205573657220417574686f72697a6564204163636f756e74732055706461746564d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500000000000000000000000000000000000000000000000000000000000000040200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002561f349d990100003d0b569d99010000";

        test_utils::tee_update(
            &mut scenario,
            payload,
            b"",
            1000000000000,
            b"authorized_account",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1046,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_authorized_accounts_as_payload_lifespan_exceeds_max_allowed_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"2f426c756566696e2050726f20544545205573657220417574686f72697a6564204163636f756e74732055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975000000000000000000000000000000000000000000000000000000000000000402000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000027e6b489d990100008096980000000000";

        test_utils::tee_update(
            &mut scenario,
            payload,
            b"",
            1000000000000,
            b"authorized_account",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1014,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_authorized_accounts_as_signer_is_not_the_guardian() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"2f426c756566696e2050726f20544545205573657220417574686f72697a6564204163636f756e74732055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500000000000000000000000000000000000000000000000000000000000000040200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002113e3f9d990100009d14579d99010000";
        let signature: vector<u8> =
            x"01502a26fb7ab68f364930ed5f00e3f09c6f821126d93aa2762d6f4b5492d782d33d8acac9239a413dc8b1442944fbe52cb18dc11f641db32499ddb2c11c5cc27a032e9ccc4eaabfb6054b71f6499fdb744e516b4ff811bb6c74796dd2b14c86a4ba";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"authorized_account",
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_tee_authorized_accounts() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"2f426c756566696e2050726f20544545205573657220417574686f72697a6564204163636f756e74732055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397500000000000000000000000000000000000000000000000000000000000000040200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002aeb8349d99010000c281599d99010000";
        let signature: vector<u8> =
            x"007352a4eabacdc6bab72fa010667c440d5d66ced0f3636c607ad6afac9b8e0cbb7cdd549ed41ff0d9505fd4e9060abc4bf2b27c9befe068433892511ed4e69c02d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"authorized_account",
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1066,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_user_trade_fee_as_payload_type_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"1f426c756566696e2050726f204c657665726167652041646a7573746d656e7463d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004000064a7b3b6e00d000064a7b3b6e00d010f563f9d990100008096980000000000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"trade_fee");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1006,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_user_trade_fee_as_target_ids_is_invalid() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"25426c756566696e2050726f205445452055736572205472616465204665652055706461746564d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004000064a7b3b6e00d000064a7b3b6e00d01a685379d990100008096980000000000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"trade_fee");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1046,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_user_trade_fee_as_payload_lifespan_exceeds_max_allowed_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"25426c756566696e2050726f205445452055736572205472616465204665652055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004000064a7b3b6e00d000064a7b3b6e00d01e6a6529d990100008096980000000000";

        test_utils::tee_update(&mut scenario, payload, b"", 1000000000000, b"trade_fee");

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1014,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_perform_tee_update_user_trade_fee_as_signer_is_not_the_guardian() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"25426c756566696e2050726f205445452055736572205472616465204665652055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004000064a7b3b6e00d000064a7b3b6e00d01805b4d9d9901000022785d9d99010000";
        let signature: vector<u8> =
            x"0156bf4c90a2abc6c6bc47a1b58e2a3710ce4f124ecb7554d3e2dd14632cd01f7120941de195fe6eb546d6a87eb19b94ce33e558c96ec8c672c3a2e2db9edd366f032e9ccc4eaabfb6054b71f6499fdb744e516b4ff811bb6c74796dd2b14c86a4ba";

        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"trade_fee",
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_tee_update_user_trade_fee() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"25426c756566696e2050726f205445452055736572205472616465204665652055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750000000000000000000000000000000000000000000000000000000000000004000064a7b3b6e00d000064a7b3b6e00d01bd943e9d990100007d225e9d99010000";
        let signature: vector<u8> =
            x"001cf430d72f5433a26f6687201a44411e8e593d5c965e1cdb8501890d80c4bcb1f91acab85018cb547617b5888a4e66bbd58e86c14b1afa138c757bb9c8048504d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"trade_fee",
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_get_asset_from_data_store() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::get_asset(&ids, string::utf8(b"USDC"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1036,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_get_asset_from_data_store_as_asset_is_not_supported() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::get_asset(&ids, string::utf8(b"XYZ"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_get_mutable_order_fills_table_from_data_store() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::get_mutable_order_fills_table_from_ids(&mut ids);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_return_first_fill_as_true() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::is_first_fill(&ids, x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1037,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_revert_when_trying_to_fetch_invalid_operator() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::get_operator_address(&ids, x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_return_filled_quantity_as_zero_for_a_non_existent_order() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            assert!(data_store::filled_order_quantity(&ids, x"12") == 0, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1009,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_fetch_unsupported_perpetual_from_table() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            let immutable_perpetual_table = data_store::get_immutable_perpetual_table_from_ids(
                &ids,
            );
            data_store::get_immutable_perpetual_from_table(
                immutable_perpetual_table,
                string::utf8(b"XYZ"),
            );

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1009,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_fail_to_fetch_unsupported_perpetual_from_ids() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::get_immutable_perpetual_from_ids(&ids, string::utf8(b"XYZ"));

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = 1005,
            location = bluefin_cross_margin_dex::data_store,
        ),
    ]
    public fun should_get_invalid_compute_and_update_sequence_hash() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(
                &scenario,
                protocol_admin,
            );
            data_store::compute_and_update_sequence_hash(&mut ids, x"12", x"12");

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_tee_update_account_type() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        let payload: vector<u8> =
            x"23426c756566696e2050726f20544545204163636f756e7420547970652055706461746563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f9ba56e9990100009ab277e999010000";
        let signature: vector<u8> =
            x"00388a54cf0d7b399b88af2b06bbb2c3f9240818faddc589d2e4f1514477fb307a7d479391add61e11f64f716949faac17b17341688d2e9cadc16759185474e202d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        test_utils::tee_update(
            &mut scenario,
            payload,
            signature,
            1000000000000,
            b"account_type",
        );

        test_scenario::end(scenario);
    }
}
