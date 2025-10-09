module bluefin_cross_margin_dex::test_coin {
    use sui::test_scenario::{Self};
    use sui::coin::{Self, Coin, TreasuryCap};
    use bluefin_cross_margin_dex::coin::{Self as test_coin, COIN};

    const TEST_ADMIN: address = @0xA;
    const TEST_USER: address = @0xB;
    const TEST_RECIPIENT: address = @0xC;

    // === Init and Setup Tests ===

    #[test]
    fun test_init_creates_treasury_and_metadata() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Check that treasury cap was created and transferred to admin
        {
            assert!(test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_ADMIN), 0);
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            // Verify treasury cap properties
            assert!(coin::total_supply(&treasury_cap) == 0, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_metadata_properties() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // The metadata should be frozen and shared
        // We'll verify the treasury cap exists as an indicator of successful init
        {
            assert!(test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_ADMIN), 0);
        };
        
        test_scenario::end(scenario);
    }

    // === Mint Function Tests ===

    #[test]
    fun test_mint_basic() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint coins to a recipient
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            // Verify initial total supply is 0
            assert!(coin::total_supply(&treasury_cap) == 0, 0);
            
            test_coin::mint(&mut treasury_cap, 1000000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            // Verify total supply increased
            assert!(coin::total_supply(&treasury_cap) == 1000000, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_RECIPIENT);
        
        // Verify recipient received the coins
        {
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_RECIPIENT), 2);
            let coin_obj = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::value(&coin_obj) == 1000000, 3);
            
            test_scenario::return_to_address(TEST_RECIPIENT, coin_obj);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_zero_amount() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint zero coins
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 0, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            // Total supply should remain 0
            assert!(coin::total_supply(&treasury_cap) == 0, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_RECIPIENT);
        
        // Verify recipient received a coin with 0 value
        {
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_RECIPIENT), 1);
            let coin_obj = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::value(&coin_obj) == 0, 2);
            
            test_scenario::return_to_address(TEST_RECIPIENT, coin_obj);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_large_amount() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint a very large amount
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            let large_amount = 1000000000000000000; // 1 quintillion (safe large amount)
            test_coin::mint(&mut treasury_cap, large_amount, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == large_amount, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_RECIPIENT);
        
        // Verify recipient received the large amount
        {
            let coin_obj = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::value(&coin_obj) == 1000000000000000000, 1);
            
            test_scenario::return_to_address(TEST_RECIPIENT, coin_obj);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_multiple_times() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // First mint
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 500000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 500000, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Second mint to same recipient
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 300000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 800000, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Third mint to different recipient
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 200000, TEST_USER, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 1000000, 2);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_to_self() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize the coin module
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint coins to self (the treasury cap owner)
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 1000000, TEST_ADMIN, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 1000000, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Verify admin received the coins
        {
            // Admin should have both the treasury cap and the minted coins
            assert!(test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_ADMIN), 1);
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_ADMIN), 2);
            
            let coin_obj = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_ADMIN);
            assert!(coin::value(&coin_obj) == 1000000, 3);
            
            test_scenario::return_to_address(TEST_ADMIN, coin_obj);
        };
        
        test_scenario::end(scenario);
    }

    // === Burn Function Tests ===

    #[test]
    fun test_burn_basic() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize and mint coins first
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            test_coin::mint(&mut treasury_cap, 1000000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Burn the coins
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            // Verify total supply before burning
            assert!(coin::total_supply(&treasury_cap) == 1000000, 0);
            assert!(coin::value(&coin_to_burn) == 1000000, 1);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            // Verify total supply decreased
            assert!(coin::total_supply(&treasury_cap) == 0, 2);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_burn_zero_value_coin() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize and mint zero coins
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            test_coin::mint(&mut treasury_cap, 0, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Burn the zero-value coin
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::total_supply(&treasury_cap) == 0, 0);
            assert!(coin::value(&coin_to_burn) == 0, 1);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            // Total supply should remain 0
            assert!(coin::total_supply(&treasury_cap) == 0, 2);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_burn_partial_supply() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize and mint coins to multiple recipients
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            // Mint to two different recipients
            test_coin::mint(&mut treasury_cap, 600000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, 400000, TEST_USER, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == 1000000, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Burn only one of the coin objects
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::value(&coin_to_burn) == 600000, 1);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            // Total supply should decrease by the burned amount
            assert!(coin::total_supply(&treasury_cap) == 400000, 2);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_USER);
        
        // Verify the other coin still exists
        {
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_USER), 3);
            let remaining_coin = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_USER);
            
            assert!(coin::value(&remaining_coin) == 400000, 4);
            
            test_scenario::return_to_address(TEST_USER, remaining_coin);
        };
        
        test_scenario::end(scenario);
    }

    // === Combined Mint and Burn Tests ===

    #[test]
    fun test_mint_burn_cycle() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Cycle 1: Mint then burn
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 500000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 500000, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            assert!(coin::total_supply(&treasury_cap) == 0, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Cycle 2: Mint again after burning
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 750000, TEST_USER, test_scenario::ctx(&mut scenario));
            assert!(coin::total_supply(&treasury_cap) == 750000, 2);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_multiple_mint_single_burn() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Multiple mints to same recipient
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 200000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, 300000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, 500000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == 1000000, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Burn one of the coins
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            // Take one of the coin objects (most recent)
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            let burn_value = coin::value(&coin_to_burn);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            // Total supply should decrease by the burned coin's value
            assert!(coin::total_supply(&treasury_cap) == 1000000 - burn_value, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    // === Edge Cases and Error Scenarios ===

    #[test]
    fun test_treasury_cap_ownership() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Verify that only TEST_ADMIN has the treasury cap
        {
            assert!(test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_ADMIN), 0);
            assert!(!test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_USER), 1);
            assert!(!test_scenario::has_most_recent_for_address<TreasuryCap<COIN>>(TEST_RECIPIENT), 2);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_large_scale_operations() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint large amounts to multiple recipients
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            let large_amount = 1000000000000; // 1 trillion units
            
            test_coin::mint(&mut treasury_cap, large_amount, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, large_amount, TEST_USER, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, large_amount, TEST_ADMIN, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == large_amount * 3, 0);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Burn one of the large amounts
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            assert!(coin::total_supply(&treasury_cap) == 2000000000000, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_coin_properties_after_operations() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // Mint coins and verify properties
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 1000000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_RECIPIENT);
        
        // Verify coin properties
        {
            let coin_obj = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            // Test coin value
            assert!(coin::value(&coin_obj) == 1000000, 0);
            
            test_scenario::return_to_address(TEST_RECIPIENT, coin_obj);
        };
        
        test_scenario::end(scenario);
    }

    // === Comprehensive Integration Test ===

    #[test]
    fun test_complete_coin_lifecycle() {
        let scenario = test_scenario::begin(TEST_ADMIN);
        
        // 1. Initialize
        {
            test_coin::test_init(test_scenario::ctx(&mut scenario));
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // 2. Verify initial state
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            assert!(coin::total_supply(&treasury_cap) == 0, 0);
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // 3. Mint to multiple recipients
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 1000000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            test_coin::mint(&mut treasury_cap, 2000000, TEST_USER, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == 3000000, 1);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // 4. Burn one coin
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            let coin_to_burn = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            
            assert!(coin::value(&coin_to_burn) == 1000000, 2);
            test_coin::burn(&mut treasury_cap, coin_to_burn);
            
            assert!(coin::total_supply(&treasury_cap) == 2000000, 3);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // 5. Mint more after burning
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            test_coin::mint(&mut treasury_cap, 500000, TEST_RECIPIENT, test_scenario::ctx(&mut scenario));
            
            assert!(coin::total_supply(&treasury_cap) == 2500000, 4);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_ADMIN);
        
        // 6. Final verification
        {
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<COIN>>(&scenario, TEST_ADMIN);
            
            // Should have total supply of 2,500,000
            assert!(coin::total_supply(&treasury_cap) == 2500000, 5);
            
            test_scenario::return_to_address(TEST_ADMIN, treasury_cap);
        };
        
        // 7. Verify recipients have their coins
        test_scenario::next_tx(&mut scenario, TEST_USER);
        {
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_USER), 6);
            let user_coin = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_USER);
            assert!(coin::value(&user_coin) == 2000000, 7);
            test_scenario::return_to_address(TEST_USER, user_coin);
        };
        
        test_scenario::next_tx(&mut scenario, TEST_RECIPIENT);
        {
            assert!(test_scenario::has_most_recent_for_address<Coin<COIN>>(TEST_RECIPIENT), 8);
            let recipient_coin = test_scenario::take_from_address<Coin<COIN>>(&scenario, TEST_RECIPIENT);
            assert!(coin::value(&recipient_coin) == 500000, 9);
            test_scenario::return_to_address(TEST_RECIPIENT, recipient_coin);
        };
        
        test_scenario::end(scenario);
    }
}
