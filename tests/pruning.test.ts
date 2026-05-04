import { expect } from "chai";
import { ADMIN, bluefinV3, SIMULATOR, SUI_CLIENT } from "../env";
import {
    ADDRESSES,
    base64ToHex,
    REQUEST_LIFESPAN,
    sleep,
    SUI_NATIVE_BASE,
    toBigNumber,
    Transaction
} from "../library-sui/src";
import { PRUNE_TABLES_INDEX } from "../library-sui/src/v3/enums";
import { Store } from "../library-sui/src/v3/on-chain-calls/store";
import { performTrades, provideMarginToAccount } from "./helpers/utils";
import { getTestAccounts } from "../library-sui/dist";

describe("Table Pruning", () => {
    let hashes: Array<Uint8Array>;
    before(async () => {
        await bluefinV3.admin.mintUSDC();
        await SIMULATOR.init();

        await provideMarginToAccount(bluefinV3, SIMULATOR, ADMIN.toSuiAddress());

        hashes = await Store.getTableKeys(
            SUI_CLIENT,
            bluefinV3.parser.getInternalDataStore(),
            PRUNE_TABLES_INDEX.HISTORY,
            5
        );

        if (hashes.length < 5) {
            let diff = 5 - hashes.length;
            for (let i = 0; i < diff; i++) {
                const payload = await bluefinV3.requests.withdrawal(
                    "USDC",
                    toBigNumber(0.1, SUI_NATIVE_BASE)
                );

                // get the expected sequence hash2
                const expectedHash = SIMULATOR.computeSequenceHash(
                    base64ToHex(payload.signature)
                );

                await bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash,
                    Date.now()
                );

                await sleep(1000);
            }

            hashes = await Store.getTableKeys(
                SUI_CLIENT,
                bluefinV3.parser.getInternalDataStore(),
                PRUNE_TABLES_INDEX.HISTORY,
                5
            );
        }
    });

    it("should successfully prune a single hash from history table", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [hashes[0]],
            PRUNE_TABLES_INDEX.HISTORY,
            { signedAt: Date.now() + 10_0000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.pruneTable(
            payload.serializedData,
            payload.signature,
            expectedHash,
            Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");
        expect(Transaction.getTxGasCost(txResponse) / 1e9 < 0);
    });

    it("should successfully prune 5 hashes from history table", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            hashes,
            PRUNE_TABLES_INDEX.HISTORY,
            { signedAt: Date.now() + 10_0000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.pruneTable(
            payload.serializedData,
            payload.signature,
            expectedHash,
            Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");
        expect(Transaction.getTxGasCost(txResponse) / 1e9 < 0);
    });

    it("should revert as the pruning payload is signed more than 3 months ago", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [hashes[0]],
            PRUNE_TABLES_INDEX.HISTORY,
            { signedAt: Date.now() - REQUEST_LIFESPAN - 10000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.pruneTable(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1046");
    });

    it("should revert as the pruning payload is signed for a different environment", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [hashes[0]],
            PRUNE_TABLES_INDEX.HISTORY,
            { ids: ADDRESSES.ZERO }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.pruneTable(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1006");
    });

    it("should revert when non-pruning operator tries to prune table", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [hashes[0]],
            PRUNE_TABLES_INDEX.HISTORY,
            { signer: getTestAccounts(false)[0].keyPair, signedAt: Date.now() + 100_000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.pruneTable(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1014");
    });

    it("should revert as the table type provided for pruning is not supported", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [hashes[0]],
            3 as any, // not a valid table type
            { signedAt: Date.now() + 10_0000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.pruneTable(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1044");
    });

    it("should revert as the hash being pruned does not exist on the table", async () => {
        const payload = await bluefinV3.requests.pruneTable(
            [Uint8Array.from([1, 2])],
            PRUNE_TABLES_INDEX.HISTORY,
            { signedAt: Date.now() + 10_0000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        await expect(
            bluefinV3.sequencer.pruneTable(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1045");
    });

    it("should successfully prune a single hash from order fills table", async () => {
        let hashes = await Store.getTableKeys(
            SUI_CLIENT,
            bluefinV3.parser.getInternalDataStore(),
            PRUNE_TABLES_INDEX.ORDER_FILLS,
            1
        );

        // if there is no order fill hash perform a trade
        if (hashes.length != 1) {
            await performTrades(bluefinV3, "ETH-PERP", [getTestAccounts(false)], 100, {
                side: "LONG",
                price: 100,
                quantity: 1
            });

            await sleep(1000);

            hashes = await Store.getTableKeys(
                SUI_CLIENT,
                bluefinV3.parser.getInternalDataStore(),
                PRUNE_TABLES_INDEX.ORDER_FILLS,
                1
            );
        }

        const payload = await bluefinV3.requests.pruneTable(
            hashes,
            PRUNE_TABLES_INDEX.ORDER_FILLS,
            { signedAt: Date.now() + 10_0000 }
        );

        const expectedHash = SIMULATOR.computeSequenceHash(
            base64ToHex(payload.signature),
            false
        );

        const txResponse = await bluefinV3.sequencer.pruneTable(
            payload.serializedData,
            payload.signature,
            expectedHash,
            Date.now() + 1000 + REQUEST_LIFESPAN, // give a future time
            { dryRun: true }
        );

        expect(Transaction.getStatus(txResponse)).to.be.equal("success");
        expect(Transaction.getTxGasCost(txResponse) / 1e9 < 0);
    });
});
