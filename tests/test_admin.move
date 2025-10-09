module bluefin_cross_margin_dex::test_admin {
    use sui::test_scenario;
    use bluefin_cross_margin_dex::test_utils;
    use bluefin_cross_margin_dex::admin::{Self, AdminCap};

    #[test]
    public fun should_initialize_admin_module(){

        let scenario = test_scenario::begin(test_utils::protocol_admin());
        admin::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::end(scenario);
    }


    #[test]
    public fun should_allow_admin_to_transfer_admin_cap(){

        let protocol_admin = test_utils::protocol_admin();

        let scenario = test_scenario::begin(test_utils::protocol_admin());
        admin::test_init(test_scenario::ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, protocol_admin);
        {
            let cap = test_scenario::take_from_address<AdminCap>(&scenario, protocol_admin);        
            admin::transfer_admin_cap(cap, @0x9);
        };

        test_scenario::end(scenario);
    }
}