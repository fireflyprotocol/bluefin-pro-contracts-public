import { ADMIN, bluefinV3, PARSER, SIMULATOR, SUI_CLIENT } from "../env";
import { TransactionBlock } from "../library-sui/dist";
import {
    ADDRESSES,
    base64ToHex,
    bigNumber,
    hexStrToUint8,
    REQUEST_LIFESPAN,
    SUI_NATIVE_BASE,
    toBigNumber,
    toBigNumberStr,
    Transaction
} from "../library-sui/src";
import { getRandomString } from "../library-sui/src/v3";

import { getTestAccounts } from "../library-sui/src/helpers";
import {
    BCSUtils,
    MarketFundingRate,
    SetFundingRate
} from "../library-sui/src/v3/utils/bcs";
import { createPerpetual, expect, provideMarginToAccount } from "./helpers/utils";
import { Account } from "../library-sui/src/v3/on-chain-calls/account";
import { PAYLOAD_REQUEST_TYPE, POSITION_TYPES } from "../library-sui/src/v3/enums";
import {
    IMarketFundingRate,
    ISetFundingRate,
    IOraclePriceUpdate,
    ISignedOrder,
    IFundingRateUpdatedEvent
} from "../library-sui/src/v3";

describe("Funding Rate", () => {
    beforeEach(async () => {
        await SIMULATOR.init();
    });

    it("should correctly bcs serialize the funding rate payload and decode it on-chain", async () => {
        const marketsFundingRate = {
            market: "ETH",
            value: 1,
            sign: true,
            oraclePrice: 1
        } as IMarketFundingRate;

        const serializedMarketFR = BCSUtils.getSerializedDataBytes(
            marketsFundingRate,
            MarketFundingRate
        );

        const setFundingRatePayload = {
            type: PAYLOAD_REQUEST_TYPE.SET_FUNDING_RATE,
            ids: PARSER.getInternalDataStore(),
            timestamp: 1,
            salt: 1,
            signedAt: 1,
            marketFundingRates: [serializedMarketFR]
        } as ISetFundingRate;

        const serialized = BCSUtils.getSerializedDataHex(
            setFundingRatePayload,
            SetFundingRate
        );

        const txb = new TransactionBlock();

        txb.moveCall({
            target: `${bluefinV3.parser.getPackageId()}::bcs_handler::dec_set_funding_rate`,
            arguments: [txb.pure.vector("u8", Array.from(hexStrToUint8(serialized)))]
        });

        const txResponse = await SUI_CLIENT.devInspectTransactionBlock({
            transactionBlock: txb,
            sender: ADMIN.toSuiAddress()
        });

        expect(Transaction.getStatus(txResponse as any)).to.be.equal("success");
    });

    it("should set funding rate for ETH market on-chain", async () => {
        const fundingRateValue = toBigNumberStr(0.001, SUI_NATIVE_BASE);

        const payload = await bluefinV3.requests.setFundingRate([
            {
                market: "ETH-PERP",
                value: fundingRateValue,
                sign: true,
                oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
            }
        ]);

        const sequenceHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.setFundingRate(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "FundingRateUpdated"
        )[0] as IFundingRateUpdatedEvent;

        expect(event.market).to.be.equal("ETH-PERP");
        expect(event.rate.sign).to.be.equal(true);
        expect(event.rate.value).to.be.equal(fundingRateValue);
    });

    it("should revert as the signed funding rate payload older than 3 months is not allowed", async () => {
        const fundingRateValue = toBigNumberStr(0.001, SUI_NATIVE_BASE);

        const payload = await bluefinV3.requests.setFundingRate([
            {
                market: "ETH-PERP",
                value: fundingRateValue,
                sign: true,
                oraclePrice: toBigNumberStr(1, SUI_NATIVE_BASE)
            }
        ]);

        const sequenceHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.setFundingRate(
                payload.serializedData,
                payload.signature,
                sequenceHash,
                Date.now() + REQUEST_LIFESPAN + 10000,
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1046");
    });

    it("should revert when setting funding rate for an already set timestamp", async () => {
        const payload = await bluefinV3.requests.setFundingRate([
            {
                market: "ETH-PERP",
                value: toBigNumberStr(0.001, SUI_NATIVE_BASE),
                sign: true,
                oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
            }
        ]);

        const sequenceHash2 = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        let txb = new TransactionBlock();

        bluefinV3.txBuilder.setFundingRate(
            payload.serializedData,
            payload.signature,
            sequenceHash2,
            Date.now(),
            { txBlock: txb }
        );

        const payload2 = await bluefinV3.requests.setFundingRate([
            {
                market: "ETH-PERP",
                value: toBigNumberStr(0.002, SUI_NATIVE_BASE),
                sign: true,
                oraclePrice: toBigNumberStr(1, SUI_NATIVE_BASE)
            }
        ]);

        const sequenceHash3 = SIMULATOR.computeSequenceHash(
            base64ToHex(payload2.signature),
            false
        );

        // set funding rate again
        bluefinV3.txBuilder.setFundingRate(
            payload2.serializedData,
            payload2.signature,
            sequenceHash3,
            Date.now(),
            { txBlock: txb }
        );

        await expect(
            bluefinV3.sequencer.execCall(txb, { dryRun: true })
        ).to.be.eventually.rejectedWith("1039");
    });

    it("should apply funding rate to ZERO accounts as none of the accounts are provided", async () => {
        const payload = await bluefinV3.requests.applyFundingRate([]);
        const sequenceHash = SIMULATOR.computeSequenceHash(payload.serializedData, false);
        await bluefinV3.sequencer.applyFundingRate(
            payload.serializedData,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );
    });

    it("should revert when funding rate is to be applied on a different environment (IDS)", async () => {
        const payload = await bluefinV3.requests.applyFundingRate([], {
            ids: ADDRESSES.ZERO
        });
        const sequenceHash = SIMULATOR.computeSequenceHash(payload.serializedData, false);
        await expect(
            bluefinV3.sequencer.applyFundingRate(
                payload.serializedData,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1006");
    });

    it("should revert when trying to apply funding rate as the signing IDS does not match with the one passed as contract argument", async () => {
        const payload = await bluefinV3.requests.applyFundingRate([], {
            ids: ADMIN.toSuiAddress()
        });
        const sequenceHash = SIMULATOR.computeSequenceHash(payload.serializedData, false);
        await expect(
            bluefinV3.sequencer.applyFundingRate(
                payload.serializedData,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1006");
    });

    it("should apply funding rate to isolated positions of provided two accounts", async () => {
        /**
         * 1. Creates a random perpetual
         * 2. Opens an cross position between 2 accounts
         * 3. Sets funding rate to -0.1%
         * 4. Applies funding rate to accounts
         */
        const market = `PERP_${getRandomString(6)}`;

        const localBFV3 = await createPerpetual(
            bluefinV3,
            { symbol: market, tradingStartTime: 1735714800001 },
            SIMULATOR
        );

        const [alice, bob] = getTestAccounts(true);

        await provideMarginToAccount(localBFV3, SIMULATOR, alice.address);
        await provideMarginToAccount(localBFV3, SIMULATOR, bob.address);

        let oraclePrices = [
            {
                perpetual: market,
                price: toBigNumber(100, SUI_NATIVE_BASE)
            }
        ] as Array<IOraclePriceUpdate>;

        /**
         * price: 100, quantity: 50 = total notional value: 5000
         * Leverage: 4, Margin required = 5000 / 4 = 1250
         */
        const makerPayload = await localBFV3.requests.createSignedOrder(
            {
                positionType: POSITION_TYPES.ISOLATED,
                leverage: 4,
                side: "SHORT",
                price: 100,
                quantity: 50,
                market
            },
            { signer: alice.signer }
        );
        const takerPayload = await localBFV3.requests.createSignedOrder(
            {
                positionType: POSITION_TYPES.ISOLATED,
                leverage: 4,
                side: "LONG",
                price: 100,
                quantity: 50,
                market
            },
            { signer: bob.signer }
        );

        const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
        const timestamp = Date.now();

        let sequenceHash = SIMULATOR.performTrade(
            makerPayload.serializedData,
            takerPayload.serializedData,
            fill,
            timestamp
        );

        await localBFV3.sequencer.performTrade(
            makerPayload.rawData as ISignedOrder,
            takerPayload.rawData as ISignedOrder,
            fill,
            oraclePrices,
            sequenceHash,
            timestamp,
            { dryRun: false }
        );

        /**
         * Set funding rate to 0.1% (max allowed funding rate)
         */
        const fundingRateValue = toBigNumberStr(0.001, SUI_NATIVE_BASE);

        const payload = await localBFV3.requests.setFundingRate([
            {
                market,
                value: fundingRateValue,
                sign: true,
                oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
            }
        ]);
        sequenceHash = SIMULATOR.computeSequenceHash(base64ToHex(payload.signature));
        await localBFV3.sequencer.setFundingRate(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now()
        );

        // get account data before
        const accountDataBefore = await Account.getAccount(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            alice.address
        );

        // apply funding rate
        const payload2 = await bluefinV3.requests.applyFundingRate([
            alice.address,
            bob.address
        ]);
        const sequenceHash2 = SIMULATOR.computeSequenceHash(
            payload2.serializedData,
            false
        );
        await bluefinV3.sequencer.applyFundingRate(
            payload2.serializedData,
            sequenceHash2,
            Date.now(),
            { dryRun: false }
        );

        // get account data after
        const accountDataAfter = await Account.getAccount(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            alice.address
        );

        // pending amount before and after should be zero
        expect(
            accountDataBefore.isolatedPositions[0].pending_funding_payment
        ).to.be.equal("0");
        expect(accountDataAfter.isolatedPositions[0].pending_funding_payment).to.be.equal(
            "0"
        );

        expect(accountDataBefore.isolatedPositions[0].margin).to.be.equal(
            toBigNumberStr(1250, SUI_NATIVE_BASE)
        );
        expect(accountDataAfter.isolatedPositions[0].margin).to.be.equal(
            toBigNumberStr(1255, SUI_NATIVE_BASE)
        );

        const bobAfter = await Account.getAccount(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            bob.address
        );
        expect(bobAfter.isolatedPositions[0].margin).to.be.equal(
            toBigNumberStr(1245, SUI_NATIVE_BASE)
        );
    });

    it("should apply funding rate to cross positions of provided two accounts", async () => {
        /**
         * 1. Creates a random perpetual
         * 2. Opens an cross position between 2 accounts
         * 3. Sets funding rate to -0.1%
         * 4. Applies funding rate to accounts
         */
        const market = `PERP_${getRandomString(6)}`;

        const localBFV3 = await createPerpetual(
            bluefinV3,
            { symbol: market, tradingStartTime: 1735714800001 },
            SIMULATOR
        );

        const [alice, bob] = getTestAccounts(true);

        await provideMarginToAccount(localBFV3, SIMULATOR, alice.address);
        await provideMarginToAccount(localBFV3, SIMULATOR, bob.address);

        let oraclePrices = [
            {
                perpetual: market,
                price: toBigNumber(100, SUI_NATIVE_BASE)
            }
        ] as Array<IOraclePriceUpdate>;

        /**
         * price: 100, quantity: 50 = total notional value: 5000
         * Leverage: 4, Margin required = 5000 / 4 = 1250
         */
        const makerPayload = await localBFV3.requests.createSignedOrder(
            {
                side: "SHORT",
                price: 100,
                quantity: 50,
                market
            },
            { signer: alice.signer }
        );
        const takerPayload = await localBFV3.requests.createSignedOrder(
            {
                side: "LONG",
                price: 100,
                quantity: 50,
                market
            },
            { signer: bob.signer }
        );

        const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
        const timestamp = Date.now();

        let sequenceHash = SIMULATOR.performTrade(
            makerPayload.serializedData,
            takerPayload.serializedData,
            fill,
            timestamp
        );

        await localBFV3.sequencer.performTrade(
            makerPayload.rawData as ISignedOrder,
            takerPayload.rawData as ISignedOrder,
            fill,
            oraclePrices,
            sequenceHash,
            timestamp,
            { dryRun: false }
        );

        /**
         * Set funding rate to 0.1% (max allowed funding rate)
         */
        const fundingRateValue = toBigNumberStr(0.001, SUI_NATIVE_BASE);

        const payload = await localBFV3.requests.setFundingRate([
            {
                market,
                value: fundingRateValue,
                sign: false,
                oraclePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
            }
        ]);
        sequenceHash = SIMULATOR.computeSequenceHash(base64ToHex(payload.signature));
        await localBFV3.sequencer.setFundingRate(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now()
        );

        // get account data before
        const accountDataBefore = await Account.getAccount(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            alice.address
        );
        // apply funding rate
        const payload2 = await bluefinV3.requests.applyFundingRate([
            alice.address,
            bob.address
        ]);
        const sequenceHash2 = SIMULATOR.computeSequenceHash(
            payload2.serializedData,
            false
        );
        await bluefinV3.sequencer.applyFundingRate(
            payload2.serializedData,
            sequenceHash2,
            Date.now(),
            { dryRun: false }
        );

        // get account data after
        const accountDataAfter = await Account.getAccount(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            alice.address
        );

        expect(accountDataBefore.crossPositions[0].pending_funding_payment).to.be.equal(
            "0"
        );
        expect(accountDataAfter.crossPositions[0].pending_funding_payment).to.be.equal(
            "0"
        );
        expect(Number(accountDataAfter.assets[0].quantity)).to.be.equal(
            bigNumber(accountDataBefore.assets[0].quantity)
                .minus(toBigNumberStr(5, SUI_NATIVE_BASE))
                .toNumber()
        );
    });
});
