module bluefin_cross_margin_dex::test_authorized_account {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::exchange;
    use sui::bcs;

    struct AuthorizeAccount has copy, drop{
        ids: address,
        account: address,
        user: address,
        status: bool,
        salt: u64,
        signed_at: u64
    }

    #[test_only]
    public fun get_authorize_account_struct(): AuthorizeAccount {
        AuthorizeAccount {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            user: test_utils::taker(),
            status: true,
            salt: 0,
            signed_at: 1735714800001
        }
    }

    #[test_only]
    public fun execute_authorize_account(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        timestamp: u64,
    ) {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());
            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_account(&mut ids, payload, signature, sequence_hash, timestamp);
            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        }
    }
    
    #[test]
    public fun should_successfully_authorize_account() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        // authorize account
        {
            let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39753a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa01b04c10a7990100008101aa2094010000";
            let signature = x"00c1d2c85f0495a47fca1c4d49303f4bee64d995a6d336244926916aba1092928950a5ae1273fd245adb50fa6e9e69366b080a9cb28530ca88caec9bc900c77808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
            let timestamp = 1735714800001;
            execute_authorize_account(&mut scenario, payload, signature, timestamp);
        };

        // de-authorize account
        {

            let payload = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39753a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa0030b308a7990100008101aa2094010000";
            let signature = x"00a91adcff722c2e9cafca8a927a14600d9103c4a9a593434f6066ff2afef355170f7bfc8c128af5cb818d962152c0163d3eb5ff3cfc7af18560bf95d6c6187a04d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
            let timestamp = 1735714800001;

            execute_authorize_account(&mut scenario, payload, signature, timestamp);
        };


        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_account_due_to_ids_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);
        
        let authorize_account = get_authorize_account_struct();
        let payload = bcs::to_bytes<AuthorizeAccount>(&authorize_account);
        let signature = x"00c1d2c85f0495a47fca1c4d49303f4bee64d995a6d336244926916aba1092928950a5ae1273fd245adb50fa6e9e69366b080a9cb28530ca88caec9bc900c77808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735714800001;

        execute_authorize_account(&mut scenario, payload, signature, timestamp);


        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_account_due_to_invalid_ids() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        let authorize_account = get_authorize_account_struct();
        authorize_account.ids = @0x0;
        let payload = bcs::to_bytes<AuthorizeAccount>(&authorize_account);
        let signature = x"00c1d2c85f0495a47fca1c4d49303f4bee64d995a6d336244926916aba1092928950a5ae1273fd245adb50fa6e9e69366b080a9cb28530ca88caec9bc900c77808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735714800001;

        execute_authorize_account(&mut scenario, payload, signature, timestamp);


        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_authorize_account_due_to_exceeds_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);
        
        let authorize_account = get_authorize_account_struct();
        authorize_account.signed_at = 100000;
        let payload = bcs::to_bytes<AuthorizeAccount>(&authorize_account);
        let signature = x"00c1d2c85f0495a47fca1c4d49303f4bee64d995a6d336244926916aba1092928950a5ae1273fd245adb50fa6e9e69366b080a9cb28530ca88caec9bc900c77808d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
        let timestamp = 1735714800001;

        execute_authorize_account(&mut scenario, payload, signature, timestamp);

        test_scenario::end(scenario);
    }
}