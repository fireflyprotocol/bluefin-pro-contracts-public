module bluefin_cross_margin_dex::test_bank {
    use sui::test_scenario;
    use bluefin_cross_margin_dex::test_utils::{Self, USDC, SUI};
    use bluefin_cross_margin_dex::account;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore, ExternalDataStore};
    use bluefin_cross_margin_dex::bank;
    use bluefin_cross_margin_dex::exchange;
    use std::vector;
    use std::string::{Self, String};
    use sui::coin;

    #[test]
    public fun should_successfully_deposit_to_asset_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let amount = 1000000;

        let nonce =test_utils::deposit_to_asset_bank(&mut scenario, b"USDC", account, amount);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let bank = data_store::get_asset_bank(&mut eds);
            // this will revert if the deposit was not successfully added to the bank
            bank::get_deposited_asset(bank, nonce);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };


        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_update_account_deposited_amount_in_internal_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let amount = 1000000;

        let nonce = test_utils::deposit_to_asset_bank(&mut scenario, b"USDC", account, amount);
 
        test_utils::deposit_to_internal_bank(&mut scenario, nonce);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            // this is amount value in 1e9
            assert!(account::get_usdc_amount(account) == 1000000000, 0);            
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_remove_tainted_deposit_from_asset_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let amount = 1000000;

        let nonce = test_utils::deposit_to_asset_bank(&mut scenario, b"USDC", account, amount);
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let bytes = test_utils::get_deposit_bytes(&mut eds, nonce, true);
            let sequence_hash = data_store::get_next_sequence_hash(&ids, bytes);
            exchange::remove_tainted_asset<USDC>(
                &mut ids, 
                &mut eds, 
                nonce,
                sequence_hash
            );

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
 
    }


    #[test]
    #[expected_failure(abort_code = 1003, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_remove_non_existent_tainted_deposit_from_asset_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            exchange::remove_tainted_asset<USDC>(
                &mut ids, 
                &mut eds, 
                1,
                b""
            );

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
 
    }


    #[test]
    public fun should_successfully_withdraw_from_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e1f50500000000b5ed9c9e9901000000e40b5402000000";
        let signature = x"01679d391cab179615782faf600f57c07f9cc463d969ec8ecd7d03443029ae011129b416eb220389c41acd79a4d318a59669c6594188e82c837d976b223865e72602ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            // this is amount value in 1e9
            assert!(account::get_usdc_amount(account) == 900000000, 0);            
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1065, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_withdraw_from_bank_as_withdraw_amount_is_greater_than_available_account_balance(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e40b54020000006750a59e9901000000e40b5402000000";
        let signature = x"015021db8eba1a7b760771d1e6df3e0e16c0c50a02180898b53ab17e9003f058f2670761f27eec209b0e9789687643254a9055d5391eba7ab69b03e611f11ef7c802ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );


        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_withdraw_as_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e40b54020000006750a59e9901000000e40b5402000000";
        let signature = x"015021db8eba1a7b760771d1e6df3e0e16c0c50a02180898b53ab17e9003f058f2670761f27eec209b0e9789687643254a9055d5391eba7ab69b03e611f11ef7c802ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );


        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_withdraw_as_eds_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_eds_version(&mut scenario, 0);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e40b54020000006750a59e9901000000e40b5402000000";
        let signature = x"015021db8eba1a7b760771d1e6df3e0e16c0c50a02180898b53ab17e9003f058f2670761f27eec209b0e9789687643254a9055d5391eba7ab69b03e611f11ef7c802ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );


        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1014, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_withdraw_as_signer_does_not_have_permission_for_account(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e1f50500000000a6dfae9e9901000000e40b5402000000";
        let signature = x"007fe1ebcafee1898786bd850de4afa68a8a01903e2918dca79ca2a3754930f94443f5645f5519fe9bedccb5be0c12ce47f347725e5be6ed1fb12431ce077d300cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );


        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_withdraw_as_withdrawal_request_is_too_old(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let deposit_amount = 1000000; // 1 in 1e6

        test_utils::deposit(&mut scenario, account, deposit_amount);

        let payload = x"e551380f9899c1445b839925a0a9cf9a1e99abf6ca70f9e8899ab37f70a7f36b045553444380c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa00e1f505000000005916bf9e990100006400000000000000";
        let signature = x"0135a9fa3bdac5e53461d25bea974cdf0d1ff03c4552342c8cc264406b3727d85864bc092b40f64888e89719df664a7331e2dc68a3248f1cb6c3681472142a795102ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";
        let oracle_prices = vector::empty<u64>();
        let perpetuals = vector::empty<String>();
        let timestamp = 10000000000;

        test_utils::withdraw_from_bank(
            &mut scenario, 
            payload, 
            signature, 
            perpetuals, 
            oracle_prices, 
            timestamp
        );

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_get_amount_as_is_when_asset_passed_is_empty(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let assets_table = data_store::get_immutable_assets_table_from_ids(&ids);

            let amount = bank::get_asset_with_provided_usd_value(assets_table, string::utf8(b""), 1000000);
            assert!(amount == 1000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
        
    }

    #[test]
    #[expected_failure(abort_code = 1036, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_get_amount_when_asset_passed_is_not_supported(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let assets_table = data_store::get_immutable_assets_table_from_ids(&ids);

            bank::get_asset_with_provided_usd_value(assets_table, string::utf8(b"xyz"), 1000000);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
        
    }

    #[test]
    public fun should_return_correct_amount_in_usdc_when_asset_passed_is_usdc(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);
            let assets_table = data_store::get_immutable_assets_table_from_ids(&ids);

            let amount = bank::get_asset_with_provided_usd_value(assets_table, string::utf8(b"USDC"), 1000000);
            assert!(amount == 1000000, 0);
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
        
    }


    #[test]
    #[expected_failure(abort_code = 1036, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_withdraw_an_unsupported_asset(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);

            bank::withdraw_from_bank_directly<USDC>(
                asset_bank, 
                string::utf8(b"xyz"), 
                protocol_admin, 1000000, 
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1047, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_withdraw_an_unsupported_asset_type_and_symbol_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);

            bank::withdraw_from_bank_directly<SUI>(
                asset_bank, 
                string::utf8(b"USDC"), 
                protocol_admin, 1000000, 
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1036, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_deposit_an_unsupported_asset_to_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);
            let amount = 1000000;
            let deposit_coin = coin::mint_for_testing<USDC>(amount, test_scenario::ctx(&mut scenario));

            bank::add_deposit_directly<USDC>(
                asset_bank, 
                string::utf8(b"xyz"), 
                protocol_admin, 
                amount, 
                &mut deposit_coin,
                test_scenario::ctx(&mut scenario)
            );

            coin::burn_for_testing<USDC>(deposit_coin);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_deposit_out_of_range_amount_to_bank(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);
            let amount = 0;
            let deposit_coin = coin::mint_for_testing<USDC>(amount, test_scenario::ctx(&mut scenario));

            bank::add_deposit_directly<USDC>(
                asset_bank, 
                string::utf8(b"USDC"), 
                protocol_admin, 
                amount, 
                &mut deposit_coin,
                test_scenario::ctx(&mut scenario)
            );

            coin::burn_for_testing<USDC>(deposit_coin);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_deposit_out_of_range_amount_to_bank_max_deposit(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);
            let amount = 10000000000000;
            let deposit_coin = coin::mint_for_testing<USDC>(amount, test_scenario::ctx(&mut scenario));

            bank::add_deposit_directly<USDC>(
                asset_bank, 
                string::utf8(b"USDC"), 
                protocol_admin, 
                amount, 
                &mut deposit_coin,
                test_scenario::ctx(&mut scenario)
            );

            coin::burn_for_testing<USDC>(deposit_coin);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }


     #[test]
    #[expected_failure(abort_code = 1002, location = bluefin_cross_margin_dex::bank)]
    public fun should_fail_to_deposit_when_coin_does_not_have_enough_amount(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let eds = test_scenario::take_shared<ExternalDataStore>(&scenario);
            let asset_bank = data_store::get_asset_bank(&mut eds);
            let amount = 1000000;
            let deposit_coin = coin::mint_for_testing<USDC>(amount - 1, test_scenario::ctx(&mut scenario));

            bank::add_deposit_directly<USDC>(
                asset_bank, 
                string::utf8(b"USDC"), 
                protocol_admin, 
                amount, 
                &mut deposit_coin,
                test_scenario::ctx(&mut scenario)
            );

            coin::burn_for_testing<USDC>(deposit_coin);
            test_scenario::return_shared<ExternalDataStore>(eds);
        };

        test_scenario::end(scenario);
    }


}