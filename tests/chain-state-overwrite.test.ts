import { IPosition } from "../library-sui/src/v3/interfaces/IUser";
import { getTestAccounts } from "../library-sui/src/helpers";
import { bluefinV3, ADMIN } from "../env";
import {
    base64ToHex,
    SUI_NATIVE_BASE,
    SuiBlocks,
    toBigNumberStr
} from "../library-sui/src";
import { expect, provideMarginToAccount } from "./helpers/utils";
import { Transaction } from "../library-sui/src";
import { sleep } from "../library-sui/src/blv";
import {
    IFundingRate,
    ITEEAuthorizedAccountsUpdated,
    ITEEPositionUpdatedEvent,
    ITEETradeFeeUpdated
} from "../library-sui/src/v3/interfaces";
import { TransactionBlock } from "../library-sui/dist";
import { Account } from "../library-sui/src/v3";

describe("Chain State OverWrite", async () => {
    const TEST_ACCOUNTS = getTestAccounts();
    const account = TEST_ACCOUNTS[0].address;
    beforeEach(async () => {
        await bluefinV3.simulator.init();
    });

    describe("Overwriting Isolated Positions", async () => {
        const position: IPosition = {
            perpetual: "ETH-PERP",
            size: "1000000000000000000",
            average_entry_price: "1000000000000000000",
            leverage: "1000000000000000000",
            margin: "1000000000000000000",
            is_long: true,
            is_isolated: true,
            pending_funding_payment: "0",
            funding: {
                timestamp: 1000,
                rate: {
                    value: "234",
                    sign: true
                }
            }
        };

        it("should overwrite an ETH position for a non-existent account", async () => {
            const request = await bluefinV3.requests.teeUpdatePosition(account, position);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });

        it("should overwrite an ETH position for an existing account but having no ETH  position", async () => {
            let newAccount = TEST_ACCOUNTS[1].address;
            await provideMarginToAccount(bluefinV3, bluefinV3.simulator, newAccount);

            await bluefinV3.simulator.init();

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                position
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });
        it("should overwrite an ETH position for an existing account having ETH  position", async () => {
            const request = await bluefinV3.requests.teeUpdatePosition(account, position);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const localPosition = { ...position, size: "0" };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                account,
                localPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });

        it("should remove the ETH position of an account as the overwritten ETH position has size 0", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                position
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const localPosition = { ...position, size: "0" };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                localPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.signAndExecuteTxBlock(
                tx2,
                bluefinV3.suiClient,
                ADMIN
            );

            expect(Transaction.getStatus(result)).to.equal("success");

            await sleep(2000);
            const accountState = await Account.getAccount(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                newAccount
            );
            const positions = accountState.isolatedPositions;
            expect(positions.length).to.equal(0);
        });

        it("should not update the pending funding payment of the account as it is passed as undefined", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            // pending_funding_payment is 2
            const pending_funding_payment = toBigNumberStr(2, SUI_NATIVE_BASE);

            const initPosition = { ...position, pending_funding_payment };

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                initPosition
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const newPosition = { ...position, pending_funding_payment: undefined };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                newPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const events = Transaction.getEvents(result, "TEEPositionUpdated").at(
                -1
            ) as ITEEPositionUpdatedEvent;
            expect(events.old_position.pending_funding_payment).to.equal(
                pending_funding_payment
            );
            expect(events.new_position.pending_funding_payment).to.equal(
                pending_funding_payment
            );
        });

        it("should not update the funding rate of the account as it is passed as undefined", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            const funding: IFundingRate = {
                timestamp: Date.now(),
                rate: {
                    value: "100000",
                    sign: true
                }
            };

            const initPosition = { ...position, funding };

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                initPosition
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const newPosition = { ...position, funding: undefined };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                newPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const events = Transaction.getEvents(result, "TEEPositionUpdated").at(
                -1
            ) as ITEEPositionUpdatedEvent;

            expect(events.new_position.funding?.timestamp).to.equal(
                String(funding.timestamp)
            );
            expect(events.new_position.funding?.rate.value).to.equal(funding.rate.value);
            expect(events.new_position.funding?.rate.sign).to.equal(funding.rate.sign);
        });
    });

    describe("Overwriting Cross Positions", async () => {
        const position: IPosition = {
            perpetual: "ETH-PERP",
            size: "1000000000000000000",
            average_entry_price: "1000000000000000000",
            leverage: "0",
            margin: "0",
            is_long: true,
            is_isolated: false,
            pending_funding_payment: "0",
            funding: {
                timestamp: 1000,
                rate: {
                    value: "234",
                    sign: true
                }
            }
        };

        it("should overwrite an ETH position for a non-existent account", async () => {
            const request = await bluefinV3.requests.teeUpdatePosition(account, position);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });

        it("should overwrite an ETH position for an existing account but having no ETH  position", async () => {
            let newAccount = TEST_ACCOUNTS[1].address;
            await provideMarginToAccount(bluefinV3, bluefinV3.simulator, newAccount);

            await bluefinV3.simulator.init();

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                position
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });
        it("should overwrite an ETH position for an existing account having ETH  position", async () => {
            const request = await bluefinV3.requests.teeUpdatePosition(account, position);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const localPosition = { ...position, size: "0" };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                account,
                localPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });

        it("should remove the ETH position of an account as the overwritten ETH position has size 0", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                position
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const localPosition = { ...position, size: "0" };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                localPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.signAndExecuteTxBlock(
                tx2,
                bluefinV3.suiClient,
                ADMIN
            );

            expect(Transaction.getStatus(result)).to.equal("success");

            await sleep(2000);
            const accountState = await Account.getAccount(
                bluefinV3.suiClient,
                bluefinV3.parser.getInternalDataStore(),
                newAccount
            );
            const positions = accountState.isolatedPositions;
            expect(positions.length).to.equal(0);
        });

        it("should not update the pending funding payment of the account as it is passed as undefined", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            // pending_funding_payment is 2
            const pending_funding_payment = toBigNumberStr(2, SUI_NATIVE_BASE);

            const initPosition = { ...position, pending_funding_payment };

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                initPosition
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const newPosition = { ...position, pending_funding_payment: undefined };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                newPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const events = Transaction.getEvents(result, "TEEPositionUpdated").at(
                -1
            ) as ITEEPositionUpdatedEvent;
            expect(events.old_position.pending_funding_payment).to.equal(
                pending_funding_payment
            );
            expect(events.new_position.pending_funding_payment).to.equal(
                pending_funding_payment
            );
        });

        it("should not update the funding rate of the account as it is passed as undefined", async () => {
            const newAccount = TEST_ACCOUNTS[4].address;

            const funding: IFundingRate = {
                timestamp: Date.now(),
                rate: {
                    value: "100000",
                    sign: true
                }
            };

            const initPosition = { ...position, funding };

            const request = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                initPosition
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserPosition(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const newPosition = { ...position, funding: undefined };

            const request2 = await bluefinV3.requests.teeUpdatePosition(
                newAccount,
                newPosition
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request2.serializedData
            );

            const tx2 = await bluefinV3.txBuilder.overwriteUserPosition(
                request2.serializedData,
                request2.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: tx }
            );

            const result = await SuiBlocks.dryRunTxBlock(tx2, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const events = Transaction.getEvents(result, "TEEPositionUpdated").at(
                -1
            ) as ITEEPositionUpdatedEvent;

            expect(events.new_position.funding?.timestamp).to.equal(
                String(funding.timestamp)
            );
            expect(events.new_position.funding?.rate.value).to.equal(funding.rate.value);
            expect(events.new_position.funding?.rate.sign).to.equal(funding.rate.sign);
        });
    });

    describe("Overwriting Assets", async () => {
        it("should overwrite the USDC balance of a non-existent account", async () => {
            const request = await bluefinV3.requests.teeUpdateAssets(
                account,
                "1000000000000000000"
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserAssets(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });

        it("should overwrite the USDC balance of an existing account", async () => {
            await provideMarginToAccount(bluefinV3, bluefinV3.simulator, account);

            await bluefinV3.simulator.init();

            const request = await bluefinV3.requests.teeUpdateAssets(
                account,
                "1000000000000000000"
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserAssets(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");
        });
    });

    describe("Overwriting Authorized Accounts", async () => {
        it("should overwrite authorized accounts for a non-existent account", async () => {
            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                account,
                [TEST_ACCOUNTS[0].address, TEST_ACCOUNTS[1].address]
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(2);
            expect(event.current_authorized_accounts[0]).to.be.equal(
                TEST_ACCOUNTS[0].address
            );
            expect(event.current_authorized_accounts[1]).to.be.equal(
                TEST_ACCOUNTS[1].address
            );
        });

        it("should overwrite authorized accounts for an existent account", async () => {
            let newAccount = TEST_ACCOUNTS[1].address;
            await provideMarginToAccount(bluefinV3, bluefinV3.simulator, newAccount);

            await bluefinV3.simulator.init();

            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                newAccount,
                [TEST_ACCOUNTS[0].address, TEST_ACCOUNTS[1].address]
            );

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(2);
            expect(event.current_authorized_accounts[0]).to.be.equal(
                TEST_ACCOUNTS[0].address
            );
            expect(event.current_authorized_accounts[1]).to.be.equal(
                TEST_ACCOUNTS[1].address
            );
        });

        it("should overwrite authorized accounts for an user with existing authorized account (replace)", async () => {
            let newAccount = TEST_ACCOUNTS[1];
            await provideMarginToAccount(
                bluefinV3,
                bluefinV3.simulator,
                newAccount.address
            );

            await bluefinV3.simulator.init();
            const txb = new TransactionBlock();

            const authRequest = await bluefinV3.requests.authorizeUser(
                TEST_ACCOUNTS[0].address,
                true,
                {
                    account: newAccount.address,
                    signer: newAccount.keyPair
                }
            );

            const sequenceHash1 = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(authRequest.signature)
            );

            await bluefinV3.sequencer.authorizeUser(
                authRequest.serializedData,
                authRequest.signature,
                sequenceHash1,
                Date.now(),
                { txBlock: txb, returnTxb: true }
            );

            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                newAccount.address,
                [TEST_ACCOUNTS[2].address]
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: txb }
            );

            const result = await SuiBlocks.dryRunTxBlock(txb, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(1);
            expect(event.current_authorized_accounts[0]).to.be.equal(
                TEST_ACCOUNTS[2].address
            );
        });

        it("should overwrite authorized accounts for an user with existing authorized account (remove)", async () => {
            let newAccount = TEST_ACCOUNTS[1];
            await provideMarginToAccount(
                bluefinV3,
                bluefinV3.simulator,
                newAccount.address
            );

            await bluefinV3.simulator.init();
            const txb = new TransactionBlock();

            const authRequest = await bluefinV3.requests.authorizeUser(
                TEST_ACCOUNTS[0].address,
                true,
                {
                    account: newAccount.address,
                    signer: newAccount.keyPair
                }
            );

            const sequenceHash1 = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(authRequest.signature)
            );

            await bluefinV3.sequencer.authorizeUser(
                authRequest.serializedData,
                authRequest.signature,
                sequenceHash1,
                Date.now(),
                { txBlock: txb, returnTxb: true }
            );

            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                newAccount.address,
                []
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: txb }
            );

            const result = await SuiBlocks.dryRunTxBlock(txb, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(0);
        });

        it("should overwrite authorized accounts for an user with existing authorized account (append)", async () => {
            let newAccount = TEST_ACCOUNTS[1];
            await provideMarginToAccount(
                bluefinV3,
                bluefinV3.simulator,
                newAccount.address
            );

            await bluefinV3.simulator.init();
            const txb = new TransactionBlock();

            const authRequest = await bluefinV3.requests.authorizeUser(
                TEST_ACCOUNTS[0].address,
                true,
                {
                    account: newAccount.address,
                    signer: newAccount.keyPair
                }
            );

            const sequenceHash1 = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(authRequest.signature)
            );

            await bluefinV3.sequencer.authorizeUser(
                authRequest.serializedData,
                authRequest.signature,
                sequenceHash1,
                Date.now(),
                { txBlock: txb, returnTxb: true }
            );

            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                newAccount.address,
                [TEST_ACCOUNTS[0].address, TEST_ACCOUNTS[2].address]
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: txb }
            );

            const result = await SuiBlocks.dryRunTxBlock(txb, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(2);
            expect(event.current_authorized_accounts[0]).to.be.equal(
                TEST_ACCOUNTS[0].address
            );
            expect(event.current_authorized_accounts[1]).to.be.equal(
                TEST_ACCOUNTS[2].address
            );
        });

        it("should overwrite authorized accounts for an user with existing authorized account (remove)", async () => {
            let newAccount = TEST_ACCOUNTS[1];
            await provideMarginToAccount(
                bluefinV3,
                bluefinV3.simulator,
                newAccount.address
            );

            await bluefinV3.simulator.init();
            const txb = new TransactionBlock();

            const authRequest = await bluefinV3.requests.authorizeUser(
                TEST_ACCOUNTS[0].address,
                true,
                {
                    account: newAccount.address,
                    signer: newAccount.keyPair
                }
            );

            const sequenceHash1 = bluefinV3.simulator.computeSequenceHash(
                base64ToHex(authRequest.signature)
            );

            await bluefinV3.sequencer.authorizeUser(
                authRequest.serializedData,
                authRequest.signature,
                sequenceHash1,
                Date.now(),
                { txBlock: txb, returnTxb: true }
            );

            const request = await bluefinV3.requests.teeUpdateAuthorizedAccounts(
                newAccount.address,
                []
            );

            const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            bluefinV3.txBuilder.overwriteUserAuthorizedAccounts(
                request.serializedData,
                request.signature,
                sequenceHash2,
                Date.now(),
                { txBlock: txb }
            );

            const result = await SuiBlocks.dryRunTxBlock(txb, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEEAuthorizedAccountsUpdated"
            )[0] as ITEEAuthorizedAccountsUpdated;
            expect(event.current_authorized_accounts.length).to.be.equal(0);
        });
    });

    describe("Overwriting Trading Fees", async () => {
        const fee = {
            maker: 1000,
            taker: 3000,
            applied: true
        };

        it("should overwrite trading fee for a non-existent account", async () => {
            const request = await bluefinV3.requests.teeUpdateTradeFee(account, fee);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserTradeFee(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEETradeFeeUpdated"
            )[0] as ITEETradeFeeUpdated;
            expect(+event.current_trading_fee.maker).to.be.equal(fee.maker);
            expect(+event.current_trading_fee.taker).to.be.equal(fee.taker);
            expect(event.current_trading_fee.applied).to.be.equal(fee.applied);
        });

        it("should overwrite trading fee for an existent account", async () => {
            let newAccount = TEST_ACCOUNTS[1].address;
            await provideMarginToAccount(bluefinV3, bluefinV3.simulator, newAccount);

            await bluefinV3.simulator.init();

            const request = await bluefinV3.requests.teeUpdateTradeFee(newAccount, fee);

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserTradeFee(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEETradeFeeUpdated"
            )[0] as ITEETradeFeeUpdated;
            expect(+event.current_trading_fee.maker).to.be.equal(fee.maker);
            expect(+event.current_trading_fee.taker).to.be.equal(fee.taker);
            expect(event.current_trading_fee.applied).to.be.equal(fee.applied);
        });

        it("should mark the trading fee as False for an account", async () => {
            const request = await bluefinV3.requests.teeUpdateTradeFee(account, {
                ...fee,
                applied: false
            });

            const sequenceHash = bluefinV3.simulator.computeSequenceHash(
                request.serializedData
            );

            const tx = await bluefinV3.txBuilder.overwriteUserTradeFee(
                request.serializedData,
                request.signature,
                sequenceHash,
                Date.now()
            );

            const result = await SuiBlocks.dryRunTxBlock(tx, bluefinV3.suiClient, ADMIN);

            expect(Transaction.getStatus(result)).to.equal("success");

            const event = Transaction.getEvents(
                result,
                "TEETradeFeeUpdated"
            )[0] as ITEETradeFeeUpdated;
            expect(+event.current_trading_fee.maker).to.be.equal(fee.maker);
            expect(+event.current_trading_fee.taker).to.be.equal(fee.taker);
            expect(event.current_trading_fee.applied).to.be.equal(false);
        });
    });
});
