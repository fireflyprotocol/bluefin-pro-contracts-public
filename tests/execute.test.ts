import * as fs from "fs";
import * as path from "path";
import { readJSONFile, sleep } from "../library-sui/src/blv";
import { createAccount } from "../library-sui/src/helpers";
import { Address, BigNumber, TransactionBlock } from "../library-sui/src/types";
import { bluefinV3 } from "../env";
import {
    base64ToHex,
    CoinUtils,
    SUI_NATIVE_BASE,
    SuiBlocks,
    toBigNumber,
    toBigNumberStr,
    Transaction,
    USDC_BASE_DECIMALS
} from "../library-sui/src";
import {
    getRandomString,
    BluefinV3,
    ITradeExecutedEvent,
    ILiquidationExecutedEvent,
    IFundingRateAppliedEvent,
    ILeverageAdjustedEvent,
    IMarginAdjustedEvent,
    IOraclePriceUpdate,
    IAssetBankDeposit,
    ISignedOrder,
    IRequestPayload,
    IMarketFundingRate
} from "../library-sui/src/v3";
import { expect } from "chai";
import { BCSUtils, Order } from "../library-sui/src/v3/utils/bcs";
import { expectPosition } from "./helpers/utils";
import { POSITION_TYPES } from "../library-sui/src/v3/enums";

const accounts = {};
let coinsToUse: string[] = [];
let v3 = bluefinV3;
let fundingTimestamp = new Date(
    3600000 * (1 + Math.round(Date.now() / 3600000))
).getTime();

const errorCodes = {
    "Realized loss would be greater than the available balance": 1017,
    "Flipping not allowed when position is in margin call": 4001,
    "Increasing position in Margin call is not allowed": 4001,
    "Increasing size is not allowed when position is in margin call": 4001,
    "Orders trade when account is below mmr is not allowed": 4001,
    "Orders trade when account is bankrupt is not allowed": 4001,
    "Orders trade increasing position and leading from case 1 to 2 not allowed": 4002,
    "Orders trade increasing position and leading from case 1 to 3 not allowed": 4002,
    "Drawing capital from cross account in margin call is not allowed": 4002,
    "Drawing capital from cross account below mmr is not allowed": 4002,
    "Drawing capital from bankrupt cross account is not allowed": 4002,
    "No trades are allowed when position is below mmr": 4003,
    "No trades are allowed when position is bankrupt": 4003,
    "Cross Account is Healthy and not liquidatable": 1042,
    "Cross Account is in margin call and not liquidatable": 1042,
    "Account has a more profitable position": 1049,
    "Liquidated Position Would Flip": 1043,
    "Position does not exist": 1035,
    "Liquidator is in margin call": 4002,
    "Liquidator's isolated account is in margin call": 4001,
    "Liquidator already has an isolated position in this market": 1059,
    "Isolated account is healthy and not liquidatable": 1042,
    "Isolated account is in margin call and not liquidatable": 1042,
    "Isolated position cannot be flipped": 1043,
    "Liquidator account would become unhealthy": 4002,
    "should fail as the user ends up in margin call after leverage adjustment": 4002,
    "User is in C2": 1017,
    "User is in C3": 1017,
    "User is in C4": 1017,
    "should fail on pre-trade checks": 4001,
    "Insufficient margin available to remove": 1017,
    "Maintenance health must be non-zero before entering a trade": 4003
};

function getFilesFromDirectory(directoryPath: string): string[] {
    if (!fs.existsSync(directoryPath)) {
        console.error(`Directory does not exist: ${directoryPath}`);
        return [];
    }

    try {
        return fs.readdirSync(directoryPath).map(file => path.join(directoryPath, file));
    } catch (error) {
        console.error(`Error reading directory: ${error}`);
        return [];
    }
}

async function createOrder(
    details: any,
    marketNameSubstitute: any
): Promise<IRequestPayload> {
    const account = accounts[details.account];
    const market = marketNameSubstitute[details.market];

    const payload = await v3.requests.createSignedOrder(
        {
            market,
            side: details.side,
            price: details.price,
            quantity: details.orderQty,
            positionType: details.positionType,
            leverage: details.positionType == "ISOLATED" ? details.leverage : 0
        },
        { signer: account.signer }
    );

    return payload;
}

function assertAccountState(
    action: any,
    marketNameSubstitute: any,
    accounts: any,
    actors: Address[],
    event:
        | ITradeExecutedEvent
        | ILiquidationExecutedEvent
        | IFundingRateAppliedEvent[]
        | ILeverageAdjustedEvent
        | IMarginAdjustedEvent
) {
    if (!action.expected) return;

    const iterable = action.expected.accounts
        ? action.expected.accounts
        : action.expected;

    for (const expected of iterable) {
        if (!actors.includes(expected.account)) {
            continue;
        }

        let onChainState = undefined as any;
        if (action.action_type == "orders_trade") {
            event = event as ITradeExecutedEvent;
            onChainState =
                expected.account == action.maker.account ? event.maker : event.taker;
        } else if (action.action_type.indexOf("liquidate") > -1) {
            event = event as ILiquidationExecutedEvent;
            onChainState =
                expected.account == action.details.maker
                    ? {
                          assets: event.liquidatee_assets,
                          position: event.liquidatee_position
                      }
                    : {
                          assets: event.liquidator_assets,
                          position: event.liquidator_position
                      };
        } else if (action.action_type == "funding_payment") {
            event = event as IFundingRateAppliedEvent[];
            for (const e of event) {
                const expectedAccountAddress = Object.keys(accounts)
                    .filter(k => k == expected.account)
                    .map(k => accounts[k].address)[0];
                if (e.account == expectedAccountAddress)
                    onChainState = { assets: e.assets, position: e.position };
            }
        } else if (
            action.action_type == "adjust_leverage" ||
            action.action_type == "adjust_margin"
        ) {
            event = event as ILeverageAdjustedEvent;
            onChainState = { assets: event.assets, position: event.position };
        } else {
            throw `Assertion for an unknown action type: ${action.action_type}`;
        }

        // assets assertion
        expect(onChainState.assets[0].name).to.be.equal(expected.assets[0].symbol);
        expect(onChainState.assets[0].quantity).to.be.equal(
            toBigNumberStr(expected.assets[0].quantity, SUI_NATIVE_BASE)
        );

        for (const position of expected.positions) {
            const marketSub = marketNameSubstitute[position.market];
            if (
                marketSub == (event as any).market ||
                action.action_type == "funding_payment" ||
                action.action_type == "adjust_margin" ||
                action.action_type == "adjust_leverage"
            ) {
                const isolated = position.type == "ISOLATED";

                expectPosition(onChainState.position, {
                    size: position.size,
                    margin: position.margin,
                    entryPrice: position.avgEntryPrice,
                    side: position.side,
                    leverage: isolated ? position.leverage : 0,
                    pendingFundingPayment: position.pendingFundingPayment,
                    isolated
                });
            }
        }
    }
}

function findOraclePrice(
    prices: Array<{ market: string; price: number }>,
    market: string
) {
    for (const price of prices) {
        if (price.market == market) return price.price;
    }

    throw `Oracle price not found for market: ${market}`;
}

async function execute(test: any) {
    const number = test.title.match(/\d+/)[0];
    if (number >= 425 && number <= 429) return;

    // initialize the simulator
    await v3.simulator.init();
    let sequenceHash = v3.simulator.getSequenceHash();
    let market;
    let userAccount;

    let txBlock = new TransactionBlock();
    txBlock.setGasBudget(10e9);

    const marketNameSubstitute = {};
    const coins = JSON.parse(JSON.stringify(coinsToUse));

    // create markets
    for (const market of test.markets) {
        marketNameSubstitute[market.name] =
            `${market.name}_${getRandomString(4)}`.substring(0, 12);

        const { txResponse, perpetualConfig } = await v3.admin.createPerpetual(
            {
                symbol: marketNameSubstitute[market.name],
                imr: toBigNumberStr(market.imr, SUI_NATIVE_BASE),
                mmr: toBigNumberStr(market.mmr, SUI_NATIVE_BASE),
                makerFee: toBigNumberStr(market.makerFee, SUI_NATIVE_BASE),
                takerFee: toBigNumberStr(market.takerFee, SUI_NATIVE_BASE),
                tickSize: toBigNumberStr(market.tickSize, SUI_NATIVE_BASE),
                stepSize: toBigNumberStr(market.stepSize, SUI_NATIVE_BASE),
                maxTradePrice: toBigNumberStr(500_000, SUI_NATIVE_BASE),
                maxNotionalAtOpen: new Array(20).fill(
                    toBigNumberStr(10_000_000, SUI_NATIVE_BASE)
                ),
                maxTradeQty: toBigNumberStr(10000, SUI_NATIVE_BASE),
                maxFundingRate: toBigNumberStr(0.05, SUI_NATIVE_BASE)
            }
            // { txBlock, returnTxb: true}
        );

        // txBlock = txResponse as TransactionBlock;

        // const response = await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer);
        // expect(Transaction.getStatus(response)).to.be.equal("success");

        const event = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

        perpetualConfig.id = event.perpetual.id as string;

        const deployment = { ...v3.parser.deployment };

        if (!deployment["Perpetuals"]) deployment["Perpetuals"] = {};

        deployment["Perpetuals"][perpetualConfig.symbol as any] = perpetualConfig;

        v3 = new BluefinV3(v3.network, v3.suiClient, deployment, v3.signer);

        v3.simulator.setSequenceHash(sequenceHash);

        sequenceHash = v3.simulator.syncPerpetual({ perpetual: perpetualConfig });

        txBlock = (await v3.sequencer.syncPerpetual(
            perpetualConfig.symbol as any,
            sequenceHash,
            { returnTxb: true, txBlock }
        )) as TransactionBlock;

        expect(
            Transaction.getStatus(
                await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer)
            )
        ).to.be.equal("success");
    }

    // set gas fee
    const payload = await v3.requests.setGasFee(
        toBigNumberStr(test.global.gasFee, SUI_NATIVE_BASE)
    );
    sequenceHash = v3.simulator.computeSequenceHash(base64ToHex(payload.signature));
    txBlock = (await v3.sequencer.setGasFee(
        payload.serializedData,
        payload.signature,
        sequenceHash,
        Date.now(),
        { txBlock, returnTxb: true }
    )) as TransactionBlock;
    expect(
        Transaction.getStatus(
            await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer)
        )
    ).to.be.equal("success");

    // iterate over the actions of the tests
    for (const action of test.actions) {
        const actors = Array<string>();
        // replace market symbols
        const oraclePrices: Array<IOraclePriceUpdate> = [];

        for (let i = 0; i < action?.oracle_prices?.length || 0; i++) {
            const marketSymbol = marketNameSubstitute[action.oracle_prices[i].market];
            oraclePrices.push({
                perpetual: marketSymbol,
                price: toBigNumberStr(action.oracle_prices[i].price, SUI_NATIVE_BASE)
            });
        }

        switch (action.action_type) {
            case `deposit`:
                // create an account for `Actor` if not exists
                if (!(action.account in accounts)) {
                    accounts[action.account] = createAccount();
                }
                const account = accounts[action.account];

                const coinId = coins.pop();

                txBlock = (await v3.user.depositToAssetBank(
                    action.symbol, // assuming the symbol will be `USDC`
                    toBigNumber(action.quantity, USDC_BASE_DECIMALS),
                    { account: account.address, txBlock, coinId, returnTxb: true }
                )) as TransactionBlock;

                const resp = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );

                if (Transaction.getStatus(resp) != "success") {
                    console.log(JSON.stringify(resp));
                }

                const event = (
                    await Transaction.getEvents(
                        await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer),
                        "AssetBankDeposit"
                    )
                ).at(-1) as IAssetBankDeposit;

                // get the expected sequence hash
                sequenceHash = v3.simulator.depositToInternalBank(event);

                txBlock = (await v3.sequencer.depositToInternalBank(
                    event.nonce,
                    sequenceHash,
                    { txBlock, returnTxb: true }
                )) as TransactionBlock;

                expect(
                    Transaction.getStatus(
                        await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer)
                    )
                ).to.be.equal("success");

                break;

            case "orders_trade":
                actors.push(action.maker.account);
                actors.push(action.taker.account);

                const makerPayload = await createOrder(
                    action.maker,
                    marketNameSubstitute
                );
                const takerPayload = await createOrder(
                    action.taker,
                    marketNameSubstitute
                );

                const makerOrder = makerPayload.rawData as ISignedOrder;
                const takerOrder = takerPayload.rawData as ISignedOrder;

                const fillQuantity = toBigNumberStr(
                    action.taker.fillQty,
                    SUI_NATIVE_BASE
                );
                const timestamp = Date.now();

                sequenceHash = v3.simulator.performTrade(
                    makerPayload.serializedData,
                    takerPayload.serializedData,
                    fillQuantity,
                    timestamp
                );

                v3.txBuilder.performTrade(
                    BCSUtils.getSerializedDataBytes(makerOrder, Order),
                    BCSUtils.getSerializedDataBytes(takerOrder, Order),
                    makerOrder.signature,
                    takerOrder.signature,
                    new BigNumber(fillQuantity).toFixed(0),
                    oraclePrices.map(op => op.perpetual),
                    oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                    sequenceHash,
                    timestamp,
                    { txBlock }
                );

                const result = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );
                console.log(result.effects.status);

                if (action.expected && action.expected.error) {
                    expect(Transaction.getErrorCode(result)).to.be.equal(
                        errorCodes[action.expected.error]
                    );
                    break;
                }

                expect(Transaction.getStatus(result)).to.be.equal("success");
                const tradeEvent = Transaction.getEvents(result, "TradeExecuted").at(
                    -1
                ) as ITradeExecutedEvent;

                assertAccountState(
                    action,
                    marketNameSubstitute,
                    accounts,
                    actors,
                    tradeEvent
                );
                break;

            case "standard_liquidate":
            case "bankrupt_liquidate":
                actors.push(action.details.maker);
                actors.push(action.details.liquidator);

                const liquidatee = accounts[action.details.maker];
                const liquidatorAccount = accounts[action.details.liquidator];
                market = marketNameSubstitute[action.details.market];

                const authRequest = await v3.requests.authorizeLiquidator(
                    liquidatorAccount.address,
                    true
                );

                sequenceHash = v3.simulator.computeSequenceHash(
                    base64ToHex(authRequest.signature)
                );

                txBlock = (await v3.sequencer.authorizeLiquidator(
                    authRequest.serializedData,
                    authRequest.signature,
                    sequenceHash,
                    Date.now(),
                    { txBlock, returnTxb: true }
                )) as TransactionBlock;

                expect(
                    Transaction.getStatus(
                        await SuiBlocks.dryRunTxBlock(txBlock, v3.suiClient, v3.signer)
                    )
                ).to.be.equal("success");

                const liqRequest = await v3.requests.createSignedLiquidation(
                    liquidatee.address,
                    market,
                    action.details.positionType,
                    action.details.assumeAs,
                    toBigNumberStr(action.details.fillQty, SUI_NATIVE_BASE),
                    {
                        signer: liquidatorAccount.signer,
                        liquidator: liquidatorAccount.address,
                        allOrNothing: action.details.allOrNothing,
                        leverageE9: toBigNumberStr(
                            action.details.assumeAs == POSITION_TYPES.CROSS
                                ? 0
                                : action.details.leverage,
                            SUI_NATIVE_BASE
                        )
                    }
                );

                sequenceHash = v3.simulator.computeSequenceHash(
                    base64ToHex(liqRequest.signature)
                );

                await v3.txBuilder.performLiquidation(
                    liqRequest.serializedData,
                    liqRequest.signature,
                    oraclePrices.map(op => op.perpetual),
                    oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                    sequenceHash,
                    Date.now(),
                    { txBlock }
                );
                const liqResult = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );
                // const liqResult = await SuiBlocks.signAndExecuteTxBlock(txBlock, v3.suiClient, v3.signer);

                if (action.expected && action.expected.error) {
                    expect(Transaction.getErrorCode(liqResult)).to.be.equal(
                        errorCodes[action.expected.error]
                    );
                    break;
                }

                expect(Transaction.getStatus(liqResult)).to.be.equal("success");
                const liquidationEvent = Transaction.getEvents(
                    liqResult,
                    "LiquidationExecuted"
                ).at(-1) as ILiquidationExecutedEvent;

                console.dir(liquidationEvent, { depth: 5 });

                assertAccountState(
                    action,
                    marketNameSubstitute,
                    accounts,
                    actors,
                    liquidationEvent
                );

                break;

            case "funding_payment":
                const marketFundingRates: IMarketFundingRate[] = [];

                for (const funding of action.funding_rates) {
                    market = marketNameSubstitute[funding.market];
                    const rate = toBigNumber(funding.funding_rate, SUI_NATIVE_BASE);
                    const oraclePrice = findOraclePrice(
                        action.oracle_prices,
                        funding.market
                    );

                    marketFundingRates.push({
                        market,
                        value: rate.absoluteValue().toFixed(0),
                        sign: rate.gt(0),
                        oraclePrice: toBigNumberStr(oraclePrice, SUI_NATIVE_BASE)
                    });
                }

                fundingTimestamp = fundingTimestamp + 3600000;
                const fundingRequest = await v3.requests.setFundingRate(
                    marketFundingRates,
                    { timestamp: fundingTimestamp }
                );

                await v3.txBuilder.setFundingRate(
                    fundingRequest.serializedData,
                    fundingRequest.signature,
                    v3.simulator.computeSequenceHash(
                        base64ToHex(fundingRequest.signature)
                    ),
                    Date.now(),
                    { txBlock }
                );

                const fundingResult = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );

                expect(Transaction.getStatus(fundingResult)).to.be.equal("success");

                const accountAddresses = [] as string[];
                for (const expected of action.expected.accounts) {
                    if (["GAS POOL", "FEE POOL"].includes(expected.account)) continue;

                    actors.push(expected.account);
                    accountAddresses.push(accounts[expected.account].address);
                }

                const applyFundingRequest =
                    await v3.requests.applyFundingRate(accountAddresses);

                await v3.txBuilder.applyFundingRate(
                    applyFundingRequest.serializedData,
                    v3.simulator.computeSequenceHash(applyFundingRequest.serializedData),
                    Date.now(),
                    { txBlock }
                );

                const applyFR = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );

                console.log(applyFR.effects.status);

                expect(Transaction.getStatus(applyFR)).to.be.equal("success");

                const fundingAppliedEvent = Transaction.getEvents(
                    applyFR,
                    "FundingRateApplied"
                ) as IFundingRateAppliedEvent[];

                assertAccountState(
                    action,
                    marketNameSubstitute,
                    accounts,
                    actors,
                    fundingAppliedEvent
                );

                break;

            case "adjust_leverage":
                actors.push(action.details.account);
                market = marketNameSubstitute[action.details.market];
                userAccount = accounts[action.details.account];

                const adjustLeverageRequest = await v3.requests.adjustLeverage(
                    market,
                    toBigNumberStr(action.details.leverage, SUI_NATIVE_BASE),
                    { signer: userAccount.signer, account: userAccount.address }
                );

                sequenceHash = v3.simulator.computeSequenceHash(
                    base64ToHex(adjustLeverageRequest.signature)
                );

                await v3.txBuilder.adjustLeverage(
                    adjustLeverageRequest.serializedData,
                    adjustLeverageRequest.signature,
                    oraclePrices.map(op => op.perpetual),
                    oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                    sequenceHash,
                    Date.now(),
                    { txBlock }
                );

                const leverageAdjustment = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );

                if (action.expected && action.expected.error) {
                    expect(Transaction.getErrorCode(leverageAdjustment)).to.be.equal(
                        errorCodes[action.expected.error]
                    );
                    break;
                }

                expect(Transaction.getStatus(leverageAdjustment)).to.be.equal("success");

                const adjustLeverageEvent = Transaction.getEvents(
                    leverageAdjustment,
                    "LeverageAdjusted"
                ).at(-1) as ILeverageAdjustedEvent;

                assertAccountState(
                    action,
                    marketNameSubstitute,
                    accounts,
                    actors,
                    adjustLeverageEvent
                );

                break;

            case "adjust_margin":
                actors.push(action.details.account);
                market = marketNameSubstitute[action.details.market];
                userAccount = accounts[action.details.account];

                const adjustMarginRequest = await v3.requests.adjustMargin(
                    market,
                    action.details.add,
                    toBigNumberStr(action.details.amount, SUI_NATIVE_BASE),
                    { signer: userAccount.signer, account: userAccount.address }
                );

                sequenceHash = v3.simulator.computeSequenceHash(
                    base64ToHex(adjustMarginRequest.signature)
                );

                await v3.txBuilder.adjustMargin(
                    adjustMarginRequest.serializedData,
                    adjustMarginRequest.signature,
                    oraclePrices.map(op => op.perpetual),
                    oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
                    sequenceHash,
                    Date.now(),
                    { txBlock }
                );

                const marginAdjustment = await SuiBlocks.dryRunTxBlock(
                    txBlock,
                    v3.suiClient,
                    v3.signer
                );

                console.log(marginAdjustment.effects.status);

                if (action.expected && action.expected.error) {
                    console.log(marginAdjustment.effects.status);
                    expect(Transaction.getErrorCode(marginAdjustment)).to.be.equal(
                        errorCodes[action.expected.error]
                    );
                    break;
                }

                expect(Transaction.getStatus(marginAdjustment)).to.be.equal("success");

                const marginAdjustmentEvent = Transaction.getEvents(
                    marginAdjustment,
                    "MarginAdjusted"
                ).at(-1) as IMarginAdjustedEvent;

                assertAccountState(
                    action,
                    marketNameSubstitute,
                    accounts,
                    actors,
                    marginAdjustmentEvent
                );

                break;

            default:
                console.log(`Action: ${action.action_type} not yet supported`);
                break;
        }
    }
}

describe("Test Executor", async () => {
    const files = getFilesFromDirectory("./pro-tests/tests");
    const tests = [] as any;
    for (const fname of files) {
        tests.push(readJSONFile(fname));
    }

    before(async () => {
        let coins = CoinUtils.sortAscending(
            await CoinUtils.getCoins(
                v3.suiClient,
                v3.walletAddress,
                v3.parser.getAssetCoinType("USDC")
            )
        );

        coinsToUse = coins
            .filter(
                coin => coin.balance == toBigNumberStr(10_000_000, USDC_BASE_DECIMALS)
            )
            .map(coin => coin.coinObjectId);

        let numCoins = coinsToUse.length;
        let txBlock = new TransactionBlock();

        // Assuming that there won't be more than 5 accounts used in any of the tests.
        // In cae we have a case with more than 5 accounts, update this number
        while (numCoins < 5) {
            txBlock = (await v3.admin.mintUSDC(
                {
                    amountE6: toBigNumberStr(10_000_000, USDC_BASE_DECIMALS)
                },
                { txBlock, returnTxb: true }
            )) as TransactionBlock;

            numCoins++;
        }

        if (txBlock.getData().commands.length > 0) {
            await v3.sequencer.signAndExecuteTxBlock(txBlock);
            await sleep(1000);
        }

        coins = CoinUtils.sortAscending(
            await CoinUtils.getCoins(
                v3.suiClient,
                v3.walletAddress,
                v3.parser.getAssetCoinType("USDC")
            )
        );

        coinsToUse = coins
            .filter(
                coin => coin.balance == toBigNumberStr(10_000_000, USDC_BASE_DECIMALS)
            )
            .map(coin => coin.coinObjectId);
    });

    // sort tests based on their titles
    tests.sort((a, b) => a.title.match(/\d+/)[0] - b.title.match(/\d+/)[0]);

    // execute scenarios in order so search each scenario and send for execution
    for (const test of tests) {
        // if(test.title.indexOf(`${start}:`) > -1){
        // if(test.title.indexOf(`Scenario 10-a`) > -1){
        // if(test.title.indexOf(`Scenario 66:`) > -1){

        it(test.title, async () => {
            await execute(test);
        });
        //     start++;
        // }

        // if(start > end) return;
    }
});
