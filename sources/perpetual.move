/*
  Copyright (c) 2025 Bluefin Labs Inc.
  Proprietary Smart Contract License – All Rights Reserved.

  This source code is provided for transparency and verification only.
  Use, modification, reproduction, or redeployment of this code 
  requires prior written permission from the Bluefin Labs Inc.
*/

module bluefin_cross_margin_dex::perpetual {
    use sui::bcs::{Self};
    use std::string::{Self, String};
    use std::vector;

    // local modules
    use bluefin_cross_margin_dex::signed_number::{Self, Number};
    use bluefin_cross_margin_dex::errors;


    // friend modules
    friend bluefin_cross_margin_dex::data_store;
    friend bluefin_cross_margin_dex::exchange;
    
    #[test_only]
    friend bluefin_cross_margin_dex::test_perpetual;

    //===========================================================//
    //                         Constants                         //
    //===========================================================//

    // Min/Max length of perpetual symbol
    const MIN_PERPETUAL_SYMBOL_LENGTH: u64 = 3;
    const MAX_PERPETUAL_SYMBOL_LENGTH: u64 = 12;

    /// Min/Max allowed IMR
    /// 50x leverage (2%)
    const MIN_IMR: u64 = 20000000;
    /// 2x leverage (50%)
    const MAX_IMR: u64 = 500000000;

    /// Min allowed MMR
    /// (1%)
    /// The max allowed MMR is capped by IMR
    const MIN_MMR: u64 = 10000000;

    /// Min/Max step size
    /// @dev min step size is min trade quantity
    const MIN_STEP_SIZE: u64 = 1000; 
    /// @dev ensure that max trade quantity % max step size is ZERO
    const MAX_STEP_SIZE: u64 = 1000000000000;

    /// Min/Max tick size
    /// @dev ensure that min/max trade price % min tick size is ZERO
    const MIN_TICK_SIZE: u64 = 1000;
    /// @dev ensure that min/max trade price % max tick size is ZERO
    const MAX_TICK_SIZE: u64 = 1000000000000;


    /// Max trade quantity
    const MAX_TRADE_QUANTITY: u64 = 100000000000000000;

    /// Min/Max trade price
    const MIN_TRADE_PRICE: u64 = 10000;
    const MAX_TRADE_PRICE: u64 = 100000000000000000;

    /// Min/Max market take bound %age
    /// 0.001 (0.1%)
    const MIN_TAKE_BOUND: u64 = 1000000;
    /// 0.2 (20 percent)
    const MAX_TAKE_BOUND: u64 = 200000000;

    /// Min/Max trade maker/taker fee
    /// Min fee allowed is zero %
    const MIN_FEE: u64 = 0;
    /// Max fee allowed is 3%
    const MAX_FEE: u64 = 30000000;

    /// Min/Max allowed notional at any leverage
    const MIN_NOTIONAL: u64 = 1000000000000;
    const MAX_NOTIONAL: u64 = 10000000000000000;

    /// Min/Max allowed funding rate
    /// Min funding rate allowed is 0.001 (0.1%)
    const MIN_FUNDING_RATE: u64 = 1000000;
    /// Max funding rate allowed is 0.05 (5%)
    const MAX_FUNDING_RATE: u64 = 50000000;

    /// Min/Max allowed insurance pool premium percentage from liquidations
    /// 1%
    const MIN_PREMIUM: u64 = 10000000;
    /// 50 %
    const MAX_PREMIUM: u64 = 500000000;

    // 2025-01-01 (7 AM GMT)
    const MIN_TRADE_START_TIME: u64 = 1735714800000;

    //===========================================================//
    //                           Structs                         //
    //===========================================================//

    /// Represents a perpetual's hourly funding
    struct FundingRate has store, copy, drop {
        /// The hour (in seconds) at which funding rate was set.
        timestamp: u64,
        /// Signed number as funding could be positive or negative.
        /// The value of funding ranges from -max_funding_rate to +max_funding_rate
        /// The funding rate is representing as percentage where 100% is 1e9, 10% is 1e8 and so on.
        rate: Number,
    }

    /// Represents a perpetual/market
    struct Perpetual has store, copy, drop {
        /// Unique address for this perpetual.
        id: address,
        /// Name of perpetual
        symbol: String,
        /// imr: the initial margin collateralization percentage
        imr: u64,
        /// mmr: the minimum collateralization percentage
        mmr: u64,
        /// the smallest decimal unit supported by asset for quantity
        step_size: u64,
        /// the smallest decimal unit supported by asset for price
        tick_size: u64,
        /// minimum quantity of asset that can be traded
        min_trade_qty: u64,
        /// maximum quantity of asset that can be traded
        max_trade_qty: u64,
        /// min price at which asset can be traded
        min_trade_price: u64,
        /// max price at which asset can be traded
        max_trade_price: u64,
        /// vector for maximum OI Open allowed for leverage. Indexes represent leverage
        max_notional_at_open: vector<u64>,
        ///  market take bound for long side ( 10% == 100000000)
        mtb_long: u64,
        ///  market take bound for short side ( 10% == 100000000)
        mtb_short: u64,
        /// default maker order fee 
        maker_fee: u64,
        /// default taker order fee 
        taker_fee: u64,
        /// max allowed funding rate
        max_funding_rate: u64,
        /// percentage of liquidation premium goes to insurance pool
        insurance_pool_ratio: u64,
        /// address of insurance pool
        insurance_pool: address,
        /// fee pool address
        fee_pool: address,
        /// is trading allowed
        trading_status: bool,
        /// trading start time
        trading_start_time: u64,
        /// delist status
        delist: bool,
        /// the price at which trades will be executed after delisting
        delisting_price: u64,
        /// is market only for isolated trades
        isolated_only: bool,
        /// Asset Information
        base_asset_symbol: String,
        base_asset_name: String,
        base_asset_decimals: u64,
        
        /// Order Limits
        max_limit_order_quantity: u64,
        max_market_order_quantity: u64,
        
        /// Default leverage for the market. This is not used on-chain and is only for off-chain
        default_leverage: u64,

        /// The oracle price of the perpetual
        oracle_price: u64,
        /// The current funding rate of the perp
        funding: FundingRate
    }


    //===============================================================//
    //                        Friend Functions                       //
    //===============================================================//

    /// Method used to create perpetual object
    public (friend) fun create_perpetual(
        id: address,
        symbol: String,
        imr: u64,
        mmr: u64,
        step_size: u64,
        tick_size: u64,
        min_trade_qty: u64,
        max_trade_qty: u64,
        min_trade_price: u64,
        max_trade_price: u64,
        max_notional_at_open: vector<u64>,
        mtb_long: u64,
        mtb_short: u64,
        maker_fee: u64,
        taker_fee: u64,
        max_funding_rate: u64,
        insurance_pool_ratio: u64,
        trading_start_time: u64,
        insurance_pool: address,
        fee_pool: address,
        isolated_only: bool,
        base_asset_symbol: String,
        base_asset_name: String,
        base_asset_decimals: u64,
        max_limit_order_quantity: u64,
        max_market_order_quantity: u64,
        default_leverage: u64,
        ): Perpetual {

        // ensure starting time is > 0
        assert!(
            trading_start_time > MIN_TRADE_START_TIME, 
            errors::invalid_trade_start_time()
        );

        let perpetual = Perpetual {
            id,
            symbol,
            imr,
            mmr,
            step_size,
            tick_size,
            min_trade_qty,
            max_trade_qty,
            min_trade_price,
            max_trade_price,
            max_notional_at_open,
            mtb_long,
            mtb_short,
            maker_fee,
            taker_fee,
            max_funding_rate,
            insurance_pool_ratio,
            insurance_pool,
            fee_pool,
            trading_start_time,
            delist: false,
            trading_status: true,
            delisting_price: 0,
            isolated_only,
            base_asset_symbol,
            base_asset_name,
            base_asset_decimals,
            max_limit_order_quantity,
            max_market_order_quantity,
            default_leverage,
            
            // default oracle price
            oracle_price: 0,
            // default funding rate
            funding: create_funding_rate(0, 0, true)
        };

        // Invoke all the setter methods to ensure that the values of all perpetual configs are within min/max allowed bounds
        // imr
        set_imr(&mut perpetual, imr);

        // mmr
        set_mmr(&mut perpetual, mmr);

        // step size
        assert!(step_size == min_trade_qty, errors::invalid_quantity());
        set_step_size_and_min_trade_qty(&mut perpetual, step_size);

        // tick size
        set_tick_size(&mut perpetual, tick_size);

        // max trade quantity
        set_max_trade_qty(&mut perpetual, max_trade_qty);

        // min/max trade price
        set_min_trade_price(&mut perpetual, min_trade_price);
        set_max_trade_price(&mut perpetual, max_trade_price);

        // set mtb long and short
        set_mtb(&mut perpetual, mtb_long, true);
        set_mtb(&mut perpetual, mtb_short, false);

        // fee
        set_fee(&mut perpetual, maker_fee, true);
        set_fee(&mut perpetual, taker_fee, false);

        // max allowed notional value
        set_max_allowed_oi_open(&mut perpetual, max_notional_at_open);

        // max funding rate
        set_max_funding_rate(&mut perpetual, max_funding_rate);

        // insurance pool premium ratio
        set_insurance_pool_liquidation_premium_percentage(&mut perpetual, insurance_pool_ratio);

        // insurance pool address
        set_insurance_pool_address(&mut perpetual, insurance_pool);

        // fee pool address
        set_fee_pool_address(&mut perpetual, fee_pool);

        // market/perpetual symbol
        let symbol_length = string::length(&symbol);
        assert!( 
            symbol_length >= MIN_PERPETUAL_SYMBOL_LENGTH && 
            symbol_length <= MAX_PERPETUAL_SYMBOL_LENGTH,
            errors::out_of_config_value_bounds()
        );

        perpetual
    }


    /// Updates initial margin required
    public (friend) fun set_imr( perpetual: &mut Perpetual, imr: u64){
        assert!(
            imr >= MIN_IMR && imr <= MAX_IMR,
            errors::out_of_config_value_bounds()
        ); 
        assert!(imr >= perpetual.mmr, errors::invalid_quantity());
        perpetual.imr = imr;
    }

    /// Updates maintenance margin required
    public (friend) fun set_mmr( perpetual: &mut Perpetual, mmr: u64){
        assert!( mmr >= MIN_MMR, errors::out_of_config_value_bounds() );  
        assert!( mmr <= perpetual.imr, errors::invalid_quantity() );
        perpetual.mmr = mmr;
    }

    /// Updates step size and min trade quantity for provided perpetual
    public (friend) fun set_step_size_and_min_trade_qty( perpetual: &mut Perpetual, step_size: u64){
        assert!(step_size >= MIN_STEP_SIZE && step_size <= MAX_STEP_SIZE, errors::out_of_config_value_bounds());
        assert!(step_size < perpetual.max_trade_qty, errors::invalid_quantity());
        perpetual.step_size = step_size;
        perpetual.min_trade_qty = step_size;
    }

    /// Updates max trade quantity
    public (friend) fun set_max_trade_qty( perpetual: &mut Perpetual, quantity: u64){
        assert!(quantity >= MIN_STEP_SIZE && quantity <= MAX_TRADE_QUANTITY, errors::out_of_config_value_bounds());
        assert!(quantity > perpetual.min_trade_qty && quantity % perpetual.step_size == 0, errors::invalid_quantity());
        perpetual.max_trade_qty = quantity;
    }

    /// Updates tick size for provided perpetual
    public (friend) fun set_tick_size( perpetual: &mut Perpetual, tick_size: u64){
        assert!(tick_size >= MIN_TICK_SIZE && tick_size <= MAX_TICK_SIZE, errors::out_of_config_value_bounds());  
        
        assert!(
            perpetual.min_trade_price % tick_size == 0 && 
            perpetual.max_trade_price % tick_size == 0, 
            errors::invalid_quantity()
        );
        perpetual.tick_size = tick_size;
    }

    /// Updates maximum limit order quantity
    public (friend) fun set_max_limit_order_quantity( perpetual: &mut Perpetual, quantity: u64){
        assert!(quantity > perpetual.min_trade_qty && quantity % perpetual.step_size == 0, errors::invalid_quantity());
        assert!(quantity >= perpetual.max_market_order_quantity, errors::invalid_quantity());
        perpetual.max_limit_order_quantity = quantity;
    }

    /// Updates maximum market order quantity
    public (friend) fun set_max_market_order_quantity( perpetual: &mut Perpetual, quantity: u64){
        assert!(quantity > perpetual.min_trade_qty && quantity % perpetual.step_size == 0, errors::invalid_quantity());
        assert!(quantity <= perpetual.max_limit_order_quantity, errors::invalid_quantity());
        perpetual.max_market_order_quantity = quantity;
    }

    /// Updates minimum trade price
    public (friend) fun set_min_trade_price( perpetual: &mut Perpetual, price: u64){
        assert!(price >= MIN_TRADE_PRICE && price <= MAX_TRADE_PRICE, errors::out_of_config_value_bounds());
        assert!(price <= perpetual.max_trade_price && price % perpetual.tick_size == 0, errors::invalid_quantity());
        perpetual.min_trade_price = price;
    }

    /// Updates maximum trade price
    public (friend) fun set_max_trade_price( perpetual: &mut Perpetual, price: u64){
        assert!(price >= MIN_TRADE_PRICE && price <= MAX_TRADE_PRICE, errors::out_of_config_value_bounds());
        assert!(price >= perpetual.min_trade_price && price % perpetual.tick_size == 0, errors::invalid_quantity());
        perpetual.max_trade_price = price;
    }

    /// Updates market take bound
    public (friend) fun set_mtb( perpetual: &mut Perpetual, mtb: u64, long: bool){
        assert!(mtb >= MIN_TAKE_BOUND && mtb <= MAX_TAKE_BOUND, errors::out_of_config_value_bounds());

        if(long){
            perpetual.mtb_long = mtb;
        } else {
            perpetual.mtb_short = mtb;
        };
    }

    /// Updates maker/taker fee
    public (friend) fun set_fee( perpetual: &mut Perpetual, fee: u64, maker: bool){
        assert!(
            fee >= MIN_FEE && fee <= MAX_FEE,
            errors::out_of_config_value_bounds()
        );  

         if(maker){
            perpetual.maker_fee = fee;
        } else {
            perpetual.taker_fee = fee;
        };
    }

    /// Updates the max allowed oi open of the market
    public (friend) fun set_max_allowed_oi_open( perpetual: &mut Perpetual, max_allowed_oi_open: vector<u64>){
        perpetual.max_notional_at_open = max_allowed_oi_open;
        while(vector::length(&max_allowed_oi_open) > 0 ){
            let max_oi = vector::pop_back(&mut max_allowed_oi_open);
            assert!(max_oi >= MIN_NOTIONAL && max_oi <= MAX_NOTIONAL, errors::out_of_config_value_bounds());
        }
    }

    /// Updates max funding rate
    public (friend) fun set_max_funding_rate( perpetual: &mut Perpetual, rate: u64){
        assert!(rate >= MIN_FUNDING_RATE && rate <= MAX_FUNDING_RATE, errors::out_of_config_value_bounds());
        perpetual.max_funding_rate = rate;
    }

    /// Updates ratio of liquidation premium that goes to insurance pool
    public (friend) fun set_insurance_pool_liquidation_premium_percentage( perpetual: &mut Perpetual, percentage: u64){
        assert!(percentage >= MIN_PREMIUM && percentage <= MAX_PREMIUM, errors::out_of_config_value_bounds());
        perpetual.insurance_pool_ratio = percentage;
    }

    /// Updates insurance pool address
    public (friend) fun set_insurance_pool_address( perpetual: &mut Perpetual, pool: address){
        assert!(pool != @0, errors::can_not_be_zero_address());
        perpetual.insurance_pool = pool;
    }

    /// Updates fee pool address
    public (friend) fun set_fee_pool_address( perpetual: &mut Perpetual, pool: address){
        assert!(pool != @0, errors::can_not_be_zero_address());
        perpetual.fee_pool = pool;
    }

    /// Updates the isolated only status of a market
    public (friend) fun set_isolated_only( perpetual: &mut Perpetual, isolated_only: bool){
        perpetual.isolated_only = isolated_only;
    }


    /// Updates trading status of a market
    public (friend) fun set_trading_status( perpetual: &mut Perpetual, status: bool){
        perpetual.trading_status = status;
    }

    /// Marks the perpetual as delisted. This can be only performed once
    public (friend) fun delist( perpetual: &mut Perpetual, delist_price: u64){
        assert!(!perpetual.delist, errors::already_delisted());

        // delist price must be in range and should conform to tick size
        assert!(
            delist_price >= perpetual.min_trade_price && 
            delist_price <= perpetual.max_trade_price && 
            delist_price % perpetual.tick_size == 0, 
            errors::invalid_oracle_price()
        );

        perpetual.delist = true;
        perpetual.delisting_price = delist_price;
    }


    /// Copies all fields except funding_rate and oracle_price from eds perpetual to ids perpetual
    /// and return the bcs serialization of eds perpetual
    ///
    /// Parameters:
    /// ids_perp: Mutable reference to ids perpetual
    /// eds_perp: Immutable reference to eds perpetual
    /// 
    /// Returns:
    /// Bcs serialization of the eds_perp data
    public (friend) fun replicate_perp_data(ids_perp: &mut Perpetual, eds_perp: &Perpetual): vector<u8>{
        ids_perp.id = eds_perp.id;
        ids_perp.symbol = eds_perp.symbol;
        ids_perp.imr =  eds_perp.imr;
        ids_perp.mmr =  eds_perp.mmr;
        ids_perp.step_size =  eds_perp.step_size;
        ids_perp.tick_size =  eds_perp.tick_size;
        ids_perp.min_trade_qty =  eds_perp.min_trade_qty;
        ids_perp.max_trade_qty =  eds_perp.max_trade_qty;
        ids_perp.min_trade_price =  eds_perp.min_trade_price;
        ids_perp.max_trade_price =  eds_perp.max_trade_price;
        ids_perp.max_notional_at_open =  eds_perp.max_notional_at_open;
        ids_perp.mtb_long =  eds_perp.mtb_long;
        ids_perp.mtb_short =  eds_perp.mtb_short;
        ids_perp.maker_fee =  eds_perp.maker_fee;
        ids_perp.taker_fee =  eds_perp.taker_fee;
        ids_perp.max_funding_rate =  eds_perp.max_funding_rate;
        ids_perp.insurance_pool_ratio =  eds_perp.insurance_pool_ratio;
        ids_perp.insurance_pool =  eds_perp.insurance_pool;
        ids_perp.fee_pool =  eds_perp.fee_pool;
        ids_perp.trading_status =  eds_perp.trading_status;
        ids_perp.trading_start_time =  eds_perp.trading_start_time;
        ids_perp.delist = eds_perp.delist;
        ids_perp.delisting_price =  eds_perp.delisting_price;        
        ids_perp.isolated_only =  eds_perp.isolated_only;        

        ids_perp.base_asset_symbol =  eds_perp.base_asset_symbol;        
        ids_perp.base_asset_name =  eds_perp.base_asset_name;      
        ids_perp.base_asset_decimals =  eds_perp.base_asset_decimals;        
        ids_perp.max_limit_order_quantity =  eds_perp.max_limit_order_quantity;        
        ids_perp.max_market_order_quantity =  eds_perp.max_market_order_quantity;        
        ids_perp.default_leverage =  eds_perp.default_leverage;      

        // if perpetual has been delisted set the delisting price as the oracle price.
        // No more oracle prices will be accepted for this perpetual
        // once its been delisted. This is the final oracle/mark price
        if(ids_perp.delist) {
            ids_perp.oracle_price = ids_perp.delisting_price;
        }; 

        return bcs::to_bytes<Perpetual>(eds_perp)
    }


    /// Updates the oracle price of the perpetual to the one provided
    ///
    /// Parameters:
    /// - perpetual: Mutable reference to the perpetual
    /// - oracle_price: The new oracle price
    public (friend) fun update_oracle_price(perpetual: &mut Perpetual, oracle_price: u64){

        // oracle price must conform to tick size
        assert!(oracle_price % perpetual.tick_size == 0, errors::invalid_oracle_price());
        
        // ensure the perpetual is not delisted
        assert!(!perpetual.delist, errors::already_delisted());

        perpetual.oracle_price = oracle_price;

    }

    /// Updates the funding rate of the  perpetual to the one provided
    ///
    /// Parameters:
    /// - perpetual: Mutable reference to the perpetual
    /// - value: The funding value
    /// - sign: The direction/sign of the funding value
    /// - timestamp: The timestamp of the window or hour for which funding rate is being set
    public (friend) fun update_funding_rate(perpetual: &mut Perpetual, value: u64, sign: bool, timestamp: u64){

        assert!(perpetual.funding.timestamp < timestamp, errors::invalid_funding_time());

        assert!(value <= perpetual.max_funding_rate, errors::funding_rate_exceeds_max_allowed_limit());

        perpetual.funding = create_funding_rate(timestamp, value, sign);

    }

    //===============================================================//
    //                         Public Methods                        //
    //===============================================================//

    /// Returns perpetual id/address
    public fun get_perpetual_address(perpetual: &Perpetual): address {
        perpetual.id
    }

    /// Returns the initial margin ratio of the perp
    public fun get_imr(perpetual: &Perpetual): u64 {
        perpetual.imr
    }

    /// Returns the maintenance margin ratio of the perp
    public fun get_mmr(perpetual: &Perpetual): u64 {
        perpetual.mmr
    }

    /// Returns the oracle price of the perp
    public fun get_oracle_price(perpetual: &Perpetual): u64 {
        perpetual.oracle_price
    }

    /// Returns the tick size of the perp
    public fun get_tick_size(perpetual: &Perpetual): u64 {
        perpetual.tick_size
    }

    /// Returns fee pool address
    public fun get_fee_pool_address(perpetual: &Perpetual): address {
        perpetual.fee_pool
    }

    /// Returns insurance pool address
    public fun get_insurance_pool_address(perpetual: &Perpetual): address {
        perpetual.insurance_pool
    }

    /// Returns insurance pool liquidation premium ratio
    public fun get_insurance_pool_ratio(perpetual: &Perpetual): u64 {
        perpetual.insurance_pool_ratio
    }

    /// Returns the isolated only flag
    public fun get_isolated_only(perpetual: &Perpetual): bool {
        perpetual.isolated_only
    }

    /// Returns the trading status of the perpetual
    public fun get_trading_status(perpetual: &Perpetual): bool {
        perpetual.trading_status
    }

    /// Returns the delist status of the perpetual
    public fun get_delist_status(perpetual: &Perpetual): bool {
        perpetual.delist
    }

    /// Returns the perpetual symbol
    public fun get_symbol(perpetual: &Perpetual): String {
        perpetual.symbol
    }

    /// Returns maker/taker fees 
    public fun get_fees(perpetual: &Perpetual): (u64, u64) {
        (perpetual.maker_fee, perpetual.taker_fee)
    }

    /// Decompresses the perpetual object and returns all its values/config
    public fun perpetual_values(perpetual: &Perpetual): (address, String, u64, u64, u64, u64, u64, u64, u64, u64, vector<u64>, u64, u64, u64, u64, u64, u64,  address, address, u64, bool, bool, u64, u64, bool){
        
        (
            perpetual.id,
            perpetual.symbol,
            perpetual.imr,
            perpetual.mmr,
            perpetual.step_size,
            perpetual.tick_size,
            perpetual.min_trade_qty,
            perpetual.max_trade_qty,
            perpetual.min_trade_price,
            perpetual.max_trade_price,
            perpetual.max_notional_at_open,
            perpetual.mtb_long,
            perpetual.mtb_short,
            perpetual.maker_fee,
            perpetual.taker_fee,
            perpetual.max_funding_rate,
            perpetual.insurance_pool_ratio,
            perpetual.insurance_pool,
            perpetual.fee_pool,
            perpetual.trading_start_time,
            perpetual.delist,
            perpetual.trading_status,
            perpetual.oracle_price,
            perpetual.delisting_price,
            perpetual.isolated_only
        )
    }

    /// Creates a new funding from provided values
    /// 
    /// Parameters:
    /// - timestamp: The timestamp in seconds at which funding is being created/set
    /// - value: The value of the funding rate in percentage
    /// - sign: sign +/- of the funding
    public fun create_funding_rate(timestamp: u64, value: u64, sign: bool): FundingRate {
        FundingRate {
            timestamp,
            rate: signed_number::from(value, sign)
        }
    }

    /// Returns current funding rate
    public fun get_current_funding(perpetual: &Perpetual): FundingRate {
        perpetual.funding
    }

    public fun get_funding_rate(funding: &FundingRate): Number {
        funding.rate
    }

    public fun get_funding_timestamp(funding: &FundingRate): u64 {
        funding.timestamp
    }
    
    public fun get_step_size(perpetual: &Perpetual): u64 {
        perpetual.step_size
    }

    public fun get_min_trade_qty(perpetual: &Perpetual): u64 {
        perpetual.min_trade_qty
    }

    public fun get_max_trade_qty(perpetual: &Perpetual): u64 {
        perpetual.max_trade_qty
    }

    public fun max_allowed_oi_open(perpetual: &Perpetual): vector<u64> {
        perpetual.max_notional_at_open        
    }

}
