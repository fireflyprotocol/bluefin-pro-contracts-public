/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::admin {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;

    // local modules
    use bluefin_cross_margin_dex::events;

    //===========================================================//
    //                           Structs                         //
    //===========================================================//

    /// Represents an administrative capability for high-level management and control functions.
    struct AdminCap has key {
        /// Unique identifier for the AdminCap.
        id: UID
    }


    //===========================================================//
    //                    Initialization                         //
    //===========================================================//

    /// Initializes the module by assigning the admin capability.
    /// This function is only called during the module's setup phase, 
    /// ensuring that administrative privileges are correctly established. 
    ///
    /// Parameters:
    /// - ctx: Mutable reference to `TxContext`, the transaction context.
    fun init(ctx: &mut TxContext) {
        
        // Generate a new AdminCap object with a unique identifier.
        let admin_cap = AdminCap { id: object::new(ctx) };
        let admin = tx_context::sender(ctx);

        // Transfer the AdminCap to the sender of the transaction.
        transfer::transfer(admin_cap, admin);
        // Emit event
        events::emit_admin_cap_transfer_event(admin);
    }


    //===============================================================//
    //                          Entry Methods                        //
    //===============================================================//

    /// Transfers the package admin-ship to the provided address
    /// Only the holder of current AdminCap can invoke the method
    ///
    /// Parameters:
    /// - admin: The AdminCap, ensuring the caller is the current admin.
    /// - new_admin: The address of the new admin
    entry fun transfer_admin_cap(admin: AdminCap, new_admin:address){
        // transfer admin cap to the new admin
        transfer::transfer(admin, new_admin);
        events::emit_admin_cap_transfer_event(new_admin);
    }



    #[test_only]
    public fun test_init(ctx: &mut TxContext){
        init(ctx);
    }

}