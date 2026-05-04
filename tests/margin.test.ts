import { expect, expectPosition, provideMarginToAccount } from "./helpers/utils";
import { bluefinV3, SIMULATOR } from "../env";
import {
    getTestAccounts,
    SUI_NATIVE_BASE,
    SuiTransactionBlockResponse,
    TransactionBlock
} from "../library-sui/dist";
import {
    toBigNumber,
    toBigNumberStr,
    Transaction,
    REQUEST_LIFESPAN,
    ADDRESSES,
    base64ToHex,
    SuiBlocks,
    USDC_BASE_DECIMALS
} from "../library-sui/src";
import { ISignedOrder } from "../library-sui/src/v3";
import { POSITION_TYPES } from "../library-sui/src/v3/enums";
import {
    IOraclePriceUpdate,
    IMarginAdjustedEvent,
    ILeverageAdjustedEvent,
    IAssetBankDeposit
} from "../library-sui/src/v3";

describe("Margin", () => {
    const [alice, bob] = getTestAccounts(true);
    let oraclePrices = [
        {
            perpetual: "ETH-PERP",
            price: toBigNumber(2000, SUI_NATIVE_BASE)
        },
        {
            perpetual: "BTC-PERP",
            price: toBigNumber(2000, SUI_NATIVE_BASE)
        }
    ] as Array<IOraclePriceUpdate>;

    before(async () => {
        // Create a cross and isolated position for the user

        await SIMULATOR.init();

        // Give each account 10K USD
        await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address);
        await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address);

        // open isolated position
        const makerPayloadIsolated = await bluefinV3.requests.createSignedOrder(
            {
                side: "LONG",
                quantity: 50,
                price: 2000,
                positionType: POSITION_TYPES.ISOLATED,
                leverage: 20,
                market: "ETH-PERP"
            },
            { signer: alice.signer }
        );
        const takerPayloadIsolated = await bluefinV3.requests.createSignedOrder(
            {
                side: "SHORT",
                quantity: 50,
                price: 2000,
                positionType: POSITION_TYPES.ISOLATED,
                leverage: 20,
                market: "ETH-PERP"
            },
            { signer: bob.signer }
        );

        const timestamp = Date.now();

        const sequenceHash = SIMULATOR.performTrade(
            makerPayloadIsolated.serializedData,
            takerPayloadIsolated.serializedData,
            toBigNumberStr(50, SUI_NATIVE_BASE),
            timestamp
        );

        // Open isolated position for maker and taker
        // leverage: 20x
        // price: 2000
        // quantity: 50
        // notional value: 2000 * 50 = 100,000
        // margin required = 100,000 / 20 = 5000
        // maker fee = 1.5 bps * 100,000 = 15
        // taker fee = 5.5 bps * 100,000 = 55
        // Margin in position for both maker/taker = 5000
        // Maker Assets in Account = 10K - 5K - 15 = 4985
        // Taker Assets in Account = 10K - 5K - 55 = 4945
        await bluefinV3.sequencer.performTrade(
            makerPayloadIsolated.rawData as ISignedOrder,
            takerPayloadIsolated.rawData as ISignedOrder,
            toBigNumberStr(50, SUI_NATIVE_BASE),
            oraclePrices,
            sequenceHash,
            timestamp
        );

        // Open cross position for maker and taker
        // price: 2000
        // quantity: 50
        // notional value: 2000 * 10 = 20,000
        // margin required = 20,000 / 20 = 1000
        // maker fee = 1.5 bps * 20,000 = 30
        // taker fee = 5.5 bps * 20,000 = 110
        // Maker Assets in Account = 4985 - 3 = 4982
        // Taker Assets in Account = 4945 - 11 = 4934
        const makerPayloadCross = await bluefinV3.requests.createSignedOrder(
            { side: "LONG", quantity: 10, price: 2000, market: "BTC-PERP" },
            { signer: alice.signer }
        );
        const takerPayloadCross = await bluefinV3.requests.createSignedOrder(
            { side: "SHORT", quantity: 10, price: 2000, market: "BTC-PERP" },
            { signer: bob.signer }
        );

        const sequenceHash2 = SIMULATOR.performTrade(
            makerPayloadCross.serializedData,
            takerPayloadCross.serializedData,
            toBigNumberStr(10, SUI_NATIVE_BASE),
            timestamp
        );

        await bluefinV3.sequencer.performTrade(
            makerPayloadCross.rawData as ISignedOrder,
            takerPayloadCross.rawData as ISignedOrder,
            toBigNumberStr(10, SUI_NATIVE_BASE),
            oraclePrices,
            sequenceHash2,
            timestamp
        );
    });

    describe("Adjust Margin", () => {
        beforeEach(async () => {
            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                },
                {
                    perpetual: "BTC-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;
        });

        it("should successfully add 50 margin to Alice's ETH isolated position", async () => {
            const account = await bluefinV3.getAccountStateOnChain(alice.address);
            expect(account.assets[0].quantity).to.be.equal(
                toBigNumberStr(4982, SUI_NATIVE_BASE)
            );

            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const txResult = await bluefinV3.sequencer.adjustMargin(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash2,
                Date.now(),
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "MarginAdjusted"
            )[0] as IMarginAdjustedEvent;

            expect(event.assets[0].quantity).to.be.equal(
                toBigNumberStr(4932, SUI_NATIVE_BASE)
            );
            expect(event.position.margin).to.be.equal(
                toBigNumberStr(5050, SUI_NATIVE_BASE)
            );
        });

        it("should revert when payload is targeting a different IDS", async () => {
            const account = await bluefinV3.getAccountStateOnChain(alice.address);
            expect(account.assets[0].quantity).to.be.equal(
                toBigNumberStr(4982, SUI_NATIVE_BASE)
            );

            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer, ids: ADDRESSES.ZERO }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1006");
        });

        it("should revert when adjust margin payload is signed more than 3 months ago", async () => {
            const account = await bluefinV3.getAccountStateOnChain(alice.address);
            expect(account.assets[0].quantity).to.be.equal(
                toBigNumberStr(4982, SUI_NATIVE_BASE)
            );

            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash2,
                    Date.now() + 1000 + REQUEST_LIFESPAN,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should revert when trying to withdraw 50$ margin from Alice's ETH isolated position when there is not enough margin", async () => {
            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                false,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1017");
        });

        it("should fail to withdraw 50$ margin from Alice's ETH isolated position when there is not enough margin although she has unrealized Pnl", async () => {
            const account = await bluefinV3.getAccountStateOnChain(alice.address);
            expect(account.assets[0].quantity).to.be.equal(
                toBigNumberStr(4982, SUI_NATIVE_BASE)
            );

            oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2100, SUI_NATIVE_BASE) // update oracle price to 2100 making isolated position in profit
                }
            ] as Array<IOraclePriceUpdate>;

            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                false,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1017");
        });

        it("should fail to move 4500$ margin to isolated ETH position of Alice as it makes the cross account position undercollat", async () => {
            const account = await bluefinV3.getAccountStateOnChain(alice.address);
            expect(account.assets[0].quantity).to.be.equal(
                toBigNumberStr(4982, SUI_NATIVE_BASE)
            );

            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(4500, SUI_NATIVE_BASE), // The cross account needs 1000$
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("4002");
        });

        it("should revert as the signer does not have permission to adjust margin for Alice", async () => {
            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: alice.address } // the signer is admin
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustMargin(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1014");
        });

        it("should revert when trying to adjust margin for a non-existent perpetual position", async () => {
            const charlie = getTestAccounts(true)[0];

            let txb = new TransactionBlock();
            await bluefinV3.simulator.init();

            txb = (await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                {
                    account: charlie.address,
                    txBlock: txb,
                    returnTxb: true
                }
            )) as TransactionBlock;

            const resp = await SuiBlocks.dryRunTxBlock(
                txb,
                bluefinV3.suiClient,
                bluefinV3.signer
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = bluefinV3.simulator.depositToInternalBank(event);

            txb = (await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash,
                { txBlock: txb, returnTxb: true }
            )) as TransactionBlock;

            const payload = await bluefinV3.requests.adjustMargin(
                "BTC-PERP",
                true,
                toBigNumberStr(50, SUI_NATIVE_BASE),
                { account: charlie.address, signer: charlie.signer }
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const response = await bluefinV3.sequencer.adjustMargin(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true, txBlock: txb }
            );

            expect(Transaction.getStatus(response)).to.be.equal("failure");
            expect(Transaction.getErrorCode(response)).to.be.equal(1035);
        });
    });

    describe("Adust Leverage", () => {
        it("should revert as the signer does not have permission to adjust leverage for Alice", async () => {
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(4, SUI_NATIVE_BASE),
                { account: alice.address } // the signer is admin
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustLeverage(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1014");
        });

        it("should revert when trying to adjust leverage of a non-existent position", async () => {
            const charlie = getTestAccounts(true)[0];

            let txb = new TransactionBlock();
            await bluefinV3.simulator.init();

            txb = (await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                {
                    account: charlie.address,
                    txBlock: txb,
                    returnTxb: true
                }
            )) as TransactionBlock;

            const resp = await SuiBlocks.dryRunTxBlock(
                txb,
                bluefinV3.suiClient,
                bluefinV3.signer
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = bluefinV3.simulator.depositToInternalBank(event);

            txb = (await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash,
                { txBlock: txb, returnTxb: true }
            )) as TransactionBlock;

            const payload = await bluefinV3.requests.adjustLeverage(
                "BTC-PERP",
                toBigNumberStr(4, SUI_NATIVE_BASE),
                { account: charlie.address, signer: charlie.signer }
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const response = await bluefinV3.sequencer.adjustLeverage(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true, txBlock: txb }
            );

            expect(Transaction.getStatus(response)).to.be.equal("failure");
            expect(Transaction.getErrorCode(response)).to.be.equal(1035);
        });

        it("should successfully reduce Alice's leverage to 16x for ETH isolated position", async () => {
            // Alice currently has 5000 margin in her position of size 50 with entry price 2000 at leverage 20x
            // Currently oracle price is 2000$ so when reducing leverage to 16x:
            // Margin required: 50 * 2000 / 16 = 100,000 / 16 = 6250
            // 1250$ will be moved from the cross account into ETH position
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(16, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const txResult = (await bluefinV3.sequencer.adjustLeverage(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            )) as SuiTransactionBlockResponse;

            const event = Transaction.getEvents(
                txResult,
                "LeverageAdjusted"
            )[0] as ILeverageAdjustedEvent;
            expectPosition(event.position, {
                size: 50,
                entryPrice: 2000,
                margin: 6250,
                isolated: true
            });
        });

        it("should revert as payload is targeting a different IDS (Environment)", async () => {
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(16, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer, ids: ADDRESSES.ZERO }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustLeverage(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1006");
        });

        it("should revert as payload was signed at more than 3 months ago", async () => {
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(16, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustLeverage(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now() + 1000 + REQUEST_LIFESPAN,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should successfully reduce Alice's leverage to 16x for ETH isolated position when oracle price increased", async () => {
            let oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2200, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;

            // Currently oracle price is 2200$ so when reducing leverage to 16x:
            // Margin required: 50 * 2200 / 16 = 110000 / 16 = 6875
            // 1875$ will be moved from the cross account into ETH position
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(16, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const txResult = await bluefinV3.sequencer.adjustLeverage(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "LeverageAdjusted"
            )[0] as ILeverageAdjustedEvent;
            expectPosition(event.position, {
                size: 50,
                entryPrice: 2000,
                margin: 6250,
                isolated: true
            });
        });

        it("should successfully decrease the leverage on isolated position despite it being in loss", async () => {
            let oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(1800, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;

            // Currently oracle price is 1800$ so when reducing leverage to 16x:
            // Margin required: 50 * 1800 / 16 = 90000 / 16 = 5625
            // 625$ will be moved from the cross account into ETH position
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(16, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await bluefinV3.sequencer.adjustLeverage(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            );
        });

        it("should successfully increase Alice's leverage to 21x for ETH isolated position", async () => {
            // Currently oracle price is 2000$ so when reducing increasing leverage to 21x:
            // Margin required: 50 * 2000 / 21 = 90000 / 21 = 4761.90
            // 5000 - 4761.90 = 238.095$ will be moved to the cross account from isolated position
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(21, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const txResult = await bluefinV3.sequencer.adjustLeverage(
                payload.serializedData,
                payload.signature,
                oraclePrices,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            );

            const event = Transaction.getEvents(
                txResult,
                "LeverageAdjusted"
            )[0] as ILeverageAdjustedEvent;
            expectPosition(event.position, {
                size: 50,
                entryPrice: 2000,
                margin: 4761.904761904,
                isolated: true
            });
        });

        it("should revert when trying to increase Alice's leverage to 25x as the max leverage supported by perpetual is 22x", async () => {
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(25, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            const sequenceHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.adjustLeverage(
                    payload.serializedData,
                    payload.signature,
                    oraclePrices,
                    sequenceHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1022");
        });
    });
});
