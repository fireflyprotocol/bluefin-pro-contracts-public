import { expect } from "./helpers/utils";
import { bluefinV3, SIMULATOR } from "../env";
import {
    SUI_NATIVE_BASE,
    TEST_WALLETS,
    Transaction,
    toBaseNumber,
    toBigNumber
} from "../library-sui/dist";
import { getRandomString } from "../library-sui/src/v3";
import { PERPETUAl_CONFIG_FIELDS } from "../library-sui/src/v3/enums";
import { toBigNumberStr } from "../library-sui/src";

describe("Perpetuals", () => {
    before(async () => {
        await SIMULATOR.init();
    });

    it("should allow admin to create a perpetual", async () => {
        const { txResponse } = await bluefinV3.admin.createPerpetual(
            {
                symbol: "ETH",
                tickSize: toBigNumberStr(1, SUI_NATIVE_BASE), // 1.0
                minTradePrice: toBigNumberStr(50, SUI_NATIVE_BASE),
                maxTradePrice: toBigNumberStr(100, SUI_NATIVE_BASE)
            },
            { dryRun: true }
        );
        expect(Transaction.getStatus(txResponse)).to.be.equal("success");
    });

    it("should allow sequencer to sync ids perp state with eds perp", async () => {
        const { txResponse } = await bluefinV3.admin.createPerpetual({
            symbol: `BTC_${getRandomString(6)}`
        });

        const event = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

        // get the expected sequence hash
        const expectedHash = SIMULATOR.syncPerpetual(event, false);

        const resp2 = await bluefinV3.sequencer.syncPerpetual(
            event.perpetual.symbol,
            expectedHash,
            {
                dryRun: true
            }
        );

        expect(Transaction.getStatus(resp2)).to.be.equal("success");
    });

    it("should allow admin to update tick size of a perpetual", async () => {
        const { txResponse } = await bluefinV3.admin.createPerpetual({
            symbol: `BTC_${getRandomString(6)}`
        });

        const event = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];
        // get the expected sequence hash
        const expectedHash = SIMULATOR.syncPerpetual(event);

        await bluefinV3.sequencer.syncPerpetual(event.perpetual.symbol, expectedHash);

        const resp = await bluefinV3.admin.updatePerpetual(
            event.perpetual.symbol,
            PERPETUAl_CONFIG_FIELDS.TICK_SIZE,
            toBigNumber(0.01, SUI_NATIVE_BASE).toNumber(),
            {
                dryRun: true
            }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event2 = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(toBaseNumber(event2.perpetual.tick_size, 3, SUI_NATIVE_BASE)).to.be.equal(
            0.01
        );
    });

    it("should allow sequencer to sync ids perp state with eds perp - II", async () => {
        const symbol = `BTC_${getRandomString(6)}`;

        const { txResponse, perpetualConfig } = await bluefinV3.admin.createPerpetual({
            symbol
        });

        const event1 = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

        // write perp id to perp config
        perpetualConfig.id = event1.perpetual.id;

        // get the expected sequence hash and update the local simulator sequence hash
        const expectedHash1 = SIMULATOR.syncPerpetual(event1);

        const resp = await bluefinV3.sequencer.syncPerpetual(
            perpetualConfig.symbol!,
            expectedHash1
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        // update simulator with the deployed perpetual config
        SIMULATOR.parser.addPerpetual(perpetualConfig);

        const resp2 = await bluefinV3.admin.updatePerpetual(
            perpetualConfig.symbol!,
            PERPETUAl_CONFIG_FIELDS.TICK_SIZE,
            toBigNumber(0.002, SUI_NATIVE_BASE).toNumber()
        );

        expect(Transaction.getStatus(resp2)).to.be.equal("success");

        const event2 = Transaction.getEvents(resp2, "PerpetualUpdate")[0];

        // get the expected sequence hash
        const expectedHash2 = SIMULATOR.syncPerpetual(event2, false);

        const resp3 = await bluefinV3.sequencer.syncPerpetual(
            perpetualConfig.symbol!,
            expectedHash2,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp3)).to.be.equal("success");
    });

    it("should revert when trying to make changes to perpetuals in EDS when EDS is in un-synced state", async () => {
        const { txResponse, perpetualConfig } = await bluefinV3.admin.createPerpetual({
            symbol: `BTC_${getRandomString(6)}`
        });

        const event1 = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

        // write perp id to perp config
        perpetualConfig.id = event1.perpetual.id;

        // get the expected sequence hash and update the local simulator sequence hash
        const expectedHash1 = SIMULATOR.syncPerpetual(event1);

        const resp2 = await bluefinV3.sequencer.syncPerpetual(
            perpetualConfig.symbol!,
            expectedHash1
        );

        expect(Transaction.getStatus(resp2)).to.be.equal("success");

        // update simulator with the deployed perpetual config
        SIMULATOR.parser.addPerpetual(perpetualConfig);

        const resp3 = await bluefinV3.admin.updatePerpetual(
            perpetualConfig.symbol!,
            PERPETUAl_CONFIG_FIELDS.TICK_SIZE,
            toBigNumber(0.002, SUI_NATIVE_BASE).toNumber()
        );

        expect(Transaction.getStatus(resp3)).to.be.equal("success");

        // will fail as the last change to perpetuals in EDS is not yet synced with IDS
        await expect(
            bluefinV3.admin.updatePerpetual(
                perpetualConfig.symbol!,
                PERPETUAl_CONFIG_FIELDS.TICK_SIZE,
                toBigNumber(0.004, SUI_NATIVE_BASE).toNumber(),
                {
                    dryRun: true
                }
            )
        ).to.eventually.be.rejectedWith("1010");
    });

    it("should revert as admin is trying to update a non-existent field of a perpetual", async () => {
        await expect(
            bluefinV3.admin.updatePerpetual(
                "ETH-PERP",
                "non-existent-field" as any,
                toBigNumber(0.01, SUI_NATIVE_BASE).toNumber(),
                { dryRun: true }
            )
        ).to.be.eventually.rejectedWith("1054");
    });

    it("should allow admin to update step size of a perpetual", async () => {
        const value = toBigNumber(0.01, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.STEP_SIZE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.step_size).to.be.equal(value);
    });

    it("should allow admin to update min trade quantity of a perpetual", async () => {
        const value = toBigNumber(0.1, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MIN_TRADE_QUANTITY,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.min_trade_qty).to.be.equal(value);
    });

    it("should allow admin to update max trade quantity of a perpetual", async () => {
        const value = toBigNumber(100000, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MAX_TRADE_QUANTITY,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.max_trade_qty).to.be.equal(value);
    });

    it("should allow admin to update min trade price of a perpetual", async () => {
        const value = toBigNumber(5, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MIN_TRADE_PRICE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.min_trade_price).to.be.equal(value);
    });

    it("should allow admin to update max trade price of a perpetual", async () => {
        const value = toBigNumber(5000000, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MAX_TRADE_PRICE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.max_trade_price).to.be.equal(value);
    });

    it("should allow admin to update market take bound long", async () => {
        const value = toBigNumber(0.1, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_LONG,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.mtb_long).to.be.equal(value);
    });

    it("should allow admin to update market take bound short", async () => {
        const value = toBigNumber(0.1, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_SHORT,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.mtb_short).to.be.equal(value);
    });

    it("should allow admin to update the default maker fee", async () => {
        const value = toBigNumber(0.01, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MAKER_FEE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.maker_fee).to.be.equal(value);
    });

    it("should allow admin to update the default taker fee", async () => {
        const value = toBigNumber(0.01, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.TAKER_FEE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.taker_fee).to.be.equal(value);
    });

    it("should allow admin to update the max funding rate", async () => {
        const value = toBigNumber(0.05, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MAX_FUNDING_RATE,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.max_funding_rate).to.be.equal(value);
    });

    it("should allow admin to update the insurance pool address", async () => {
        const value = TEST_WALLETS[2].address;

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.INSURANCE_POOL_ADDRESS,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(event.perpetual.insurance_pool).to.be.equal(value);
    });

    it("should allow admin to update the fee pool address", async () => {
        const value = TEST_WALLETS[2].address;

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.FEE_POOL_ADDRESS,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];

        expect(event.perpetual.fee_pool).to.be.equal(value);
    });

    it("should allow admin to update insurance pool's liquidation premium ratio", async () => {
        const value = toBigNumber(0.05, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.INSURANCE_POOL_PREMIUM_PORTION,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.insurance_pool_ratio).to.be.equal(value);
    });

    it("should allow admin to mark a perpetual as isolated only", async () => {
        const value = true;

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.ISOLATED_ONLY,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(event.perpetual.isolated_only).to.be.equal(value);
    });

    it("should allow admin to pause trading on a perpetual", async () => {
        const value = true;

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.TRADING_STATUS,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(event.perpetual.trading_status).to.be.equal(value);
    });

    it("should allow admin to delist a market", async () => {
        const value = toBigNumber(3451.2, SUI_NATIVE_BASE).toNumber();

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.DELIST,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.delisting_price).to.be.equal(value);
        expect(event.perpetual.delist).to.be.equal(true);
    });

    it("should allow admin to update the max allowed oi open", async () => {
        const value = [
            toBigNumber(10_000, SUI_NATIVE_BASE).toNumber(),
            toBigNumber(20_000, SUI_NATIVE_BASE).toNumber()
        ];

        const resp = await bluefinV3.admin.updatePerpetual(
            "ETH-PERP",
            PERPETUAl_CONFIG_FIELDS.MAX_ALLOWED_OI_OPEN,
            value,
            { dryRun: true }
        );

        expect(Transaction.getStatus(resp)).to.be.equal("success");

        const event = Transaction.getEvents(resp, "PerpetualUpdate")[0];
        expect(+event.perpetual.max_notional_at_open[0]).to.be.equal(value[0]);
        expect(+event.perpetual.max_notional_at_open[1]).to.be.equal(value[1]);
    });

    describe("Market Config Bounds Reversions", () => {
        it("should fail to set step size < min allowed step size", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.STEP_SIZE,
                    1,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set step size > max allowed step size", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.STEP_SIZE,
                    1000000000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set imr < max allowed imr", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.IMR,
                    10000000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set imr > max allowed imr", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.IMR,
                    500000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set mmr < min allowed mmr", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.IMR,
                    17400000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set min trade qty < min allowed tick size", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MIN_TRADE_QUANTITY,
                    1,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set max trade qty > max allowed trade quantity", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_TRADE_QUANTITY,
                    100000000000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1030");
        });

        it("should fail to set min trade price < min allowed trade price", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MIN_TRADE_PRICE,
                    9999,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set max trade price > max allowed trade price", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_TRADE_PRICE,
                    200000000000000000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set market take bound (long) > max market take bound", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_LONG,
                    200000000000000000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set market take bound (short) > max market take bound", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_SHORT,
                    200000000000000000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set market take bound (long) > min market take bound", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_LONG,
                    100000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set market take bound (short) < min market take bound", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MARKET_TAKE_BOUND_SHORT,
                    100000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set maker fee > max allowed fee", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAKER_FEE,
                    30000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set taker fee > max allowed fee", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.TAKER_FEE,
                    30000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set max funding rate > max allowed funding rate", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_FUNDING_RATE,
                    500000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set max funding rate < min allowed funding rate", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_FUNDING_RATE,
                    999999,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set insurance pool premium percentage < min allowed premium percentage", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.INSURANCE_POOL_PREMIUM_PORTION,
                    1000000,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set insurance pool premium percentage > max allowed premium percentage", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.INSURANCE_POOL_PREMIUM_PORTION,
                    500000001,
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set notional value > max allowed notion", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_ALLOWED_OI_OPEN,
                    [20000000000000000],
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });

        it("should fail to set notional value < min allowed notion", async () => {
            await expect(
                bluefinV3.admin.updatePerpetual(
                    "ETH-PERP",
                    PERPETUAl_CONFIG_FIELDS.MAX_ALLOWED_OI_OPEN,
                    [100000000000],
                    { dryRun: true }
                )
            ).to.be.eventually.rejectedWith("1060");
        });
    });
});
