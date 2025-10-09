module bluefin_cross_margin_dex::test_operator_controlled_methods {

    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::exchange;
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::account;



    #[test_only]
    public fun insert_tx_hash_in_ids(scenario: &mut Scenario, hash: vector<u8>, timestamp: u64){
        let protocol_admin = test_utils::protocol_admin();
        test_scenario::next_tx(scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, protocol_admin);
            data_store::insert_tx_hash_in_ids(&mut ids, hash, timestamp);
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };
    }

    #[test_only]
    public fun insert_order_fill_in_ids(scenario: &mut Scenario, hash: vector<u8>, quantity: u64, timestamp: u64){
        let protocol_admin = test_utils::protocol_admin();
        test_scenario::next_tx(scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, protocol_admin);
            data_store::insert_order_fill_in_ids(&mut ids, hash, quantity, timestamp);
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };
    }

    #[test]
    public fun should_successfully_prune_tx_hash_table(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);
        insert_tx_hash_in_ids(&mut scenario, x"56", 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1045, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_prune_non_existent_hash_from_tx_hash_table(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_prune_order_filles_table(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_order_fill_in_ids(&mut scenario, x"12", 1, 1);
        insert_order_fill_in_ids(&mut scenario, x"34", 1, 1);
        insert_order_fill_in_ids(&mut scenario, x"56", 1, 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750301120134015602abf186a9990100008201aa2094010000";
        let signature = x"00af4768ca26f435d9c4167702906244edefcd13daad8d6943d902930b7d862d120ad7d19ab13aaef4419880265adabc9ba577702214ea81b348b9a777603d7705d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1735714800002);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1045, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_prune_non_existent_hash_from_order_filles_table(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_order_fill_in_ids(&mut scenario, x"12", 1, 1);
        insert_order_fill_in_ids(&mut scenario, x"34", 1, 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750301120134015602abf186a9990100008201aa2094010000";
        let signature = x"00af4768ca26f435d9c4167702906244edefcd13daad8d6943d902930b7d862d120ad7d19ab13aaef4419880265adabc9ba577702214ea81b348b9a777603d7705d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1735714800002);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_prune_tx_hash_table_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);
        insert_tx_hash_in_ids(&mut scenario, x"56", 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_prune_tx_hash_table_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);
        insert_tx_hash_in_ids(&mut scenario, x"56", 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 2000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_prune_tx_hash_table_as_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);
        insert_tx_hash_in_ids(&mut scenario, x"56", 1);

        let payload = x"19436c756566696e2050726f205072756e696e67205461626c6563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_prune_tx_hash_table_as_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        insert_tx_hash_in_ids(&mut scenario, x"12", 1);
        insert_tx_hash_in_ids(&mut scenario, x"34", 1);
        insert_tx_hash_in_ids(&mut scenario, x"56", 1);

        let payload = x"19426c756566696e2050726f205072756e696e67205461626c6563d9a65220318069fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397503011201340156017f4f099e990100008c68199e99010000";
        let signature = x"00821a69f1d733b15c793a8775400c1e1615b3e61fe29550d731163bf4f9cd728890c7300b5961ca4e6ebdb280f6f0914037b9acd37ea10fa1f7f6103fcc130808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::prune_table(&mut ids, payload, signature, sequence_hash, 1000000000000);

            // will revert if hash is not removed
            data_store::validate_tx_replay(&mut ids, x"12", 1);
            data_store::validate_tx_replay(&mut ids, x"34", 1);
            data_store::validate_tx_replay(&mut ids, x"56", 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_authorize_and_unauthorize_liquidator(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;

        // authorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
             let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f8b90e9e990100006667289e99010000";
             let signature = x"009087804b3952958fefdef20603fca4af2d76fb7e556c1dcc7ff53b774a8b56295759bedc4ab6c212477cf03dd28441386fda6ec160db316b1325b603ab0a6f0dd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        // unauthorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa000f851e9e99010000b05b339e99010000";
            let signature = x"00ecd6cad4a3d5385fcd26122def2dcfdd9e730044546ea5a9cbb63cb76f8b2cee1a96931bdd782da3931f8833a3a98bc53664a55b4025b81a2aee0fab221f600cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == false, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_and_unauthorize_liquidator_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;

        // authorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
             let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f8b90e9e990100006667289e99010000";
             let signature = x"009087804b3952958fefdef20603fca4af2d76fb7e556c1dcc7ff53b774a8b56295759bedc4ab6c212477cf03dd28441386fda6ec160db316b1325b603ab0a6f0dd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        // unauthorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa000f851e9e99010000b05b339e99010000";
            let signature = x"00ecd6cad4a3d5385fcd26122def2dcfdd9e730044546ea5a9cbb63cb76f8b2cee1a96931bdd782da3931f8833a3a98bc53664a55b4025b81a2aee0fab221f600cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == false, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_and_unauthorize_liquidator_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;

        // authorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
             let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f8b90e9e990100006667289e99010000";
             let signature = x"009087804b3952958fefdef20603fca4af2d76fb7e556c1dcc7ff53b774a8b56295759bedc4ab6c212477cf03dd28441386fda6ec160db316b1325b603ab0a6f0dd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 2000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_and_unauthorize_liquidator_due_to_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;

        // authorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
             let payload = x"22426c256566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f8b90e9e990100006667289e99010000";
             let signature = x"009087804b3952958fefdef20603fca4af2d76fb7e556c1dcc7ff53b774a8b56295759bedc4ab6c212477cf03dd28441386fda6ec160db316b1325b603ab0a6f0dd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        // unauthorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let payload = x"22426c456566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa000f851e9e99010000b05b339e99010000";
            let signature = x"00ecd6cad4a3d5385fcd26122def2dcfdd9e730044546ea5a9cbb63cb76f8b2cee1a96931bdd782da3931f8833a3a98bc53664a55b4025b81a2aee0fab221f600cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == false, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_and_unauthorize_liquidator_due_to_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;

        // authorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
             let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c906183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01f8b90e9e990100006667289e99010000";
             let signature = x"009087804b3952958fefdef20603fca4af2d76fb7e556c1dcc7ff53b774a8b56295759bedc4ab6c212477cf03dd28441386fda6ec160db316b1325b603ab0a6f0dd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        // unauthorize liquidator
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa000f851e9e99010000b05b339e99010000";
            let signature = x"00ecd6cad4a3d5385fcd26122def2dcfdd9e730044546ea5a9cbb63cb76f8b2cee1a96931bdd782da3931f8833a3a98bc53664a55b4025b81a2aee0fab221f600cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1000000000000);

            assert!(data_store::is_whitelisted_liquidator(&ids, account) == false, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_set_an_account_fee_tier(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"24426c756566696e2050726f2053657474696e67204163636f756e7420466565205469657263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0065cd1d0000000000e1f5050000000001137c309e990100000010a5d4e8000000";
        let signature = x"00350953a50aba4ff6abc0c75e4843a0d8a618c826f68668a86a231ee4abe315d34c02742752eb7d8ea342d537c7c7222a892f98762ea0333817201fad32e2e30cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_fee_tier(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let (maker, taker, applied) = account::get_fees(account);   

            assert!(maker == 500000000, 0);
            assert!(taker == 100000000, 1);
            assert!(applied == true, 2);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_fee_tier_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);
        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"24426c756566696e2050726f2053657474696e67204163636f756e7420466565205469657263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0065cd1d0000000000e1f5050000000001137c309e990100000010a5d4e8000000";
        let signature = x"00350953a50aba4ff6abc0c75e4843a0d8a618c826f68668a86a231ee4abe315d34c02742752eb7d8ea342d537c7c7222a892f98762ea0333817201fad32e2e30cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_fee_tier(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let (maker, taker, applied) = account::get_fees(account);   

            assert!(maker == 500000000, 0);
            assert!(taker == 100000000, 1);
            assert!(applied == true, 2);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_fee_tier_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"24426c756566696e2050726f2053657474696e67204163636f756e7420466565205469657263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0065cd1d0000000000e1f5050000000001137c309e990100000010a5d4e8000000";
        let signature = x"00350953a50aba4ff6abc0c75e4843a0d8a618c826f68668a86a231ee4abe315d34c02742752eb7d8ea342d537c7c7222a892f98762ea0333817201fad32e2e30cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_fee_tier(&mut ids, payload, signature, sequence_hash, 2000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let (maker, taker, applied) = account::get_fees(account);   

            assert!(maker == 500000000, 0);
            assert!(taker == 100000000, 1);
            assert!(applied == true, 2);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_fee_tier_due_to_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"24426c256566696e2050726f2053657474696e67204163636f756e7420466565205469657263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0065cd1d0000000000e1f5050000000001137c309e990100000010a5d4e8000000";
        let signature = x"00350953a50aba4ff6abc0c75e4843a0d8a618c826f68668a86a231ee4abe315d34c02742752eb7d8ea342d537c7c7222a892f98762ea0333817201fad32e2e30cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_fee_tier(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let (maker, taker, applied) = account::get_fees(account);   

            assert!(maker == 500000000, 0);
            assert!(taker == 100000000, 1);
            assert!(applied == true, 2);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_fee_tier_due_to_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"24426c756566696e2050726f2053657474696e67204163636f756e7420466565205469657263d9a65220318469fb169034d1a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0065cd1d0000000000e1f5050000000001137c309e990100000010a5d4e8000000";
        let signature = x"00350953a50aba4ff6abc0c75e4843a0d8a618c826f68668a86a231ee4abe315d34c02742752eb7d8ea342d537c7c7222a892f98762ea0333817201fad32e2e30cd6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_fee_tier(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let (maker, taker, applied) = account::get_fees(account);   

            assert!(maker == 500000000, 0);
            assert!(taker == 100000000, 1);
            assert!(applied == true, 2);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_set_an_account_type(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"20426c756566696e2050726f2053657474696e67204163636f756e74207479706563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa012c842b9e990100000010a5d4e8000000";
        let signature = x"00c814dd7f005dc8151171008cdecdf5865173583ea0d266ecba4f3a02cd045dde24edfef3b00e4137983cf26e4d74b69efc6b63604ce50ffb5fdfd29f38e34c03d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_account_type(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let is_institution = account::is_institution(account);   

            assert!(is_institution == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_type_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"20426c756566696e2050726f2053657474696e67204163636f756e74207479706563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa012c842b9e990100000010a5d4e8000000";
        let signature = x"00c814dd7f005dc8151171008cdecdf5865173583ea0d266ecba4f3a02cd045dde24edfef3b00e4137983cf26e4d74b69efc6b63604ce50ffb5fdfd29f38e34c03d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_account_type(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let is_institution = account::is_institution(account);   

            assert!(is_institution == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_type_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"20426c756566696e2050726f2053657474696e67204163636f756e74207479706563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa012c842b9e990100000010a5d4e8000000";
        let signature = x"00c814dd7f005dc8151171008cdecdf5865173583ea0d266ecba4f3a02cd045dde24edfef3b00e4137983cf26e4d74b69efc6b63604ce50ffb5fdfd29f38e34c03d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_account_type(&mut ids, payload, signature, sequence_hash, 2000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let is_institution = account::is_institution(account);   

            assert!(is_institution == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_type_due_to_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"20426c356566696e2050726f2053657474696e67204163636f756e74207479706563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa012c842b9e990100000010a5d4e8000000";
        let signature = x"00c814dd7f005dc8151171008cdecdf5865173583ea0d266ecba4f3a02cd045dde24edfef3b00e4137983cf26e4d74b69efc6b63604ce50ffb5fdfd29f38e34c03d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_account_type(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let is_institution = account::is_institution(account);   

            assert!(is_institution == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_account_type_due_to_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"20426c756566696e2050726f2053657474696e67204163636f756e74207479706563d9a65220318461fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa012c842b9e990100000010a5d4e8000000";
        let signature = x"00c814dd7f005dc8151171008cdecdf5865173583ea0d266ecba4f3a02cd045dde24edfef3b00e4137983cf26e4d74b69efc6b63604ce50ffb5fdfd29f38e34c03d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set fee tier
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);

            data_store::create_user_account(&mut ids, account);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_account_type(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let account = data_store::get_immutable_account_from_ids(&ids, account);
            let is_institution = account::is_institution(account);   

            assert!(is_institution == true, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_set_an_gas_fee(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let payload = x"1b426c756566696e2050726f2053657474696e67204761732046656563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750065cd1d00000000d0222d9e990100000010a5d4e8000000";
        let signature = x"00b8369bc19b41cae4d4b8db518c24aec437b501019e5669fc8778139092e88f8366c4229a5aab60998e58087418d6f09833f8db9436ca4d8f10f5b5c5ee019c08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set gas fee
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_fee(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let gas_fee_amount = data_store::get_gas_fee_amount(&ids);   

            assert!(gas_fee_amount == 500000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_gas_fee_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        test_utils::set_ids_version(&mut scenario, 0);

        let payload = x"1b426c756566696e2050726f2053657474696e67204761732046656563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750065cd1d00000000d0222d9e990100000010a5d4e8000000";
        let signature = x"00b8369bc19b41cae4d4b8db518c24aec437b501019e5669fc8778139092e88f8366c4229a5aab60998e58087418d6f09833f8db9436ca4d8f10f5b5c5ee019c08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set gas fee
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_fee(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let gas_fee_amount = data_store::get_gas_fee_amount(&ids);   

            assert!(gas_fee_amount == 500000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_gas_fee_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let payload = x"1b426c756566696e2050726f2053657474696e67204761732046656563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750065cd1d00000000d0222d9e990100000010a5d4e8000000";
        let signature = x"00b8369bc19b41cae4d4b8db518c24aec437b501019e5669fc8778139092e88f8366c4229a5aab60998e58087418d6f09833f8db9436ca4d8f10f5b5c5ee019c08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set gas fee
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_fee(&mut ids, payload, signature, sequence_hash, 2000000000000);
            let gas_fee_amount = data_store::get_gas_fee_amount(&ids);   

            assert!(gas_fee_amount == 500000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_gas_fee_due_to_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let payload = x"1b426c756166696e2050726f2053657474696e67204761732046656563d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39750065cd1d00000000d0222d9e990100000010a5d4e8000000";
        let signature = x"00b8369bc19b41cae4d4b8db518c24aec437b501019e5669fc8778139092e88f8366c4229a5aab60998e58087418d6f09833f8db9436ca4d8f10f5b5c5ee019c08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set gas fee
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_fee(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let gas_fee_amount = data_store::get_gas_fee_amount(&ids);   

            assert!(gas_fee_amount == 500000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_an_gas_fee_due_to_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let payload = x"1b426c756566696e2050726f2053657474696e67204761732046656563d9a65220318469fb119034d8a011eae3f014fed2a1f8c006183e2ece3c39750065cd1d00000000d0222d9e990100000010a5d4e8000000";
        let signature = x"00b8369bc19b41cae4d4b8db518c24aec437b501019e5669fc8778139092e88f8366c4229a5aab60998e58087418d6f09833f8db9436ca4d8f10f5b5c5ee019c08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
        // set gas fee
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_fee(&mut ids, payload, signature, sequence_hash, 1000000000000);
            let gas_fee_amount = data_store::get_gas_fee_amount(&ids);   

            assert!(gas_fee_amount == 500000000, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_set_new_gas_pool(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"1c426c756566696e2050726f2053657474696e672047617320506f6f6c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aab3b2279e990100000010a5d4e8000000";
        let signature = x"009b15723091aeac1556e0390b1c703e652616ce6b7b702faee2c3efd2f96863cefa382b8a76b144e43e45919b69361dd3309064fd0f67434e6c9b6a37b0522800d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        // set gas pool
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_pool(&mut ids, payload, signature, sequence_hash, 1000000000000);
            
            let gas_pool = data_store::get_gas_pool(&ids);   
            assert!(gas_pool == account, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_new_gas_pool_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        test_utils::set_ids_version(&mut scenario, 0);
        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"1c426c756566696e2050726f2053657474696e672047617320506f6f6c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aab3b2279e990100000010a5d4e8000000";
        let signature = x"009b15723091aeac1556e0390b1c703e652616ce6b7b702faee2c3efd2f96863cefa382b8a76b144e43e45919b69361dd3309064fd0f67434e6c9b6a37b0522800d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        // set gas pool
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_pool(&mut ids, payload, signature, sequence_hash, 1000000000000);
            
            let gas_pool = data_store::get_gas_pool(&ids);   
            assert!(gas_pool == account, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_new_gas_pool_due_to_payload_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"1c426c756566696e2050726f2053657474696e672047617320506f6f6c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aab3b2279e990100000010a5d4e8000000";
        let signature = x"009b15723091aeac1556e0390b1c703e652616ce6b7b702faee2c3efd2f96863cefa382b8a76b144e43e45919b69361dd3309064fd0f67434e6c9b6a37b0522800d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        // set gas pool
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_pool(&mut ids, payload, signature, sequence_hash, 2000000000000);
            
            let gas_pool = data_store::get_gas_pool(&ids);   
            assert!(gas_pool == account, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_new_gas_pool_as_payload_type_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"1c426c756566196e2050726f2053657474696e672047617320506f6f6c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aab3b2279e990100000010a5d4e8000000";
        let signature = x"009b15723091aeac1556e0390b1c703e652616ce6b7b702faee2c3efd2f96863cefa382b8a76b144e43e45919b69361dd3309064fd0f67434e6c9b6a37b0522800d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        // set gas pool
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_pool(&mut ids, payload, signature, sequence_hash, 1000000000000);
            
            let gas_pool = data_store::get_gas_pool(&ids);   
            assert!(gas_pool == account, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_set_new_gas_pool_due_to_target_ids_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        let account = @0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa;
        let payload = x"1c426c756566696e2050726f2053657474696e672047617320506f6f6c63d9a65221318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aab3b2279e990100000010a5d4e8000000";
        let signature = x"009b15723091aeac1556e0390b1c703e652616ce6b7b702faee2c3efd2f96863cefa382b8a76b144e43e45919b69361dd3309064fd0f67434e6c9b6a37b0522800d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        // set gas pool
        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, protocol_admin);


            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::set_gas_pool(&mut ids, payload, signature, sequence_hash, 1000000000000);
            
            let gas_pool = data_store::get_gas_pool(&ids);   
            assert!(gas_pool == account, 0);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        };

        test_scenario::end(scenario);
    }


}