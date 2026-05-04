import { expect, expectPosition, provideMarginToAccount } from "./helpers/utils";
import { bluefinV3, SIMULATOR } from "../env";
import { getTestAccounts, SUI_NATIVE_BASE } from "../library-sui/dist";
import {
    toBigNumber,
    toBigNumberStr,
    Transaction,
    REQUEST_LIFESPAN,
    ADDRESSES,
    SuiBlocks,
    hexStrToUint8,
    bigNumber
} from "../library-sui/src";
import {
    Account,
    IBatchTrade,
    ICompleteOrder,
    IOraclePriceUpdate,
    IRequestPayload,
    ISignedOrder,
    ITradeExecutedEvent
} from "../library-sui/src/v3";
import { POSITION_TYPES } from "../library-sui/src/v3/enums";
import { blake2b } from "@noble/hashes/blake2b";

describe("Trades", () => {
    const [alice, bob] = getTestAccounts(true);
    let oraclePrices = [
        {
            perpetual: "ETH-PERP",
            price: toBigNumber(100, SUI_NATIVE_BASE)
        },
        {
            perpetual: "BTC-PERP",
            price: toBigNumber(100, SUI_NATIVE_BASE)
        }
    ] as Array<IOraclePriceUpdate>;

    before(async () => {
        await SIMULATOR.init();
        await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address);
        await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address);
    });

    beforeEach(async () => {
        await SIMULATOR.init();
    });

    describe("Order validation reversions", async () => {
        let makerPayload: IRequestPayload;
        let takerPayload: IRequestPayload;
        let quantity = toBigNumber(1, SUI_NATIVE_BASE);
        const timestamp = Date.now();
        const sequenceHash = "1";
        beforeEach(async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", quantity: 1, price: 100 },
                { signer: alice.signer }
            );
            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", quantity: 1, price: 100 },
                { signer: bob.signer }
            );
        });

        it("should revert as self trade is not allowed", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    makerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1058");
        });

        it("should revert as the maker or taker order is signed for some other IDS", async () => {
            takerPayload = await bluefinV3.requests.createSignedOrder({
                ids: ADDRESSES.ZERO,
                side: "SHORT"
            });

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1006");
        });

        it("should revert as the maker and taker order are not for the same market", async () => {
            // using alice address as the address of market for taker
            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", market: bob.address },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1021");
        });

        it("should revert when the targeted perpetual does not exist on protocol", async () => {
            // using alice address as the address of market
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", market: alice.address },
                { signer: alice.signer }
            );
            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", market: alice.address },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1009");
        });

        it("should revert when maker and taker orders are of same direction", async () => {
            // using alice address as the address of market
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG" },
                { signer: alice.signer }
            );
            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG" },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1025");
        });

        it("should revert as the maker has no account on exchange as they never deposited any funds", async () => {
            // using address of eth perp as maker
            makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    account: bluefinV3.parser.getPerpetualAddress("ETH-PERP")
                },
                { signer: alice.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,

                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1016");
        });

        it("should revert as trading is not permitted on the perpetual at the moment", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    // providing an old ts before the trade start time
                    Date.now() - 86400000,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1024");
        });

        it("should revert as trade quantity is < min tradeable quantity", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(0.0001, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        it("should revert as trade quantity is > max tradeable quantity", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(10000000, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        it("should revert as trade quantity is doesn't conform to step size", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(100.0000001, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        it("should revert as trade price is < min tradeable", async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 10 },
                { signer: alice.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1029");
        });

        it("should revert as trade price is > max tradeable price", async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 100000000 },
                { signer: alice.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1029");
        });

        it("should revert as trade price doesn't conform to tick size", async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 100.0000001 },
                { signer: alice.signer }
            );
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1029");
        });

        it("should revert as the taker order is going LONG beyond the accepted market take bound", async () => {
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;

            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 121, quantity: 1 },
                { signer: alice.signer }
            );

            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 121, quantity: 1 },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1031");
        });

        it("should revert as the taker order is going SHORT beyond the accepted market take bound", async () => {
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(100, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;

            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 75, quantity: 1 },
                { signer: alice.signer }
            );
            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 75, quantity: 1 },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1031");
        });

        it("should revert as the maker order is expired", async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 100, expiration: Date.now() - 86400000 },
                { signer: alice.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1027");
        });

        it("should revert as the maker order was signed more than 3 months ago", async () => {
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 100 },
                { signer: alice.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    Date.now() + 1000 + REQUEST_LIFESPAN,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should revert as signature could not be verified - The maker order payload was modified", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    // changing the quantity of order
                    {
                        ...(makerPayload.rawData as ISignedOrder),
                        quantity: toBigNumberStr(0.02, SUI_NATIVE_BASE)
                    },
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith(/2003/i);
        });

        it("should revert as signature could not be verified - The taker order payload was modified", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    // changing the quantity of order
                    {
                        ...(takerPayload.rawData as ISignedOrder),
                        quantity: toBigNumberStr(0.02, SUI_NATIVE_BASE)
                    },
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith(/2003/i);
        });

        it("should revert as signature could not be verified - The maker and taker signatures were switched", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    {
                        ...(makerPayload.rawData as ISignedOrder),
                        signature: takerPayload.signature
                    },
                    {
                        ...(takerPayload.rawData as ISignedOrder),
                        signature: makerPayload.signature
                    },
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith(/2003/i);
        });

        it("should revert as signature could not be verified - The maker signature is invalid", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    {
                        ...(makerPayload.rawData as ISignedOrder),
                        signature: "42" + makerPayload.signature.slice(2)
                    },
                    takerPayload.rawData as ISignedOrder,
                    quantity,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith(/2002/i);
        });

        it("should revert as Bob does not have permission to sign orders for Alice", async () => {
            // Bob signing order for alice
            makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 101, account: alice.address },
                { signer: bob.signer }
            );

            takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 101, quantity: 0.1 },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(0.1, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1014");
        });

        it("should revert as the fill price is not valid for the SHORT side order", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 101, quantity: 0.1 },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 103, quantity: 0.1 },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(0.1, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1026");
        });

        it("should revert as the fill price is not valid for LONG side order", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 101, quantity: 0.1 },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 99, quantity: 0.1 },
                { signer: bob.signer }
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(0.1, SUI_NATIVE_BASE),
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1026");
        });

        it("should revert as the maker order is getting over filled", async () => {
            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    toBigNumber(2, SUI_NATIVE_BASE), // both maker and taker orders are of 1 quantity
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1028");
        });

        it("should succeed when placing cross order with non-zero leverage", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 100,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS,
                    leverage: 1
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                false
            );

            await bluefinV3.sequencer.performTrade(
                makerPayload.rawData as ISignedOrder,
                takerPayload.rawData as ISignedOrder,
                fill,
                oraclePrices,
                sequenceHash,
                timestamp,
                { dryRun: true }
            );
        });

        it("should revert as isolated order must have leverage > 0 ", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 0
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                false
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    fill,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1022");
        });

        it("should revert as isolated order leverage is a floating value", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2.3
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                false
            );

            await expect(
                bluefinV3.sequencer.performTrade(
                    makerPayload.rawData as ISignedOrder,
                    takerPayload.rawData as ISignedOrder,
                    fill,
                    oraclePrices,
                    sequenceHash,
                    timestamp,

                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1022");
        });
    });

    describe("Cross Trades", async () => {
        before(() => {
            // Oracle price will be 2000
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ];
        });

        it("should successfully execute a trade between two cross orders and open a new position for both Alice and Bob", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                false
            );

            const txResult = await bluefinV3.sequencer.performTrade(
                makerPayload.rawData as ISignedOrder,
                takerPayload.rawData as ISignedOrder,
                fill,
                oraclePrices,
                sequenceHash,
                timestamp,
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;
            expect(event.fill_price).to.be.equal(toBigNumberStr(2000, SUI_NATIVE_BASE));
            expect(event.fill_quantity).to.be.equal(fill);
            expectPosition(event.taker.position, {
                size: 50,
                entryPrice: 2000,
                margin: 0,
                side: "LONG"
            });
        });

        it("should successfully execute a trade between two cross orders and increase position sizes for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 10 },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 10 },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(10, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];
            expectPosition(event1.taker.position, {
                size: 50,
                entryPrice: 2000,
                side: "LONG"
            });
            expectPosition(event2.taker.position, {
                size: 60,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should successfully execute a trade between two cross orders and decrease position sizes for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 10 },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 10 },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(10, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expectPosition(event1.taker.position, {
                size: 50,
                entryPrice: 2000,
                side: "LONG"
            });
            expectPosition(event2.taker.position, {
                size: 40,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should successfully perform a filliping trade for cross positions", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 70 },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 70 },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(70, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expectPosition(event1.maker.position, {
                size: 50,
                entryPrice: 2000,
                side: "SHORT"
            });
            expectPosition(event2.maker.position, {
                size: 20,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should revert as Alice's maker order is getting over filled", async () => {
            const aliceBalance = await Account.getAccountMargin(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                alice.address
            );
            const bobBalance = await Account.getAccountMargin(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                alice.address
            );

            expect(aliceBalance).to.be.equal(10_000);
            expect(bobBalance).to.be.equal(10_000);

            // Oracle price will be 2000
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ];

            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 30 },
                { signer: bob.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 30 },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(30, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload2.serializedData,
                fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            await expect(
                bluefinV3.sequencer.performTradeBatch(
                    [
                        {
                            makerOrder: makerPayload1.rawData as ISignedOrder,
                            takerOrder: takerPayload1.rawData as ISignedOrder,
                            quantity: fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade1
                        },
                        {
                            makerOrder: makerPayload1.rawData as ISignedOrder,
                            takerOrder: takerPayload2.rawData as ISignedOrder,
                            quantity: fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade2
                        } // can just have `1028` but `in command 1` ensures that the error occured in 2nd transaction
                    ],
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1028) in command 1");
        });

        it("should successfully open and close a cross position for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[1] as ITradeExecutedEvent;

            expectPosition(event.maker.position, { size: 0 });
            expectPosition(event.taker.position, { size: 0 });
        });

        it("should revert as the trade is being replayed", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 50 },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 50 },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                fill,
                timestamp,
                false
            );

            await expect(
                bluefinV3.sequencer.performTradeBatch(
                    [
                        {
                            makerOrder: makerPayload1.rawData as ISignedOrder,
                            takerOrder: takerPayload1.rawData as ISignedOrder,
                            quantity: fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade
                        },
                        {
                            makerOrder: makerPayload1.rawData as ISignedOrder,
                            takerOrder: takerPayload1.rawData as ISignedOrder,
                            quantity: fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade
                        }
                    ],
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1011");
        });
    });

    describe("Isolated Trades", async () => {
        before(() => {
            // Oracle price will be 2000
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ];
        });

        it("should successfully execute a trade between two isolated orders and open a new position for both Alice and Bob", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
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
                false
            );

            const txResult = await bluefinV3.sequencer.performTrade(
                makerPayload.rawData as ISignedOrder,
                takerPayload.rawData as ISignedOrder,
                fill,
                oraclePrices,
                sequenceHash,
                timestamp,

                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[0] as ITradeExecutedEvent;
            expect(event.fill_price).to.be.equal(toBigNumberStr(2000, SUI_NATIVE_BASE));
            expect(event.fill_quantity).to.be.equal(fill);

            expectPosition(event.taker.position, {
                size: 1,
                entryPrice: 2000,
                margin: 1000,
                side: "LONG",
                isolated: true
            });
        });

        it("should successfully execute a trade between two isolated orders and increase position sizes for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 2,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 2,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(1, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(2, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];
            expectPosition(event1.taker.position, {
                size: 1,
                entryPrice: 2000,
                side: "LONG"
            });
            expectPosition(event2.taker.position, {
                size: 3,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should successfully execute a trade between two isolated orders and decrease position sizes for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 3,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 3,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 2
                },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(3, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(1, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expectPosition(event1.taker.position, {
                size: 3,
                entryPrice: 2000,
                side: "LONG"
            });
            expectPosition(event2.taker.position, {
                size: 2,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should successfully perform a filliping trade for isolated position", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 70,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 70,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(70, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expectPosition(event1.maker.position, {
                size: 50,
                entryPrice: 2000,
                side: "SHORT"
            });
            expectPosition(event2.maker.position, {
                size: 20,
                entryPrice: 2000,
                side: "LONG"
            });
        });

        it("should successfully open and close an isolated position for both Alice and Bob", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 20
                },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(50, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            )[1] as ITradeExecutedEvent;

            expectPosition(event.maker.position, { size: 0 });
            expectPosition(event.taker.position, { size: 0 });
        });

        it("should successfully open an isolated position at a leverage > max allowed leverage when the position is not in margin call", async () => {
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 25
                },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.ISOLATED,
                    leverage: 25
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
                false
            );

            await bluefinV3.sequencer.performTrade(
                makerPayload.rawData as ISignedOrder,
                takerPayload.rawData as ISignedOrder,
                fill,
                oraclePrices,
                sequenceHash,
                timestamp,

                { dryRun: true }
            );
        });
    });

    describe("Cross & Isolated Positions", async () => {
        before(() => {
            // Oracle price will be 2000
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                },
                {
                    perpetual: "BTC-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ];
        });

        it("should open a cross and isolated position for Alice and Bob on ETH/BTC perpetual - I", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 1,
                    leverage: 2,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 1,
                    leverage: 2,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: bob.signer }
            );

            const tradeFill = toBigNumberStr(1, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                tradeFill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                tradeFill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: tradeFill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: tradeFill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];
            expectPosition(event1.taker.position, {
                size: 1,
                entryPrice: 2000,
                side: "LONG",
                isolated: false,
                margin: 0
            });
            expectPosition(event2.taker.position, {
                size: 1,
                entryPrice: 2000,
                side: "LONG",
                isolated: true,
                margin: 1000
            });
        });

        it("should open a cross and isolated position for Alice and Bob on ETH perpetual - II", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 10,
                    leverage: 10,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 10,
                    leverage: 10,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: bob.signer }
            );

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(10, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            const txResult = await bluefinV3.sequencer.performTradeBatch(
                [
                    {
                        makerOrder: makerPayload1.rawData as ISignedOrder,
                        takerOrder: takerPayload1.rawData as ISignedOrder,
                        quantity: trade1Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade1
                    },
                    {
                        makerOrder: makerPayload2.rawData as ISignedOrder,
                        takerOrder: takerPayload2.rawData as ISignedOrder,
                        quantity: trade2Fill,
                        timestamp,
                        oraclePrices,
                        sequenceHash: sequenceHashTrade2
                    }
                ],
                { dryRun: true }
            );

            const [event1, event2] = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];
            expectPosition(event1.taker.position, {
                size: 50,
                entryPrice: 2000,
                side: "LONG",
                isolated: false,
                margin: 0
            });
            expectPosition(event2.taker.position, {
                size: 10,
                entryPrice: 2000,
                side: "LONG",
                isolated: true,
                margin: 2000
            });
        });

        it("should revert when trying to open an isolated position as the cross position gets undercollat", async () => {
            const makerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload1 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 50,
                    positionType: POSITION_TYPES.CROSS,
                    market: "ETH-PERP"
                },
                { signer: bob.signer }
            );

            const makerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "SHORT",
                    price: 2000,
                    quantity: 60,
                    leverage: 20,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: alice.signer }
            );
            const takerPayload2 = await bluefinV3.requests.createSignedOrder(
                {
                    side: "LONG",
                    price: 2000,
                    quantity: 60,
                    leverage: 20,
                    positionType: POSITION_TYPES.ISOLATED,
                    market: "BTC-PERP"
                },
                { signer: bob.signer }
            );

            // cross:
            // 2000 * 50 = 100,000 position value
            // margin required at 20x = 5000
            // isolated:
            // 2000 * 60 = 120,000 position value
            // margin required at 20x = 6000 <- user only has 5000$ free collat so will revert

            const trade1Fill = toBigNumberStr(50, SUI_NATIVE_BASE);
            const trade2Fill = toBigNumberStr(60, SUI_NATIVE_BASE);

            const timestamp = Date.now();

            const sequenceHashTrade1 = SIMULATOR.performTrade(
                makerPayload1.serializedData,
                takerPayload1.serializedData,
                trade1Fill,
                timestamp,
                false
            );

            const sequenceHashTrade2 = SIMULATOR.performTrade(
                makerPayload2.serializedData,
                takerPayload2.serializedData,
                trade2Fill,
                timestamp,
                false,
                sequenceHashTrade1
            );

            await expect(
                bluefinV3.sequencer.performTradeBatch(
                    [
                        {
                            makerOrder: makerPayload1.rawData as ISignedOrder,
                            takerOrder: takerPayload1.rawData as ISignedOrder,
                            quantity: trade1Fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade1
                        },
                        {
                            makerOrder: makerPayload2.rawData as ISignedOrder,
                            takerOrder: takerPayload2.rawData as ISignedOrder,
                            quantity: trade2Fill,
                            timestamp,
                            oraclePrices,
                            sequenceHash: sequenceHashTrade2
                        }
                    ],
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("4002");
        });
    });

    describe("Batch Trade", async () => {
        const oraclePrices: IOraclePriceUpdate[] = [
            {
                perpetual: "ETH-PERP",
                price: toBigNumberStr(2000, SUI_NATIVE_BASE)
            }
        ];

        let batchTrade: IBatchTrade;
        let sequenceHash: string;
        let batchHash: string;

        beforeEach(async () => {
            await bluefinV3.simulator.init();

            const trades: any[] = [];

            for (let i = 0; i < 4; i++) {
                const makerOrder = await bluefinV3.requests.createSignedOrder(
                    {
                        quantity: 0.01,
                        price: 2000,
                        market: "ETH-PERP",
                        side: "LONG",
                        positionType: POSITION_TYPES.CROSS,
                        account: alice.address
                    },
                    {
                        signer: alice.signer
                    }
                );

                const takerOrder = await bluefinV3.requests.createSignedOrder(
                    {
                        quantity: 0.01,
                        price: 2000,
                        market: "ETH-PERP",
                        side: "SHORT",
                        positionType: POSITION_TYPES.CROSS,
                        account: bob.address
                    },
                    {
                        signer: bob.signer
                    }
                );

                trades.push({ makerOrder, takerOrder, fill: 0.01 });
            }

            batchTrade = {
                makerOrders: trades.map((p: any) => {
                    return {
                        ...p.makerOrder.rawData,
                        serialized: p.makerOrder.serializedData
                    } as ICompleteOrder;
                }),
                takerOrders: trades.map((p: any) => {
                    return {
                        ...p.takerOrder.rawData,
                        serialized: p.takerOrder.serializedData
                    } as ICompleteOrder;
                }),
                fills: trades.map((p: any) => toBigNumberStr(p.fill, SUI_NATIVE_BASE))
            };

            batchHash = Buffer.from(
                blake2b(hexStrToUint8(JSON.stringify(batchTrade)), { dkLen: 32 })
            ).toString("hex");

            sequenceHash = bluefinV3.simulator.computeSequenceHash(batchHash);
        });
        it("should successfully perform a batch trade with default gas fee", async () => {
            const txb = bluefinV3.txBuilder.performBatchTrade(
                batchTrade,
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => bigNumber(op.price).toFixed(0)),
                batchHash,
                sequenceHash,
                Date.now()
            );

            const txResult = await SuiBlocks.dryRunTxBlock(
                txb,
                bluefinV3.suiClient,
                bluefinV3.signer
            );

            expect(Transaction.getStatus(txResult)).to.equal("success");

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expect(event[0].taker_gas_fee).to.be.equal("30000000");
        });

        it("should successfully perform a batch trade with provided gas fee", async () => {
            const txb = bluefinV3.txBuilder.performBatchTrade(
                batchTrade,
                oraclePrices.map(op => op.perpetual),
                oraclePrices.map(op => bigNumber(op.price).toFixed(0)),
                batchHash,
                sequenceHash,
                Date.now(),
                { gasFee: "100000000" }
            );

            const txResult = await SuiBlocks.dryRunTxBlock(
                txb,
                bluefinV3.suiClient,
                bluefinV3.signer
            );

            expect(Transaction.getStatus(txResult)).to.equal("success");

            const event = Transaction.getEvents(
                txResult,
                "TradeExecuted"
            ) as ITradeExecutedEvent[];

            expect(event[0].taker_gas_fee).to.be.equal("100000000");
        });
    });
});
