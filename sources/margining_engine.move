/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::margining_engine {
    use sui::table::{Table};
    use std::string::{Self, String};
    use std::vector;
    use std::u64;
    use std::option::{Self, Option};


    // local modules
    use bluefin_cross_margin_dex::signed_number::{Self, Number};
    use bluefin_cross_margin_dex::perpetual::{Self, Perpetual};
    use bluefin_cross_margin_dex::account::{Self, DepositedAsset, Position, Account};
    use bluefin_cross_margin_dex::data_store::{Self, InternalDataStore};
    use bluefin_cross_margin_dex::bank::{Self, Asset};
    use bluefin_cross_margin_dex::constants;
    use bluefin_cross_margin_dex::utils;
    use bluefin_cross_margin_dex::errors;    

    // friend modules
    friend bluefin_cross_margin_dex::exchange;
    

    // @dev This event is only for debugging. Not being used any more
    #[allow(unused_field)]
    struct Check has copy, drop {
        pnl: Number,
        bad_debt_orig: u64,
        bad_debt_final: u64,
        margin_remaining_in_position_final: u64,
        margin_remaining_in_position_orig: u64
    }

    /// Applies cross margining maths to the account
    /// 
    /// Parameters
    /// - ids: Mutable reference to internal data store
    /// - perpetual: Symbol of the perpetual being traded on
    /// - maker: Address of the account
    /// - fill_price: Price at which trade is being executed
    /// - fill_quantity: The amount of quantity being traded
    /// - leverage: The leverage to be used. Will be zero for cross orders/positions
    /// - is_long: If the trade is going long or short 
    /// - is_isolated: True if the trade is isolated false otherwise
    /// - is_maker: True if the provided account is the maker of the trade
    /// - premium_or_debt: An optional liquidation premium or bad debt that liquidator makes or has to pay to take over the position
    /// - is_first_fill: An optional field informing the margining engine its the first order fill during trade call
    public (friend) fun apply_maths(
        ids: &mut InternalDataStore, 
        perpetual:String, 
        account: address, 
        fill_price: u64, 
        fill_quantity: u64, 
        leverage: u64, 
        is_long: bool, 
        is_isolated: bool, 
        is_maker: bool, 
        action: u8,
        premium_or_debt: Option<Number>,
        is_first_fill: Option<bool>,
        ): (u64, u64, String, Position, vector<DepositedAsset>, u64, u64 ) {

        // Get list of all perpetuals
        let perpetual_table = data_store::get_immutable_perpetual_table_from_ids(ids);
        // Get list of all supported assets
        let assets_table = data_store::get_immutable_assets_table_from_ids(ids);
        // Get perpetual of the trade
        let perpetual_details = data_store::get_immutable_perpetual_from_ids(ids, perpetual);

        // Get the user account
        let account_details = data_store::get_immutable_account_from_ids(ids, account);

        let gas_charges = data_store::get_gas_fee_amount(ids);

        let ( fee,
            fee_coins_amount,
            fee_asset,
            positions,
            updated_position_index,
            position,
            assets,
            bad_debt,
            gas_charges,
            ) = apply_maths_internal(
            perpetual_table,
            assets_table,
            perpetual_details, 
            account_details, 
            fill_price, 
            fill_quantity, 
            leverage, 
            is_long, 
            is_isolated, 
            is_maker, 
            action,
            premium_or_debt,
            is_first_fill,
            gas_charges
        );

        // Update the user account with new asset and position
        let mutable_account_details = data_store::get_mutable_account_from_ids(ids, account);

        account::update_account(
            mutable_account_details, 
            &assets, 
            &positions, 
            updated_position_index, 
            is_isolated,
        );

        // return fee, position and current asset
        return (fee, fee_coins_amount, fee_asset, position, assets, bad_debt, gas_charges)

    }



    /// Applies cross margining maths to the account
    /// 
    /// Parameters
    /// - ids: Mutable reference to internal data store
    /// - perpetual: Symbol of the perpetual being traded on
    /// - maker: Address of the account
    /// - fill_price: Price at which trade is being executed
    /// - fill_quantity: The amount of quantity being traded
    /// - leverage: The leverage to be used. Will be zero for cross orders/positions
    /// - is_long: If the trade is going long or short 
    /// - is_isolated: True if the trade is isolated false otherwise
    /// - is_maker: True if the provided account is the maker of the trade
    /// - premium_or_debt: An optional liquidation premium or bad debt that liquidator makes or has to pay to take over the position
    /// - is_first_fill: An optional field informing the margining engine its the first order fill during trade call
    /// - gas_fee: The gas fee to be used for the trade
    public (friend) fun apply_maths_internal(
        perpetual_table:&Table<String, Perpetual>,
        assets_table:&Table<String, Asset>,
        perpetual:&Perpetual, 
        account: &Account, 
        fill_price: u64, 
        fill_quantity: u64, 
        leverage: u64, 
        is_long: bool, 
        is_isolated: bool, 
        is_maker: bool, 
        action: u8,
        premium_or_debt: Option<Number>,
        is_first_fill: Option<bool>,
        gas_fee: u64
        ): (
            u64, 
            u64, 
            String,
            vector<Position>,
            u64,
            Position, 
            vector<DepositedAsset>, 
            u64, 
            u64 ) {

        let symbol = perpetual::get_symbol(perpetual);
        // // the variable is used to get positions and assets vector from account
        // // if math is being applied to an isolated position, we just need the position 
        // // of that perpetual else we need all positions for cross
        let fetch_for = if(is_isolated) { symbol } else { constants::empty_string() };
        let current_positions = account::get_positions_vector(account, fetch_for);
        let current_assets = account::get_assets_vector(account, fetch_for);

        // // get current cross positions and assets as well ( in case we are dealing with isolated trade)
        let current_cross_positions = account::get_positions_vector(account, constants::empty_string());
        let current_cross_assets = account::get_assets_vector(account, constants::empty_string());
        let initial_cross_assets = current_cross_assets;

        // make a copy of the current position vector
        let initial_positions = current_positions;
        // make a copy of initial user assets vector
        let initial_assets = current_assets;

        // the assets that will be updated with new balance
        let user_assets = if( is_isolated ) { &mut current_cross_assets } else { &mut current_assets };

        let ( current_perp_position, position_index ) = account::get_mutable_position_for_perpetual(&mut current_positions, symbol, is_isolated);

        // implies the initial position vector does not have current_perp_position 
        // as it was created during get_mutable_position_for_perpetual call
        if( vector::length(&initial_positions) < position_index + 1){
            vector::push_back(&mut initial_positions, *current_perp_position);
        };

        let (_, initial_position_size, initial_position_average_entry_price, initial_position_side, initial_position_leverage, initial_position_margin, _, pending_funding_payment) = account::get_position_values(current_perp_position);

        // Either the order should be cross or should have non zero leverage
        assert!(!is_isolated || leverage > 0, errors::invalid_leverage());
        // If isolated order then either a new position is being opened 
        // or the leverage is same as existing position leverage
        assert!(!is_isolated || (initial_position_size == 0 || initial_position_leverage == leverage), errors::invalid_leverage());

        let effective_leverage = account::calculate_effective_leverage(current_perp_position, option::some(leverage));

        // POSITION UPDATE
        let (current_position_side,
            current_position_size, 
            current_position_average_entry_price, 
            pnl) = update_position(
            initial_position_side,
            initial_position_size,
            initial_position_average_entry_price,
            is_long,
            fill_quantity,
            fill_price
            );


        // PNL SETTLEMENT and FUNDING PAYMENT SETTLEMENT (for normal trades)
        let (margin_remaining_in_position,pending_funding_payment, bad_debt) = settle_pnl(
            assets_table,
            user_assets,
            initial_position_margin,
            pnl,
            pending_funding_payment,
            is_maker,
            is_isolated,
            action
        );

        // PENDING FUNDING RATE SETTLEMENT FOR LIQUIDATIONS
        (margin_remaining_in_position, pending_funding_payment, bad_debt) = settle_liquidatee_pending_funding_payment(
            assets_table,
            user_assets,
            pending_funding_payment,
            fill_quantity,
            initial_position_size,
            margin_remaining_in_position,
            bad_debt,
            is_isolated,
            is_maker,
            action
        );

        // MARGIN SETTLEMENT
        let margin_needed_for_position;

        (margin_needed_for_position, bad_debt) = settle_margin(
            user_assets,
            margin_remaining_in_position,
            current_position_size,
            current_position_average_entry_price,
            bad_debt,
            effective_leverage,
            is_maker,
            is_isolated,
            action,
        );

        // FEE SETTLEMENT
        let (fee, fee_coins_amount,fee_asset) = settle_fee(
            assets_table,
            perpetual,
            account,
            user_assets,
            fill_quantity,
            fill_price,
            is_maker,
            action,
        );      


        // LIQUIDATOR'S PREMIUM or DEBT SETTLEMENT
        premium_or_debt_settlement(
            user_assets,
            premium_or_debt,
            is_maker,
            action
        );

        // GAS CHARGES SETTLEMENT for TRADES
        let gas_charges = settle_gas_charges(
            gas_fee,
            user_assets,
            account,
            is_first_fill,
            is_maker,
            action,
        );  

        // update the assets with margin required (for cross position this will do nothing)
        account::set_isolated_position_assets(&mut current_assets, margin_needed_for_position);
        
        // update the current position values
        if(!is_isolated){ leverage = 0 };
        account::update_position_values(
            current_perp_position, 
            current_position_size, 
            current_position_average_entry_price,
            margin_needed_for_position,
            leverage,
            current_position_side,
            pending_funding_payment // The remaining pending funding payment to be settled
        );

        let position = *current_perp_position;

        // user assets and position has been updated, compute the health of the account
        // and ensure that the account is not undercollat
        verify_health(
            perpetual_table,
            assets_table,
            &current_assets, 
            &current_positions, 
            &initial_assets, 
            &initial_positions, 
            position_index,
            action,
            is_maker,
        );

        // if isolated trade and the trade is not a reducing one then verify health 
        // of the cross account as some funds got withdrawn from it
        if (
            is_isolated && (action == constants::action_trade()  || action == constants::action_liquidate()) &&
            !utils::is_reducing_trade(initial_position_side, initial_position_size, is_long, fill_quantity)
           ) {
                
            verify_health(
                perpetual_table,
                assets_table,
                &current_cross_assets, 
                &current_cross_positions, 
                &initial_cross_assets, 
                &current_cross_positions, 
                position_index,
                constants::action_isolated_trade(),
                is_maker,
            );
        };

        current_assets = if (is_isolated) { current_cross_assets } else { current_assets };

        return (fee, fee_coins_amount, fee_asset, current_positions, position_index, position, current_assets, bad_debt, gas_charges)

    }


    /// Finds the fee percentage to be applied to the trade value 
    /// and returns the fee to be charged for the trade
    /// Parameters:
    /// - account: The immutable reference to user account
    /// - perpetual: The immutable reference to perpetual being traded on
    /// - trade_notional_value: The notional value (size * qty) of the trade
    /// - is_maker: True if the account is maker of the trade
    public (friend) fun compute_trade_fee(account: &Account, perpetual: &Perpetual, trade_notional_value: u64, is_maker: bool): u64 {

        let (default_maker_fee, default_staker_fee)  = perpetual::get_fees(perpetual);
        let (user_maker_fee, user_taker_fee, is_applied) = account::get_fees(account);

        let fee_percent; 

        // if the special fee is applied to user
        if(is_applied){
            fee_percent = if (is_maker) { user_maker_fee } else { user_taker_fee };
        } else {
            fee_percent = if (is_maker) { default_maker_fee } else { default_staker_fee };
        };

        utils::base_mul(fee_percent, trade_notional_value)
    }

    /// Method to compute the account health. This will revert if after the 
    /// trade, adjust margin, leverage the user is below water
    /// 
    /// Parameters:
    /// - current_assets: Assets vector of the user after trade
    /// - supported_assets_table: Immutable reference to the assets table
    /// - current_positions: Position vector of the user after trade
    /// - initial_assets: Assets vector of the user before trade
    /// - initial_positions: Position vector of the user before trade
    /// - position_index: The index of the position updated by trade
    /// - action: The type of action after which account health is being verified
    /// - is_maker: health verification is being done for maker or not
    public (friend) fun verify_health(
        perpetuals_table: &Table<String, Perpetual>,
        supported_assets_table: &Table<String, Asset>,
        current_assets: &vector<DepositedAsset>, 
        current_positions: &vector<Position>, 
        initial_assets: &vector<DepositedAsset>, 
        initial_positions: &vector<Position>, 
        position_index: u64,
        action: u8, 
        is_maker: bool,
        ){
        
        let initial_position;
        let current_position;

        if(vector::length(initial_positions) == 0){
            initial_position = &account::create_empty_position(constants::empty_string(), false);
            current_position = &account::create_empty_position(constants::empty_string(), false);
        } else {
            initial_position = vector::borrow(initial_positions, position_index);
            current_position = vector::borrow(current_positions, position_index);
        };

        let (_, initial_position_size, _ , initial_position_side, _, _, _, _) = account::get_position_values(initial_position);
        let (_, current_position_size, _ , current_position_side, _, _, _, _) = account::get_position_values(current_position);


        // calculate the account value
        let account_value = account::get_account_value(current_assets, current_positions, perpetuals_table, supported_assets_table);
        // calculate the initial margin required
        let initial_margin_required = account::get_total_margin_required(current_positions, perpetuals_table, constants::imr_threshold());
        // calculate the maintenance margin required
        let maintenance_margin_required = account::get_total_margin_required(current_positions, perpetuals_table, constants::mmr_threshold());

        // initial_health = account value - initial margin required
        let initial_health = signed_number::sub_uint(account_value, initial_margin_required);
        // maintenance = account value - maintenance margin required
        let maintenance_health = signed_number::sub_uint(account_value, maintenance_margin_required);

        // Calculate the maintenance health of the account before the action

        // calculate the account value
        let account_value_before_action = account::get_account_value(initial_assets, initial_positions, perpetuals_table, supported_assets_table);
        // calculate the maintenance margin required
        let maintenance_margin_required_before_action = account::get_total_margin_required(initial_positions, perpetuals_table, constants::mmr_threshold());
        // maintenance_health = account value - maintenance margin required
        let maintenance_health_before_action = signed_number::sub_uint(account_value_before_action, maintenance_margin_required_before_action);

        // Case 1: Account value - Initial Margin Required >= 0 or
        // the maintenance health after the action has improved
        // All actions are permitted
        if ( signed_number::gte_uint(initial_health, 0)  || 
             signed_number::gt(maintenance_health, maintenance_health_before_action)
            ) {
            return
        };
      

        // Case 2: Account value - Initial Margin Required is < 0 so only actions allowed are:
        // add margin
        // reduce position size
        assert!(
            action == constants::action_add_margin() || 
            (
                current_position_side == initial_position_side && 
                current_position_size < initial_position_size
            ),
            errors::health_check_failed(2)
        );

        // Case 2.1: Invariant maintenance health post action improves or is greater than ZERO unless 
        // the action is Liquidate/ADL and the account is maker
        assert!(
            (is_maker && (action == constants::action_liquidate() || action == constants::action_deleverage())) || 
            signed_number::gt_uint(maintenance_health, 0) || 
            signed_number::gt(maintenance_health, maintenance_health_before_action),
            errors::health_check_failed(5)
        );

        // Case 3: If Account value - Maintenance Margin required < 0, only actions allowed are:
        // Liquidation/ADL trades for maker
        // Adding margin
        assert!(
            signed_number::gte_uint(maintenance_health, 0) ||  
            action == constants::action_add_margin() ||
            ((action == constants::action_liquidate() ||  action == constants::action_deleverage()) && is_maker),
            errors::health_check_failed(3)
        );

        // Case 4: If account value < 0, only actions allowed are:
        // margin deposit
        // liquidation/adl for maker
        assert!(
            signed_number::gte_uint(account_value, 0) || 
            action == constants::action_add_margin() || 
            ((action == constants::action_liquidate() ||  action == constants::action_deleverage()) && is_maker), 
            errors::health_check_failed(4)
        );

    }

    /// Returns the withdrawable amount of assets user has
    ///
    /// Parameters:
    /// - ids: Immutable reference to Internal Data Store
    /// - account: Address of the account
    /// - asset_name: Name of the asset USDC | ETH | BTC etc.. (TODO: For now it is unused need to know how it will be used down the line)
    public fun get_withdrawable_assets(ids: &InternalDataStore, account:address, asset_name: vector<u8>): u64 {

        // Get list of all perpetuals
        let perpetual_table = data_store::get_immutable_perpetual_table_from_ids(ids);
        // Get list of all supported assets
        let assets_table = data_store::get_immutable_assets_table_from_ids(ids);

        let account_state = data_store::get_immutable_account_from_ids(ids, account);

        let current_positions = account::get_positions_vector(account_state, constants::empty_string());
        let current_assets = account::get_assets_vector(account_state, constants::empty_string());

        // calculate the account value
        let account_value = account::get_account_value(&current_assets, &current_positions, perpetual_table, assets_table);

        // calculate the initial margin required
        let initial_margin_required = account::get_total_margin_required(&current_positions, perpetual_table, constants::imr_threshold());

        let initial_margin_available = signed_number::sub_uint(account_value, initial_margin_required);

        let asset_quantity = account::get_asset_quantity(&current_assets, asset_name);

        let asset_state = data_store::get_asset(ids, string::utf8(asset_name));
        let (_, _, _, _, price, _,) = bank::asset_values(*asset_state);

        // Max ( Min (initialMarginAvailable, Asset Quantity), 0)
        return ( if (signed_number::gt_uint(initial_margin_available, 0)) { 
            u64::min(
                utils::base_div( signed_number::value(initial_margin_available), price ),
                asset_quantity 
            )  
        } else { 0 } as u64 )
    }


    /// Calculate and returns the portion of liquidation's premium that should
    /// go to the liquidator and insurance pool
    /// 
    /// Parameters:
    /// - is_long: The direction of the position SHORT or LONG
    /// - liq_purchase_price: The discounted price at which liquidator is supposed to buy the position
    /// - mark_price: Market/oracle price
    /// - liquidation_quantity: The amount of position/size being liquidated
    /// - is_position_bankrupt: True if the position being liquidated is bankrupt
    /// - insurance_pool_premium_ratio: The percentage or premium (liquidation) that goes to insurance pool
    /// 
    /// Returns
    /// - u64: The liquidator's part of the premium
    /// - u64: The insurance pool's part of the premium
    public fun calculate_liquidation_premium_portions(
        is_long: bool,
        liq_purchase_price: u64,
        mark_price: u64, 
        liquidation_quantity: u64,
        is_position_bankrupt: bool, 
        insurance_pool_premium_ratio: u64
    ): (u64, u64) {
        
        // if the position is bankrupt, there is not premium
        let (liq_premium_portion, insurance_pool_portion) = if(is_position_bankrupt){
            (0, 0)
        } else {
            // if standard liquidation, the premium is (mark price - discounted liquidation price)
            let total_premium = utils::base_mul(
                if(is_long){ mark_price - liq_purchase_price }
                   else { liq_purchase_price  - mark_price },
                   liquidation_quantity
                );

            // insurance pool portion = total premium * insurance pool ratio 
            let insurance_pool_portion = utils::base_mul(total_premium, insurance_pool_premium_ratio);

            // liquidator's portion =  total premium - insurance pool portion
            let liquidator_portion = total_premium - insurance_pool_portion;

            (liquidator_portion, insurance_pool_portion)
        };

        (liq_premium_portion, insurance_pool_portion)
    }

    /// Calculates the pnl
    /// 
    /// Parameters:
    /// - quantity: The quantity traded
    /// - execution_price: The price at which trade was executed
    /// - entry_price: The price at which position was opened
    /// - is_long: The position direction
    /// 
    /// Returns:
    /// Number: A signed number indicating the Pnl
    public fun calculate_pnl(
        quantity: u64,
        execution_price: u64,
        entry_price: u64,
        is_long: bool
    ): Number {
        
        // ((execution_price - entry_price) * quantity) * side (+1 for long -1 for short)
        let pnl = signed_number::mul_uint(
            signed_number::sub_uint(signed_number::from(execution_price, true), entry_price),
            quantity
        );

        pnl = if (is_long) { pnl } else { signed_number::negate(pnl) };

        pnl
    }

    // Calculates the effective leverage of a position
    // Deprecated function
    // @Dev the method can not be removed as we have contracts already live on production. 
    // Removing the method will break the upgrade compatibility with the live contracts.
    public fun calculate_effective_leverage(_: bool, _: u64, _: u64, _: u64, _: u64): u64 {
        abort errors::deprecated_function()
    }


    //===============================================================//
    //                        Private Methods                        //
    //===============================================================//

    /// Update accounts's position size, side and average entry price
    /// based on this trade size, direction and price and computes the pnl realized
    fun update_position(
        initial_position_side: bool,
        initial_position_size: u64,
        initial_position_average_entry_price: u64,
        is_long: bool,
        fill_quantity: u64,
        fill_price: u64,
        ): (bool, u64, u64, Number) {
        
        let current_position_side = initial_position_side;
        let current_position_average_entry_price = initial_position_average_entry_price;
        let current_position_size;
        let pnl = signed_number::new();

        // user's current position and current trade is of same direction
        if(initial_position_side == is_long){
            // compute new size
            current_position_size = initial_position_size + fill_quantity;

            // compute new average entry price
            current_position_average_entry_price =
            ((((initial_position_average_entry_price as u128) * (initial_position_size as u128)) + 
            ((fill_price as u128) * (fill_quantity as u128))) / (current_position_size as u128) as u64);

            
        } else {
            // if user's existing position and incoming order are of opposite direction
            if(initial_position_size >= fill_quantity ) { 
                current_position_size = initial_position_size - fill_quantity; 
                pnl = calculate_pnl(
                    fill_quantity,
                    fill_price,
                    initial_position_average_entry_price,
                    initial_position_side
                );
                }
            else {

                pnl = calculate_pnl(
                    initial_position_size,
                    fill_price,
                    initial_position_average_entry_price,
                    initial_position_side
                );

                current_position_size  = fill_quantity - initial_position_size;
                current_position_average_entry_price = fill_price;
                current_position_side = is_long;

            };
        };

        (current_position_side, current_position_size, current_position_average_entry_price, pnl)

    }


    /// Computes and deducts the fee required for the trade
    fun settle_fee(
        assets_table: & Table<String, Asset>,
        perpetual_details: &Perpetual,
        account_details: &Account,
        assets: &mut vector<DepositedAsset>,
        fill_quantity: u64,
        fill_price: u64,
        is_maker: bool,
        action: u8,
    ): (u64, u64, String) {

        let fee = 0;
        let fee_in_selected_fee_asset = 0;
        // get the fee asset of the account
        let fee_asset = account::get_fee_asset(account_details);

        // if a normal trade is being performed compute and subtract the fee amount to be charged from user's assets
        if(action == constants::action_trade()){
            let trade_value = utils::base_mul(fill_price, fill_quantity);
            fee = compute_trade_fee(account_details, perpetual_details, trade_value, is_maker);
            fee_in_selected_fee_asset = fee;

            // if fee asset is set and fee to be paid is non-zero
            // find out the amount of fee to be paid in selected fee asset
            if(fee > 0 && !utils::is_empty_string(fee_asset)){
                fee_in_selected_fee_asset = bank::get_asset_with_provided_usd_value(assets_table, fee_asset, fee);
            };
        
            // if fee is positive, deduct fee from user assets
            if (fee_in_selected_fee_asset > 0) {
                account::sub_margin_from_asset_vector( assets, fee_in_selected_fee_asset, fee_asset);
            };
        };

        // if the fee asset selected by user is empty, default fee asset to USDC
        if(utils::is_empty_string(fee_asset)){
            fee_asset = constants::usdc_token_symbol();
        };

        (fee, fee_in_selected_fee_asset, fee_asset) 

    }

    /// Settles the computed pnl by either adding it to the user assets or deducting from it
    /// If the user assets are not enough to cover the negative pnl computes the bad debt and returns
    /// it.
    fun settle_pnl(
        assets_table: & Table<String, Asset>,
        assets: &mut vector<DepositedAsset>,
        initial_position_margin: u64,
        pnl: Number, 
        pending_funding_payment: u64,
        is_maker: bool,
        is_isolated: bool,
        action: u8,
        ): (u64, u64, u64){

        let pnl_amount = signed_number::value(pnl);
        let remaining_pending_funding_payment = pending_funding_payment;
        let bad_debt:u64 = 0;

        // This will be zero for cross position as all Assets locked in user Account are being used to collat
        // the cross position
        let margin_remaining_in_position = initial_position_margin;

        // if the account has any pending funding payment
        if (pending_funding_payment > 0) {
            // if the pnl is positive, subtract the pending funding payment from the pnl amount
            if(signed_number::gte_uint(pnl, 0)) {

                if(pnl_amount >= pending_funding_payment) {
                    pnl_amount = pnl_amount - pending_funding_payment;
                    remaining_pending_funding_payment = 0;
                } else {
                    remaining_pending_funding_payment = pending_funding_payment - pnl_amount;
                    pnl_amount = 0;
                };
            } else { // if the pnl is negative, add the pending funding payment to the pnl amount
                pnl_amount = pnl_amount + pending_funding_payment;
                remaining_pending_funding_payment = 0;
            };
        };

        // if the pnl is positive add to user assets
        if(signed_number::gte_uint(pnl, 0)){
            // for an ADL, the maker does not get any positive Pnl
            if(action != constants::action_deleverage() || !is_maker){
                if(is_isolated){
                    margin_remaining_in_position = margin_remaining_in_position + pnl_amount;
                } else {
                    account::add_margin_to_asset_vector(
                        assets, 
                        pnl_amount, 
                        constants::empty_string()
                    );
                };
            }
        } else { // if the pnl is negative            
            
            // if an isolated position, then reduce the isolated position margin by the loss (-pnl)
            if(is_isolated){                
                // if the negative PNL exceeds the margin locked in the user isolated position take away all the margin
                // This can happen in a bankrupt liquidation. The liquidator will put up the loss
                (bad_debt, margin_remaining_in_position) = if (initial_position_margin < pnl_amount) { 
                    (
                        pnl_amount - initial_position_margin, 
                        0
                    ) 
                } else { 
                    (   0,
                        initial_position_margin - pnl_amount
                    ) 
                };

            } else {
                // for cross first get the value of the account assets
                let account_balance = account::get_total_effective_balance(
                    assets,
                    assets_table
                );

                if (account_balance < pnl_amount) { 
                    bad_debt = pnl_amount - account_balance;
                };

                // for cross subtract pnl from  account assets
                account::sub_margin_from_asset_vector(
                    assets, 
                    if (bad_debt == 0) {pnl_amount} else { account_balance }, 
                    constants::empty_string()
                );

            };

        };

        (margin_remaining_in_position, remaining_pending_funding_payment, bad_debt)
    }


     /// Settles the pending funding payment of the liquidatee (maker) during liquidation trade. 
     /// If the user does not have enough balance, the pending funding payment will
     /// be added to bad debt else user's balance will be reduced by pending funding payment amount
    fun settle_liquidatee_pending_funding_payment(
        assets_table: & Table<String, Asset>,
        assets: &mut vector<DepositedAsset>,
        pending_funding_payment: u64,
        fill_quantity: u64,
        position_size: u64,
        margin_remaining_in_position: u64,
        bad_debt: u64,
        is_isolated: bool,
        is_maker: bool,
        action: u8
        ): (u64, u64, u64){

        if(!is_maker || pending_funding_payment == 0 || action != constants::action_liquidate()){
            (margin_remaining_in_position, pending_funding_payment, bad_debt)
        } else { // if the 
            
            // compute the pending funding payment amount that will be settled by 
            // liquidator depending on how much position is being liquidated
            let pending_funding_payment_being_settled = utils::mul_div_uint(pending_funding_payment, fill_quantity, position_size);

            // this is the remaining pending funding payment to be settled
            pending_funding_payment = pending_funding_payment - pending_funding_payment_being_settled;

            if(is_isolated){

                if(margin_remaining_in_position >= pending_funding_payment_being_settled){
                    margin_remaining_in_position = margin_remaining_in_position - pending_funding_payment_being_settled;
                } else {
                    bad_debt = bad_debt + pending_funding_payment_being_settled - margin_remaining_in_position;
                    margin_remaining_in_position = 0;
                }

            } else {
                // for cross first get the value of the account assets
                let account_balance = account::get_total_effective_balance(
                    assets,
                    assets_table
                );

                if (account_balance < pending_funding_payment_being_settled) { 
                    bad_debt = bad_debt + pending_funding_payment_being_settled - account_balance;

                    account::sub_margin_from_asset_vector(
                        assets, 
                        account_balance, 
                        constants::empty_string()
                    );
                } else {
                    account::sub_margin_from_asset_vector(
                        assets, 
                        pending_funding_payment_being_settled, 
                        constants::empty_string()
                    );
                }
            };

            (margin_remaining_in_position, pending_funding_payment, bad_debt)
        }
    }

    /// Settles the margin for the isolated position
    fun settle_margin(
        account_assets: &mut vector<DepositedAsset>,
        margin_remaining_in_position: u64,
        current_position_size: u64,
        current_position_average_entry_price: u64,
        bad_debt: u64,
        leverage: u64,
        is_maker: bool,
        is_isolated: bool,
        action: u8
        ): (u64, u64) {
        
        let margin_needed_for_position = margin_remaining_in_position;

        // if the position type is isolated, compute the margin required for the current position
        // This amount will be moved into the isolated position or out of it from the assets of the account
        if(is_isolated){ 
            
            // this is the margin required for the isolated position
            // margin required for isolated position = (size * average entry price) / leverage
            margin_needed_for_position = utils::mul_div_uint(current_position_size, current_position_average_entry_price, leverage);

            let difference = signed_number::from_subtraction(margin_needed_for_position, margin_remaining_in_position);
            let difference_amount = signed_number::value(difference);

            // if the margin required for new position is more than the margin already in position
            // Move required margin from user assets
            if (signed_number::gt_uint(difference, 0)){

                if(action != constants::action_liquidate() || !is_maker){
                    // Reduce margin required from cross account
                    account::sub_margin_from_asset_vector(account_assets, difference_amount, constants::empty_string());
                } else {
                    bad_debt = bad_debt + difference_amount;
                }             
            } else {                
                // Add the margin back to cross account
                account::add_margin_to_asset_vector(account_assets, difference_amount, constants::empty_string());            
            }
        };

        (margin_needed_for_position, bad_debt)

    }

    /// Settles the premium or debt 
    fun premium_or_debt_settlement(
        assets: &mut vector<DepositedAsset>,
        premium_or_debt: Option<Number>,
        is_maker:bool,
        action: u8){

        // if a liquidation is being performed handle liquidation premium or debt
        if(action == constants::action_liquidate() && !is_maker){
            
            // revert if premium/debt is not provided
            assert!(option::is_some<Number>(&premium_or_debt), errors::missing_optional_param());

            let number = option::extract(&mut premium_or_debt);
            let value = signed_number::value(number);
            // if premium/debit value is zero, do nothing
            if(value > 0) {
                // if positive, the liquidator is supposed to receive the premium portion
                if(signed_number::sign(number)){
                    account::add_margin_to_asset_vector(assets, value, constants::empty_string());
                } else { // else pay the debit. This happens during bankrupt liquidations
                    account::sub_margin_from_asset_vector(assets, value, constants::empty_string());
                }
            };

        };

    }


     /// Settle the gas charges
    fun settle_gas_charges(
        gas_charges: u64,
        assets: &mut vector<DepositedAsset>,
        account_details: &Account,
        is_first_fill: Option<bool>,
        is_maker: bool,
        action: u8,
    ): u64 {
        
        let gas_fee = 0;

        //  Gas fee settlement
        if(action == constants::action_trade() && !is_maker){

            assert!(option::is_some<bool>(&is_first_fill), errors::missing_optional_param());
            let is_first_fill = option::extract(&mut is_first_fill);
            
            // if its first order fill and the account is not an institution
            if(is_first_fill && !account::is_institution(account_details)){

                gas_fee = gas_charges;

                account::sub_margin_from_asset_vector(
                assets, 
                gas_fee, 
                constants::empty_string());

            };

        };

        return gas_fee

    }
}
