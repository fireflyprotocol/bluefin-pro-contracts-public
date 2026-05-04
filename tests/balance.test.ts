import { expect } from "chai";
import { bluefinV3, PARSER, SIMULATOR, SUI_CLIENT } from "../env";
import {
    USDC_BASE_DECIMALS,
    bigNumber,
    toBaseNumber,
    toBigNumber
} from "../library-sui/dist";
import { IOraclePriceUpdate, ISignedOrder } from "../library-sui/src/v3";
import { createAccount, getTestAccounts } from "../library-sui/src/helpers";
import { provideMarginToAccount } from "./helpers/utils";
import { SUI_NATIVE_BASE } from "../library-sui/src/constants";
import { toBigNumberStr } from "../library-sui/src/library";
import { CoinUtils } from "../library-sui/src";
import { Account } from "../library-sui/src/v3/on-chain-calls/account";

describe("Balance", () => {
    before(async () => {
        await SIMULATOR.init();
    });

    it("should mint 5 USDC to provided address", async () => {
        const accountAddress =
            "0x17826aa78491a3dd76a13187cdd4b35b2cc5acbbcb6712582fced3856dbb12ec";

        const oldBalance = await CoinUtils.getCoinBalance(
            SUI_CLIENT,
            accountAddress,
            PARSER.getAssetCoinType("USDC")
        );

        await bluefinV3.admin.mintUSDC({
            amountE6: toBigNumberStr(5, USDC_BASE_DECIMALS),
            to: accountAddress
        });

        const newBalance = await CoinUtils.getCoinBalance(
            SUI_CLIENT,
            accountAddress,
            PARSER.getAssetCoinType("USDC")
        );

        const result = toBaseNumber(
            bigNumber(newBalance).minus(bigNumber(oldBalance)),
            0,
            USDC_BASE_DECIMALS
        );

        expect(result).to.be.equal(5);
    });

    it("should show withdrawable balance as zero", async () => {
        const account = createAccount();
        const balance = await Account.getWithdrawableAssets(
            bluefinV3.suiClient,
            bluefinV3.parser,
            account.address,
            "USDC"
        );
        expect(balance).to.be.equal(0);
    });

    it("should show withdrawable balance as 100$", async () => {
        const account = createAccount();

        await provideMarginToAccount(bluefinV3, SIMULATOR, account.address, {
            amount: 100
        });

        const balance = await Account.getWithdrawableAssets(
            bluefinV3.suiClient,
            bluefinV3.parser,
            account.address,
            "USDC"
        );
        expect(balance).to.be.equal(100);
    });

    it("should show withdrawable balance as 5485$ as the remaining amount is being used to collateralize the position", async () => {
        const [alice, bob] = getTestAccounts(true);

        await provideMarginToAccount(bluefinV3, SIMULATOR, alice.address, {
            amount: 10000
        });

        await provideMarginToAccount(bluefinV3, SIMULATOR, bob.address, {
            amount: 10000
        });

        /// position value: 2000 * 50 = 100_000
        /// margin required = 100_000 * 0.045 = 4500
        /// fee: 1.5 bps = position value * 1.5 bps = 15$
        /// Available margin to withdraw should be 10K - 4.5K - 15$ = 5485$
        const makerPayload = await bluefinV3.requests.createSignedOrder(
            { side: "SHORT", price: 2000, quantity: 50 },
            { signer: alice.signer }
        );
        const takerPayload = await bluefinV3.requests.createSignedOrder(
            { side: "LONG", price: 2000, quantity: 50 },
            { signer: bob.signer }
        );

        const fill = toBigNumberStr(50, SUI_NATIVE_BASE);
        const timestamp = Date.now();

        const sequenceHash = SIMULATOR.performTrade(
            makerPayload.serializedData,
            takerPayload.serializedData,
            fill,
            timestamp,
            false
        );

        const oraclePrices = [
            {
                perpetual: "ETH-PERP",
                price: toBigNumber(2000, SUI_NATIVE_BASE)
            }
        ] as Array<IOraclePriceUpdate>;

        await bluefinV3.sequencer.performTrade(
            makerPayload.rawData as ISignedOrder,
            takerPayload.rawData as ISignedOrder,
            fill,
            oraclePrices,
            sequenceHash,
            timestamp,
            { dryRun: false }
        );

        const balance = await Account.getWithdrawableAssets(
            bluefinV3.suiClient,
            bluefinV3.parser,
            alice.address,
            "USDC"
        );
        expect(balance).to.be.equal(5485);
    });
});
