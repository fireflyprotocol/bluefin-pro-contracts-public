module bluefin_cross_margin_dex::test_adl {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::test_trade;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::exchange;
    use std::string::{Self, String};

    #[test_only]
    public fun execute_adl(
        scenario: &mut Scenario,
        payload: vector<u8>,
        signature: vector<u8>,
        perpetuals: vector<String>,
        oracle_prices: vector<u64>,
        timestamp: u64,
    ) {
        let protocol_admin = test_utils::protocol_admin();
        test_scenario::next_tx(scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, protocol_admin);
            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::deleverage(&mut ids, payload, signature, perpetuals, oracle_prices, sequence_hash, timestamp);
            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
        }
    }

    #[test_only]
    public fun setup_scenario(scenario: &mut Scenario) {
        test_utils::init_package_for_testing(scenario);

        test_utils::deposit(scenario, test_utils::maker(), 100000000);
        test_utils::deposit(scenario, test_utils::taker(), 5000000000);

        let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d101000000ca9a3b000000000000000000000000044c4f4e470543524f53538f01aa2094010000446c8ba4990100008501aa2094010000";
        let maker_signature = x"01f2307acfa4bf917bf2cb16bd35a1de361dbc7bc376b7be8912fd2cbb7c0db4654926e0113e9f6635d54af8976ee9009fde5756d66bce001e0b5ff18bb541f94802ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

        let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d101000000ca9a3b0000000000943577000000000553484f52540849534f4c415445448f01aa2094010000552f7ca4990100008501aa2094010000";
        let taker_signature = x"0183742a24e029bcc8fff78aeb4d755b8c921761e885eed83103e83b738ed47d85068fd43e4bc1ecb5ff4710e4cb79619b61f99307a0159ec9ce788cfd8d8fa08502d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        let quantity = 1000000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        test_trade::trade(
            scenario,
            maker_order,
            taker_order,
            maker_signature,
            taker_signature,
            quantity,
            price,
            timestamp
        );

    }

    #[test]
    public fun should_perform_adl_successfully() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        let payload = x"0f426c756566696e2050726f2041444c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a290001084554482d5045525000e1f5050000000000dd9f6ada01000019157ca4990100008201aa2094010000";
        let signature = x"00b1a32332117234553909095ccbd90efe580d1fe3e466a2c2117de0a14dc6c8a009c1f11a065bc5240777480b643aa39104aa927cc04f5ef21c2a1bd54ed46906d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[1000000000000];
        let timestamp = 1735714800002;

        execute_adl(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_adl_as_ids_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);
        test_utils::set_ids_version(&mut scenario, 0);

        let payload = x"0f426c756566696e2050726f2041444c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a290001084554482d5045525000e1f5050000000000dd9f6ada01000019157ca4990100008201aa2094010000";
        let signature = x"00b1a32332117234553909095ccbd90efe580d1fe3e466a2c2117de0a14dc6c8a009c1f11a065bc5240777480b643aa39104aa927cc04f5ef21c2a1bd54ed46906d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[1000000000000];
        let timestamp = 1735714800002;

        execute_adl(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1012, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_adl_as_maker_is_not_bankrupt() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        let payload = x"0f426c756566696e2050726f2041444c63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a290001084554482d5045525000e1f5050000000000dd9f6ada01000019157ca4990100008201aa2094010000";
        let signature = x"00b1a32332117234553909095ccbd90efe580d1fe3e466a2c2117de0a14dc6c8a009c1f11a065bc5240777480b643aa39104aa927cc04f5ef21c2a1bd54ed46906d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[1950000000000];
        let timestamp = 1735714800002;

        execute_adl(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);

        test_scenario::end(scenario);
    }
}