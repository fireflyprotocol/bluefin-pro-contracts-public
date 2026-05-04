import {
    createPerpetual,
    expect,
    expectPosition,
    INSURANCE_POOL_ADDRESS,
    provideMarginToAccount,
    setLiquidator,
    setupLiquidation,
    setupTrade
} from "./helpers/utils";
import { ADMIN, bluefinV3, PARSER, SIMULATOR, SUI_CLIENT } from "../env";
import {
    BigNumber,
    getTestAccounts,
    SUI_NATIVE_BASE,
    TransactionBlock
} from "../library-sui/dist";
import { ISignedOrder } from "../library-sui/src/v3";
import {
    toBigNumber,
    toBigNumberStr,
    Transaction,
    getKeyPairFromSeed,
    REQUEST_LIFESPAN,
    ADDRESSES,
    SuiBlocks,
    base64ToHex
} from "../library-sui/src";
import { TEST_WALLETS } from "../library-sui/src/helpers";
import { BCSUtils, Order } from "../library-sui/src/v3/utils/bcs";
import { Account } from "../library-sui/src/v3/on-chain-calls/account";
import { ASSUME_AS, POSITION_TYPES } from "../library-sui/src/v3/enums";
import {
    IOraclePriceUpdate,
    ITradeExecutedEvent,
    ILiquidationExecutedEvent
} from "../library-sui/src/v3";

describe("Liquidations", () => {
    const [alice, bob] = getTestAccounts(true);
    const [dorthy, ellen] = getTestAccounts(true);

    let charlie = getKeyPairFromSeed(TEST_WALLETS[0].phrase, "ED25519");
    let marketName: string = "ETH-PERP";
    const bankruptLiquidator = getKeyPairFromSeed(TEST_WALLETS[6].phrase, "ED25519");
    const bankruptLiquidatorAddress = bankruptLiquidator.toSuiAddress();

    let oraclePrices = [
        {
            perpetual: marketName,
            price: toBigNumber(100, SUI_NATIVE_BASE)
        }
    ] as Array<IOraclePriceUpdate>;

    before(async () => {
        await setLiquidator(bluefinV3, bankruptLiquidatorAddress, true);
        await setLiquidator(bluefinV3, ADMIN.toSuiAddress(), true);
        await setLiquidator(bluefinV3, charlie.toSuiAddress(), true);
    });

    describe("Reversions", async () => {
        let txb: TransactionBlock;
        before(async () => {
            await SIMULATOR.init();
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address);

            await provideMarginToAccount(bluefinV3, SIMULATOR, ADMIN.toSuiAddress());
            await provideMarginToAccount(bluefinV3, SIMULATOR, charlie.toSuiAddress());

            await provideMarginToAccount(bluefinV3, SIMULATOR, dorthy.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, ellen.address);
        });

        beforeEach(async () => {
            await SIMULATOR.init();

            txb = new TransactionBlock();

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                true // update sequence hash
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );
        });

        it("should revert as self liquidation is not allowed", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                bluefinV3.walletAddress,
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE),
                { expiry: Date.now() }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now() + 1000,
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1058");
        });

        it("should revert as the liquidation payload is expired", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { expiry: Date.now() }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now() + 1000,
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1027");
        });

        it("should revert liquidation payload was signed more than 3 months ago", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE) // liquidating 1 quantity
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now() + 1000 + REQUEST_LIFESPAN,
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should revert as the liquidation payload is signed for some other environment(IDS)", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { ids: ADDRESSES.ZERO }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1006");
        });

        it("should revert as allOrNothing flag is set and liquidatee's positions size < liquidation quantity", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1.2, SUI_NATIVE_BASE), // liquidating 1.2 quantity
                { allOrNothing: true }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1043");
        });

        it("should revert as signer is not authorized by the liquidator account", async () => {
            const signer = getKeyPairFromSeed(TEST_WALLETS[3].phrase, "ED25519");

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                {
                    liquidator: ADMIN.toSuiAddress(), // the liquidator is admin
                    signer // the signer is a random wallet
                }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1014");
        });

        it("should revert as the liquidator does not have an account (never deposited)", async () => {
            const account = getTestAccounts(true)[0];

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { signer: account.signer } // the entire 1 quantity provided must be liquidated
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1016");
        });

        it("should revert as the liquidatee account is not under water", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE) // liquidating 1 quantity
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1042");
        });
    });

    describe("Standard Isolated Liquidations", async () => {
        let txb: TransactionBlock;

        before(async () => {
            await SIMULATOR.init();
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address);

            await provideMarginToAccount(bluefinV3, SIMULATOR, ADMIN.toSuiAddress());
            await provideMarginToAccount(bluefinV3, SIMULATOR, charlie.toSuiAddress());

            await provideMarginToAccount(bluefinV3, SIMULATOR, dorthy.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, ellen.address);
        });

        beforeEach(async () => {
            await SIMULATOR.init();

            // Oracle price will be 100
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: alice.signer }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            txb = new TransactionBlock();

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );
        });

        it("should perform an isolated liquidation and assume it as isolated position", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { allOrNothing: true } // the entire 1 quantity provided must be liquidated
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            expectPosition(liquidationEvent.liquidatee_position, { size: 0, margin: 0 });

            expectPosition(liquidationEvent.liquidator_position, {
                size: 1,
                entryPrice: 92,
                margin: 92,
                side: "LONG"
            });

            expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                "9990605000000"
            );
        });

        it("should perform a partial isolated liquidation and assume it as isolated position", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(0.4, SUI_NATIVE_BASE),
                { allOrNothing: true } // the entire 0.4 quantity provided must be liquidated
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;
            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            expectPosition(liquidationEvent.liquidatee_position, {
                size: 0.6,
                margin: 6
            });

            expectPosition(liquidationEvent.liquidator_position, {
                size: 0.4,
                entryPrice: 92,
                margin: 36.8,
                side: "LONG"
            });
        });

        it("should allow liquidator to take on an isolated liquidation as isolated position with 5x leverage", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE),
                { leverageE9: toBigNumberStr(5, SUI_NATIVE_BASE) }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;
            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            expectPosition(liquidationEvent.liquidatee_position, { size: 0, margin: 0 });
            expectPosition(liquidationEvent.liquidator_position, {
                size: 1,
                entryPrice: 92,
                margin: 18.4,
                side: "LONG"
            });
        });

        it("should successfully perform a liquidation when `allOrNothing` flag is false and the liquidatee does not have provided quantity to liquidate", async () => {
            // liquidating the quantity by 0.4 first
            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(0.4, SUI_NATIVE_BASE)
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            bluefinV3.txBuilder.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash2,
                Date.now(),
                { txBlock: txb }
            );

            // make a payload to liquidate 1 quantity
            const payload2 = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice with short position
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE)
            );

            const sequenceHash3 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload2.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload2.serializedData,
                payload2.signature,
                oraclePrices,
                sequenceHash3,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;
            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            expectPosition(liquidationEvent[0].liquidatee_position, {
                size: 0.6,
                margin: 6
            });
            expectPosition(liquidationEvent[1].liquidatee_position, {
                size: 0,
                margin: 0
            });

            expectPosition(liquidationEvent[1].liquidator_position, {
                size: 1,
                entryPrice: 92,
                side: "LONG"
            });
        });

        it("should have non-zero funds in insurance pool account after liquidation", async () => {
            await SIMULATOR.init();

            const insurancePoolAssets = await Account.getAccountAssets(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                INSURANCE_POOL_ADDRESS
            );

            const initialBalance =
                insurancePoolAssets.length > 0
                    ? Number(insurancePoolAssets[0].quantity)
                    : 0;

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: dorthy.signer }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: ellen.signer }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            const txb = new TransactionBlock();

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );

            const payload = await bluefinV3.requests.createSignedLiquidation(
                dorthy.address,
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE),
                { signer: charlie, liquidator: charlie.toSuiAddress() }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: false }
            );

            const currentPoolAssets = await Account.getAccountAssets(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                INSURANCE_POOL_ADDRESS
            );

            const currentBalance =
                currentPoolAssets.length > 0 ? Number(currentPoolAssets[0].quantity) : 0;

            expect(currentBalance > initialBalance).to.be.true;
        });

        it("should close the liquidator's SHORT position when taking over a LONG liquidation position", async () => {
            const initBalance = Number(
                (
                    await Account.getAccountAssets(
                        SUI_CLIENT,
                        PARSER.getInternalDataStore(),
                        ADMIN.toSuiAddress()
                    )
                )[0].quantity
            );
            // Oracle price will be 96
            const price = 96;
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(price, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: price,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: ADMIN }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: price,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { leverageE9: toBigNumberStr(2, SUI_NATIVE_BASE) }
            );

            // price moves to 92 - Alice is now liquidate-able and Liquidator(Admin)
            // is now in profit.
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(92, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expect(+liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                initBalance + 5011600000
            );
        });

        it("should flip liquidator's SHORT position and open a LONG position when taking over a LONG liquidation", async () => {
            const initBalance = Number(
                (
                    await Account.getAccountAssets(
                        SUI_CLIENT,
                        PARSER.getInternalDataStore(),
                        ADMIN.toSuiAddress()
                    )
                )[0].quantity
            );
            const positionSize = 0.8;
            const tradePrice = 96;
            const liquidationPrice = 92;

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(tradePrice, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: tradePrice,
                    quantity: positionSize,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: ADMIN }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: tradePrice,
                    quantity: positionSize,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(positionSize, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address, // liquidating alice
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { leverageE9: toBigNumberStr(2, SUI_NATIVE_BASE) }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(liquidationPrice, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expect(+liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                initBalance - 4985520000
            );

            expectPosition(liquidationEvent.liquidator_position, {
                size: 0.2,
                entryPrice: 92,
                margin: 9.2
            });
        });
    });

    describe("Bankrupt Isolated Liquidations", async () => {
        before(async () => {
            await SIMULATOR.init();
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address);

            await provideMarginToAccount(bluefinV3, SIMULATOR, ADMIN.toSuiAddress());
            await provideMarginToAccount(bluefinV3, SIMULATOR, charlie.toSuiAddress());

            await provideMarginToAccount(bluefinV3, SIMULATOR, dorthy.address);
            await provideMarginToAccount(bluefinV3, SIMULATOR, ellen.address);
        });

        let txb: TransactionBlock;

        beforeEach(async () => {
            await SIMULATOR.init();

            await provideMarginToAccount(
                bluefinV3,
                SIMULATOR,
                bankruptLiquidatorAddress,
                { exactAmount: 100 }
            );

            // Oracle price will be 100
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: alice.signer }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            txb = new TransactionBlock();

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );
        });

        it("should successfully perform bankrupt isolated liquidation and assume it as isolated position", async () => {
            const oraclePrice = 88;
            const quantity = 1;

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address,
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(quantity, SUI_NATIVE_BASE),
                {
                    liquidator: bankruptLiquidatorAddress,
                    signer: bankruptLiquidator
                }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            expectPosition(liquidationEvent.liquidatee_position, { size: 0, margin: 0 });

            expectPosition(liquidationEvent.liquidator_position, {
                size: 1,
                entryPrice: 88,
                margin: 88,
                side: "LONG"
            });

            // The liquidator initial balance was 100
            // Performed a bankrupt liquidation at price 88
            // Paid 2$ to cover the loss
            // Remaining balance should be 10$
            expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                toBigNumberStr(10, SUI_NATIVE_BASE)
            );
        });

        it("should successfully perform partial bankrupt isolated liquidation and assume it as isolated position", async () => {
            const oraclePrice = 88;
            const quantity = 0.5;

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address,
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(quantity, SUI_NATIVE_BASE),
                {
                    liquidator: bankruptLiquidatorAddress,
                    signer: bankruptLiquidator
                }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 10 });

            // expect the liquidatee's margin to be 5$
            expectPosition(liquidationEvent.liquidatee_position, {
                size: 1 - quantity,
                margin: 5
            });

            expectPosition(liquidationEvent.liquidator_position, {
                size: quantity,
                entryPrice: 88,
                margin: 44,
                side: "LONG"
            });

            // The liquidator initial balance was 100
            // Performed a bankrupt liquidation at price 88 * 0.5 = 44
            expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                toBigNumberStr(55, SUI_NATIVE_BASE)
            );
        });

        it("should allow a flipping trade liquidation to help pay for bankrupt liquidation cost", async () => {
            const tradePrice = 96;
            const liquidationPrice = 86;
            const quantity = 1;
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(tradePrice, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: tradePrice,
                    quantity,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 1
                },
                { signer: bankruptLiquidator }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: tradePrice,
                    quantity,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 10
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(quantity, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.address,
                marketName,
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE), // liquidating 1 quantity
                { liquidator: bankruptLiquidatorAddress, signer: bankruptLiquidator }
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(liquidationPrice, SUI_NATIVE_BASE)
                }
            ];

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );
        });
    });

    describe("Cross Liquidations", async () => {
        let txb: TransactionBlock;
        const alice = getKeyPairFromSeed(TEST_WALLETS[5].phrase, "Secp256k1");
        const bob = getKeyPairFromSeed(TEST_WALLETS[5].phrase, "ED25519");

        beforeEach(async () => {
            await SIMULATOR.init();

            await provideMarginToAccount(
                bluefinV3,
                SIMULATOR,
                bankruptLiquidatorAddress,
                { exactAmount: 100 }
            );
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.toSuiAddress(), {
                exactAmount: 50
            });
            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.toSuiAddress());
            await provideMarginToAccount(bluefinV3, SIMULATOR, ADMIN.toSuiAddress());

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "LONG",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.CROSS
                },
                { signer: alice }
            );

            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    market: marketName,
                    side: "SHORT",
                    price: 100,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 1
                },
                { signer: bob }
            );

            const fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp
            );

            const makerOrder = makerPayload.rawData as ISignedOrder;
            const takerOrder = takerPayload.rawData as ISignedOrder;

            txb = new TransactionBlock();

            bluefinV3.txBuilder.performTrade(
                BCSUtils.getSerializedDataBytes(makerOrder, Order),
                BCSUtils.getSerializedDataBytes(takerOrder, Order),
                makerOrder.signature,
                takerOrder.signature,
                new BigNumber(fill).toFixed(0),
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                sequenceHash,
                timestamp,
                { txBlock: txb }
            );
        });

        it("should revert as the liquidatee account is not under water", async () => {
            const oraclePrice = 90;
            const liquidationQuantity = 1;

            // Alice has 50$ in her account
            // Has an open position of size 1 at price 100 - she has 2x leverage to start  with
            // There is just one position in her account which has 20x leverage allowed
            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.toSuiAddress(),
                marketName,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                toBigNumberStr(liquidationQuantity, SUI_NATIVE_BASE)
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            await expect(
                bluefinV3.sequencer.performLiquidation(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { txBlock: txb, dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1042");
        });

        it("should successfully liquidate a cross position and assume it as cross", async () => {
            // Alice has 50$ in her account
            // Has an open position of size 1 at price 100 - she has 2x leverage to start  with
            // There is just one position in her account for ETH that allows 20x leverage

            const initBalance = Number(
                (
                    await Account.getAccountAssets(
                        SUI_CLIENT,
                        PARSER.getInternalDataStore(),
                        ADMIN.toSuiAddress()
                    )
                )[0].quantity
            );

            const oraclePrice = 51;
            const liquidationQuantity = 1;

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.toSuiAddress(),
                marketName,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                toBigNumberStr(liquidationQuantity, SUI_NATIVE_BASE)
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 0 });
            expectPosition(liquidationEvent.liquidatee_position, { size: 0, margin: 0 });
            expectPosition(liquidationEvent.liquidator_position, {
                size: 1,
                entryPrice: oraclePrice,
                margin: 0,
                side: "LONG"
            });

            expect(liquidationEvent.bankruptcy_price).to.be.equal("50020000000");
            expect(liquidationEvent.liq_purchase_price).to.be.equal("50240000000");
            expect(+liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                225000000
            );

            expect(+liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                initBalance + 562000000
            );
        });

        it("should successfully liquidate a cross position partially and assume it as cross", async () => {
            // Alice has 50$ in her account
            // Has an open position of size 1 at price 100 - she has 2x leverage to start  with
            // There is just one position in her account for ETH that allows 20x leverage
            const oraclePrice = 51;
            const liquidationQuantity = 0.5;

            const initBalance = Number(
                (
                    await Account.getAccountAssets(
                        SUI_CLIENT,
                        PARSER.getInternalDataStore(),
                        ADMIN.toSuiAddress()
                    )
                )[0].quantity
            );

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.toSuiAddress(),
                marketName,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                toBigNumberStr(liquidationQuantity, SUI_NATIVE_BASE)
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 0 });
            expectPosition(liquidationEvent.liquidatee_position, {
                size: 0.5,
                margin: 0
            });
            expectPosition(liquidationEvent.liquidator_position, {
                size: liquidationQuantity,
                entryPrice: oraclePrice,
                margin: 0,
                side: "LONG"
            });

            expect(+liquidationEvent.bankruptcy_price).to.be.equal(50020000000);
            expect(+liquidationEvent.liq_purchase_price).to.be.equal(50240000000);
            expect(+liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                25105000000
            );

            expect(+liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                initBalance + 296000000
            );
        });

        it("should successfully liquidate a bankrupt cross position", async () => {
            // Alice has 50$ in her account
            // Has an open position of size 1 at price 100 - she has 2x leverage to start  with
            // There is just one position in her account for ETH that allows 20x leverage

            const initBalance = Number(
                (
                    await Account.getAccountAssets(
                        SUI_CLIENT,
                        PARSER.getInternalDataStore(),
                        ADMIN.toSuiAddress()
                    )
                )[0].quantity
            );

            const oraclePrice = 50;
            const liquidationQuantity = 1;

            oraclePrices = [
                {
                    perpetual: marketName,
                    price: toBigNumber(oraclePrice, SUI_NATIVE_BASE)
                }
            ];

            const payload = await bluefinV3.requests.createSignedLiquidation(
                alice.toSuiAddress(),
                marketName,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                toBigNumberStr(liquidationQuantity, SUI_NATIVE_BASE)
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const txResult = await bluefinV3.sequencer.performLiquidation(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { txBlock: txb, dryRun: true }
            );

            const tradeEvent = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expectPosition(tradeEvent.maker.position, { size: 1, margin: 0 });
            expectPosition(liquidationEvent.liquidatee_position, { size: 0, margin: 0 });
            expectPosition(liquidationEvent.liquidator_position, {
                size: liquidationQuantity,
                entryPrice: oraclePrice,
                margin: 0,
                side: "LONG"
            });

            expect(+liquidationEvent.bankruptcy_price).to.be.equal(50020000000);
            expect(+liquidationEvent.liq_purchase_price).to.be.equal(
                +toBigNumberStr(oraclePrice, SUI_NATIVE_BASE)
            );
            expect(+liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(0);

            expect(+liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                initBalance + 15000000
            );
        });
    });

    describe("More Liquidations", async () => {
        const [alice, bob] = getTestAccounts(true);
        const [liquidator] = getTestAccounts(true);
        const btcPerp = `TEST_BTC`;
        const ethPerp = `TEST_ETH`;
        let txb: TransactionBlock;

        before(async () => {
            await SIMULATOR.init();
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address, {
                exactAmount: 50
            });
            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address, {
                exactAmount: 10_000
            });
            await provideMarginToAccount(bluefinV3, SIMULATOR, liquidator.address, {
                exactAmount: 200_000
            });
            await setLiquidator(bluefinV3, liquidator.address, true);

            const imr = toBigNumberStr(0.05, SUI_NATIVE_BASE);
            const mmr = toBigNumberStr(0.025, SUI_NATIVE_BASE);
            const minTradeQty = toBigNumberStr(0.00001, SUI_NATIVE_BASE);
            const stepSize = minTradeQty;

            if ((await bluefinV3.getPerpetualFromIDS(btcPerp)) == undefined) {
                await createPerpetual(bluefinV3, {
                    symbol: btcPerp,
                    imr,
                    mmr,
                    minTradeQty,
                    stepSize,
                    makerFee: 0,
                    takerFee: 0
                    // Max funding allowed is 5% on contract level. Update MAX_FUNDING_RATE on contract to allow this
                    // maxFundingRate: toBigNumberStr(0.01, SUI_NATIVE_BASE)
                });
            }

            if ((await bluefinV3.getPerpetualFromIDS(ethPerp)) == undefined) {
                await createPerpetual(bluefinV3, {
                    symbol: ethPerp,
                    imr,
                    mmr,
                    minTradeQty,
                    stepSize,
                    makerFee: 0,
                    takerFee: 0
                    // Max funding allowed is 5% on contract level. Update MAX_FUNDING_RATE on contract to allow this
                    // maxFundingRate: toBigNumberStr(0.01, SUI_NATIVE_BASE)
                });
            }
        });

        beforeEach(async () => {
            txb = new TransactionBlock();
            await bluefinV3.simulator.init();
        });

        describe.skip("Liquidations with Pending Funding Payments", async () => {
            describe("Cross", async () => {
                beforeEach(async () => {
                    txb = new TransactionBlock();
                    await bluefinV3.simulator.init();

                    await setupTrade(bluefinV3, txb, {
                        oraclePrice: 1_00,
                        executionPrice: 1_00,
                        perpetual: btcPerp,
                        quantity: 1,
                        makerSide: "LONG",
                        maker: {
                            signer: alice.signer,
                            positionType: POSITION_TYPES.CROSS
                        },
                        taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
                    });

                    // set funding rate positive 70%
                    // since Alice has positive (long) position and funding rate is +70%, she will be
                    // paying the funding payment
                    const payload = await bluefinV3.requests.setFundingRate([
                        {
                            market: btcPerp,
                            value: toBigNumberStr(0.7, SUI_NATIVE_BASE),
                            sign: true,
                            oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
                        }
                    ]);

                    const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                        base64ToHex(payload.signature)
                    );

                    txb = (await bluefinV3.sequencer.setFundingRate(
                        payload.serializedData,
                        payload.signature,
                        sequenceHash,
                        Date.now(),
                        { txBlock: txb, returnTxb: true }
                    )) as TransactionBlock;

                    // apply funding rate to Alice
                    const payload2 = await bluefinV3.requests.applyFundingRate([
                        alice.address
                    ]);

                    const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                        payload2.serializedData
                    );

                    // Alice has 50$ in her account
                    // Alice has 1 size position opened at price 100
                    // The current mark price is 100
                    // The notional value of position is 100
                    // The funding rate is positive 70%
                    // since position is long and funding rate is also positive, Alice has to pay funding amount
                    // The funding payment is 0.7 * 100 = 70$
                    // Alice has 50$ in her account so after applying funding rate, her account balance becomes ZERO and pending funding 20$
                    txb = (await bluefinV3.sequencer.applyFundingRate(
                        payload2.serializedData,
                        sequenceHash2,
                        Date.now(),
                        { txBlock: txb, returnTxb: true }
                    )) as TransactionBlock;
                });

                it("should bankrupt liquidate alice due to her negative funding payment despite no change in oracle price (CROSS)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(100, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.CROSS,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                        "0"
                    );
                    expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                        "199980000000000"
                    );
                });

                it("should bankrupt liquidate alice due to her negative funding payment when she actually has a positive Pnl on the position (CROSS)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(120, SUI_NATIVE_BASE)
                        }
                    ];

                    // At the time of liquidation the oracle/mark price is 120 so alice has an unrealized Pnl of 20$
                    // That makes her account value: 0 (assets) + 20$ (pnl) - 20$ (pending funding payment) = 0
                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.CROSS,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                        "0"
                    );
                    expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                        "200000000000000"
                    );
                });

                it("should bankrupt liquidate alice due to her negative funding payment when she has a negative Pnl on the position (CROSS)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(80, SUI_NATIVE_BASE)
                        }
                    ];

                    // At the time of liquidation the oracle/mark price is 80 so alice has an unrealized Pnl of 20$
                    // That makes her account value: 0 (assets) - 20$ (pnl) - 20$ (pending funding payment) = -40$
                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.CROSS,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    // console.log(+liquidationEvent.premium_or_debt.value / 1e9, liquidationEvent.premium_or_debt.sign);
                    // console.log("liq_purchase_price:", +liquidationEvent.liq_purchase_price / 1e9);
                    // console.log("bankruptcy_price:", +liquidationEvent.bankruptcy_price / 1e9);
                    // console.log("liquidatee position", liquidationEvent.liquidatee_position);

                    expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                        "0"
                    );
                    expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                        "199960000000000"
                    );
                });

                it("the liquidator should pay partial pending funding payment when taking over partial position as bankrupt liquidation (CROSS)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(100, SUI_NATIVE_BASE)
                        }
                    ];

                    // At the time of liquidation the oracle/mark price is 100 so alice has an unrealized Pnl of 0$
                    // That makes her account value: 0 (assets) - 0$ (pnl) - 20$ (pending funding payment) = -40$
                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.CROSS,
                        ASSUME_AS.CROSS,
                        0.6, // assuming 0.6 size
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                        "0"
                    );
                    expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                        "199988000000000"
                    );
                });

                it("should standard Liquidate alice due to her negative funding payment despite her position being in a positive Pnl (CROSS)", async () => {
                    // Alice started with 50$ account balance
                    // She has a 1 size long BTC position Opened at 100$ mark price
                    // She has right now 0$ asset and -20$ pending funding payment
                    // At the time of liquidation the oracle price is 122$, allowing
                    // Alice to cover for -negative funding payment using the realized Pnl but not
                    // enough to save her from liquidation.
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(122, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.CROSS,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(+liquidationEvent.liq_purchase_price / 1e9).to.be.equal(
                        120.475
                    );
                    expect(+liquidationEvent.bankruptcy_price / 1e9).to.be.equal(120);

                    // 70% of the premium that went to liquidator 1.0675
                    expect(+liquidationEvent.premium_or_debt.value / 1e9).to.be.equal(
                        1.0675
                    );

                    // 30% of the premium that went to insurance pool
                    expect(
                        +liquidationEvent.insurance_pool_premium_portion / 1e9
                    ).to.be.equal(0.4575);

                    // the discount that user/alice got due to standard liquidation
                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(0.475);

                    // liquidator had 200K before the liquidation should
                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(200001.0675);
                });
            });

            describe("Isolated", async () => {
                beforeEach(async () => {
                    txb = new TransactionBlock();
                    await bluefinV3.simulator.init();

                    await setupTrade(bluefinV3, txb, {
                        oraclePrice: 1_00,
                        executionPrice: 1_00,
                        perpetual: btcPerp,
                        quantity: 1,
                        makerSide: "LONG",
                        maker: {
                            signer: alice.signer,
                            positionType: POSITION_TYPES.ISOLATED,
                            leverage: 4
                        },
                        taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
                    });

                    // set funding rate positive 70%
                    // since Alice has positive (long) position and funding rate is +70%, she will be
                    // paying the funding payment
                    const payload = await bluefinV3.requests.setFundingRate([
                        {
                            market: btcPerp,
                            value: toBigNumberStr(0.7, SUI_NATIVE_BASE),
                            sign: true,
                            oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
                        }
                    ]);

                    const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                        base64ToHex(payload.signature)
                    );

                    txb = (await bluefinV3.sequencer.setFundingRate(
                        payload.serializedData,
                        payload.signature,
                        sequenceHash,
                        Date.now(),
                        { txBlock: txb, returnTxb: true }
                    )) as TransactionBlock;

                    // apply funding rate to Alice
                    const payload2 = await bluefinV3.requests.applyFundingRate([
                        alice.address
                    ]);

                    const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                        payload2.serializedData
                    );

                    // Alice has 50$ in her account
                    // Alice has 1 size position opened at price 100
                    // The current mark price is 100
                    // The notional value of position is 100
                    // The funding rate is positive 70%
                    // since position is long and funding rate is also positive, Alice has to pay funding amount
                    // The funding payment is 0.7 * 100 = 70$
                    // Alice's position was opened at 4x leverage i.e. there are 25$ margin in her BTC isolated position
                    // So after applying funding rate, her position margin becomes ZERO and pending funding 45$
                    txb = (await bluefinV3.sequencer.applyFundingRate(
                        payload2.serializedData,
                        sequenceHash2,
                        Date.now(),
                        { txBlock: txb, returnTxb: true }
                    )) as TransactionBlock;
                });

                it("should bankrupt liquidate Alice due to her negative funding payment despite no change in oracle price (ISOLATED)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(100, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.ISOLATED,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(
                        +liquidationEvent.liquidatee_position.margin / 1e9
                    ).to.be.equal(0);

                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(25);
                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(199955);
                });

                it("should bankrupt liquidate alice due to her negative funding payment when she actually has a positive Pnl on the position (ISOLATED)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(145, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.ISOLATED,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(25);
                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(200000);
                });

                it("should bankrupt liquidate alice due to her negative funding payment when she has a negative Pnl on the position (ISOLATED)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(80, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.ISOLATED,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(25);
                    // liquidator pays for -45 pending funding and -20$ loss by Alice
                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(199935);
                });

                it("the liquidator should pay partial pending funding payment when taking over partial position as bankrupt liquidation (ISOLATED)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(100, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.ISOLATED,
                        ASSUME_AS.CROSS,
                        0.6,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(25);
                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(199973);
                });

                it("should standard Liquidate alice due to her negative funding payment despite her position being in a positive Pnl (ISOLATED)", async () => {
                    oraclePrices = [
                        {
                            perpetual: btcPerp,
                            price: toBigNumber(147, SUI_NATIVE_BASE)
                        }
                    ];

                    await setupLiquidation(
                        bluefinV3,
                        txb,
                        oraclePrices,
                        alice.address,
                        liquidator.address,
                        btcPerp,
                        POSITION_TYPES.ISOLATED,
                        ASSUME_AS.CROSS,
                        1,
                        liquidator.signer
                    );

                    const txResult = await SuiBlocks.dryRunTxBlock(
                        txb,
                        SUI_CLIENT,
                        ADMIN
                    );

                    expect(Transaction.getStatus(txResult) == "success").to.be.true;

                    const liquidationEvent = Transaction.getEvents(
                        txResult,
                        "LiquidationExecuted"
                    )[0] as ILiquidationExecutedEvent;

                    expect(+liquidationEvent.liq_purchase_price / 1e9).to.be.equal(
                        145.1625
                    );
                    expect(+liquidationEvent.bankruptcy_price / 1e9).to.be.equal(145);

                    expect(+liquidationEvent.premium_or_debt.value / 1e9).to.be.equal(
                        1.28625
                    );

                    expect(
                        +liquidationEvent.insurance_pool_premium_portion / 1e9
                    ).to.be.equal(0.55125);

                    expect(
                        +liquidationEvent.liquidatee_assets[0].quantity / 1e9
                    ).to.be.equal(25.1625);

                    expect(
                        +liquidationEvent.liquidator_assets[0].quantity / 1e9
                    ).to.be.equal(200001.28625);
                });
            });
        });

        xit("should be able to liquidate btc position as standard liquidation - long", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_600,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(57_100, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2_460, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal(
                "13862500000"
            );
            expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                "200004996250000"
            );
        });

        xit("should be able to liquidate btc position as standard liquidation - short", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "SHORT",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_500,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "SHORT",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(65_950, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2_200, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            )[0] as ILiquidationExecutedEvent;

            expect(liquidationEvent.liquidatee_assets[0].quantity).to.be.equal("0");
            expect(liquidationEvent.liquidator_assets[0].quantity).to.be.equal(
                "200005770625000"
            );
        });

        xit("should be able to liquidate the btc position but revert on eth as the account is now healthy", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_600,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(57_100, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2_460, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            await expect(
                SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
            ).to.be.eventually.rejectedWith("1042");
        });

        xit("should be able to liquidate both btc and eth positions before bankruptcy", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_600,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(56_200, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2460, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expect(liquidationEvent[1].liquidatee_assets[0].quantity == "0").to.be.true;
            expect(liquidationEvent[1].liquidator_assets[0].quantity == "200005600000000")
                .to.be.true;
        });

        it("should be able to liquidate both btc and eth positions before bankruptcy", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_600,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(54_600, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2460, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expect(liquidationEvent[1].liquidatee_assets[0].quantity == "0").to.be.true;
            expect(liquidationEvent[1].liquidator_assets[0].quantity == "199992000000000")
                .to.be.true;
        });

        it("Y3.2 should be able to liquidate both btc and eth positions after the account becomes bankrupt", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "SHORT",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_500,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "SHORT",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(67_000, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(2_350, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expect(liquidationEvent[0].liquidatee_assets[0].quantity == "65000000000").to
                .be.true;
            expect(liquidationEvent[0].liquidator_assets[0].quantity == "200000000000000")
                .to.be.true;

            expect(liquidationEvent[1].liquidatee_assets[0].quantity == "0").to.be.true;
            expect(liquidationEvent[1].liquidator_assets[0].quantity == "199995000000000")
                .to.be.true;
        });

        it("Examples A: Case 3 (Below Maintenance) Liquidation", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_500,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            // no change in oracle price
            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(63_000, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(1_800, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expect(liquidationEvent[0].liquidator_assets[0].quantity).to.be.equal(
                "200005512500000"
            );

            expect(liquidationEvent[1].liquidator_assets[0].quantity).to.be.equal(
                "200007000000000"
            );
        });

        it("Examples A: Case 4 (Bankrupt) Liquidation", async () => {
            await setupTrade(bluefinV3, txb, {
                oraclePrice: 60_000,
                executionPrice: 60_000,
                perpetual: btcPerp,
                quantity: 0.01,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            await setupTrade(bluefinV3, txb, {
                oraclePrice: 2_500,
                executionPrice: 2_500,
                perpetual: ethPerp,
                quantity: 0.1,
                makerSide: "LONG",
                maker: { signer: alice.signer, positionType: POSITION_TYPES.CROSS },
                taker: { signer: bob.signer, positionType: POSITION_TYPES.CROSS }
            });

            // no change in oracle price
            oraclePrices = [
                {
                    perpetual: btcPerp,
                    price: toBigNumber(63_000, SUI_NATIVE_BASE)
                },
                {
                    perpetual: ethPerp,
                    price: toBigNumber(1_600, SUI_NATIVE_BASE)
                }
            ];

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                btcPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.01,
                liquidator.signer
            );

            await setupLiquidation(
                bluefinV3,
                txb,
                oraclePrices,
                alice.address,
                liquidator.address,
                ethPerp,
                POSITION_TYPES.CROSS,
                ASSUME_AS.CROSS,
                0.1,
                liquidator.signer
            );

            const txResult = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

            expect(Transaction.getStatus(txResult) == "success").to.be.true;

            const liquidationEvent = Transaction.getEvents(
                txResult,
                "LiquidationExecuted"
            ) as ILiquidationExecutedEvent[];

            expect(liquidationEvent[0].liquidator_assets[0].quantity).to.be.equal(
                "200000000000000"
            );

            expect(liquidationEvent[1].liquidator_assets[0].quantity).to.be.equal(
                "199990000000000"
            );
        });
    });
});
