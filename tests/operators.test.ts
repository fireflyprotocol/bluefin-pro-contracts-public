import { bluefinV3, PARSER, SIMULATOR, SUI_CLIENT } from "../env";
import { TEST_WALLETS, TransactionBlock } from "../library-sui/dist";
import { base64ToHex, Transaction } from "../library-sui/src";
import { OPERATORS } from "../library-sui/src/v3/enums";
import { Store } from "../library-sui/src/v3/on-chain-calls/store";
import { expect } from "./helpers/utils";
import {
    IOperatorUpdatedEvent,
    IBankruptLiquidatorAuthorizedEvent
} from "../library-sui/src/v3";

describe("Operators", () => {
    before(async () => {
        await SIMULATOR.init();
    });

    it("should set the funding operator on external data store", async () => {
        const txResponse = await bluefinV3.admin.setOperatorEDS(
            OPERATORS.FUNDING,
            TEST_WALLETS[0].address,
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "EDSOperatorUpdated"
        )[0] as IOperatorUpdatedEvent;

        expect(event.operator_type).to.be.equal("funding");
        expect(event.new_operator).to.be.equal(TEST_WALLETS[0].address);
    });

    it("should sync the funding operator with internal data store", async () => {
        const operator = await Store.getOperator(
            SUI_CLIENT,
            PARSER.getInternalDataStore(),
            OPERATORS.FUNDING
        );

        let txb = new TransactionBlock();

        bluefinV3.txBuilder.setOperatorEDS(OPERATORS.FUNDING, TEST_WALLETS[0].address, {
            txBlock: txb
        });

        const sequenceHash = await SIMULATOR.syncOperator(
            {
                previous_operator: operator,
                new_operator: TEST_WALLETS[0].address,
                operator_type: "funding"
            } as any,
            false
        );

        bluefinV3.txBuilder.syncOperator(OPERATORS.FUNDING, sequenceHash, {
            txBlock: txb
        });

        const txResponse = await bluefinV3.sequencer.dryRunTxBlock(txb);

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "OperatorSynced"
        )[0] as IOperatorUpdatedEvent;

        expect(event.operator_type).to.be.equal("funding");
        expect(event.previous_operator).to.be.equal(operator);
        expect(event.new_operator).to.be.equal(TEST_WALLETS[0].address);
    });

    it("should set the guardian on external data store", async () => {
        const txResponse = await bluefinV3.admin.setOperatorEDS(
            OPERATORS.GUARDIAN,
            TEST_WALLETS[0].address,
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "EDSOperatorUpdated"
        )[0] as IOperatorUpdatedEvent;

        expect(event.operator_type).to.be.equal(OPERATORS.GUARDIAN);
        expect(event.new_operator).to.be.equal(TEST_WALLETS[0].address);
    });

    it("should set the fee operator on external data store", async () => {
        const txResponse = await bluefinV3.admin.setOperatorEDS(
            OPERATORS.FEE,
            TEST_WALLETS[0].address,
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "EDSOperatorUpdated"
        )[0] as IOperatorUpdatedEvent;

        expect(event.operator_type).to.be.equal(OPERATORS.FEE);
        expect(event.new_operator).to.be.equal(TEST_WALLETS[0].address);
    });

    it("should whitelist an account as liquidator", async () => {
        const payload = await bluefinV3.requests.authorizeLiquidator(
            TEST_WALLETS[0].address,
            true
        );

        const sequenceHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.authorizeLiquidator(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "BankruptLiquidatorAuthorizedEvent"
        )[0] as IBankruptLiquidatorAuthorizedEvent;

        expect(event.account).to.be.equal(TEST_WALLETS[0].address);
        expect(event.authorized).to.be.true;
    });

    it("should remove a whitelisted liquidator", async () => {
        const payload = await bluefinV3.requests.authorizeLiquidator(
            TEST_WALLETS[0].address,
            true
        );

        const sequenceHash = await SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            true
        );

        const txb = await bluefinV3.sequencer.authorizeLiquidator(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { returnTxb: true }
        );

        const payload2 = await bluefinV3.requests.authorizeLiquidator(
            TEST_WALLETS[0].address,
            false
        );

        const sequenceHash2 = await SIMULATOR.computeSequenceHash(
            base64ToHex(payload2.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.authorizeLiquidator(
            payload2.serializedData,
            payload2.signature,
            sequenceHash2,
            Date.now(),
            { dryRun: true, txBlock: txb as TransactionBlock }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "BankruptLiquidatorAuthorizedEvent"
        )[1] as IBankruptLiquidatorAuthorizedEvent;

        expect(event.account).to.be.equal(TEST_WALLETS[0].address);
        expect(event.authorized).to.be.false;
    });

    it("should set adl operator on external data store", async () => {
        const txResponse = await bluefinV3.admin.setOperatorEDS(
            OPERATORS.ADL,
            TEST_WALLETS[0].address,
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");

        const event = Transaction.getEvents(
            txResponse,
            "EDSOperatorUpdated"
        )[0] as IOperatorUpdatedEvent;

        expect(event.operator_type).to.be.equal(OPERATORS.ADL);
        expect(event.new_operator).to.be.equal(TEST_WALLETS[0].address);
    });
});
