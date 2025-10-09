/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::account {
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use std::option::{Self, Option};
    use std::vector;
    use std::u64;


    use bluefin_cross_margin_dex::signed_number::{Self, Number};
    use bluefin_cross_margin_dex::bank::{Self, Asset};
    use bluefin_cross_margin_dex::perpetual::{Self, Perpetual, FundingRate};
    use bluefin_cross_margin_dex::constants;
    use bluefin_cross_margin_dex::errors;
    use bluefin_cross_margin_dex::utils;

    // friend modules
    friend bluefin_cross_margin_dex::data_store;
    friend bluefin_cross_margin_dex::exchange;
    friend bluefin_cross_margin_dex::margining_engine;

    #[test_only]
    friend bluefin_cross_margin_dex::test_utils;
    #[test_only]
    friend bluefin_cross_margin_dex::test_liquidations;

    //===========================================================//
    //                           Structs                         //
    //===========================================================//

     /// For storing fee information of an account
    struct TradeFee has store, copy, drop {
        // maker side fee percentage
        maker: u64,
        // taker side fee percentage
        taker: u64,
        // True if the above fee percentages are to be applied, False will revert
        // to perpetual default fees
        applied: bool
    }

    /// For storing an account's information in the system
    struct Account has store {
        // Address of the Account. This is the owner of the account.
        address: address,

        // Addresses of users/wallets that are authorized to perform
        // actions on the account's behalf ( everything excluding withdrawal)
        authorized: vector<address>,

        // the list of assets currently collateralizing the user cross position.
        assets: vector<DepositedAsset>,

        // list of cross positions the account has
        cross_positions: vector<Position>,

        // list of isolated positions
        isolated_positions: vector<Position>,

        // trading fees to be applied on the user
        trading_fees: TradeFee,

        is_institution: bool,

        // symbol of the asset to be used for payment of trade fees
        fee_asset: String
    }

    /// A single account position
    struct Position has copy, drop, store {
        // The address of the perpetual to which the position belongs
        perpetual: String,
        // The size of the current open position
        size: u64,
        // average entry price for current open position
        average_entry_price: u64,
        // True if long, false otherwise
        is_long: bool,
        // Leverage being used for the position. This will be zero for cross
        leverage: u64,
        // The amount of margin locked in the position.
        // for cross positions this is zero.
        // for isolated the margin represents the amount of USDC
        margin: u64,
        // flag indicating if the position is isolated or not
        is_isolated: bool,
        // The last funding rate that got applied to the position
        funding: FundingRate,
        // Any pending funding payment that is needed to be paid
        pending_funding_payment: u64,
    }

    /// Represents the deposited asset in account
    struct DepositedAsset has store, copy, drop {
        // Name/symbol of the asset
        name: String,
        // The quantity of the asset deposited
        quantity: u64
    }


    struct FundingApplied has store, copy, drop {
        position: Position,
        assets: vector<DepositedAsset>,
        funding_rate: FundingRate,
        funding_amount: Number
    }

    //===========================================================//
    //                      Friend Functions                     //
    //===========================================================//

    /// Allows caller to create a account object with provided address
    public (friend) fun initialize(address: address): Account {
        return Account {
            address,
            authorized: vector::empty<address>(),
            assets: vector::empty<DepositedAsset>(),
            cross_positions: vector::empty<Position>(),
            isolated_positions: vector::empty<Position>(),
            trading_fees: TradeFee { maker: 0, taker: 0, applied: false },
            is_institution: false,
            fee_asset: string::utf8(b"") // defaults to empty
        }
    }

    /// Creates a position object from provided attributes and returns it
    public (friend) fun create_position(perpetual:String, size: u64, average_entry_price: u64, leverage:u64, margin: u64, is_long: bool, is_isolated:bool):Position {
        return Position {
            perpetual,
            size,
            average_entry_price,
            is_long,
            leverage,
            margin,
            is_isolated,
            funding: perpetual::create_funding_rate(0, 0, true),
            pending_funding_payment: 0
        }
    }

    /// Creates a position with provided perp address, having zero size and average entry price
    public (friend) fun create_empty_position(perpetual:String, is_isolated: bool): Position {
        return create_position(perpetual, 0, 0, 0, 0, true, is_isolated)
    }


    /// Adds provided margin to account balance
    public (friend) fun add_margin(account: &mut Account, asset_name: String, amount: u64) {
        // get number of assets
        let count = vector::length(&account.assets);
        let i = 0;
        let added = false;
        while(i < count && !added){
            let deposited_asset = vector::borrow_mut(&mut account.assets, i);
            if(deposited_asset.name == asset_name){
                deposited_asset.quantity = deposited_asset.quantity + amount;
                added = true;
            };
            i = i+1;
        };

        // this implies, the user has zero quantity of the provided asset, we need to create its entry in asset vector
        if(!added){
            vector::push_back(&mut account.assets, DepositedAsset{name: asset_name, quantity: amount});
        }
    }

    /// Reduces account margin by provided amount.
    ///
    /// Parameters
    /// - assets: The current assets user have
    /// - amount: The amount to be subtracted.
    /// - asset: If a value other than empty string is provided then the provided amount is subtracted from that specific asset
    public (friend) fun sub_margin_from_asset_vector(assets: &mut vector<DepositedAsset>, amount: u64, asset_symbol: String) {
        assert!(vector::length(assets) > 0, errors::insufficient_margin());

        // if fee asset is provided, it implies we are subtracting fee for the user
        if(!utils::is_empty_string(asset_symbol)){
            let count = vector::length(assets);
            let i = 0;
            let amount_subbed = false;
            while(i < count){
                let user_asset = vector::borrow_mut(assets, i);
                if(user_asset.name == asset_symbol){
                    // revert if the user asset quantity is < the amount to be subtracted
                    assert!(user_asset.quantity >= amount, errors::insufficient_margin());
                    user_asset.quantity = user_asset.quantity - amount;
                    amount_subbed = true;
                    break
                };

                i = i + 1;
            }; // end of for loop

            // if the user does not have the asset to pay for fee, revert
            assert!(amount_subbed, errors::insufficient_margin());

        } else {

            // TODO: Add multi asset logic. This assumes that asset at 0th index is USDC/USDT
            let asset = vector::borrow_mut(assets, 0);
            // revert if not enough amount
            assert!(asset.quantity >= amount, errors::insufficient_margin());
            asset.quantity = asset.quantity - amount;
        };



    }

    /// Adds the provided amount to account Assets
    ///
    /// Parameters
    /// - assets: user current assets
    /// - amount: The amount of assets to be deposited
    /// - asset_symbol: Name of the asset to which provided amount will be deposited
    public (friend) fun add_margin_to_asset_vector(assets: &mut vector<DepositedAsset>, amount: u64, asset_symbol: String) {

        // if asset symbol is non-empty then add provided amount to the provided asset
        if(!utils::is_empty_string(asset_symbol)){
            let count = vector::length(assets);
            let i = 0;
            let amount_added = false;
            while(i < count && !amount_added){
                let user_asset = vector::borrow_mut(assets, i);
                if(user_asset.name == asset_symbol){
                    user_asset.quantity = user_asset.quantity + amount;
                    amount_added = true;
                };
                i = i + 1;
            };

            // if asset does not exist in user asset vector, create it.
            if (!amount_added){
                vector::push_back(assets, DepositedAsset{name: asset_symbol, quantity: amount});
            };

        } else {
            // The asset on first index will be USDC
            let asset = vector::borrow_mut(assets, 0);
            asset.quantity = asset.quantity + amount;

        };
    }

    /// Returns the vector of current open position of the account.
    /// If the perpetual address is provided, then returns the isolated position of provided perpetual
    /// Else returns the cross position vector
    public (friend) fun get_positions_vector(account: &Account, perpetual: String): vector<Position> {
        if(perpetual == constants::empty_string()){
            account.cross_positions
        } else {
            let user_position = create_empty_position(perpetual, true);

            let (open, index) = has_open_position(&account.isolated_positions, perpetual);

            if(open){
                user_position = *vector::borrow(&account.isolated_positions, index);
            };

            let isolated_positions = vector::empty<Position>();
            vector::push_back(&mut isolated_positions, user_position);

            isolated_positions
        }
    }

    /// Updates account authorized account list based on the provided user/wallet and authorization status
    public (friend) fun set_authorized_user(account: &mut Account, user:address, authorized:bool){

        // if authorized
        if(authorized){

            // add to authorized vector only if the user is not already authorized
            let (exists,_) = vector::index_of(&account.authorized, &user);
            if(exists == false){
                vector::push_back(&mut account.authorized, user);
            }

        }
        // if un-authorized
        else {

            // remove user/user from authorized vector if exists
            let (exists, index) = vector::index_of(&account.authorized, &user);
            if(exists){
                vector::remove(&mut account.authorized, index);
            }
        };
    }

    /// Returns vector of current user assets. If the perpetual address is provided,
    /// then returns the asset/margin locked in provided perpetual position
    public (friend) fun get_assets_vector(account: &Account, perpetual: String): vector<DepositedAsset>{

        return if(perpetual == constants::empty_string()) {
            account.assets
        } else {
            let assets = vector::empty<DepositedAsset>();

            let margin = 0;
            let (open, index) = has_open_position(&account.isolated_positions, perpetual);

            if(open){
                margin = vector::borrow(&account.isolated_positions, index).margin;
            };

            vector::push_back(&mut assets, DepositedAsset {name: constants::usdc_token_symbol(), quantity: margin});
            return assets
        }
    }



    /// Returns the position of provided perpetual address from the vector of positions.
    /// If the user does not have a position for provided perp, the method creates an empty position
    /// and returns it.
    public (friend) fun get_mutable_position_for_perpetual(positions: &mut vector<Position>, perpetual: String, isolated: bool): (&mut Position, u64){

          let positions_count = vector::length(positions);
          let i = 0;

          // iterate through vector positions
          while(i < positions_count){
            // if position exists return it;
            let position = vector::borrow_mut(positions, i);
            if(position.perpetual == perpetual){
                return ( position, i)
            };
            i = i + 1;
          };

          // if we are here, it implies user has no position for provided perpetual. lets create it and return
          vector::push_back(positions, create_empty_position(perpetual, isolated));
          return (vector::borrow_mut(positions, positions_count), positions_count)

    }

    // Updates the values of position to the ones provided
    public (friend) fun update_position_values(position: &mut Position, size: u64, average_entry_price: u64, margin: u64, leverage: u64, is_long: bool, pending_funding_payment: u64){

        // for cross positions leverage and margin are always zero
        if(!position.is_isolated){
            leverage = 0;
            margin = 0;
        };

        position.size = size;
        position.average_entry_price = average_entry_price;
        position.margin = margin;
        position.is_long = is_long;
        position.leverage = leverage;
        position.pending_funding_payment = pending_funding_payment;
    }

    // Updates the values of position to the ones provided
    public (friend) fun update_position_values_including_funding_rate(
        position: &mut Position,
        size: u64,
        average_entry_price: u64,
        margin: u64,
        leverage: u64,
        is_long: bool,
        pending_funding_payment: u64,
        funding_rate: FundingRate,
    ){
        update_position_values(position, size, average_entry_price, margin, leverage, is_long, pending_funding_payment);

        position.funding = funding_rate;
    }


    /// Returns the total effective balance of the account
    /// for all assets sum of (quantity * price * weight)
    ///
    /// Parameters:
    /// - deposited_assets: The list of current assets that account has
    /// - supported_assets_table: The map of Asset Symbol to Asset stored in IDS
    public (friend) fun get_total_effective_balance(deposited_assets: &vector<DepositedAsset>, supported_assets_table: &Table<String, Asset>): u64 {

        let count = vector::length(deposited_assets);
        let i = 0;
        let total_effective_balance  = 0;
        while(i < count){
            let deposited_asset = vector::borrow(deposited_assets, i);
            let asset_details = *table::borrow(supported_assets_table, deposited_asset.name);
            let (_, _, _, weight, price, accepted_as_collateral) = bank::asset_values(asset_details);


            if(accepted_as_collateral){
                // quantity * price * weight
                total_effective_balance = total_effective_balance + asset_to_usd(deposited_asset.quantity, price, weight);
            };

            i = i + 1;
        };

        total_effective_balance
    }

    /// Returns the cumulative unrealized pnl the user has for all his positions
    ///
    /// Parameters:
    /// - positions: The immutable reference to user positions (will contain just one entry for isolated)
    /// - perpetuals_table: Immutable reference to the perpetuals table containing all perps config
    public (friend) fun get_unrealized_pnl(positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>): Number {

        let count = vector::length(positions);
        let i = 0;
        let total_unrealized_pnl = signed_number::new();
        while(i < count){

            let position = vector::borrow(positions, i);

            let position_pnl = compute_position_pnl(perpetuals_table, position);

            total_unrealized_pnl = signed_number::add(total_unrealized_pnl, position_pnl);

            i = i + 1;
        };

        total_unrealized_pnl

    }


    /// Returns the cumulative pending funding payment for all positions
    ///
    /// Parameters:
    /// - positions: The immutable reference to user positions (will contain just one entry for isolated)
    public (friend) fun get_pending_funding_payment(positions: &vector<Position>): u64 {

        let count = vector::length(positions);
        let i = 0;
        let total_pending_funding_payment = 0;
        while(i < count){

            let position = vector::borrow(positions, i);

            total_pending_funding_payment = total_pending_funding_payment + position.pending_funding_payment;

            i = i + 1;
        };

        total_pending_funding_payment

    }


    /// Returns the account value based on the provided assets and positions
    ///
    /// Parameters:
    /// - deposited_assets: The list of current assets that account has
    /// - user_positions: The immutable reference to user positions (will contain just one entry for isolated)
    /// - perpetuals_table: Immutable reference to the perpetuals table containing all perps config
    /// - supported_assets_table: The map of Asset Symbol to Asset stored in IDS
    public (friend) fun get_account_value(deposited_assets: &vector<DepositedAsset>, user_positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>, supported_assets_table: &Table<String, Asset>): Number{

        let total_effective_balance = get_total_effective_balance(deposited_assets, supported_assets_table);
        let total_unrealized_pnl = get_unrealized_pnl(user_positions, perpetuals_table);
        let total_pending_funding_payment = get_pending_funding_payment(user_positions);

        // account value = (total_effective_balance + total_unrealized_pnl) - pending funding payment
        signed_number::sub_uint(
            signed_number::add_uint(total_unrealized_pnl, total_effective_balance),
            total_pending_funding_payment
        )
    }

    /// Returns the max withdrawable amount based on user's current assets, positions and Unrealized Pnl
    ///
    /// Parameters:
    /// - deposited_assets: The list of current assets that account has
    /// - user_positions: The immutable reference to user positions (will contain just one entry for isolated)
    /// - perpetuals_table: Immutable reference to the perpetuals table containing all perps config
    /// - supported_assets_table: The map of Asset Symbol to Asset stored in IDS
    public (friend) fun get_max_withdrawable_amount(deposited_assets: &vector<DepositedAsset>, user_positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>, supported_assets_table: &Table<String, Asset>): u64 {

        let total_effective_balance = get_total_effective_balance(deposited_assets, supported_assets_table);
        let total_absolute_loss = signed_number::negative_value(get_unrealized_pnl(user_positions, perpetuals_table));
        let total_pending_funding_payment = get_pending_funding_payment(user_positions);
        let initial_margin_required = get_total_margin_required(user_positions, perpetuals_table, constants::imr_threshold());


        // max withdrawable amount = Max(
        //     total_effective_balance - total_absolute_loss - pending funding payment - initial margin required,
        //     0
        // )
        signed_number::positive_value(
            signed_number::sub_uint(
                signed_number::sub_uint(
                    signed_number::sub_uint(
                        signed_number::from(total_effective_balance, true),
                        total_absolute_loss
                    ),
                total_pending_funding_payment
                ),
            initial_margin_required
            )
        )

    }

    /// Returns the total maintenance or initial margin required to maintain the positions or open the positions
    ///
    /// Parameters:
    /// - user_positions: The immutable reference to user positions (will contain just one entry for isolated)
    /// - perpetuals_table: Immutable reference to the perpetuals table containing all perps config
    /// - threshold: imr or mmr
    public (friend) fun get_total_margin_required(user_positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>, threshold: u8): u64 {

        let count = vector::length(user_positions);
        let i = 0;
        let total_margin_required: u64 = 0;


        while(i < count){

            let position = vector::borrow(user_positions, i);

            let perpetual = table::borrow(perpetuals_table, position.perpetual);

            // For isolated: position size * entry price
            // For cross: size * oracle price
            let price = if(position.is_isolated) { position.average_entry_price } else { perpetual::get_oracle_price(perpetual) };

            let margin_ratio = if (threshold == constants::mmr_threshold()) {
                perpetual::get_mmr(perpetual)
            } else {
                perpetual::get_imr(perpetual)
            };

            let position_value = utils::base_mul(position.size,  price);

            total_margin_required = total_margin_required + utils::base_mul(position_value, margin_ratio);

            i = i + 1;
        };

        total_margin_required

    }


    /// Updates the account assets and positions to the one provided
    ///
    /// Parameters:
    /// - account: Mutable reference to the account to be updated
    /// - assets: the vector of new assets to be stored
    /// - positions: the vector of new positions to be stored
    /// - position_index: The index of the position that got updated. This will be zero if isolated position got updated
    /// - is_isolated: true if the update is being made due to an action performed on isolated position
    public (friend) fun update_account(account: &mut Account, assets: &vector<DepositedAsset>, positions: &vector<Position>, position_index: u64, is_isolated: bool){

        let position = *vector::borrow(positions, position_index);

        // if updating isolated position
        if(is_isolated){

            let (open, index) = has_open_position(&account.isolated_positions, position.perpetual);

            // if user does not already have a position for the perpetual, create one
            if(!open){
                if(position.size > 0){
                    vector::push_back(&mut account.isolated_positions, position);
                }
            } else {
                // if the new position size is zero, then remove the position from the isolated positions map
                if (position.size == 0) {
                    vector::remove(&mut account.isolated_positions, index);
                } else {
                    // position is non zero, update the existing position values
                    let isolated_position = vector::borrow_mut(&mut account.isolated_positions, index);
                    isolated_position.is_long = position.is_long;
                    isolated_position.size = position.size;
                    isolated_position.average_entry_price = position.average_entry_price;
                    isolated_position.margin = position.margin;
                    isolated_position.leverage = position.leverage;
                    isolated_position.pending_funding_payment = position.pending_funding_payment;
                    isolated_position.funding = position.funding;
                }
            };
        } else { // if updating cross position
            account.cross_positions = *positions;
            // if the new position size is zero, remove it from vector of cross positions
            if (position.size == 0) {
                vector::remove(&mut account.cross_positions, position_index);
            };
        };

        account.assets = *assets;

    }

    /// Updates account assets to the provided ones
    public (friend) fun update_account_cross_assets(account: &mut Account, assets: vector<DepositedAsset>){
        account.assets = assets;
    }

    public (friend) fun update_account_cross_positions(account: &mut Account, positions: vector<Position>){
        account.cross_positions = positions;
    }


    // Returns the quantity of provided asset
    public (friend) fun get_asset_quantity(assets: &vector<DepositedAsset>, asset_name: vector<u8>): u64 {

        let count = vector::length(assets);
        let i = 0;
        let asset_name_string = string::utf8(asset_name);
        let quantity = 0;

        while(i < count){
            let deposited_asset = vector::borrow(assets, i);

            if (deposited_asset.name  == asset_name_string ) {
                quantity = deposited_asset.quantity;
                break
            };

            i = i + 1;
        };

        quantity
    }

    /// Applies funding rate to all the current open positions (cross and isolated) of the account
    public (friend) fun apply_funding_rate(account: &mut Account, perpetual_table: &Table<String, Perpetual>, market: Option<String>): vector<FundingApplied> {

        let funding_applied = apply_funding_rate_to_positions(account, perpetual_table, market, true);
        vector::append(&mut funding_applied, apply_funding_rate_to_positions(account, perpetual_table, market, false));

        funding_applied
    }

    /// Sets the provided fee tier on the account
    public (friend) fun set_fee_tier(account: &mut Account, maker: u64, taker: u64, applied: bool){
        account.trading_fees = TradeFee {
            maker,
            taker,
            applied
        };
    }

    /// Updates the account type
    public (friend) fun set_account_type(account: &mut Account, is_institution: bool){
        account.is_institution = is_institution;
    }


    // returns the position of provided perpetual
    public (friend) fun get_position(account: &Account, perpetual: String, isolated: bool): Position {

        let positions = if (isolated) { account.isolated_positions} else {
            account.cross_positions
        };

        let (open, index) = has_open_position(&positions, perpetual);


        if(open){
            *vector::borrow(&positions, index)
        } else {
            create_empty_position(perpetual, isolated)
        }
    }

    /// Sets the provided margin as the amount of assets
    /// @dev this assumes that the asset at 0th index is USDC/USDT
    public (friend) fun set_isolated_position_assets(assets: &mut vector<DepositedAsset>, margin: u64) {

        if (margin == 0){
            return
        };

        assert!(vector::length(assets) > 0, errors::insufficient_margin());

        let asset = vector::borrow_mut(assets, 0);
        asset.quantity = margin;

    }

    //===============================================================//
    //                         Public Methods                        //
    //===============================================================//


    public fun get_position_values(position: &Position): (String, u64, u64, bool, u64, u64, bool, u64) {

        (
            position.perpetual,
            position.size,
            position.average_entry_price,
            position.is_long,
            position.leverage,
            position.margin,
            position.is_isolated,
            position.pending_funding_payment
        )

    }

    public fun get_position_values_including_funding(position: &Position): (String, u64, u64, bool, u64, u64, bool, u64, FundingRate) {

        let (perpetual, size, average_entry_price, is_long, leverage, margin, is_isolated, pending_funding_payment) = get_position_values(position);
        let funding = position.funding;
        (
            perpetual,
            size,
            average_entry_price,
            is_long,
            leverage,
            margin,
            is_isolated,
            pending_funding_payment,
            funding

        )

    }

    public fun get_cross_positions(account: &Account): vector<Position> {
        return account.cross_positions
    }

    public fun get_isolated_positions(account: &Account): vector<Position> {
        return account.isolated_positions
    }

    public fun get_assets(account: &Account): vector<DepositedAsset> {
        return account.assets
    }

    public fun get_usdc_amount(account: &Account): u64 {
        if(vector::length(&account.assets) > 0){
            vector::borrow(&account.assets, 0).quantity
        } else {
            0
        }
    }

    public fun get_fee_asset(account: &Account): String {
        return account.fee_asset
    }

    // Returns true if the signer is the owner of the account or one of its authorized account
    public fun has_permission(account: &Account, signatory: address): bool {
        signatory == account.address || vector::contains(&account.authorized, &signatory)
    }

    /// Returns the user maker/taker fees
    public fun get_fees(account: &Account): (u64, u64, bool) {
        (
            account.trading_fees.maker,
            account.trading_fees.taker,
            account.trading_fees.applied,
        )
    }

    /// Returns the user trading fee struct
    public fun get_trading_fee(account: &Account): TradeFee {
        account.trading_fees
    }

    /// Returns true/false along with the index if the vector contains a position for provided perpetual
    public fun has_open_position(positions: &vector<Position>, perpetual: String): (bool, u64) {

        let i = 0;
        let count = vector::length(positions);

        while(i < count){
            let position = vector::borrow(positions, i);
            if(position.perpetual == perpetual){
                return (true, i)
            };
            i = i + 1;
        };

        (false, 0)
    }

    /// Returns the immutable position from provided position vector
    /// The method reverts if the user does not have a position open for provided perpetual
    public fun get_immutable_position_for_perpetual(positions: &vector<Position>, perpetual: String): (&Position){

          let positions_count = vector::length(positions);
          let i = 0;

          // iterate through vector positions
          while(i < positions_count){
            // if position exists return it;
            let position = vector::borrow(positions, i);
            if(position.perpetual == perpetual){
                return position
            };
            i = i + 1;
          };

          abort errors::position_does_not_exist()
    }

    /// Returns the position of provided perpetual symbol
    public fun get_account_position(account: &Account, perpetual: String, isolated: bool): (Position){

        let positions = if (isolated) {account.isolated_positions} else {account.cross_positions};

        let positions_count = vector::length(&positions);
        let i = 0;

          // iterate through vector positions
        while(i < positions_count){
            // if position exists return it;
            let position = vector::borrow(&positions, i);
            if(position.perpetual == perpetual){
                return *position
            };
            i = i + 1;
        };

        abort errors::position_does_not_exist()
    }


    /// Computes the requested health and returns it
    public fun get_account_value_and_health(
        account: &Account,
        perpetual:String,
        is_isolated: bool,
        perpetuals_table: &Table<String, Perpetual>,
        supported_assets_table: &Table<String, Asset>,
        threshold:u8,
        ): (Number,Number) {

        let fetch_for = if(is_isolated) { perpetual } else { constants::empty_string() };
        let current_positions = get_positions_vector(account, fetch_for);
        let current_assets = get_assets_vector(account, fetch_for);

        let account_value = get_account_value(&current_assets, &current_positions, perpetuals_table, supported_assets_table);

        let margin_required = get_total_margin_required(
            &current_positions, perpetuals_table, threshold);

        (account_value, signed_number::sub_uint(account_value, margin_required))
    }

    /// Returns true if the account is liquidateable
    public fun is_liquidateable(
        account: &Account,
        perpetual:String,
        is_isolated: bool,
        perpetuals_table: &Table<String, Perpetual>,
        supported_assets_table: &Table<String, Asset>
    ): bool {
        let (_, health) = get_account_value_and_health(
            account,
            perpetual,
            is_isolated,
            perpetuals_table,
            supported_assets_table,
            constants::mmr_threshold()
        );

        signed_number::lt_uint(health, 0)

    }


    /// Returns true if the account is bankrupt
    public fun is_bankrupt(
        account: &Account,
        perpetual:String,
        is_isolated: bool,
        perpetuals_table: &Table<String, Perpetual>,
        supported_assets_table: &Table<String, Asset>
    ): bool {

        let fetch_for = if(is_isolated) { perpetual } else { constants::empty_string() };
        let current_positions = get_positions_vector(account, fetch_for);
        let current_assets = get_assets_vector(account, fetch_for);

        let account_value = get_account_value(&current_assets, &current_positions, perpetuals_table, supported_assets_table);

        signed_number::lt_uint(account_value, 0)

    }

    /// Computes the bankruptcy and purchase price for user's position of provided perpetual
    public fun get_position_bankruptcy_and_purchase_price(
        account: &Account,
        perpetual:String,
        is_isolated: bool,
        perpetuals_table: &Table<String, Perpetual>,
        supported_assets_table: &Table<String, Asset>
        ): (u64, u64, u64, bool, bool) {

        let fetch_for = if(is_isolated) { perpetual } else { constants::empty_string() };
        let current_positions = get_positions_vector(account, fetch_for);
        let current_assets = get_assets_vector(account, fetch_for);

        let account_value = get_account_value(&current_assets, &current_positions, perpetuals_table, supported_assets_table);

        let perp_object = table::borrow(perpetuals_table, perpetual);
        let mark_price = perpetual::get_oracle_price(perp_object);
        let mmr = perpetual::get_mmr(perp_object);
        let tick_size = perpetual::get_tick_size(perp_object);


        let position = get_immutable_position_for_perpetual(&current_positions, perpetual);

        let (_, size, _,is_long,_,_,_, _) = get_position_values(position);

        // bankruptcyPrice = markPrice - (position Side * Account Value / position size )
        // = 100 - (+1 * -20/1)
        // = 100 +20
        // = 120

        // num1 = Account value / position size
        let num1 = signed_number::div_uint(account_value, size);

        // position side * num(Account value / position size)
        if(!is_long){
            num1 = signed_number::negate(num1);
        };

        // mark price - num(position Side * Account Value / position size)
        let price =
            signed_number::sub(
                signed_number::from(mark_price, true),
                num1
            );

        // cap the bankruptcy price at ZERO
        let bankruptcy_price = if(signed_number::gte_uint(price, 0)) { signed_number::value(price)} else { 0 };

        bankruptcy_price = utils::round_to_tick_size_based_on_direction(bankruptcy_price, tick_size, is_long);


        // for bankrupt positions, the liquidator buys at mark price
        let (liq_purchase_price, is_position_bankrupt) = if (
            (is_long && bankruptcy_price > mark_price) || (!is_long && bankruptcy_price < mark_price)){
            (mark_price, true)
        } else {

            // for non-bankrupt positions, liquidator buys position at liq purchase price
            let price = if(is_long) {
                u64::max(utils::base_mul(mark_price, constants::base_uint() - (mmr/2)), bankruptcy_price)
            } else {
                u64::min(utils::base_mul(mark_price, constants::base_uint() + (mmr/2)), bankruptcy_price)
            };

            // ensure the liquidator's price conforms to tick size
            // if liquiditor is going long, the liquiditor's price will be rounded up to the tick size
            // if liquiditor is going short, the liquiditor's price will be rounded down to the tick size
            price = utils::round_to_tick_size_based_on_direction(price, tick_size, is_long);

            (price, false)
        };

        (bankruptcy_price, liq_purchase_price, mark_price, is_position_bankrupt, signed_number::lt_uint(account_value, 0))


    }


    /// Returns true if the position of provided symbol has the biggest (>=) positive Pnl out of all positions
    public fun has_most_positive_pnl(positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>, perpetual: String): bool {

        if (vector::is_empty(positions)) {
                return false // No positions, so no highest PnL
        };

        let count = vector::length(positions);
        let i = 0;

        // symbol of the market/perpetual with most PNL
        let position_with_most_positive_pnl = string::utf8(b"");
        let most_pnl = signed_number::from(constants::max_value_u64(), false);

        let requested_perpetual_position_pnl     = signed_number::new();

        while(i < count){

            let position = vector::borrow(positions, i);

            let position_pnl = compute_position_pnl(perpetuals_table, position);

            if(signed_number::gt(position_pnl, most_pnl)){
                position_with_most_positive_pnl = position.perpetual;
                most_pnl =  position_pnl;
            };

            if(position.perpetual == perpetual) {
                requested_perpetual_position_pnl = position_pnl;
            };

            i = i+1;
        };


        if(position_with_most_positive_pnl == perpetual || signed_number::eq(requested_perpetual_position_pnl, most_pnl) ) { true } else { false }
    }

     /// Returns true if the position of provided symbol has the biggest (<=)negative Pnl out of all positions
    public fun has_most_negative_pnl(positions: &vector<Position>, perpetuals_table: &Table<String, Perpetual>, perpetual: String): bool {

        let count = vector::length(positions);
        let i = 0;

        // symbol of the market/perpetual with most PNL
        let position_with_most_negative_pnl = perpetual;
        let most_pnl = signed_number::from(constants::max_value_u64(), true);
        let requested_perpetual_position_pnl     = signed_number::new();

        while(i < count){

            let position = vector::borrow(positions, i);

            let position_pnl = compute_position_pnl(perpetuals_table, position);


            if(signed_number::lt(position_pnl,most_pnl)){
                position_with_most_negative_pnl = position.perpetual;
                most_pnl =  position_pnl;
            };

            if(position.perpetual == perpetual) {
                requested_perpetual_position_pnl = position_pnl;
            };

            i = i+1;
        };

        if(position_with_most_negative_pnl == perpetual || signed_number::eq(requested_perpetual_position_pnl, most_pnl) ) { true } else { false }
    }

    public fun is_institution(account: &Account): bool {
        account.is_institution
    }

    /// Computes the PNL of the provided position and returns it
    public fun compute_position_pnl(perpetuals_table: &Table<String, Perpetual>, position: &Position): Number {

        // get oracle price for the position's perpetual
        let perpetual = table::borrow(perpetuals_table, position.perpetual);
        let mark_price = perpetual::get_oracle_price(perpetual);

        // (mark price - entry price) * size
        let position_pnl = signed_number::mul_uint(
            signed_number::from_subtraction(mark_price, position.average_entry_price),
            position.size
            );

        // multiply by -1 if position is short
        position_pnl = if ( position.is_long ) { position_pnl } else { signed_number::negate(position_pnl)};

        position_pnl

    }

    /// Creates the Deposited Asset and returns it
    public fun create_deposited_asset(name: String, quantity: u64): DepositedAsset {
        DepositedAsset { name, quantity }
    }

    // Calculates the effective leverage of a position
    public fun calculate_effective_leverage(position: &Position, leverage: Option<u64>): u64 {
        // if position is isolated
        if(position.is_isolated){
            // if position has non zero size and margin compute effective leverage
           if(position.size > 0 && position.margin > 0 ) {
                utils::mul_div_uint(position.average_entry_price, position.size, position.margin - position.pending_funding_payment)
           } else {
            // else the user defined leverage is its effective leverage
            if (option::is_some<u64>(&leverage)) {
                *option::borrow(&leverage)
            } else {
                position.leverage
            }
           }
        } else { // for cross position there is no concept of effective leverage
            0
        }
    }

    //===============================================================//
    //                        Private Methods                        //
    //===============================================================//


    /// Returns the asset value
    fun asset_to_usd(quantity: u64, price: u64, weight: u64): u64{
        utils::base_mul(utils::base_mul(quantity, price), weight)
    }

    /// Tries to subtract the provided amount from the 1st asset stored in users deposited asset vector
    /// If the amount can not be completed subtracted, makes the asset quantity zero and returns
    /// the remainder amount that couldn't be taken from assets along with `overflow` flag true
    fun try_sub_margin(assets: &mut vector<DepositedAsset>, amount: u64): (bool, u64) {
        if (vector::length(assets) == 0){
            return (true, amount)
        };

        let asset = vector::borrow_mut(assets, 0);

        if(asset.quantity >= amount) {
            asset.quantity = asset.quantity - amount;
            return (false, 0)
        } else {
            let remainder = amount - asset.quantity;
            asset.quantity = 0;
            return (true, remainder)
        }
    }

    /// Applies funding rate to the positions specified by the flag `isolated`
    /// If `True` FR is applied to isolated positions. The funding amount is added/deducted from margin of isolated positions
    /// If `False` FR is applied to cross position. The funding amount is added/deducted from the asset/balance of the account
    fun apply_funding_rate_to_positions(account: &mut Account, perpetual_table: &Table<String, Perpetual>, market: Option<String>, isolated: bool): vector<FundingApplied>{

        let applied_funding = vector::empty<FundingApplied>();


        let positions = if (isolated) { &mut account.isolated_positions} else {&mut account.cross_positions};

        // if market is provided, then FR is to be applied to only provided market position
        if(option::is_some<String>(&market)){
            // Check if user open position for provided market
            let (has, index) = has_open_position(positions, *option::borrow(&market));
            if(!has){
                // if not then return
                return applied_funding
            } else {
                // if yes, then empty the position vector and just keep that one market position in it
                // this effectively removes user position, remember to put it back after the work is done
                let position = vector::remove(positions, index);
                positions = &mut vector::empty<Position>();
                vector::push_back(positions, position);
            }
        };

        let i = 0;
        let count = vector::length(positions);

        // iterate over each position and apply funding rate
        while( i < count){

            let position = vector::borrow_mut(positions, i);

            i = i + 1;


            let perpetual = table::borrow(perpetual_table, position.perpetual);

            // size * current oracle price
            let position_value = utils::base_mul(position.size, perpetual::get_oracle_price(perpetual));

            // get current funding rate from perpetual
            let current_funding =  perpetual::get_current_funding(perpetual);

            let current_funding_ts = perpetual::get_funding_timestamp(&current_funding);
            let position_funding_ts = perpetual::get_funding_timestamp(&position.funding);

            // if the timestamp for position's funding rate is same as the current funding timestamp
            // on perpetual, just continue as the current funding is already applied to the position
            // TODO shall we assert and revert the contract call? Reason being, it should never be the case
            // that an account is being sent twice to be applied funding rate in the same funding window
            // Both the off-chain margining engine and the sequencer should ensure this
            if (position_funding_ts  == current_funding_ts){
                continue
            };

            // Funding payment = - Position side * Position value * Funding Rate
            // If funding rate is negative, shorts pay longs.
            // If funding rate is positive, longs pay shorts.

            let funding_rate = perpetual::get_funding_rate(&current_funding);
            let value = signed_number::value(funding_rate);
            let is_positive = signed_number::sign(funding_rate);

            // current funding rate * current position value;
            let funding_amount = utils::base_mul(position_value, value);

            // If funding and position are both positive or negative (having same sign), the user pays the funding amount
            // The `signed_amount` is negative implying user owes the system
            let signed_amount = if(is_positive  == position.is_long){
                    if(funding_amount > 0){
                        signed_number::from(funding_amount, false)
                    } else {
                        signed_number::from(0, true)
                    }
            }
            // if funding rate and user position are in opposite direction, the system pays the user
            else {
                    signed_number::from(funding_amount, true)
            };

            // if funding is being applied to isolated position
            if(isolated){
                // if amount is positive, increase margin
                if (signed_number::sign(signed_amount)){
                    position.margin = position.margin + funding_amount
                } else { // funding is negative, sub from margin if possible
                    if (funding_amount <= position.margin){
                        position.margin = position.margin - funding_amount;
                    } else {
                        let remainder = funding_amount - position.margin;
                        // funding value to be paid > user's margin in position. Make the position margin zero
                        // and increase pending funding payment amount
                        position.margin = 0;
                        position.pending_funding_payment = position.pending_funding_payment + remainder;
                    }
                }

            } else { // if cross position

                // if amount is positive, increase user assets.
                // NOTE: This assumes user has single collateral asset and i.e USDC
                // TODO: To support multi-collat, we need to update this
                if (signed_number::sign(signed_amount)){
                    add_margin_to_asset_vector(&mut account.assets, funding_amount, constants::usdc_token_symbol());
                } else { // funding is negative, sub from user assets if possible

                    let (overflow, remainder) = try_sub_margin(&mut account.assets, funding_amount);
                    if(overflow){
                        position.pending_funding_payment = position.pending_funding_payment + remainder;
                    }
                }

            };

            position.funding = current_funding;

            vector::push_back(&mut applied_funding, FundingApplied{
                position: *position,
                assets: account.assets,
                funding_rate: current_funding,
                funding_amount:signed_amount
            });
        };


        // if FR was applied for a specific market then put that market's position back
        if(option::is_some<String>(&market)){
            let user_positions = if (isolated) { &mut account.isolated_positions} else {&mut account.cross_positions};
            vector::push_back(user_positions, vector::pop_back(positions));
        };

        applied_funding
    }

    public fun dec_funding_applied(funding_applied: &FundingApplied): (Position, vector<DepositedAsset>, FundingRate, Number) {
        (
            funding_applied.position,
            funding_applied.assets,
            funding_applied.funding_rate,
            funding_applied.funding_amount
        )
    }

    /// Returns the list of accounts authorized by the account
    public fun get_authorized_accounts(account: &Account): vector<address> {
        {
            account.authorized
        }
    }



    #[test_only]
    public fun create_position_for_testing(
        perpetual:String,
        size: u64,
        average_entry_price: u64,
        leverage:u64,
        margin: u64,
        is_long: bool,
        is_isolated:bool,
        pending_funding_payment: u64) : Position {

        return Position {
            perpetual,
            size,
            average_entry_price,
            is_long,
            leverage,
            margin,
            is_isolated,
            funding: perpetual::create_funding_rate(0, 0, true),
            pending_funding_payment
        }
    }


    #[test]
    public fun should_calculate_the_effective_leverage_as_zero_for_cross_position() {

        let position = create_position_for_testing(
            string::utf8(b"BTCUSDT"),
            0,
            0,
            0,
            0,
            false,
            false,
            0
        );

        let effective_leverage = calculate_effective_leverage(&position, option::none<u64>());

        assert!(effective_leverage == 0, 0);
    }




    #[test]
    public fun should_calculate_the_effective_leverage_to_be_less_than_user_set_leverage() {


        let position = create_position_for_testing(
            string::utf8(b"BTCUSDT"),
            1000000000, //size
            1500000000, //entry price
            2000000000, // leverage,
            1000000000, //margin
            true, //is_long
            true, //is_isolated
            0 //pending_funding_payment
        );

        let effective_leverage = calculate_effective_leverage(&position, option::none<u64>());

        assert!(effective_leverage < 2000000000, 0);
        assert!(effective_leverage == 1500000000, 0);

    }



    #[test]
    public fun should_calculate_the_effective_leverage_to_be_greater_than_user_set_leverage() {

        let position = create_position_for_testing(
            string::utf8(b"BTCUSDT"),
            1000000000, //size
            2500000000, //entry price
            2000000000, // leverage,
            1000000000, //margin
            true, //is_long
            true, //is_isolated
            0 //pending_funding_payment
        );


        let effective_leverage = calculate_effective_leverage(&position, option::none<u64>());

        assert!(effective_leverage > 2000000000, 0);
        assert!(effective_leverage == 2500000000, 0);

    }


    #[test]
    public fun should_calculate_the_effective_leverage_to_be_four() {


        let position = create_position_for_testing(
            string::utf8(b"BTCUSDT"),
            2000000000, //size
            4000000000, //entry price
            2000000000, // leverage,
            2000000000, //margin
            true, //is_long
            true, //is_isolated
            0 //pending_funding_payment
        );

        let effective_leverage = calculate_effective_leverage(&position, option::none<u64>());

        assert!(effective_leverage == 4000000000, 0);
    }

    #[test_only]
    public fun set_pending_funding_payment(account: &mut Account, perpetual: String, isolated: bool, amount: u64){
        
        
        let positions = if (isolated) { &mut account.isolated_positions} else {
            &mut account.cross_positions
        };

        let (open, index) = has_open_position(positions, perpetual);

        assert!(open, 0);

        let position = vector::borrow_mut(positions, index);
        position.pending_funding_payment = amount;
    }


}




