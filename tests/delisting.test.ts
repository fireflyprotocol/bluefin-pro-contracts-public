import { expect, provideMarginToAccount, setupTrade } from "./helpers/utils";
import { ADMIN, bluefinV3, SIMULATOR, SUI_CLIENT } from "../env";
import { SUI_NATIVE_BASE, TransactionBlock } from "../library-sui/dist";
import {
    toBigNumber,
    toBigNumberStr,
    getKeyPairFromSeed,
    SuiBlocks,
    Transaction,
    base64ToHex
} from "../library-sui/src";
import { TEST_WALLETS } from "../library-sui/src/helpers";
import { PERPETUAl_CONFIG_FIELDS, POSITION_TYPES } from "../library-sui/src/v3/enums";
import { IPositionClosedEvent } from "../library-sui/src/v3";

describe("Delisting", () => {
    const alice = getKeyPairFromSeed(TEST_WALLETS[1].phrase, "Secp256k1");
    const bob = getKeyPairFromSeed(TEST_WALLETS[1].phrase, "ED25519");

    let txb: TransactionBlock;
    const marketName = "ETH-PERP";

    const delistPerp = async (delistPrice: number) => {
        await bluefinV3.admin.updatePerpetual(
            marketName,
            PERPETUAl_CONFIG_FIELDS.DELIST,
            toBigNumber(delistPrice, SUI_NATIVE_BASE).toNumber(),
            { txBlock: txb, returnTxb: true }
        );

        const txResponse = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

        const event = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

        // get the expected sequence hash
        const expectedHash = bluefinV3.simulator.syncPerpetual(event);

        (await bluefinV3.sequencer.syncPerpetual(marketName, expectedHash, {
            txBlock: txb,
            returnTxb: true
        })) as TransactionBlock;
    };

    before(async () => {
        await SIMULATOR.init();
        await provideMarginToAccount(bluefinV3, SIMULATOR, alice.toSuiAddress(), {
            exactAmount: 50
        });
        await provideMarginToAccount(bluefinV3, SIMULATOR, bob.toSuiAddress(), {
            exactAmount: 10_000
        });
    });

    beforeEach(async () => {
        txb = new TransactionBlock();
        await bluefinV3.simulator.init();
    });

    it("should delist the ETH market on EDS and sync it with the IDS", async () => {
        await delistPerp(2550);
    });

    it("should revert when trying to delist an already delisted market", async () => {
        await delistPerp(2550);
        await bluefinV3.admin.updatePerpetual(
            marketName,
            PERPETUAl_CONFIG_FIELDS.DELIST,
            toBigNumber(2600, SUI_NATIVE_BASE).toNumber(),
            { txBlock: txb, returnTxb: true }
        );

        const resp = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);

        expect(Transaction.getStatus(resp)).to.be.equal("failure");
    });

    it("should revert when trying to update oracle price for a delisted perp", async () => {
        await delistPerp(2400);

        const payload = await bluefinV3.requests.closePosition(
            marketName,
            POSITION_TYPES.CROSS,
            { signer: alice }
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            payload.signature,
            false
        );

        const response = await bluefinV3.sequencer.closePosition(
            payload.serializedData,
            payload.signature,
            [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumberStr(2500, SUI_NATIVE_BASE)
                }
            ],
            sequenceHash,
            Date.now(),
            { txBlock: txb, dryRun: true }
        );

        expect(Transaction.getStatus(response)).to.be.equal("failure");

        expect(JSON.stringify(response).indexOf("1055") > -1).to.be.true;
    });

    it("should successfully close Alice's position in a positive Pnl after delist - CROSS", async () => {
        await setupTrade(bluefinV3, txb, {
            oraclePrice: 2500,
            executionPrice: 2500,
            perpetual: marketName,
            quantity: 0.1,
            makerSide: "SHORT",
            maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
            taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
        });

        // Alice is on short at 2500 for quantity 0.01
        await delistPerp(2400);

        const payload = await bluefinV3.requests.closePosition(
            marketName,
            POSITION_TYPES.CROSS,
            { signer: alice }
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature)
        );

        const txResponse = await bluefinV3.sequencer.closePosition(
            payload.serializedData,
            payload.signature,
            [],
            sequenceHash,
            Date.now(),
            { txBlock: txb, dryRun: true, gasBudget: 0.5e9 }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "PositionClosed"
        )[0] as IPositionClosedEvent;

        expect(event.assets[0].quantity).to.be.equal("59962500000");
    });

    it("should successfully close Alice's position in a negative Pnl after delist - CROSS", async () => {
        await setupTrade(bluefinV3, txb, {
            oraclePrice: 2500,
            executionPrice: 2500,
            perpetual: marketName,
            quantity: 0.1,
            makerSide: "SHORT",
            maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
            taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
        });

        await delistPerp(2600);

        const payload = await bluefinV3.requests.closePosition(
            marketName,
            POSITION_TYPES.CROSS,
            { signer: alice }
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature)
        );

        const txResponse = await bluefinV3.sequencer.closePosition(
            payload.serializedData,
            payload.signature,
            [],
            sequenceHash,
            Date.now(),
            { txBlock: txb, dryRun: true, gasBudget: 0.5e9 }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "PositionClosed"
        )[0] as IPositionClosedEvent;

        expect(event.assets[0].quantity).to.be.equal("39962500000");
    });

    it("should successfully close Alice's position in a positive Pnl after delist - ISOLATED", async () => {
        await setupTrade(bluefinV3, txb, {
            oraclePrice: 2500,
            executionPrice: 2500,
            perpetual: marketName,
            quantity: 0.1,
            makerSide: "SHORT",
            maker: { signer: alice, positionType: POSITION_TYPES.ISOLATED, leverage: 10 },
            taker: { signer: bob, positionType: POSITION_TYPES.ISOLATED, leverage: 10 }
        });

        await delistPerp(2450);

        const payload = await bluefinV3.requests.closePosition(
            marketName,
            POSITION_TYPES.ISOLATED,
            { signer: alice }
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature)
        );

        const txResponse = await bluefinV3.sequencer.closePosition(
            payload.serializedData,
            payload.signature,
            [],
            sequenceHash,
            Date.now(),
            { txBlock: txb, dryRun: true, gasBudget: 0.5e9 }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "PositionClosed"
        )[0] as IPositionClosedEvent;

        expect(event.assets[0].quantity).to.be.equal("54962500000");
    });

    it("should successfully close Alice's position in a negative Pnl after delist - ISOLATED", async () => {
        await setupTrade(bluefinV3, txb, {
            oraclePrice: 2500,
            executionPrice: 2500,
            perpetual: marketName,
            quantity: 0.1,
            makerSide: "SHORT",
            maker: { signer: alice, positionType: POSITION_TYPES.ISOLATED, leverage: 10 },
            taker: { signer: bob, positionType: POSITION_TYPES.ISOLATED, leverage: 10 }
        });

        await delistPerp(2550);

        const payload = await bluefinV3.requests.closePosition(
            marketName,
            POSITION_TYPES.ISOLATED,
            { signer: alice }
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature)
        );

        const txResponse = await bluefinV3.sequencer.closePosition(
            payload.serializedData,
            payload.signature,
            [],
            sequenceHash,
            Date.now(),
            { txBlock: txb, dryRun: true, gasBudget: 0.5e9 }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "PositionClosed"
        )[0] as IPositionClosedEvent;

        expect(event.assets[0].quantity).to.be.equal("44962500000");
    });
});
