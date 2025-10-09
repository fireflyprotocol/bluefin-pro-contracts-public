module bluefin_cross_margin_dex::test_signature {
    use sui::test_scenario::{Self};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::signature;

    #[test]
    public fun should_pass_zk_signature_without_verification() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {

            let message = x"";
            let signature = x"05a91adcff722c2e9cafca8a927a14600d9103c4a9a593434f6066ff2afef355170f7bfc8c128af5cb818d962152c0163d3eb5ff3cfc7af18560bf95d6c6187a04d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            let signer = signature::verify_signature_and_recover_signer(message, signature);
            assert!(signer == @0, 0);

        };

        test_scenario::end(scenario);
    }   


    #[test]
    #[expected_failure(abort_code = 2002, location = bluefin_cross_margin_dex::signature)]
    public fun should_revert_with_unknown_wallet_scheme() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {

            let message = x"";
            let signature = x"06a91adcff722c2e9cafca8a927a14600d9103c4a9a593434f6066ff2afef355170f7bfc8c128af5cb818d962152c0163d3eb5ff3cfc7af18560bf95d6c6187a04d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

            signature::verify_signature_and_recover_signer(message, signature);

        };

        test_scenario::end(scenario);
    }   


    #[test]
    #[expected_failure(abort_code = 2000, location = bluefin_cross_margin_dex::signature)]
    public fun should_revert_as_payload_type_is_unknown() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {

            signature::verify_bcs_serialized_payload_signature(x"", x"", b"unknown");

        };

        test_scenario::end(scenario);
    }   


}