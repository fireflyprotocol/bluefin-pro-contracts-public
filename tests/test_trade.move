module bluefin_cross_margin_dex::test_trade {
    use sui::test_scenario::{Self, Scenario};
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::exchange;
    use std::option::{Self, Option};
    use sui::bcs;
    use std::string::{Self, String};
    use bluefin_cross_margin_dex::bcs_handler;
    use std::vector;

    struct Order has copy, drop {
        ids: address,
        account: address,
        market: String,
        price: u64,
        quantity: u64,
        leverage: u64,
        side: String,
        position_type: String,
        expiration: u64,
        salt: u64,
        signed_at: u64,
    }

    struct BatchHash has copy, drop {
        maker_hash: vector<u8>,
        taker_hash: vector<u8>,
    }

    #[test_only]
    public fun get_order(maker: bool): Order {

        let account = if(maker) { test_utils::maker() } else { test_utils::taker() };
        let side = if(maker) { string::utf8(b"LONG") } else { string::utf8(b"SHORT") };
        let position_type = if (maker) { string::utf8(b"CROSS") } else { string::utf8(b"ISOLATED") };
        let leverage = if(maker) { 0 } else { 2000000000 };
        Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account,
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage,
            side,
            position_type,
            expiration: 1735714800015,
            salt: 0,
            signed_at: 1735714800002,
        }
    }

    #[test_only]
    public fun trade(
        scenario: &mut Scenario, 
        maker_order: vector<u8>, 
        taker_order: vector<u8>, 
        maker_signature: vector<u8>,
        taker_signature: vector<u8>,
        quantity: u64, 
        price: u64,
        timestamp: u64)
        {
        test_scenario::next_tx(scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, test_utils::protocol_admin());

            let trade_bytes = bcs_handler::enc_trade(maker_order, taker_order, quantity, timestamp);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, trade_bytes);

            let perpetuals = vector::empty();
            let oracle_prices = vector::empty();
            vector::push_back(&mut perpetuals, string::utf8(b"ETH-PERP"));
            vector::push_back(&mut oracle_prices, price);

            exchange::trade(
                &mut ids, 
                maker_order, 
                taker_order, 
                maker_signature, 
                taker_signature, 
                quantity, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
                );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        }
    }


    #[test_only]
    public fun execute_trade(scenario: &mut Scenario) {

        // deposit 1000 USDC to maker and taker
        test_utils::deposit(scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(scenario, test_utils::taker(), 1000000000);

        let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d101000080969800000000000000000000000000044c4f4e470543524f53538f01aa2094010000ab696b9f990100008501aa2094010000";
        let maker_signature = x"01cc81524964f360e77a37652f4b6e6b5bb82193fd9be7ab5afdd71f668b6d7e9177f545bc0f040f7f8373b7a1e62fb26fe329c98e954836350716a464e00dcb3c02ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

        let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d1010000809698000000000000943577000000000553484f52540849534f4c415445448f01aa20940100001c68619f990100008501aa2094010000";
        let taker_signature = x"01aed23654cce9b4090a4213b1ec6e42ef22a95deed22535d33328d1a74d028ee4366ef48e7eec48cf8771043ff6a5703c2ac01fe7fe9437eb6b0d5a044e8def6602d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        let quantity = 10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
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

    #[test_only]
    public fun execute_trade_v2(scenario: &mut Scenario) {

        // deposit 1000 USDC to maker and taker
        test_utils::deposit(scenario, test_utils::maker(), 110000000);
        test_utils::deposit(scenario, test_utils::taker(), 2000000000);

        let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d101000000ca9a3b000000000000000000000000044c4f4e470543524f53538f01aa2094010000960994a7990100008501aa2094010000";
        let maker_signature = x"01433429f2d9e4155c0b6d5b5032accf5696c1c83e2afa499218e42e1cf72db29578bd3b894361cc327d80a1bb811baec929742ebe32fcfc671f9bf5664fe3467c02ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

        let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d101000000ca9a3b0000000000943577000000000553484f52540849534f4c415445448f01aa209401000056e383a7990100008501aa2094010000";
        let taker_signature = x"014edd78f61ea32e4b67075c199b774a1c3ec03e3f2b39fe0b02c65ef75a8985c3768e68862cd800efadbd0d06d9846cb626bb750db27aaac3d23590c804fbb89c02d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

        let quantity = 1000000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
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


    #[test_only]
    public fun batch_trade(
        scenario: &mut Scenario,
        maker_order: Order,
        taker_order: Order,
        fills: vector<u64>,
        perpetuals: vector<String>,
        oracle_prices: vector<u64>,
        timestamp: u64,
        gas_fee: Option<u64>
    ) {
        let protocol_admin = test_utils::protocol_admin();
        test_scenario::next_tx(scenario, protocol_admin);
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(scenario, protocol_admin);

            let maker_hash = bcs::to_bytes<Order>(&maker_order);
            let taker_hash = bcs::to_bytes<Order>(&taker_order);
            let batch_hash = bcs::to_bytes<BatchHash>(&BatchHash {
                maker_hash,
                taker_hash,
            });

            let sequence_hash =  data_store::get_next_sequence_hash(&ids, batch_hash);


            let makers_target_ids = vector[maker_order.ids];
            let makers_address = vector[maker_order.account];
            let makers_perpetual = vector[maker_order.market];
            let makers_price = vector[maker_order.price];
            let makers_quantity = vector[maker_order.quantity];
            let makers_leverage = vector[maker_order.leverage];
            let makers_is_long = vector[maker_order.side == string::utf8(b"LONG")];
            let makers_is_isolated = vector[maker_order.position_type == string::utf8(b"ISOLATED")];
            let makers_expiry = vector[maker_order.expiration];
            let makers_signed_at = vector[maker_order.signed_at];
            let makers_signature = vector[maker_hash];
            let makers_hash = vector[maker_hash];
            
            let takers_target_ids = vector[taker_order.ids];
            let takers_address = vector[taker_order.account];
            let takers_perpetual = vector[taker_order.market];
            let takers_price = vector[taker_order.price];
            let takers_quantity = vector[taker_order.quantity];
            let takers_leverage = vector[taker_order.leverage];
            let takers_is_long = vector[taker_order.side == string::utf8(b"LONG")];
            let takers_is_isolated = vector[taker_order.position_type == string::utf8(b"ISOLATED")];
            let takers_expiry = vector[taker_order.expiration];
            let takers_signed_at = vector[taker_order.signed_at];
            let takers_signature = vector[taker_hash];
            let takers_hash = vector[taker_hash];

            if(option::is_some(&gas_fee)) {
                exchange::batch_trade_with_provided_gas_fee(
                &mut ids,
                makers_target_ids,
                makers_address,
                makers_perpetual,
                makers_price,
                makers_quantity,
                makers_leverage,
                makers_is_long,
                makers_is_isolated,
                makers_expiry,
                makers_signed_at,
                makers_signature,
                makers_hash,
                takers_target_ids,
                takers_address,
                takers_perpetual,
                takers_price,
                takers_quantity,
                takers_leverage,
                takers_is_long,
                takers_is_isolated,
                takers_expiry,
                takers_signed_at,
                takers_signature,
                takers_hash,
                fills,
                perpetuals,
                oracle_prices,
            option::extract<u64>(&mut gas_fee),
                batch_hash,
                sequence_hash,
                timestamp,
                
            );
            } else {
            exchange::batch_trade(
                &mut ids,
                makers_target_ids,
                makers_address,
                makers_perpetual,
                makers_price,
                makers_quantity,
                makers_leverage,
                makers_is_long,
                makers_is_isolated,
                makers_expiry,
                makers_signed_at,
                makers_signature,
                makers_hash,
                takers_target_ids,
                takers_address,
                takers_perpetual,
                takers_price,
                takers_quantity,
                takers_leverage,
                takers_is_long,
                takers_is_isolated,
                takers_expiry,
                takers_signed_at,
                takers_signature,
                takers_hash,
                fills,
                perpetuals,
                oracle_prices,
                batch_hash,
                sequence_hash,
                timestamp
            );
            };


            test_scenario::return_to_address<InternalDataStore>(protocol_admin, ids);

        }

    }
    
    #[test]
    public fun should_successfully_execute_a_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        execute_trade(&mut scenario);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_execute_a_reducing_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        {
            let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d101000000e1f505000000000000000000000000044c4f4e470543524f53538f01aa209401000027a8719f990100008501aa2094010000";
            let maker_signature = x"01743d16a454ea6ce1790c0c4955d3f9bb0ab03347519f274797c80ccc2c34f40e21c2d15d23ef969b142fa5c6d59e4e1fbe41efab1fa6343a8bc70382fb4eded802ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

            let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d101000000e1f5050000000000943577000000000553484f52540849534f4c415445448f01aa209401000066c2759f990100008501aa2094010000";
            let taker_signature = x"01b64a724bd80fb041fb0a137a5482d9e5b8e869edd19e0f3965474b50851ef0ba7e816b7259dd36c84c86bcd25c6287fb264dabf1a3069c547721d9ce2c37770402d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

            let quantity = 100000000;
            let price = 2000000000000;
            let timestamp = 1735714800002;

            trade(
                &mut scenario,
                maker_order,
                taker_order,
                maker_signature,
                taker_signature,
                quantity,
                price,
                timestamp
            );
        };

        {
            let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d1010000002d31010000000000000000000000000553484f52540543524f53538f01aa2094010000aace739f990100008501aa2094010000";
            let maker_signature = x"01363fde4b220042554484c1361bebbfa2a15cc979a8943fffb17a9f9fa7d4e4c37f7d991e6efd59ac8016b6667d7ed34630503dc0490e83ff4f505af6f8c70db202ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

            let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d1010000002d3101000000000094357700000000044c4f4e470849534f4c415445448f01aa2094010000eac86c9f990100008501aa2094010000";
            let taker_signature = x"01d135b799f2c8c13dc56d9e21d75d76e536a08fccac3fa9fe313f1c8663be475979923fe81d93a6f1872a80eed75a70e808dc0b3afd1e1f407e2d6b832e7a7b8802d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

            let quantity = 20000000;
            let price = 2000000000000;
            let timestamp = 1735714800002;

            trade(
                &mut scenario,
                maker_order,
                taker_order,
                maker_signature,
                taker_signature,
                quantity,
                price,
                timestamp
            );
        };

        let (_, size, _, _, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, test_utils::maker(), string::utf8(b"ETH-PERP"), false);
        assert!(size == 80000000, 1);

        test_scenario::end(scenario);
    }

    #[test]
    public fun should_successfully_execute_a_flipping_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        {
            let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d101000080969800000000000000000000000000044c4f4e470543524f53538f01aa2094010000ab696b9f990100008501aa2094010000";
            let maker_signature = x"01cc81524964f360e77a37652f4b6e6b5bb82193fd9be7ab5afdd71f668b6d7e9177f545bc0f040f7f8373b7a1e62fb26fe329c98e954836350716a464e00dcb3c02ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

            let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d1010000809698000000000000943577000000000553484f52540849534f4c415445448f01aa20940100001c68619f990100008501aa2094010000";
            let taker_signature = x"01aed23654cce9b4090a4213b1ec6e42ef22a95deed22535d33328d1a74d028ee4366ef48e7eec48cf8771043ff6a5703c2ac01fe7fe9437eb6b0d5a044e8def6602d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

            let quantity = 10000000;
            let price = 2000000000000;
            let timestamp = 1735714800002;

            trade(
                &mut scenario,
                maker_order,
                taker_order,
                maker_signature,
                taker_signature,
                quantity,
                price,
                timestamp
            );
        };

        {
            let maker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c397580c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa084554482d5045525000204aa9d1010000002d31010000000000000000000000000553484f52540543524f53538f01aa20940100008f886a9f990100008501aa2094010000";
            let maker_signature = x"01da0692f7afac4c1b04973f7d07e90fa2c85abcffbfbdd75fcc7867ec24eb415b10acc34d6a0ad4ba3def161c9e22862eea9b4196e680a478feb822b1eac07ab202ccb0fb4d77d716808975222dcabce7c7c5cf749fd1697bd95e74aa3733676d99";

            let taker_order = x"63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c39752183df5aaf6366e5445c95fa238fc223dbbda54b7c363680578b435f657f1a29084554482d5045525000204aa9d1010000002d3101000000000094357700000000044c4f4e470849534f4c415445448f01aa20940100005b76749f990100008501aa2094010000";
            let taker_signature = x"01dad795c62df8bea5d4382a1ac1defdb82a9a0e779718165b47c741e0742e1e187709c1ca0a248f8bee5059c2fa6026a91fd28d1921ef6e16aad823aaa717161702d488e3966f44ca0b486e8b13c299621657243c0b7d58cdc578e1413faa4854a7";

            let quantity = 20000000;
            let price = 2000000000000;
            let timestamp = 1735714800002;

            trade(
                &mut scenario,
                maker_order,
                taker_order,
                maker_signature,
                taker_signature,
                quantity,
                price,
                timestamp
            );
        };

        let (_, size, _, is_long, _, _, _, _, _) = test_utils::get_position_values(&mut scenario, test_utils::maker(), string::utf8(b"ETH-PERP"), false);
        assert!(size == 10000000, 1);
        assert!(is_long == false, 2);
        test_scenario::end(scenario);
    }


    #[test]
    public fun should_successfully_execute_a_batch_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }

    #[test]
    public fun should_successfully_execute_a_batch_trade_with_provided_gas_fee(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;
        let gas_fee = 30000000;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::some<u64>(gas_fee),
        );

        test_scenario::end(scenario);


    }

    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_execute_a_batch_trade_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        test_utils::set_ids_version(&mut scenario, 0);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }

    #[test]
    #[expected_failure(abort_code = 1058, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_due_to_self_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }


    #[test]
    #[expected_failure(abort_code = 1021, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_due_to_maker_taker_order_belong_to_different_markets(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"BTC-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }

    #[test]
    #[expected_failure(abort_code = 1025, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_as_maker_taker_order_are_of_same_side(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }


    #[test]
    #[expected_failure(abort_code = 1009, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_as_perpetual_does_not_exist(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::maker(),
            market: string::utf8(b"BTC-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x63d9a65220318469fb169034d8a011eae3f014fed2a1f8c006183e2ece3c3975,
            account: test_utils::taker(),
            market: string::utf8(b"BTC-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_as_maker_taker_orders_do_not_target_the_same_ids(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x1,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x2,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_batch_trade_as_maker_taker_orders_do_not_target_the_same_ids_v2(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = Order {
            ids: @0x1,
            account: test_utils::maker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 0,
            side: string::utf8(b"LONG"),
            position_type: string::utf8(b"CROSS"),
            expiration: 1735714800015,
            salt: 1759375745751,
            signed_at: 1735714800005,
        };

        let taker_order = Order {
            ids: @0x1,
            account: test_utils::taker(),
            market: string::utf8(b"ETH-PERP"),
            price: 2000000000000,
            quantity: 10000000,
            leverage: 2000000000,
            side: string::utf8(b"SHORT"),
            position_type: string::utf8(b"ISOLATED"),
            expiration: 1735714800015,
            salt: 1759375481497,
            signed_at: 1735714800005,
        };

        let fills = vector[10000000];
        let perpetuals = vector[string::utf8(b"ETH-PERP")];
        let oracle_prices = vector[2000000000000];
        let timestamp = 1735714800002;

        batch_trade(
            &mut scenario,
            maker_order,
            taker_order,
            fills,
            perpetuals,
            oracle_prices,
            timestamp,
            option::none<u64>()
        );

        test_scenario::end(scenario);


    }


    #[test]
    #[expected_failure(abort_code = 1001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_due_to_ids_version_mismatch(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::set_ids_version(&mut scenario, 0);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1019, location = bluefin_cross_margin_dex::perpetual)]
    public fun should_fail_to_trade_due_as_oracle_price_is_invalid(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let timestamp = 1735714800002;    

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());

            let trade_bytes = bcs_handler::enc_trade(bcs::to_bytes<Order>(&maker_order), bcs::to_bytes<Order>(&taker_order), quantity, timestamp);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, trade_bytes);


            let perpetuals = vector[string::utf8(b"ETH-PERP")];
            let oracle_prices = vector[2000000000001];
    
            exchange::trade(
                &mut ids, 
                bcs::to_bytes<Order>(&maker_order), 
                bcs::to_bytes<Order>(&taker_order), 
                b"", 
                b"", 
                quantity, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
                );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1055, location = bluefin_cross_margin_dex::perpetual)]
    public fun should_fail_to_trade_as_perpetual_is_delisted(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        test_utils::update_perpetual(
            &mut scenario, 
            b"ETH-PERP", 
            b"delist", 
            bcs::to_bytes<u64>(&2000000000000)
        );

        test_utils::sync_perpetual(&mut scenario, b"ETH-PERP");


        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1058, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_perform_self_trade(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.account = test_utils::maker();

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1009, location = bluefin_cross_margin_dex::data_store)]
    public fun should_fail_to_trade_as_oracle_price_is_being_set_for_non_existent_perpetual(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let timestamp = 1735714800002;    

        test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());

            let trade_bytes = bcs_handler::enc_trade(bcs::to_bytes<Order>(&maker_order), bcs::to_bytes<Order>(&taker_order), quantity, timestamp);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, trade_bytes);


            let perpetuals = vector[string::utf8(b"BTC-PERP")];
            let oracle_prices = vector[2000000000001];
    
            exchange::trade(
                &mut ids, 
                bcs::to_bytes<Order>(&maker_order), 
                bcs::to_bytes<Order>(&taker_order), 
                b"", 
                b"", 
                quantity, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
                );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        };

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1021, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_taker_order_belong_to_different_markets(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.market = string::utf8(b"BTC-PERP");

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1025, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_taker_order_are_of_same_side(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.side = string::utf8(b"LONG");


        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1009, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_btc_perpetual_is_not_supported_for_trading(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.market = string::utf8(b"BTC-PERP");
        maker_order.market = string::utf8(b"BTC-PERP");


        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_taker_orders_target_ids_are_different(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.ids = @0x1;
        maker_order.ids = @0x2;

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_taker_orders_target_ids_are_same_but_being_executed_on_different_ids(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        taker_order.ids = @0x1;
        maker_order.ids = @0x1;

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1046, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_order_has_lifespan_greater_than_max_allowed_lifespan(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        maker_order.signed_at = 1000000000000;

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1024, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_current_time_is_less_than_trading_start_time(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);


        let maker_order = get_order(true);
        let taker_order = get_order(false);
        maker_order.signed_at = 7776000000;

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 7776000000;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1024, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_trading_is_not_permitted(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        test_utils::update_perpetual(
            &mut scenario, 
            b"ETH-PERP", 
            b"trading_status", 
            bcs::to_bytes<bool>(&false));

        test_utils::sync_perpetual(&mut scenario, b"ETH-PERP");

        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_fill_quantity_is_not_within_trade_quantity_range(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =100;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_fill_quantity_is_not_within_trade_quantity_range_2(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000000000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1030, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_fill_quantity_is_not_within_trade_quantity_range_3(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =25000000;
        let price = 2000000000000;
        let timestamp = 1735714800002;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1027, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_trade_as_maker_order_is_expired(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        test_utils::deposit(&mut scenario, test_utils::maker(), 1000000000);
        test_utils::deposit(&mut scenario, test_utils::taker(), 1000000000);

        let maker_order = get_order(true);
        let taker_order = get_order(false);

        let quantity =10000000;
        let price = 2000000000000;
        let timestamp = 1735714800020;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );

        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 4001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_increase_position_size_when_user_is_in_margin_call(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        execute_trade(&mut scenario);

        let maker_order = get_order(true);
        let taker_order = get_order(false);
        maker_order.price = 5000000000000;
        taker_order.price = 5000000000000;


        let quantity =10000000;
        let price = 5000000000000;
        let timestamp = 1735714800020;

        trade(
            &mut scenario,
            bcs::to_bytes<Order>(&maker_order),
            bcs::to_bytes<Order>(&taker_order),
            b"",
            b"",
            quantity,
            price,
            timestamp
        );
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 4001, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_open_new_cross_position_when_user_is_in_margin_call(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        execute_trade_v2(&mut scenario);
        let market = string::utf8(b"BTC-PERP");

        test_utils::create_perpetual(
            &mut scenario,
             option::some<String>(market),
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

        let maker_order = get_order(true);
        let taker_order = get_order(false);
        maker_order.market = market;
        taker_order.market = market;


        let quantity =10000000;
        let timestamp = 1735714800020;

         test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());

            let trade_bytes = bcs_handler::enc_trade(bcs::to_bytes<Order>(&maker_order), bcs::to_bytes<Order>(&taker_order), quantity, timestamp);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, trade_bytes);


            let perpetuals = vector[string::utf8(b"ETH-PERP"), string::utf8(b"BTC-PERP")];
            let oracle_prices = vector[1000000000000, 2000000000000];
    
            exchange::trade(
                &mut ids, 
                bcs::to_bytes<Order>(&maker_order), 
                bcs::to_bytes<Order>(&taker_order), 
                b"", 
                b"", 
                quantity, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
                );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        };

        test_scenario::end(scenario);

    }


    #[test]
    #[expected_failure(abort_code = 4003, location = bluefin_cross_margin_dex::exchange)]
    public fun should_fail_to_reduce_position_when_user_maintains_health_below_zero(){
        let protocol_admin = test_utils::protocol_admin();
        let scenario = test_scenario::begin(protocol_admin);
        test_utils::init_package_for_testing(&mut scenario);

        execute_trade_v2(&mut scenario);
    
        let maker_order = get_order(true);
        let taker_order = get_order(false);
        maker_order.side = string::utf8(b"SHORT");
        taker_order.side = string::utf8(b"LONG");

        let quantity =10000000;
        let timestamp = 1735714800020;

         test_scenario::next_tx(&mut scenario, test_utils::protocol_admin());
        {
            let ids = test_scenario::take_from_address<InternalDataStore>(&scenario, test_utils::protocol_admin());

            let trade_bytes = bcs_handler::enc_trade(bcs::to_bytes<Order>(&maker_order), bcs::to_bytes<Order>(&taker_order), quantity, timestamp);

            let sequence_hash = data_store::get_next_sequence_hash(&ids, trade_bytes);


            let perpetuals = vector[string::utf8(b"ETH-PERP")];
            let oracle_prices = vector[4000000000000];
    
            exchange::trade(
                &mut ids, 
                bcs::to_bytes<Order>(&maker_order), 
                bcs::to_bytes<Order>(&taker_order), 
                b"", 
                b"", 
                quantity, 
                perpetuals, 
                oracle_prices, 
                sequence_hash, 
                timestamp
                );

            test_scenario::return_to_address<InternalDataStore>(test_utils::protocol_admin(), ids);
        };

        test_scenario::end(scenario);
    }

}