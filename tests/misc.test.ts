import { bluefinV3 } from "../env";
import {
    base64ToHex,
    SUI_NATIVE_BASE,
    TEST_WALLETS,
    toBigNumberStr,
    Transaction
} from "../library-sui/dist";
import { ADDRESSES } from "../library-sui/src";
import { ACCOUNT_TYPE } from "../library-sui/src/v3/enums";
import { expect, provideMarginToAccount } from "./helpers/utils";
import {
    IAccountTypeUpdatedEvent,
    IFeeTierUpdatedEvent,
    IGasFeeUpdatedEvent,
    IGasPoolUpdatedEvent
} from "../library-sui/src/v3";

describe("Miscellaneous", () => {
    beforeEach(async () => {
        await bluefinV3.simulator.init();
        await provideMarginToAccount(
            bluefinV3,
            bluefinV3.simulator,
            TEST_WALLETS[0].address
        );
    });

    it("should updated fee tier of the account on-chain", async () => {
        const payload = await bluefinV3.requests.setFeeTier(
            TEST_WALLETS[0].address,
            toBigNumberStr(0.5, SUI_NATIVE_BASE),
            toBigNumberStr(0.1, SUI_NATIVE_BASE),
            true
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResult = await bluefinV3.sequencer.setFeeTier(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResult) == "success").to.be.true;

        const event = Transaction.getEvents(
            txResult,
            "FeeTierUpdatedEvent"
        )[0] as IFeeTierUpdatedEvent;

        expect(event.applied).to.be.true;
        expect(event.maker).to.be.equal(toBigNumberStr(0.5, SUI_NATIVE_BASE));
        expect(event.taker).to.be.equal(toBigNumberStr(0.1, SUI_NATIVE_BASE));
    });

    it("should update the gas fee on-chain", async () => {
        const payload = await bluefinV3.requests.setGasFee(
            toBigNumberStr(1, SUI_NATIVE_BASE)
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResult = await bluefinV3.sequencer.setGasFee(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResult) == "success").to.be.true;

        const event = Transaction.getEvents(
            txResult,
            "GasFeeUpdatedEvent"
        )[0] as IGasFeeUpdatedEvent;
        expect(event.gas_fee).to.be.equal(toBigNumberStr(1, SUI_NATIVE_BASE));
    });

    it("should update the gas pool address on-chain", async () => {
        const payload = await bluefinV3.requests.setGasPool(TEST_WALLETS[0].address);

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResult = await bluefinV3.sequencer.setGasPool(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResult) == "success").to.be.true;

        const event = Transaction.getEvents(
            txResult,
            "GasPoolUpdatedEvent"
        )[0] as IGasPoolUpdatedEvent;
        expect(event.current_gas_pool).to.be.equal(TEST_WALLETS[0].address);
    });

    it("should revert when trying to set ZERO address as gas pool", async () => {
        const payload = await bluefinV3.requests.setGasPool(ADDRESSES.ZERO);

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.setGasPool(
                payload.serializedData,
                payload.signature,
                sequenceHash,
                Date.now(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1004");
    });

    it("should update the type of account to retail", async () => {
        const payload = await bluefinV3.requests.setAccountType(
            TEST_WALLETS[0].address,
            ACCOUNT_TYPE.INSTITUTION
        );

        const sequenceHash = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResult = await bluefinV3.sequencer.setAccountType(
            payload.serializedData,
            payload.signature,
            sequenceHash,
            Date.now(),
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResult) == "success").to.be.true;

        const event = Transaction.getEvents(
            txResult,
            "AccountTypeUpdatedEvent"
        )[0] as IAccountTypeUpdatedEvent;
        expect(event.account).to.be.equal(TEST_WALLETS[0].address);
        expect(event.is_institution).to.be.true;
    });
});
