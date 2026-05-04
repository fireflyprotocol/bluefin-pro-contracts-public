import { expect } from "./helpers/utils";
import { ADMIN, bluefinV3, SIMULATOR } from "../env";
import { Transaction, TEST_WALLETS } from "../library-sui/dist";
import { SUI_NATIVE_BASE, toBigNumberStr } from "../library-sui/src";
import { getRandomString } from "../library-sui/src/v3";
import { IAssetSupportedEvent } from "../library-sui/src/v3";

describe("Data Store", () => {
    before(async () => {
        await SIMULATOR.init();
    });

    it("should create the internal data store", async () => {
        const resp = await bluefinV3.admin.createInternalDataStore(ADMIN.toSuiAddress(), {
            dryRun: true
        });
        expect(Transaction.getStatus(resp)).to.be.equal("success");
    });

    it("should transfer internal data store to new sequencer", async () => {
        const resp = await bluefinV3.sequencer.transferInternalDataStore(
            TEST_WALLETS[0].address,
            {
                dryRun: true
            }
        );
        expect(Transaction.getStatus(resp)).to.be.equal("success");
    });

    it("should sync supported asset between external and internal data store", async () => {
        const resp = await bluefinV3.admin.supportAsset(
            bluefinV3.parser.getAssetCoinType("USDC"),
            `TEST_ASSET_${getRandomString(6)}`,
            SUI_NATIVE_BASE,
            SUI_NATIVE_BASE,
            SUI_NATIVE_BASE,
            true,
            toBigNumberStr(1, SUI_NATIVE_BASE),
            toBigNumberStr(1_000_000, SUI_NATIVE_BASE),
            { dryRun: false }
        );
        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(
            resp,
            "AssetSupported"
        )[0] as IAssetSupportedEvent;

        // get the expected sequence hash
        const expectedHash = SIMULATOR.syncSupportedAsset(event, false);

        const resp2 = await bluefinV3.sequencer.syncSupportedAsset(
            event.asset.symbol,
            expectedHash,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp2)).to.be.equal("success");
    });
});
