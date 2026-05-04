import { expect, provideMarginToAccount } from "./helpers/utils";
import { bluefinV3, PARSER, SIMULATOR, SUI_CLIENT } from "../env";
import { Transaction, TEST_WALLETS } from "../library-sui/dist";
import { Account } from "../library-sui/src/v3/on-chain-calls/account";
import { ADDRESSES, base64ToHex, fromBase64, REQUEST_LIFESPAN } from "../library-sui/src";

describe("Account", () => {
    before(async () => {
        await bluefinV3.admin.mintUSDC();
        await SIMULATOR.init();
        await provideMarginToAccount(
            bluefinV3,
            SIMULATOR,
            bluefinV3.signer.toSuiAddress()
        );
    });

    describe("Authorization", () => {
        it("should revert as the authorization payload has lived out its lifespan", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                true
            );

            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now() + REQUEST_LIFESPAN + 1000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should revert as the authorization payload is signed for some other IDS", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                true,
                { ids: ADDRESSES.ZERO }
            );

            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1006");
        });

        it("should allow the parent (account owner) to authorize an account on its behalf", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                true
            );

            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const resp = await bluefinV3.sequencer.authorizeUser(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now()
            );

            expect(Transaction.getStatus(resp)).to.be.equal("success");

            const authUsers = await Account.getAuthorizedAccounts(
                SUI_CLIENT,
                PARSER.getInternalDataStore(),
                bluefinV3.walletAddress
            );

            expect(authUsers.length).to.be.equal(1);
            expect(
                authUsers.indexOf(
                    "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa"
                )
            ).to.be.greaterThanOrEqual(0);
        });

        it("should allow the parent (account owner) to authorize multiple accounts", async () => {
            {
                const payload = await bluefinV3.requests.authorizeUser(
                    "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                    true
                );

                const expectedHash = SIMULATOR.computeSequenceHash(
                    base64ToHex(payload.signature)
                );

                const resp = await bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now()
                );
                expect(Transaction.getStatus(resp)).to.be.equal("success");
            }

            {
                const payload = await bluefinV3.requests.authorizeUser(
                    "0x80c3d285c2fe5ccacd1a1fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                    true
                );

                const expectedHash = SIMULATOR.computeSequenceHash(
                    base64ToHex(payload.signature)
                );

                const resp = await bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now()
                );
                expect(Transaction.getStatus(resp)).to.be.equal("success");
            }

            const authUsers = await Account.getAuthorizedAccounts(
                SUI_CLIENT,
                PARSER.getInternalDataStore(),
                bluefinV3.walletAddress
            );

            expect(authUsers.length).to.be.equal(2);
            expect(
                authUsers.indexOf(
                    "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa"
                )
            ).to.be.equal(0);
            expect(
                authUsers.indexOf(
                    "0x80c3d285c2fe5ccacd1a1fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa"
                )
            ).to.be.equal(1);

            {
                const payload = await bluefinV3.requests.authorizeUser(
                    "0x80c3d285c2fe5ccacd1a1fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                    false
                );

                const expectedHash = SIMULATOR.computeSequenceHash(
                    base64ToHex(payload.signature)
                );

                const resp = await bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now()
                );
                expect(Transaction.getStatus(resp)).to.be.equal("success");
            }
        });

        it("should allow the parent of the account to remove a user from its authorized list", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                true
            );

            // get the expected sequence hash2
            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature)
            );

            const resp = await bluefinV3.sequencer.authorizeUser(
                payload.serializedData,
                payload.signature,
                expectedHash,
                Date.now()
            );

            expect(Transaction.getStatus(resp)).to.be.equal("success");

            const authUsers = await Account.getAuthorizedAccounts(
                SUI_CLIENT,
                PARSER.getInternalDataStore(),
                bluefinV3.walletAddress
            );

            expect(authUsers.length).to.be.equal(1);

            const payload2 = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                false
            );

            // get the expected sequence hash2
            const expectedHash3 = SIMULATOR.computeSequenceHash(
                Buffer.from(fromBase64(payload2.signature)).toString("hex")
            );

            const resp3 = await bluefinV3.sequencer.authorizeUser(
                payload2.serializedData,
                payload2.signature,
                expectedHash3,
                Date.now()
            );

            expect(Transaction.getStatus(resp3)).to.be.equal("success");

            const authUsers2 = await Account.getAuthorizedAccounts(
                SUI_CLIENT,
                PARSER.getInternalDataStore(),
                bluefinV3.walletAddress
            );

            expect(authUsers2.length).to.be.equal(0);
        });

        it("should succeed when trying to remove a non-existent authorized account", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x81c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                false
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const resp2 = await bluefinV3.sequencer.authorizeUser(
                payload.serializedData,
                payload.signature,
                expectedHash2,
                Date.now(),
                { dryRun: true }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");
        });

        it("should revert when trying to authorize for some one else's account", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                "0x80c3d285c2fe5ccacd1a2fbc1fc757cbeab5134f1ef1e97803fe653e041c88aa",
                true,
                { account: TEST_WALLETS[0].address }
            );

            // get the expected sequence hash2
            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.authorizeUser(
                    payload.serializedData,
                    payload.signature,
                    expectedHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1014");
        });
    });
});
