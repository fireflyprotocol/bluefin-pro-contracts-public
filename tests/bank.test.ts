import { expect, provideMarginToAccount } from "./helpers/utils";
import { bluefinV3, SIMULATOR } from "../env";
import {
    TEST_WALLETS,
    Transaction,
    SUI_NATIVE_BASE,
    toBaseNumber,
    toBigNumber,
    toBigNumberStr,
    getKeyPairFromSeed,
    base64ToHex,
    USDC_BASE_DECIMALS
} from "../library-sui";
import { bytesToHex } from "@noble/hashes/utils";
import {
    getRandomString,
    IAssetBankDeposit,
    IDepositEvent,
    IOraclePriceUpdate,
    ISignedOrder,
    ITaintedAssetRemoved,
    IWithdrawEvent
} from "../library-sui/src/v3";
import { ADDRESSES, fromBase64, REQUEST_LIFESPAN } from "../library-sui/src";
import { getTestAccounts } from "../library-sui/src/helpers";

describe("Bank", () => {
    before(async () => {
        await bluefinV3.admin.mintUSDC({
            amountE6: toBigNumberStr(2_000_000, USDC_BASE_DECIMALS)
        });
        await SIMULATOR.init();
    });

    describe("External/Asset Bank", () => {
        it("should fail to support `USDC` asset as there already exists an asset with same symbol", async () => {
            await expect(
                bluefinV3.admin.supportAsset(
                    bluefinV3.parser.getAssetCoinType("USDC"),
                    "USDC",
                    SUI_NATIVE_BASE,
                    SUI_NATIVE_BASE,
                    SUI_NATIVE_BASE,
                    true,
                    toBigNumberStr(1, SUI_NATIVE_BASE),
                    toBigNumberStr(1_000_000, SUI_NATIVE_BASE),
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1041");
        });

        it("should allow the admin to support an asset on external bank", async () => {
            const resp = await bluefinV3.admin.supportAsset(
                `${bluefinV3.parser.getPackageId()}::coin::COIN`,
                `TEST_ASSET_${getRandomString(6)}`,
                SUI_NATIVE_BASE,
                toBigNumberStr(1, SUI_NATIVE_BASE),
                toBigNumberStr(1, SUI_NATIVE_BASE),
                true,
                toBigNumberStr(1, SUI_NATIVE_BASE),
                toBigNumberStr(1_000_000, SUI_NATIVE_BASE),
                { dryRun: true }
            );
            expect(Transaction.getStatus(resp)).to.be.equal("success");
        });

        it("should deposit 5.6 USDC to external margin/asset bank", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                {
                    dryRun: true,
                    account: TEST_WALLETS[4].address
                }
            );
            expect(Transaction.getStatus(resp)).to.be.equal("success");
            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            expect(toBaseNumber(event.amount, 2, 9)).to.be.equal(5.6);
        });

        it("should fail to deposit 0.1 USDC as min allowed deposits are 1 USDC", async () => {
            await expect(
                bluefinV3.user.depositToAssetBank(
                    "USDC",
                    toBigNumber(0.1, USDC_BASE_DECIMALS),
                    {
                        dryRun: true,
                        account: TEST_WALLETS[4].address
                    }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        xit("should fail to deposit 1.1 million USDC as max allowed deposits are 1M USDC", async () => {
            await expect(
                bluefinV3.user.depositToAssetBank(
                    "USDC",
                    toBigNumber(1_100_000, USDC_BASE_DECIMALS),
                    {
                        dryRun: true,
                        account: TEST_WALLETS[4].address
                    }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        it("should revert as deposits can not be made to ZERO address", async () => {
            await expect(
                bluefinV3.user.depositToAssetBank(
                    "USDC",
                    toBigNumber(5.6, USDC_BASE_DECIMALS),
                    {
                        account: ADDRESSES.ZERO, // zero address
                        dryRun: true
                    }
                )
            ).to.be.rejectedWith("1004");
        });
    });

    describe("Internal Bank", () => {
        it("should deposit 5.6 USDC to user address in internal bank", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[0].address }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.depositToInternalBank(event, false);

            const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash,
                {
                    dryRun: true
                }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const events2 = (await Transaction.getEvents(
                resp2,
                "Deposit"
            )[0]) as IDepositEvent;

            expect(toBaseNumber(events2.amount, 2, 9)).to.be.equal(5.6);

            expect(bytesToHex(new Uint8Array(events2.sequence_hash))).to.be.equal(
                expectedHash
            );
        });

        it("should allow alice to deposit into bob's account", async () => {
            // the depositor is admin/alice
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[0].address } // bob's address
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.depositToInternalBank(event, false);

            const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash,
                {
                    dryRun: true
                }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const events2 = (await Transaction.getEvents(
                resp2,
                "Deposit"
            )[0]) as IDepositEvent;

            expect(toBaseNumber(events2.amount, 2, 9)).to.be.equal(5.6);

            expect(bytesToHex(new Uint8Array(events2.sequence_hash))).to.be.equal(
                expectedHash
            );
        });

        it("should revert when trying to deposit twice in internal bank using same nonce", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[4].address }
            );

            expect(Transaction.getStatus(resp)).to.be.equal("success");

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            const expectedHash = SIMULATOR.depositToInternalBank(event);

            // will pass
            const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const expectedHash2 = SIMULATOR.depositToInternalBank(event, false);

            // will fail
            await expect(
                bluefinV3.sequencer.depositToInternalBank(event.nonce, expectedHash2, {
                    dryRun: true
                })
            ).to.eventually.be.rejectedWith("1003");
        });

        it("should successfully withdraw 5$ from margin bank", async () => {
            const account = getKeyPairFromSeed(TEST_WALLETS[7].phrase, "ED25519");

            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(10, USDC_BASE_DECIMALS),
                { account: account.toSuiAddress() }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash1 = SIMULATOR.depositToInternalBank(event);

            // move funds to internal bank
            const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash1
            );

            const depositEvent = Transaction.getEvents(
                resp2,
                "Deposit"
            )[0] as IDepositEvent;

            const payload = await bluefinV3.requests.withdrawal(
                event.asset,
                toBigNumber(5, SUI_NATIVE_BASE),
                {
                    signer: account,
                    account: account.toSuiAddress()
                }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            const resp3 = await bluefinV3.sequencer.withdrawFromBank(
                payload.serializedData,
                payload.signature,
                [],
                expectedHash2,
                Date.now(),
                { dryRun: true }
            );

            expect(Transaction.getStatus(resp3)).to.be.equal("success");

            const withdrawEvent = Transaction.getEvents(
                resp3,
                "Withdraw"
            )[0] as IWithdrawEvent;

            expect(
                toBaseNumber(depositEvent.assets[0].quantity, 0, SUI_NATIVE_BASE) -
                    toBaseNumber(withdrawEvent.assets[0].quantity, 0, SUI_NATIVE_BASE)
            ).to.be.equal(5);
        });

        it("should revert as the withdraw payload is expired", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(5, SUI_NATIVE_BASE)
            );

            const expectedHash = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash,
                    Date.now() + REQUEST_LIFESPAN + 1000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1046");
        });

        it("should revert when trying to withdraw more than available margin", async () => {
            const keyPair = getKeyPairFromSeed(TEST_WALLETS[7].phrase, "ED25519");

            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(5_000_000, SUI_NATIVE_BASE),
                {
                    account: keyPair.toSuiAddress(),
                    signer: keyPair
                }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith("1017");
        });

        it("should fail as there are not enough funds to withdraw", async () => {
            const [alice, bob] = getTestAccounts(true);

            let oraclePrices = [
                {
                    perpetual: "ETH-PERP",
                    price: toBigNumber(2000, SUI_NATIVE_BASE)
                }
            ] as Array<IOraclePriceUpdate>;

            // will fund both accounts with 10000 USDC
            await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address, {
                amount: 10000
            });

            await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address, {
                amount: 10000
            });

            // need 2000 * 100 = 200_000 USDC to open the positions.
            // Since perpetual has imr 4.5% this allows max leverage 22.2%
            // i.e. with 10000$, the user will be able to open 200K USD
            // worth positions.
            const makerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "SHORT", price: 2000, quantity: 100 },
                { signer: alice.signer }
            );
            const takerPayload = await bluefinV3.requests.createSignedOrder(
                { side: "LONG", price: 2000, quantity: 100 },
                { signer: bob.signer }
            );

            const fill = toBigNumberStr(100, SUI_NATIVE_BASE);
            const timestamp = Date.now();

            const sequenceHash = SIMULATOR.performTrade(
                makerPayload.serializedData,
                takerPayload.serializedData,
                fill,
                timestamp,
                true // will update
            );

            await bluefinV3.sequencer.performTrade(
                makerPayload.rawData as ISignedOrder,
                takerPayload.rawData as ISignedOrder,
                fill,
                oraclePrices,
                sequenceHash,
                timestamp,
                { dryRun: false }
            );

            // try to withdraw 2000$
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(2000, SUI_NATIVE_BASE),
                { account: alice.address, signer: alice.signer }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith("1065");
        });

        it("should revert when trying to withdraw from an account that doesn't exist", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(5_000_000, SUI_NATIVE_BASE),
                { account: TEST_WALLETS[4].address }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith("1014");
        });

        it("should revert as the signatures and payload bytes don't match", async () => {
            const payload1 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(5, SUI_NATIVE_BASE)
            );

            const payload2 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(6, SUI_NATIVE_BASE)
            );

            // get the expected sequence hash2
            const expectedHash = SIMULATOR.computeSequenceHash(
                Buffer.from(fromBase64(payload1.signature)).toString("hex"),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload1.serializedData,
                    payload2.signature,
                    [],
                    expectedHash,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith(/2003/i);
        });

        it("should not be able to create withdrawal payload with account address not having 0x in the beginning", async () => {
            const keyPair = getKeyPairFromSeed(TEST_WALLETS[7].phrase, "ED25519");

            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                {
                    account: keyPair.toSuiAddress()
                }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.depositToInternalBank(event);

            await bluefinV3.sequencer.depositToInternalBank(event.nonce, expectedHash);

            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(1, SUI_NATIVE_BASE),
                // removing 0x from the address
                { account: `${keyPair.toSuiAddress().slice(2)}`, signer: keyPair }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith(/2003/i);
        });

        it("should revert as signatory account does not have permission for the user", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumber(5, SUI_NATIVE_BASE),
                { account: TEST_WALLETS[0].address }
            );

            // get the expected sequence hash2
            const expectedHash2 = SIMULATOR.computeSequenceHash(
                base64ToHex(payload.signature),
                false
            );

            await expect(
                bluefinV3.sequencer.withdrawFromBank(
                    payload.serializedData,
                    payload.signature,
                    [],
                    expectedHash2,
                    Date.now(),
                    { dryRun: true }
                )
            ).to.eventually.be.rejectedWith("1014");
        });
    });

    describe("Tainted Deposit", () => {
        it("Should remove a tainted asset from EDS", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[0].address }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.removeTaintedAsset(event, false);

            const resp2 = await bluefinV3.sequencer.removeTaintedAsset(
                event.nonce,
                expectedHash,
                {
                    dryRun: true
                }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const events2 = (await Transaction.getEvents(
                resp2,
                "TaintedAssetRemoved"
            )[0]) as ITaintedAssetRemoved;

            expect(toBaseNumber(events2.amount, 2, 9)).to.be.equal(5.6);

            expect(bytesToHex(new Uint8Array(events2.sequence_hash))).to.be.equal(
                expectedHash
            );
        });

        it("Should fail to remove a tainted asset that has already been moved to IDS", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[0].address }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.depositToInternalBank(event);

            const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                event.nonce,
                expectedHash,
                {
                    dryRun: false
                }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const expectedHash3 = SIMULATOR.removeTaintedAsset(event, false);

            await expect(
                bluefinV3.sequencer.removeTaintedAsset(event.nonce, expectedHash3, {
                    dryRun: true
                })
            ).to.rejectedWith("1003");
        });

        it("Should be able to deposit even after the asset of a user are marked as tainted", async () => {
            const resp = await bluefinV3.user.depositToAssetBank(
                "USDC",
                toBigNumber(5.6, USDC_BASE_DECIMALS),
                { account: TEST_WALLETS[0].address }
            );

            const event = (await Transaction.getEvents(
                resp,
                "AssetBankDeposit"
            )[0]) as IAssetBankDeposit;

            // get the expected sequence hash
            const expectedHash = SIMULATOR.removeTaintedAsset(event);

            const resp2 = await bluefinV3.sequencer.removeTaintedAsset(
                event.nonce,
                expectedHash,
                {
                    dryRun: false
                }
            );

            expect(Transaction.getStatus(resp2)).to.be.equal("success");

            const events2 = (await Transaction.getEvents(
                resp2,
                "TaintedAssetRemoved"
            )[0]) as ITaintedAssetRemoved;

            expect(toBaseNumber(events2.amount, 2, 9)).to.be.equal(5.6);

            expect(bytesToHex(new Uint8Array(events2.sequence_hash))).to.be.equal(
                expectedHash
            );

            {
                const resp = await bluefinV3.user.depositToAssetBank(
                    "USDC",
                    toBigNumber(5.6, USDC_BASE_DECIMALS),
                    { account: TEST_WALLETS[0].address }
                );

                const event = (await Transaction.getEvents(
                    resp,
                    "AssetBankDeposit"
                )[0]) as IAssetBankDeposit;

                // get the expected sequence hash
                const expectedHash = SIMULATOR.depositToInternalBank(event, false);

                const resp2 = await bluefinV3.sequencer.depositToInternalBank(
                    event.nonce,
                    expectedHash,
                    {
                        dryRun: true
                    }
                );

                expect(Transaction.getStatus(resp2)).to.be.equal("success");
            }
        });
    });
});
