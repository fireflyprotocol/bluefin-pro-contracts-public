/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::bcs_handler {
    use sui::bcs::{Self};
    use std::string::{Self, String};
    use std::option::{Option};
    use sui::hash;

    use bluefin_cross_margin_dex::constants;
    //===========================================================//
    //                           Structs                         //
    //===========================================================//


    /// Represents trade payload. Used for uniqueness of trade call
    #[allow(unused_field)]
    struct Trade has copy, drop {
        maker_order_signature: vector<u8>, 
        taker_order_signature: vector<u8>,
        quantity: u64,
        timestamp: u64
    }

    /// Represents the internal bank deposit struct
    #[allow(unused_field)]
    struct Deposit has copy, drop {
        id: address,
        asset: String,
        from: address,
        to: address,
        amount: u64,
        nonce: u128,
        tainted: bool
    }

    /// Represents the operator update struct
    #[allow(unused_field)]
    struct OperatorUpdate has copy, drop {
        operator_type: String,
        previous_operator: address,
        new_operator: address,
    }



    //===============================================================//
    //                         Public methods                        //
    //===============================================================//

    /// Deserializes the BCS encoded payload into Withdrawal struct
    public fun dec_withdrawal(payload: vector<u8>): (address, String, address, u64, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )
    }

    /// Deserializes the BCS encoded payload into Withdrawal struct
    public fun dec_authorization(payload: vector<u8>): (address, address, address, bool, u64, u64) {
        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    
    }

    /// Builds trade payload, bcs serializes and returns it
    public fun enc_trade(maker_order_signature: vector<u8>, taker_order_signature: vector<u8>, quantity: u64, timestamp: u64): vector<u8>{
        
        let data = Trade {
            maker_order_signature,
            taker_order_signature,
            quantity,
            timestamp
        };

        bcs::to_bytes<Trade>(&data)
    }

    /// Builds the deposit payload, bcs serializes and returns it
    public fun enc_deposit(id: address, asset: String, from: address, to: address, amount: u64, nonce: u128, tainted: bool): vector<u8>{
        
        // create internal deposit payload
        let data = Deposit {
            id,
            asset,
            from,
            to,
            amount,
            nonce,
            tainted
        };

        // return bcs serialized payload        
        bcs::to_bytes<Deposit>(&data)

    }

    /// Builds operator update struct and returns its bcs bytes
    public fun enc_operator_update(operator_type: String, previous_operator:address, new_operator: address): vector<u8>{
        
        let data = OperatorUpdate {
            operator_type,
            previous_operator,
            new_operator
        };

        bcs::to_bytes<OperatorUpdate>(&data)
    }


    /// Deserializes the BCS encoded payload into Order struct
    public fun dec_order(payload: vector<u8>): (vector<u8>, address, address, String, u64, u64, u64, bool, bool, u64, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            hash::blake2b256(&payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)) == constants::position_long(),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)) == constants::position_isolated(),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )
    }

    /// Deserializes the BCS encoded payload into adjust_margin struct
    public fun dec_adjust_margin(payload: vector<u8>): (address, address, String, bool, u64, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }

    /// Deserializes the BCS encoded payload into adjust_leverage struct
    public fun dec_adjust_leverage(payload: vector<u8>): (address, address, String, u64, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }

    public fun dec_set_funding_rate(payload: vector<u8>): (vector<u8>, address, u64, vector<vector<u8>>, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (   bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }

    public fun dec_market_details(bytes: vector<u8>): (String, u64, bool, u64) {

        let bcs_payload = bcs::new(bytes);

        (
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }

    public fun dec_apply_funding_rate(bytes: vector<u8>): (address, u64, vector<address>, u64, u64, String) {
        let bcs_payload = bcs::new(bytes);

        (
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_vec_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
        )
    }


    public fun dec_liquidation(bytes: vector<u8>): (vector<u8>, address, address, address, String, u64, bool, bool, bool, u64, u64, u64, u64) {
        let bcs_payload = bcs::new(bytes);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }


    public fun dec_prune_table(payload: vector<u8>): (vector<u8>, address, vector<vector<u8>>, u8, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_u8(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }

    public fun dec_authorize_liquidator(payload: vector<u8>): (vector<u8>, address, address, bool, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }


    public fun dec_set_fee_tier(payload: vector<u8>): (vector<u8>, address, address, u64, u64, bool, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }


    public fun dec_set_account_type(payload: vector<u8>): (vector<u8>, address, address, bool, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }


    public fun dec_set_gas_fee(payload: vector<u8>): (vector<u8>, address, u64, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }

    public fun dec_set_gas_pool(payload: vector<u8>): (vector<u8>, address, address, u64, u64) {

        let bcs_payload = bcs::new(payload);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
        )

    }


    public fun dec_adl(bytes: vector<u8>): (vector<u8>, address, address, address, bool, bool, String, u64, u64, u64, u64) {
        let bcs_payload = bcs::new(bytes);

        (
            bcs::peel_vec_u8(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_bool(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }


     public fun dec_close_position(bytes: vector<u8>): (address, address, String, bool, u64, u64) {
        let bcs_payload = bcs::new(bytes);

        (
            bcs::peel_address(&mut bcs_payload),
            bcs::peel_address(&mut bcs_payload),
            string::utf8(bcs::peel_vec_u8(&mut bcs_payload)),
            bcs::peel_bool(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload),
            bcs::peel_u64(&mut bcs_payload)
        )
    }


    public fun dec_trades_batch(payload: vector<u8>): (vector<vector<u8>>, vector<vector<u8>>, vector<vector<u8>>, vector<vector<u8>>, vector<u64>) {

        let bcs_payload = bcs::new(payload);

        (   
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_vec_vec_u8(&mut bcs_payload),
            bcs::peel_vec_u64(&mut bcs_payload),
        )
    }

}