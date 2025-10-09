/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::utils {
    use std::string::{Self, String};
    use std::u64;

    // local modules
    use bluefin_cross_margin_dex::constants;

    //===========================================================//
    //                      Public Methods                       //
    //===========================================================//

    /// Converts the provided value into the base decimals(9)
    /// format supported by the protocol
    ///
    /// Parameters:
    /// - value: The value to be converted into base decimals
    /// - decimals: The current decimals in which the value is expressed
    public fun convert_to_protocol_decimals(value: u64, decimals: u8): u64 {

        // get protocol decimals
        let protocol_decimals = constants::protocol_decimals();

        // if value decimals are less than protocol decimals
        // we need to add 0s at the end
        if(decimals < protocol_decimals){
            (value * u64::pow(10, protocol_decimals - decimals))
        } else {
        // if decimals are greater than protocol decimals
        // we need to remove leading zeros
            (value / u64::pow(10, decimals - protocol_decimals))
        }
    }

    /// Converts the value in protocol decimals into a value containing provided
    /// number of decimals
    ///
    /// Parameters:
    /// - value: The base decimal value to be converted
    /// - decimals: The new decimals in which the value is to be represented
    public fun convert_to_provided_decimals(value: u64, decimals: u8): u64 {
        // get protocol decimals
        let protocol_decimals = constants::protocol_decimals();
        if(decimals < protocol_decimals){
            (value / u64::pow(10, protocol_decimals - decimals))
        } else {
            (value * u64::pow(10, decimals - protocol_decimals))
        }
    }


    /// Multiplies given values in base decimals
    public fun base_mul(a : u64, b: u64): u64 {
        (((a as u128) * (b as u128)) / (constants::base_uint() as u128) as u64)
    }

    /// Division by a base value with the result rounded down
    public fun base_div(a : u64, b: u64): u64 {
        ((a as u128) * ( constants::base_uint() as u128) / (b as u128) as u64)
    }


    /// Returns true if the provided string is empty
    public fun is_empty_string(value: String): bool {
        value == string::utf8(b"")
    }

    /// Returns true if the trade is reducing
    public fun is_reducing_trade(current_direction: bool, current_size: u64, trade_direction: bool, trade_size: u64): bool {
        current_direction != trade_direction && trade_size <= current_size
    }


    // Rounds the given number up/down
    // if the number is <= 0.5 its rounded down
    // if the number is > 0.5, its always rounded up
    public fun round(value: u64, scale: u64): u64 {
        let int_part = value / scale;
        let remainder = value % scale;

        let rounded = if (remainder * 2 > scale) {
            int_part + 1
        } else {
            int_part
        };
        rounded * scale
    }

    /// Round up a value to the nearest tick size
    /// Example: if tick_size is 10 and value is 123, it will return 130
    /// @param value: The value to round up
    /// @param tick_size: The tick size to round up to
    /// @return The rounded up value
    public fun round_up_to_tick_size(value: u64, tick_size: u64): u64 {
        if (tick_size == 0) {
            return value
        };

        let remainder = value % tick_size;
        if (remainder == 0) {
            value
        } else {
            value + (tick_size - remainder)
        }
    }


    public fun round_to_tick_size_based_on_direction(value: u64, tick_size: u64, direction: bool): u64 {
        if (direction) {
            round_up_to_tick_size(value, tick_size)
        } else {
            round_down_to_tick_size(value, tick_size)
        }
    }

    /// Multiplies two u64 values and divides the result by a u64 value
    /// @param a: The first u64 value
    /// @param b: The second u64 value
    /// @param c: The u64 value to divide the result by
    /// @return The result of the multiplication and division
    public fun mul_div_uint(a: u64, b: u64, c: u64): u64 {
        ((((a as u128) * (b as u128)) / (c as u128)) as u64)
    }

    public fun round_down_to_tick_size(value: u64, tick_size: u64): u64 {
        if (tick_size == 0) {
            return value
        };

        let remainder = value % tick_size;
        value - remainder
    }

}


