/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::signed_number {
    use sui::bcs::{Self};
    use bluefin_cross_margin_dex::utils;
    use bluefin_cross_margin_dex::constants;
   
   const EInvalidValue: u64 = 5000;

    struct Number has store, copy, drop {
        value: u64,
        sign: bool
    }

    public fun new():Number {
        return Number {
            value: 0,
            sign: true
        }
    }
    
    public fun from(value:u64, sign: bool): Number {
        assert!(value > 0 || sign, EInvalidValue);

        return Number {
            value,
            sign
        }
    }   
    

    public fun one():Number {
        return Number {
            value: constants::base_uint(),
            sign: true
        }
    }   

    public fun from_bytes(bytes:vector<u8>): Number {
        let bcs_bytes = bcs::new(bytes);
        let value = bcs::peel_u64(&mut bcs_bytes);
        let sign = bcs::peel_bool(&mut bcs_bytes);

        from(value, sign)

    }

    public fun add_uint(a:Number, b: u64): Number {

        let value = a.value; 
        let sign = a.sign;

        if (sign == true) {
            value = value + b;
        } else {
            if (value > b) { value = value - b; }
            else {value = b - value; sign = true };
        };

        return Number { 
            value,
            sign
        }
    }

    public fun sub_uint(a:Number, b: u64): Number {

        let value = a.value; 
        let sign = a.sign;

        if (sign == false) {
            value = value + b;
        } else {
            if (value >= b) { value = value - b; }
            else {value = b - value; sign = false };
        };

        // zero is considered as positive value
        if(value == 0){
            sign = true;
        };

        return Number { 
            value,
            sign
        }
    }

    public fun mul_uint(a:Number, b: u64): Number {

        let value = utils::base_mul(a.value, b);
        // zero is considered as positive value
        let sign = if(value == 0 ){ true } else { a.sign };
        
        return Number { 
            value,
            sign
        }
    }

    public fun div_uint(a:Number, b: u64): Number {

        let value = utils::base_div(a.value, b);
        
        // zero is considered as positive value
        let sign = if(value == 0 ){ true } else { a.sign };
        
        return Number { 
            value,
            sign
        }
    }

    public fun negate(n:Number): Number {
        return Number { 
            value: n.value,
            sign: if(n.value == 0) {true} else {!n.sign}
        }
    }

    public fun add(a:Number, b:Number): Number {

        let value;
        let sign;

        if (a.sign == b.sign ) { 
            value = a.value + b.value;
            sign = a.sign;
            } 
        else if (a.value >= b.value) {
            value = a.value - b.value;
            sign = a.sign;
        }
        else {
            value = b.value - a.value;
            sign = b.sign;
        };

        // zero is considered as positive value
        if(value == 0) { sign = true; };

        return Number {
            value,
            sign 
        }

    }

    public fun sub(a:Number, b:Number): Number {

        let value;
        let sign;
        b.sign = !b.sign;

        if (a.sign == b.sign ) { 
            value = a.value + b.value;
            sign = a.sign;
            } 
        else if (a.value >= b.value) {
            value = a.value - b.value;
            sign = a.sign;
        }
        else {
            value = b.value - a.value;
            sign = b.sign;
        };

        // zero is considered as positive value
        if(value == 0) { sign = true; };

        return Number {
            value,
            sign 
        }

    }

    public fun gte_uint(a:Number, num: u64): bool {
        return if (!a.sign) { false } else { a.value >= num }
    }

    public fun gt_uint(a:Number, num: u64): bool {
        return if (!a.sign) { false } else { a.value > num }
    }

    
    public fun lt_uint(a:Number, num: u64): bool {
        return if (!a.sign) { true } else { a.value < num }
    }

    public fun lte_uint(a:Number, num: u64): bool {
        return if (!a.sign) { true } else { a.value <= num }
    }

    public fun gte(a:Number, b: Number): bool {
        if(a.sign && b.sign){
            a.value >= b.value
        } else if(!a.sign && !b.sign){
            a.value <= b.value
        } else {
            a.sign
        }
    }

    public fun gt(a:Number, b: Number): bool {
        if(a.sign && b.sign){
            a.value > b.value
        } else if(!a.sign && !b.sign){
            a.value < b.value
        } else {
            a.sign
        }
    }

    public fun lt(a:Number, b: Number): bool {
        if(a.sign && b.sign){
            a.value < b.value
        } else if(!a.sign && !b.sign){
            a.value > b.value
        } else {
            !a.sign
        }
    }

    public fun eq(a:Number, b: Number): bool {
        return a.sign == b.sign && a.value == b.value
    }

    public fun from_subtraction(a:u64, b:u64):Number {
        
        return if ( a >= b ){
            Number {
                value: a - b,
                sign: true
            }
        } else {
            Number {
                value: b - a,
                sign: false
            }
        }

    }

    public fun value(n:Number): u64 {
        return n.value
    }

    public fun sign(n:Number): bool {
        return n.sign
    }


    public fun positive_value(n:Number): u64 {
        return if (!n.sign) { 0 } else { n.value }
    }

    public fun negative_value(n:Number): u64 {
        return if (n.sign) { 0 } else { n.value }
    }

    public fun positive_number(n:Number): Number{
        return if (!n.sign) { Number { value:0, sign: true} } else { n }
    }

    public fun negative_number(n:Number): Number{
        return if (!n.sign) { n } else { from(0, true) }
    }

}
