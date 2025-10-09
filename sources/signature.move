/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::signature {
    
    use std::string::{Self};
    use std::vector;
    use sui::bcs;
    use sui::address;
    use std::u64;
    use sui::hash;
    use sui::ed25519;
    use sui::ecdsa_k1;
    use bluefin_cross_margin_dex::errors;
    use bluefin_cross_margin_dex::constants;

    /// Triggered when an unknown payload is provided for 
    /// BCS serialized signature verification
    const EInvalidBcsSerializedPayload: u64 = 2000;

    /// Triggered when an unknown field type is provided
    const EUnknownFieldType: u64 = 2001;

    /// Triggered when a signature from a non-supported wallet is received for verification
    const EWalletSchemeNotSupported: u64 = 2002;

    /// Triggered when the signature is invalid
    const EInvalidSignature: u64 = 2003;

    /// Triggered when an unknown payload type is provided
    const EUnknownPayloadType: u64 = 2004;


    struct PayloadKeys has copy, drop {
        field_name: vector<u8>,
        // 1 = address
        // 2 = string
        // 3 = u64
        // 4 = boolean
        field_type: u8,
    }


    //===========================================================//
    //                      Public Methods                       //
    //===========================================================//

    /// Verifies that the signature is created from the provided payload bytes and returns
    /// the signer address
    /// 
    /// Parameter: 
    /// - payload: BCS serialized payload bytes
    /// - signature: signature created using `signPersonalMessage()` converted to its bytes representation
    /// - type: The type of the payload
    /// 
    /// Returns:
    /// - The address of the signer. Note that for ZK signatures, there is no verification so the signer is returned as ZERO address
    public fun verify(payload: vector<u8>, signature: vector<u8>, type:vector<u8>): address {
        
        if(type == b"Bluefin Pro Withdrawal"){
            verify_withdrawal_signature(payload, signature, type)
        } 
        else if(type == b"Bluefin Pro Order"){
            verify_order_signature(payload, signature, type)
        } 
        else if(type == b"Bluefin Pro Authorize Account"){
            verify_authorize_account_signature(payload, signature, type)
        } 
        else if(type == b"Bluefin Pro Margin Adjustment"){
            verify_adjust_margin_signature(payload, signature, type)
        } else if(type == b"Bluefin Pro Leverage Adjustment"){
            verify_adjust_leverage_signature(payload, signature, type)
        } else if(type == b"Bluefin Pro Close Position For Delisted Market"){
            verify_close_position_signature(payload, signature, type)
        }else if(
            type == constants::payload_type_setting_funding_rate() || 
            type == constants::payload_type_pruning_table() ||
            type == constants::payload_type_authorizing_liquidator() || 
            type == constants::payload_type_setting_account_fee_tier() ||
            type == constants::payload_type_setting_account_type() ||
            type == constants::payload_type_setting_gas_fee() || 
            type == constants::payload_type_setting_gas_pool() ||
            type == constants::payload_type_adl() || 
            type == constants::payload_type_liquidate()
            )
            verify_bcs_serialized_payload_signature(payload, signature, type) 
        else {
            abort EUnknownPayloadType
        }
    }

    /// Verifies the withdrawal payload signature
    public fun verify_withdrawal_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"eds", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"assetSymbol", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"amount", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );


         verify_signature_and_recover_signer(message, signature)
    }

    /// Verifies the order payload signature
    public fun verify_order_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"ids", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"market", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"price", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"quantity", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"leverage", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"side", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"positionType", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"expiration", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );
    
        verify_signature_and_recover_signer(message, signature)
    }


    /// Verifies the authorize  account payload signature
    public fun verify_authorize_account_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"ids", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"user", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"status", field_type:4});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );

        verify_signature_and_recover_signer(message, signature)
    }


    /// Deprecated function. This function is no longer used.
    public fun verify_liquidation_signature(_: vector<u8>, _: vector<u8>, _: vector<u8>): address {
        abort errors::deprecated_function()
    }

    /// Verifies the adjust margin  payload signature
    public fun verify_adjust_margin_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"ids", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"market", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"add", field_type:4});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"amount", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );
    
        verify_signature_and_recover_signer(message, signature)
    }


    /// Verifies the adjust leverage payload signature
    public fun verify_adjust_leverage_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"ids", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"market", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"leverage", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );
    
        verify_signature_and_recover_signer(message, signature)
    }

    /// Verifies the authorize  account payload signature
    public fun verify_close_position_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address {

        let payload_keys = vector::empty<PayloadKeys>();
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"ids", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"account", field_type:1});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"market", field_type:2});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"isolated", field_type:4});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"salt", field_type:3});
        vector::push_back(&mut payload_keys, PayloadKeys{field_name:b"signedAt", field_type:3});

        let message = build_signed_message(
            type, 
            payload_keys,
            payload
            );
    
        verify_signature_and_recover_signer(message, signature)
    }

    /// Verifies signatures for payloads that are bcs serializes not JSON stringified before signature
    /// These payloads are generally signed by backend services like funding rate or admin whitelisting bankrupt liquidator etc.
    public fun verify_bcs_serialized_payload_signature(payload: vector<u8>, signature: vector<u8>, type: vector<u8>): address{ 

        // revert if not a valid bcs serialized payload
        assert!(
            type == constants::payload_type_setting_funding_rate() || 
            type == constants::payload_type_pruning_table() ||
            type == constants::payload_type_authorizing_liquidator() || 
            type == constants::payload_type_setting_account_fee_tier() ||
            type == constants::payload_type_setting_account_type() ||
            type == constants::payload_type_setting_gas_fee() || 
            type == constants::payload_type_setting_gas_pool() ||
            type == constants::payload_type_adl() || 
            type == constants::payload_type_liquidate()
            , EInvalidBcsSerializedPayload
        );

        let message = add_intent_bytes_and_hash(payload);

        verify_signature_and_recover_signer(message, signature)

    }


    /// Builds the message bytes that were signed on
    public fun build_signed_message(msg_type: vector<u8>, msg_keys: vector<PayloadKeys>, payload: vector<u8>): vector<u8> {

        let type_field_start = b"{\n  \"type\": \"";
        let type_field_end = b"\",\n";

        let message_bytes =  vector::empty<u8>();

        vector::append(&mut message_bytes, type_field_start);
        vector::append(&mut message_bytes, msg_type);
        vector::append(&mut message_bytes, type_field_end);


        let bcs_payload = bcs::new(payload);

        let i = 0;
        let num_keys = vector::length(&msg_keys);

        let prefix = b"  \"";
        let stem = b"\": \"";
        let suffix = b"\",\n";
        let last_suffix = b"\"\n";

        while(i < num_keys){
            // remove the first key
            let key = vector::remove(&mut msg_keys, 0);

            i = i + 1;

            let value = if (key.field_type == 1){
                let address_string = string::utf8(b"0x");
                string::append(&mut address_string, address::to_string(bcs::peel_address(&mut bcs_payload)));
                string::into_bytes(address_string)
            } else if(key.field_type == 2){
                bcs::peel_vec_u8(&mut bcs_payload)
            } else if (key.field_type == 3){
                string::into_bytes(u64::to_string(bcs::peel_u64(&mut bcs_payload)))
            } else if(key.field_type == 4){
                // convert bool to text
                let bool_text = if (bcs::peel_bool((&mut bcs_payload))){
                    b"true"
                } else {
                    b"false"
                };
                bool_text
            } else {
                abort EUnknownFieldType
            };

            let suffix_to_use = if(i == num_keys ){ last_suffix } else { suffix };
            let stem_to_use = stem;
            if(key.field_type == 4){
                vector::remove(&mut suffix_to_use, 0, );
                vector::pop_back(&mut stem_to_use);
            };

            vector::append(&mut message_bytes, prefix );
            vector::append(&mut message_bytes, key.field_name );
            vector::append(&mut message_bytes, stem_to_use );
            vector::append(&mut message_bytes, value );
            vector::append(&mut message_bytes, suffix_to_use );

        };

        vector::append(&mut message_bytes, b"}" );

       
       add_intent_bytes_and_hash(message_bytes)

    }

    /// Verifies if the given signature is valid or not for the provided message payload bytes
    /// The payload is expected to be signed using `wallet.signPersonalMessage() with intent scope
    /// as `PersonalMessage` and built using `build_signed_message()` on-chain
    /// Returns:
    /// - The address of the signer
    public fun verify_signature_and_recover_signer(message: vector<u8>, signature: vector<u8>): address {

        let scheme = vector::remove(&mut signature, 0);
        let signature_bytes = vector::empty<u8>();
        let public_key_bytes = vector::empty<u8>();

        let  i = 0;
        let length  = vector::length(&signature);

        // extract the signature bytes
        while (i < 64){
            vector::push_back(&mut signature_bytes, *vector::borrow(&signature, i));
            i = i + 1;
        };

        // extract the public key bytes
        while (i < length){
            vector::push_back(&mut public_key_bytes, *vector::borrow(&signature, i));
            i = i + 1;
        };

        let verified:bool;

        if(scheme == 0){
            
            verified = ed25519::ed25519_verify(
                &signature_bytes, 
                &public_key_bytes, 
                &message
            );

            vector::insert(&mut public_key_bytes, 0, 0);

        } else if(scheme == 1){
            
            verified = ecdsa_k1::secp256k1_verify(
                &signature_bytes,
                &public_key_bytes,
                &message,
                1
            );

            vector::insert(&mut public_key_bytes, 1, 0);

        } else if (scheme == 5){ 
            // Zk signature
            // We do not verify zk signatures on-chain and trust off-chain 
            // auth gateway to have them validated. Currently sui move does
            // not support ZK signature validation on-chain.
            // TODO: in future upgrades check with Mysten team with progress on
            // on-chain ZK signature verification 
            return @0 
        }else {
            abort EWalletSchemeNotSupported
        };


        assert!(verified, EInvalidSignature);

        address::from_bytes(hash::blake2b256(&public_key_bytes))

    }

    // Adds personal message intent bytes and hashes the payload bytes and returns it
    fun add_intent_bytes_and_hash(message_bytes: vector<u8>): vector<u8>{

        // bcs serialize the message
        let serialize = bcs::to_bytes(&message_bytes);

        // attach the intent scope bytes
        let intent_bytes = vector::empty<u8>();
        vector::push_back(&mut intent_bytes, 3);
        vector::push_back(&mut intent_bytes, 0);
        vector::push_back(&mut intent_bytes, 0);
        vector::append(&mut intent_bytes, serialize);

        // blake encode message
        hash::blake2b256(&intent_bytes)
    }


}