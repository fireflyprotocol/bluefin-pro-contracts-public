module bluefin_cross_margin_dex::test_signed_number {
    use bluefin_cross_margin_dex::signed_number;
    use bluefin_cross_margin_dex::constants;
    use sui::bcs;

    // Test constants
    const TEST_VALUE_1: u64 = 1000000000; // 1 * base_uint
    const TEST_VALUE_2: u64 = 2000000000; // 2 * base_uint

    // === Constructor Tests ===

    #[test]
    fun test_new() {
        let n = signed_number::new();
        assert!(signed_number::value(n) == 0, 1);
        assert!(signed_number::sign(n) == true, 2);
    }

    #[test]
    fun test_from_positive() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::value(n) == TEST_VALUE_1, 1);
        assert!(signed_number::sign(n) == true, 2);
    }

    #[test]
    fun test_from_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::value(n) == TEST_VALUE_1, 1);
        assert!(signed_number::sign(n) == false, 2);
    }

    #[test]
    fun test_from_zero_positive() {
        let n = signed_number::from(0, true);
        assert!(signed_number::value(n) == 0, 1);
        assert!(signed_number::sign(n) == true, 2);
    }

    #[test]
    #[expected_failure(abort_code = 5000, location = bluefin_cross_margin_dex::signed_number)]
    fun test_from_zero_negative_fails() {
        signed_number::from(0, false);
    }

    #[test]
    fun test_one() {
        let n = signed_number::one();
        assert!(signed_number::value(n) == constants::base_uint(), 1);
        assert!(signed_number::sign(n) == true, 2);
    }

    #[test]
    fun test_from_bytes() {
        let value: u64 = TEST_VALUE_1;
        let sign: bool = true;
        
        // Create properly formatted bytes for BCS deserialization
        let value_bytes = bcs::to_bytes(&value);
        let sign_bytes = bcs::to_bytes(&sign);
        
        // Combine bytes in the correct order (value first, then sign)
        let all_bytes = value_bytes;
        std::vector::append(&mut all_bytes, sign_bytes);
        
        let n = signed_number::from_bytes(all_bytes);
        assert!(signed_number::value(n) == value, 1);
        assert!(signed_number::sign(n) == sign, 2);
    }

    // === Arithmetic with Unsigned Integers Tests ===

    #[test]
    fun test_add_uint_positive() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::add_uint(n, TEST_VALUE_2);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_add_uint_negative_larger() {
        let n = signed_number::from(TEST_VALUE_2, false);
        let result = signed_number::add_uint(n, TEST_VALUE_1);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_add_uint_negative_smaller() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::add_uint(n, TEST_VALUE_2);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_add_uint_negative_equal() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::add_uint(n, TEST_VALUE_1);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_uint_positive_larger() {
        let n = signed_number::from(TEST_VALUE_2, true);
        let result = signed_number::sub_uint(n, TEST_VALUE_1);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_uint_positive_smaller() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::sub_uint(n, TEST_VALUE_2);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_sub_uint_positive_equal() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::sub_uint(n, TEST_VALUE_1);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::sub_uint(n, TEST_VALUE_2);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_mul_uint_positive() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::mul_uint(n, 2);
        // base_mul(TEST_VALUE_1, 2) = (TEST_VALUE_1 * 2) / base_uint()
        let expected = (((TEST_VALUE_1 as u128) * 2) / (constants::base_uint() as u128) as u64);
        assert!(signed_number::value(result) == expected, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_mul_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::mul_uint(n, 2);
        let expected = (((TEST_VALUE_1 as u128) * 2) / (constants::base_uint() as u128) as u64);
        assert!(signed_number::value(result) == expected, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_mul_uint_zero_result() {
        let n = signed_number::from(1, false); // Very small negative number
        let result = signed_number::mul_uint(n, 0);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2); // Zero is positive
    }

    #[test]
    fun test_div_uint_positive() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::div_uint(n, 2);
        // base_div(TEST_VALUE_1, 2) = (TEST_VALUE_1 * base_uint()) / 2
        let expected = (((TEST_VALUE_1 as u128) * (constants::base_uint() as u128)) / 2 as u64);
        assert!(signed_number::value(result) == expected, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_div_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::div_uint(n, 2);
        let expected = (((TEST_VALUE_1 as u128) * (constants::base_uint() as u128)) / 2 as u64);
        assert!(signed_number::value(result) == expected, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    // === Signed Number Arithmetic Tests ===

    #[test]
    fun test_negate_positive() {
        let n = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::negate(n);
        assert!(signed_number::value(result) == TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_negate_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::negate(n);
        assert!(signed_number::value(result) == TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_negate_zero() {
        let n = signed_number::new();
        let result = signed_number::negate(n);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2); // Zero remains positive
    }

    #[test]
    fun test_add_same_sign_positive() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, true);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_add_same_sign_negative() {
        let a = signed_number::from(TEST_VALUE_1, false);
        let b = signed_number::from(TEST_VALUE_2, false);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_add_different_sign_a_larger() {
        let a = signed_number::from(TEST_VALUE_2, true);
        let b = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_add_different_sign_b_larger() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, false);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_add_different_sign_equal() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_1, false);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2); // Zero is positive
    }

    #[test]
    fun test_sub_positive_minus_positive() {
        let a = signed_number::from(TEST_VALUE_2, true);
        let b = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::sub(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_positive_minus_negative() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, false);
        let result = signed_number::sub(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_negative_minus_positive() {
        let a = signed_number::from(TEST_VALUE_1, false);
        let b = signed_number::from(TEST_VALUE_2, true);
        let result = signed_number::sub(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_1 + TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_sub_negative_minus_negative() {
        let a = signed_number::from(TEST_VALUE_1, false);
        let b = signed_number::from(TEST_VALUE_2, false);
        let result = signed_number::sub(a, b);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_sub_equal_values() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_1, true);
        let result = signed_number::sub(a, b);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2); // Zero is positive
    }

    // === Comparison Tests ===

    #[test]
    fun test_gte_uint_positive_greater() {
        let n = signed_number::from(TEST_VALUE_2, true);
        assert!(signed_number::gte_uint(n, TEST_VALUE_1) == true, 1);
    }

    #[test]
    fun test_gte_uint_positive_equal() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gte_uint(n, TEST_VALUE_1) == true, 1);
    }

    #[test]
    fun test_gte_uint_positive_less() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gte_uint(n, TEST_VALUE_2) == false, 1);
    }

    #[test]
    fun test_gte_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::gte_uint(n, 0) == false, 1);
        assert!(signed_number::gte_uint(n, TEST_VALUE_1) == false, 2);
    }

    #[test]
    fun test_gt_uint_positive_greater() {
        let n = signed_number::from(TEST_VALUE_2, true);
        assert!(signed_number::gt_uint(n, TEST_VALUE_1) == true, 1);
    }

    #[test]
    fun test_gt_uint_positive_equal() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gt_uint(n, TEST_VALUE_1) == false, 1);
    }

    #[test]
    fun test_gt_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::gt_uint(n, 0) == false, 1);
    }

    #[test]
    fun test_lt_uint_positive_less() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::lt_uint(n, TEST_VALUE_2) == true, 1);
    }

    #[test]
    fun test_lt_uint_positive_greater() {
        let n = signed_number::from(TEST_VALUE_2, true);
        assert!(signed_number::lt_uint(n, TEST_VALUE_1) == false, 1);
    }

    #[test]
    fun test_lt_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::lt_uint(n, 0) == true, 1);
        assert!(signed_number::lt_uint(n, TEST_VALUE_1) == true, 2);
    }

    #[test]
    fun test_lte_uint_positive_less() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::lte_uint(n, TEST_VALUE_2) == true, 1);
    }

    #[test]
    fun test_lte_uint_positive_equal() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::lte_uint(n, TEST_VALUE_1) == true, 1);
    }

    #[test]
    fun test_lte_uint_negative() {
        let n = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::lte_uint(n, 0) == true, 1);
    }

    #[test]
    fun test_gte_both_positive() {
        let a = signed_number::from(TEST_VALUE_2, true);
        let b = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gte(a, b) == true, 1);
        assert!(signed_number::gte(b, a) == false, 2);
        
        let c = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gte(b, c) == true, 3); // Equal
    }

    #[test]
    fun test_gte_both_negative() {
        let a = signed_number::from(TEST_VALUE_1, false); // -1000000000
        let b = signed_number::from(TEST_VALUE_2, false); // -2000000000
        assert!(signed_number::gte(a, b) == true, 1); // -1000000000 >= -2000000000
        assert!(signed_number::gte(b, a) == false, 2);
    }

    #[test]
    fun test_gte_mixed_signs() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, false);
        assert!(signed_number::gte(a, b) == true, 1); // positive >= negative
        assert!(signed_number::gte(b, a) == false, 2); // negative >= positive
    }

    #[test]
    fun test_gt_both_positive() {
        let a = signed_number::from(TEST_VALUE_2, true);
        let b = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gt(a, b) == true, 1);
        assert!(signed_number::gt(b, a) == false, 2);
        
        let c = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::gt(b, c) == false, 3); // Equal
    }

    #[test]
    fun test_gt_both_negative() {
        let a = signed_number::from(TEST_VALUE_1, false);
        let b = signed_number::from(TEST_VALUE_2, false);
        assert!(signed_number::gt(a, b) == true, 1);
        assert!(signed_number::gt(b, a) == false, 2);
    }

    #[test]
    fun test_gt_mixed_signs() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, false);
        assert!(signed_number::gt(a, b) == true, 1);
        assert!(signed_number::gt(b, a) == false, 2);
    }

    #[test]
    fun test_lt_both_positive() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, true);
        assert!(signed_number::lt(a, b) == true, 1);
        assert!(signed_number::lt(b, a) == false, 2);
    }

    #[test]
    fun test_lt_both_negative() {
        let a = signed_number::from(TEST_VALUE_2, false); // -2000000000
        let b = signed_number::from(TEST_VALUE_1, false); // -1000000000
        assert!(signed_number::lt(a, b) == true, 1); // -2000000000 < -1000000000
        assert!(signed_number::lt(b, a) == false, 2);
    }

    #[test]
    fun test_lt_mixed_signs() {
        let a = signed_number::from(TEST_VALUE_2, false);
        let b = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::lt(a, b) == true, 1); // negative < positive
        assert!(signed_number::lt(b, a) == false, 2);
    }

    #[test]
    fun test_eq_same_values() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::eq(a, b) == true, 1);
        
        let c = signed_number::from(TEST_VALUE_1, false);
        let d = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::eq(c, d) == true, 2);
    }

    #[test]
    fun test_eq_different_values() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_2, true);
        assert!(signed_number::eq(a, b) == false, 1);
    }

    #[test]
    fun test_eq_different_signs() {
        let a = signed_number::from(TEST_VALUE_1, true);
        let b = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::eq(a, b) == false, 1);
    }

    #[test]
    fun test_eq_zero() {
        let a = signed_number::new();
        let b = signed_number::from(0, true);
        assert!(signed_number::eq(a, b) == true, 1);
    }

    // === Utility Functions Tests ===

    #[test]
    fun test_from_subtraction_positive_result() {
        let result = signed_number::from_subtraction(TEST_VALUE_2, TEST_VALUE_1);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_from_subtraction_negative_result() {
        let result = signed_number::from_subtraction(TEST_VALUE_1, TEST_VALUE_2);
        assert!(signed_number::value(result) == TEST_VALUE_2 - TEST_VALUE_1, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_from_subtraction_zero_result() {
        let result = signed_number::from_subtraction(TEST_VALUE_1, TEST_VALUE_1);
        assert!(signed_number::value(result) == 0, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_value_accessor() {
        let n = signed_number::from(TEST_VALUE_1, true);
        assert!(signed_number::value(n) == TEST_VALUE_1, 1);
    }

    #[test]
    fun test_sign_accessor() {
        let n_pos = signed_number::from(TEST_VALUE_1, true);
        let n_neg = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::sign(n_pos) == true, 1);
        assert!(signed_number::sign(n_neg) == false, 2);
    }

    #[test]
    fun test_positive_value() {
        let n_pos = signed_number::from(TEST_VALUE_1, true);
        let n_neg = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::positive_value(n_pos) == TEST_VALUE_1, 1);
        assert!(signed_number::positive_value(n_neg) == 0, 2);
    }

    #[test]
    fun test_negative_value() {
        let n_pos = signed_number::from(TEST_VALUE_1, true);
        let n_neg = signed_number::from(TEST_VALUE_1, false);
        assert!(signed_number::negative_value(n_pos) == 0, 1);
        assert!(signed_number::negative_value(n_neg) == TEST_VALUE_1, 2);
    }

    #[test]
    fun test_positive_number() {
        let n_pos = signed_number::from(TEST_VALUE_1, true);
        let n_neg = signed_number::from(TEST_VALUE_1, false);
        
        let result_pos = signed_number::positive_number(n_pos);
        assert!(signed_number::value(result_pos) == TEST_VALUE_1, 1);
        assert!(signed_number::sign(result_pos) == true, 2);
        
        let result_neg = signed_number::positive_number(n_neg);
        assert!(signed_number::value(result_neg) == 0, 3);
        assert!(signed_number::sign(result_neg) == true, 4);
    }

    #[test]
    fun test_negative_number() {
        let n_pos = signed_number::from(TEST_VALUE_1, true);
        let n_neg = signed_number::from(TEST_VALUE_1, false);
        
        let result_pos = signed_number::negative_number(n_pos);
        assert!(signed_number::value(result_pos) == 0, 1);
        assert!(signed_number::sign(result_pos) == true, 2);
        
        let result_neg = signed_number::negative_number(n_neg);
        assert!(signed_number::value(result_neg) == TEST_VALUE_1, 3);
        assert!(signed_number::sign(result_neg) == false, 4);
    }

    // === Edge Cases and Special Scenarios ===

    #[test]
    fun test_large_numbers() {
        let large_value = 18446744073709551615u64; // max u64
        let n = signed_number::from(large_value, true);
        assert!(signed_number::value(n) == large_value, 1);
        assert!(signed_number::sign(n) == true, 2);
    }

    #[test]
    fun test_overflow_scenarios() {
        // Test that addition doesn't overflow
        let max_half = 9223372036854775807u64; // roughly max u64 / 2
        let a = signed_number::from(max_half, true);
        let b = signed_number::from(max_half, true);
        let result = signed_number::add(a, b);
        assert!(signed_number::value(result) == max_half + max_half, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_chain_operations() {
        // Test chaining multiple operations
        let a = signed_number::from(TEST_VALUE_1, true);  // +1000000000
        let b = signed_number::from(TEST_VALUE_2, false); // -2000000000
        
        // (a + b) - a should equal b
        // (1000000000 + (-2000000000)) - 1000000000 = -1000000000 - 1000000000 = -2000000000
        let sum = signed_number::add(a, b);
        let result = signed_number::sub(sum, a);
        
        // Result should equal b (negative 2000000000)
        assert!(signed_number::value(result) == TEST_VALUE_2, 1);
        assert!(signed_number::sign(result) == false, 2);
    }

    #[test]
    fun test_comparison_edge_cases() {
        let zero_pos = signed_number::new();
        let small_pos = signed_number::from(1, true);
        let small_neg = signed_number::from(1, false);
        
        // Zero comparisons
        assert!(signed_number::gt(small_pos, zero_pos) == true, 1);
        assert!(signed_number::lt(small_neg, zero_pos) == true, 2);
        assert!(signed_number::gte(zero_pos, zero_pos) == true, 3);
        assert!(signed_number::eq(zero_pos, zero_pos) == true, 4);
    }

    #[test]
    fun test_multiplication_precision() {
        // Test that multiplication maintains precision according to base_mul logic
        let base = constants::base_uint();
        let n = signed_number::from(base, true); // Represents 1.0
        let result = signed_number::mul_uint(n, base); // 1.0 * 1.0 should equal 1.0
        assert!(signed_number::value(result) == base, 1);
        assert!(signed_number::sign(result) == true, 2);
    }

    #[test]
    fun test_division_precision() {
        // Test that division maintains precision according to base_div logic
        let base = constants::base_uint();
        let n = signed_number::from(base, true); // Represents 1.0
        let result = signed_number::div_uint(n, 1); // 1.0 / 1 should equal base^2 / 1
        let expected = base * base; // Since base_div multiplies by base
        assert!(signed_number::value(result) == expected, 1);
        assert!(signed_number::sign(result) == true, 2);
    }
}
