import { expect } from "chai";
import { ADMIN, bluefinV3 } from "../env";
import { getTestAccounts, TransactionBlock } from "../library-sui/dist";
import {
    base64ToHex,
    SUI_NATIVE_BASE,
    SuiBlocks,
    toBigNumberStr,
    Transaction
} from "../library-sui/src";
import { provideMarginToAccount, setupTrade } from "./helpers/utils";
import { IOraclePriceUpdate, IPosition } from "../library-sui/src/v3";

describe("Edge Cases", () => {
    it("should not revert due to insufficient margin when trading on isolated position and have ZERO balance in cross assets", async () => {
        const [alice, bob] = getTestAccounts(true);
        await bluefinV3.simulator.init();

        await provideMarginToAccount(bluefinV3, bluefinV3.simulator, alice.address, {
            amount: 10000
        });
        await provideMarginToAccount(bluefinV3, bluefinV3.simulator, bob.address, {
            amount: 100.085
        });

        let txb = new TransactionBlock();

        await setupTrade(bluefinV3, txb, {
            oraclePrice: 100,
            executionPrice: 100,
            perpetual: "BTC-PERP",
            quantity: 1,
            makerSide: "SHORT",
            maker: {
                signer: alice.signer,
                positionType: "ISOLATED",
                leverage: 1
            },
            taker: {
                signer: bob.signer,
                positionType: "ISOLATED",
                leverage: 1
            }
        });

        await setupTrade(bluefinV3, txb, {
            oraclePrice: 90,
            executionPrice: 90,
            perpetual: "BTC-PERP",
            quantity: 1,
            makerSide: "LONG",
            maker: {
                signer: alice.signer,
                positionType: "ISOLATED",
                leverage: 1
            },
            taker: {
                signer: bob.signer,
                positionType: "ISOLATED",
                leverage: 1
            }
        });

        txb.setGasBudget(1000000000);

        const result2 = await SuiBlocks.dryRunTxBlock(
            txb,
            bluefinV3.suiClient,
            bluefinV3.signer
        );
        expect(result2.effects.status.status).to.equal("success");
    });

    it("fail to open a position when selected leverage > max allowed market leverage", async () => {
        // max allowed leverage is 22x on ETH

        const [alice, bob] = getTestAccounts(true);
        await bluefinV3.simulator.init();

        await provideMarginToAccount(bluefinV3, bluefinV3.simulator, alice.address, {
            amount: 1000000
        });
        await provideMarginToAccount(bluefinV3, bluefinV3.simulator, bob.address, {
            amount: 10000
        });

        let txb = new TransactionBlock();

        await setupTrade(bluefinV3, txb, {
            oraclePrice: 4000,
            executionPrice: 4000,
            perpetual: "ETH-PERP",
            quantity: 1.5,
            makerSide: "SHORT",
            maker: {
                signer: alice.signer,
                positionType: "ISOLATED",
                leverage: 35 // < this is wrong, max allowed leverage is 22x
            },
            taker: {
                signer: bob.signer,
                positionType: "CROSS"
            }
        });

        await expect(
            SuiBlocks.dryRunTxBlock(txb, bluefinV3.suiClient, bluefinV3.signer)
        ).to.eventually.be.rejectedWith("4002");
    });

    it("should remove margin", async () => {
        const [alice] = getTestAccounts(true);
        await bluefinV3.simulator.init();

        const position: IPosition = {
            perpetual: "ETH-PERP",
            size: toBigNumberStr(1, SUI_NATIVE_BASE),
            average_entry_price: toBigNumberStr(1000, SUI_NATIVE_BASE),
            leverage: toBigNumberStr(2, SUI_NATIVE_BASE),
            margin: toBigNumberStr(1500, SUI_NATIVE_BASE),
            is_long: true,
            is_isolated: true,
            pending_funding_payment: "0"
        };

        const request = await bluefinV3.requests.teeUpdatePosition(
            alice.address,
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

        const request2 = await bluefinV3.requests.teeUpdateAssets(
            alice.address,
            "1000000000000000000"
        );

        const sequenceHash2 = bluefinV3.simulator.computeSequenceHash(
            request2.serializedData
        );

        await bluefinV3.txBuilder.overwriteUserAssets(
            request2.serializedData,
            request2.signature,
            sequenceHash2,
            Date.now(),
            { txBlock: tx }
        );

        const oraclePrices = [
            {
                perpetual: "ETH-PERP",
                price: toBigNumberStr(1000, SUI_NATIVE_BASE) // update oracle price to 2100 making isolated position in profit
            }
        ] as Array<IOraclePriceUpdate>;

        const payload = await bluefinV3.requests.adjustMargin(
            "ETH-PERP",
            false,
            toBigNumberStr(10, SUI_NATIVE_BASE),
            { account: alice.address, signer: alice.signer }
        );

        const sequenceHash3 = bluefinV3.simulator.computeSequenceHash(
            base64ToHex(payload.signature)
        );

        const txResult = await bluefinV3.sequencer.adjustMargin(
            payload.serializedData,
            payload.signature,
            oraclePrices,
            sequenceHash3,
            Date.now(),
            { dryRun: true, txBlock: tx }
        );

        const newBug = Transaction.getEvents(txResult, "Debugging")[0];
        console.dir(newBug);
    });
});
