module bluefin_cross_margin_dex::test_liquidations {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::test_trade;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::exchange;
    use bluefin_cross_margin_dex::account;
    use std::string::{Self, String};
    use sui::bcs;

    const LIQUIDATOR: address = @0x3a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e;

    struct Liquidate has copy, drop {
        type: String,
        ids: address,
        liquidatee: address,
        liquidator: address,
        market: String,
        quantity: u64,
        isolated: bool,
        assume_as_cross: bool,
        all_or_nothing: bool,
        leverage: u64,
        expiry: u64,
        salt: u64,
        signed_at: u64,
    }

    public fun liquidate_order(): Liquidate {
        Liquidate {
            type: string::utf8(b"Bluefin Pro Liquidation"), 
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            liquidatee: @0x2183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29,
            liquidator: @0x3a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e,
            market: string::utf8(b"ETH-PERP"),
            quantity: 100000000,
            isolated: true,
            assume_as_cross: false,
            all_or_nothing: false,
            leverage: 1000000000,
            expiry: 2037603360000,
            salt:   1759399666108,
            signed_at: 1735714800002
        }       
    }

    #[test_only]
    public fun setup_scenario(scenario: &mut Scenario) {
        test_utils::init_package_for_testing(scenario);

        test_trade::execute_trade(scenario);

        test_utils::deposit(scenario, LIQUIDATOR, 1000000000);

         test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
             let payload = x"22426c756566696e2050726f20417574686f72697a696e67204c697175696461746f7263d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39753a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e01de635ba4990100008201aa2094010000";
             let signature = x"0007ffdbdb148ea637d22fc20f40400ab5d02a387b7c5291bc4652e12b28fd287ffbd5c3f7caffe517de958cf8a8240d8918f0861a95f6caf334cb47f4e9053b05d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";
       
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);
            exchange::authorize_liquidator(&mut ids, payload, signature, sequence_hash, 1735714800002);

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        };        
    }

    #[test_only]
    public fun  liquidate_position(
        scenario: &mut Scenario, 
        payload: vector<u8>, 
        signature: vector<u8>, 
        perpetuals: vector<String>, 
        oracle_prices: vector<u64>, 
        timestamp: u64
        ) {

        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let sequence_hash = data_store::get_next_sequence_hash(&ids, signature);

            exchange::liquidate(
                &mut ids, 
                payload, 
                signature, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
            );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);

        }

    }

    #[test]
    public fun should_successfully_perform_standard_liquidation() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_standard_liquidation_with_pending_funding_payment() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        test_utils::set_pending_funding_payment(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true, 300000000);

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, pending_funding_payment, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);
        assert!(pending_funding_payment == 0, 2);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_perform_bankrupt_liquidation() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[4100000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_perform_bankrupt_liquidation_with_pending_funding_payment() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        test_utils::set_pending_funding_payment(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true, 300000000);

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[4100000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, pending_funding_payment, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);
        assert!(pending_funding_payment == 0, 2);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1042, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_as_account_is_not_liquidateable() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2900000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_due_to_ids_version_mismatch() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);
        test_utils::set_ids_version(&mut scenario, 0);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();

        let payload = x"17426c756566696e2050726f204c69717569646174696f6e63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a293a95dd9b605dfc6859fc6d3ed88d22f3491881af404b2ef0bbe1d02a03ccf38e084554482d5045525000e1f5050000000001000000ca9a3b0000000000dd9f6ada01000050fe58a4990100008201aa2094010000";
        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);
        assert!(size == 0, 1);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1066, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_due_to_invalid_payload_type() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.type = string::utf8(b"Dummy");
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1058, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_due_to_self_trade() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.liquidatee = test_utils::taker();
        liquidate_order.liquidator = test_utils::taker();
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_due_to_invalid_ids() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.ids = @0x0;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_due_to_payload_life_exceeds_max_allowed_lifespan() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.signed_at = 100000;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1027, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_as_liquidation_order_is_expired() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.expiry = 1735714800000;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1059, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_as_both_isolated_and_cross_positions_are_not_allowed() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.liquidator = test_utils::maker();
        liquidate_order.assume_as_cross = false;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1035, location = bluefin_cross_margin_dex::account)]
    public fun should_fail_to_perform_liquidation_as_liquidatee_has_no_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.liquidatee = protocol_admin;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1016, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_perform_liquidation_as_liquidatee_account_does_not_exist() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.liquidatee = @0x0;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);

        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }



    #[test]
    #[expected_failure(abort_code = 1024, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_as_trading_is_not_permitted() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // pause trading
        test_utils::update_perpetual(&mut scenario, b"ETH-PERP", b"trading_status", bcs::to_bytes<bool>(&false));
        test_utils::sync_perpetual(&mut scenario, b"ETH-PERP");   


        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);


        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1043, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_liquidation_as_all_or_nothing_is_set_and_quantity_is_greater_than_liquidatee_position_size() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        // liquidating the taker position that is short at 2000$
        let account_address = test_utils::taker();
        
        let liquidate_order = liquidate_order();
        liquidate_order.quantity = 200000000;
        liquidate_order.all_or_nothing = true;
        let payload = bcs::to_bytes<Liquidate>(&liquidate_order);


        let signature = x"0092acca14a0f732427e434285330d2056be0d6e36b3eb2fce123c558acd798668e770d75348bfa7a3ad728285f5ca7c8103655af291b2930a13a333b21301cf08d6a165bd1b1300884471e09bb49bca6195029ef39b2ff5a4dd63e5a19249d084";

        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2945000000000];
        let timestamp = 1735714800002;

        liquidate_position(&mut scenario, payload, signature, perpetuals, oracle_prices, timestamp);


        test_utils::get_position_values(&mut scenario, account_address, string::utf8(b"ETH-PERP"), true);

        test_scenario::end(scenario);
    }
    

    #[test]
    public fun should_show_eth_position_as_most_negative_pnl_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario,protocol_admin);
            let account = data_store::get_immutable_account_from_ids(&ids, test_utils::maker());
            let positions = account::get_positions_vector(account, string::utf8(b""));
            let perpetuals_table = data_store::get_immutable_perpetual_table_from_ids(&ids);

            let result = account::has_most_negative_pnl(
                &positions, 
                perpetuals_table, 
                string::utf8(b"ETH-PERP")
                );

            assert!(result, 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
            
        };

        test_scenario::end(scenario);
        
    }


    #[test]
    public fun should_show_eth_position_as_most_positive_pnl_position() {
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);

        setup_scenario(&mut scenario);

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario,protocol_admin);
            let account = data_store::get_immutable_account_from_ids(&ids, test_utils::maker());
            let positions = account::get_positions_vector(account, string::utf8(b""));
            let perpetuals_table = data_store::get_immutable_perpetual_table_from_ids(&ids);

            let result = account::has_most_positive_pnl(
                &positions, 
                perpetuals_table, 
                string::utf8(b"ETH-PERP")
                );

            assert!(result, 1);

            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);
            
        };

        test_scenario::end(scenario);
        
    }

}