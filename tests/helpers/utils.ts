import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { MarketName, PositionType, Side } from "../../library-sui/src/v3/types";
import {
    BluefinV3,
    IOraclePriceUpdate,
    IPerpetualConfig,
    IPosition
} from "../../library-sui/src/v3";
import {
    CoinUtils,
    SUI_NATIVE_BASE,
    toBaseNumber,
    toBigNumber,
    toBigNumberStr,
    Transaction,
    USDC_BASE_DECIMALS
} from "../../library-sui/src";
import { IAssetBankDeposit, MarginingEngineSimulator } from "../../library-sui/src/v3";
import {
    Address,
    base64ToHex,
    BigNumber,
    Account as IAccount,
    NumStr,
    Signer,
    TransactionBlock
} from "../../library-sui";
import { IOrderCreation, ISignedOrder } from "../../library-sui/src/v3/interfaces/IOrder";
import { Account } from "../../library-sui/src/v3/on-chain-calls/account";
import { Store } from "../../library-sui/src/v3/on-chain-calls/store";
import { ASSUME_AS, POSITION_TYPES } from "../../library-sui/src/v3/enums";
import { BCSUtils, Order } from "../../library-sui/src/v3/utils/bcs";
chai.use(chaiAsPromised);
export const expect = chai.expect;

export async function provideMarginToAccount(
    bluefin: BluefinV3,
    simulator: MarginingEngineSimulator,
    account: Address,
    options?: { amount?: number; coinType?: string; exactAmount?: number }
): Promise<void> {
    // don't fund the account if it already has >= 10K
    const balance = await Account.getWithdrawableAssets(
        bluefin.suiClient,
        bluefin.parser,
        account,
        "USDC"
    );

    const exactAmount =
        options?.exactAmount == undefined ? -1 : Number(options?.exactAmount);

    if (exactAmount == -1 && balance >= 10000) return;

    if (exactAmount > -1 && balance > exactAmount)
        throw `Account has ${balance}, please withdraw extra amount`;

    const amountToFund =
        exactAmount == -1 ? options?.amount || 10000 : exactAmount - balance;

    if (amountToFund == 0) return;

    // mint USDC tokens if faucet is running low
    const faucetBalance = await CoinUtils.getCoinBalance(
        bluefin.suiClient,
        bluefin.signer.toSuiAddress(),
        options?.coinType || bluefin.parser.getAssetCoinType("USDC")
    );

    if (toBaseNumber(faucetBalance, USDC_BASE_DECIMALS) < amountToFund) {
        await bluefin.admin.mintUSDC({
            amountE6: toBigNumberStr(1_000_000, USDC_BASE_DECIMALS)
        });
    }

    const resp = await bluefin.user.depositToAssetBank(
        "USDC",
        toBigNumber(amountToFund, USDC_BASE_DECIMALS),
        { account }
    );

    const event = (await Transaction.getEvents(
        resp,
        "AssetBankDeposit"
    )[0]) as IAssetBankDeposit;

    // get the expected sequence hash
    const expectedHash = simulator.depositToInternalBank(event);

    await bluefin.sequencer.depositToInternalBank(event.nonce, expectedHash);
}

export function expectPosition(
    position: IPosition,
    expectedValues: {
        size?: NumStr;
        entryPrice?: NumStr;
        margin?: NumStr;
        side?: Side;
        isolated?: boolean;
        leverage?: NumStr;
        pendingFundingPayment?: NumStr;
    }
) {
    expectedValues.size != undefined
        ? expect(position.size).to.be.equal(
              toBigNumberStr(expectedValues.size, SUI_NATIVE_BASE)
          )
        : {};

    expectedValues.entryPrice != undefined
        ? expect(position.average_entry_price).to.be.equal(
              toBigNumberStr(expectedValues.entryPrice, SUI_NATIVE_BASE)
          )
        : {};

    expectedValues.leverage != undefined
        ? expect(position.leverage).to.be.equal(
              toBigNumberStr(expectedValues.leverage, SUI_NATIVE_BASE)
          )
        : {};

    expectedValues.pendingFundingPayment != undefined
        ? expect(position.pending_funding_payment).to.be.equal(
              toBigNumberStr(expectedValues.pendingFundingPayment, SUI_NATIVE_BASE)
          )
        : {};

    expectedValues.margin != undefined
        ? expect(position.margin).to.be.equal(
              toBigNumberStr(expectedValues.margin, SUI_NATIVE_BASE)
          )
        : {};
    expectedValues.side != undefined
        ? expect(position.is_long).to.be.equal(expectedValues.side == "LONG")
        : {};
    expectedValues.isolated != undefined
        ? expect(position.is_isolated).to.be.equal(expectedValues.isolated)
        : {};
}

export async function createPerpetual(
    bluefinV3: BluefinV3,
    config: IPerpetualConfig,
    simulator?: MarginingEngineSimulator
): Promise<BluefinV3> {
    const sim = simulator || bluefinV3.simulator;
    if (!simulator) await sim.init();

    const { txResponse, perpetualConfig } = await bluefinV3.admin.createPerpetual(config);

    const event = Transaction.getEvents(txResponse, "PerpetualUpdate")[0];

    perpetualConfig.id = event.perpetual.id as string;

    const deployment = { ...bluefinV3.parser.deployment };

    if (!deployment["Perpetuals"]) deployment["Perpetuals"] = {};

    deployment["Perpetuals"][perpetualConfig.symbol as any] = perpetualConfig;

    const localBFV3 = new BluefinV3(
        bluefinV3.network,
        bluefinV3.suiClient,
        deployment,
        bluefinV3.signer
    );

    const sequencerHash = sim.syncPerpetual({ perpetual: perpetualConfig });

    await localBFV3.sequencer.syncPerpetual(perpetualConfig.symbol, sequencerHash);

    return localBFV3;
}

export async function performTrades(
    v3: BluefinV3,
    perpName: string,
    accounts: Array<IAccount[]>,
    perpOraclePrice: number,
    orderParams: IOrderCreation
) {
    await v3.simulator.init();

    let oraclePrices = [
        {
            perpetual: perpName,
            price: toBigNumber(perpOraclePrice, SUI_NATIVE_BASE)
        }
    ] as Array<IOraclePriceUpdate>;

    for (const makerTaker of accounts) {
        await provideMarginToAccount(v3, v3.simulator, makerTaker[0].address);
        await provideMarginToAccount(v3, v3.simulator, makerTaker[1].address);

        const makerPayload = await v3.requests.createSignedOrder(
            { ...orderParams, market: perpName },
            { signer: makerTaker[0].signer }
        );
        const takerPayload = await v3.requests.createSignedOrder(
            {
                ...orderParams,
                side: orderParams.side == "LONG" ? "SHORT" : "LONG",
                market: perpName
            },
            { signer: makerTaker[1].signer }
        );

        const fill = toBigNumberStr(orderParams.quantity, SUI_NATIVE_BASE);
        const timestamp = Date.now();

        let sequenceHash = v3.simulator.performTrade(
            makerPayload.serializedData,
            takerPayload.serializedData,
            fill,
            timestamp
        );

        await v3.sequencer.performTrade(
            makerPayload.rawData as ISignedOrder,
            takerPayload.rawData as ISignedOrder,
            fill,
            oraclePrices,
            sequenceHash,
            timestamp,
            { dryRun: false }
        );
    }
}

export const INSURANCE_POOL_ADDRESS =
    "0x90c55f2a388a0e31ebca93cbf87fdd08e9716be082ca8a3c479bb14bcb5e1b88";

// Helper method to set up the provided account as bankrupt liquidator
export async function setLiquidator(v3: BluefinV3, account: Address, status: boolean) {
    if (
        (
            await Store.getLiquidators(v3.suiClient, v3.parser.getInternalDataStore())
        ).indexOf(account) >= 0
    )
        return;

    await v3.simulator.init();

    const payload = await v3.requests.authorizeLiquidator(account, status);

    const sequenceHash = v3.simulator.computeSequenceHash(base64ToHex(payload.signature));

    await v3.sequencer.authorizeLiquidator(
        payload.serializedData,
        payload.signature,
        sequenceHash,
        Date.now()
    );
}

export type Params = {
    signer: Signer;
    positionType: PositionType;
    leverage?: number;
};

export async function setupTrade(
    v3: BluefinV3,
    txb: TransactionBlock,
    params: {
        oraclePrice: number;
        executionPrice: number;
        perpetual: MarketName;
        quantity: number;
        makerSide: Side;
        maker: Params;
        taker: Params;
    }
) {
    const makerPayload = await v3.requests.createSignedOrder(
        {
            market: params.perpetual,
            side: params.makerSide,
            price: params.executionPrice,
            quantity: params.quantity,
            positionType: params.maker.positionType,
            leverage: params.maker.leverage || 0
        },
        { signer: params.maker.signer }
    );

    const takerPayload = await v3.requests.createSignedOrder(
        {
            market: params.perpetual,
            side: params.makerSide == "LONG" ? "SHORT" : "LONG",
            price: params.executionPrice,
            quantity: params.quantity,
            positionType: params.taker.positionType,
            leverage: params.taker.leverage || 0
        },
        { signer: params.taker.signer }
    );

    const fill = toBigNumberStr(params.quantity, SUI_NATIVE_BASE);
    const timestamp = Date.now();

    const sequenceHash = v3.simulator.performTrade(
        makerPayload.serializedData,
        takerPayload.serializedData,
        fill,
        timestamp
    );

    const makerOrder = makerPayload.rawData as ISignedOrder;
    const takerOrder = takerPayload.rawData as ISignedOrder;

    const oraclePrices = [
        {
            perpetual: params.perpetual,
            price: toBigNumber(params.oraclePrice, SUI_NATIVE_BASE)
        }
    ] as Array<IOraclePriceUpdate>;

    v3.txBuilder.performTrade(
        BCSUtils.getSerializedDataBytes(makerOrder, Order),
        BCSUtils.getSerializedDataBytes(takerOrder, Order),
        makerOrder.signature,
        takerOrder.signature,
        new BigNumber(fill).toFixed(0),
        oraclePrices.map(op => op.perpetual),
        oraclePrices.map(op => new BigNumber(op.price).toFixed(0)),
        sequenceHash,
        timestamp,
        { txBlock: txb }
    );
}

export async function setupLiquidation(
    v3: BluefinV3,
    txb: TransactionBlock,
    oraclePrices: IOraclePriceUpdate[],
    liquidatee: Address,
    liquidator: Address,
    perpetual: MarketName,
    positionType: POSITION_TYPES,
    assumeAs: ASSUME_AS,
    quantity: NumStr,
    signer: Signer,
    options?: {
        leverage?: NumStr;
    }
) {
    const payload = await v3.requests.createSignedLiquidation(
        liquidatee,
        perpetual,
        positionType,
        assumeAs,
        toBigNumberStr(quantity, SUI_NATIVE_BASE),
        {
            liquidator,
            signer,
            leverageE9: toBigNumberStr(options?.leverage || 0, SUI_NATIVE_BASE)
        }
    );

    const sequenceHash = v3.simulator.computeSequenceHash(base64ToHex(payload.signature));

    await v3.sequencer.performLiquidation(
        payload.serializedData,
        payload.signature,
        oraclePrices,
        sequenceHash,
        Date.now(),
        { txBlock: txb, returnTxb: true }
    );
}

export async function setupADL(
    v3: BluefinV3,
    txb: TransactionBlock,
    oraclePrices: IOraclePriceUpdate[],
    maker: Address,
    taker: Address,
    perpetual: MarketName,
    makerPositionType: POSITION_TYPES,
    takerPositionType: POSITION_TYPES,
    quantity: NumStr,
    options?: {
        ids?: Address;
        signer?: Signer;
        execTime?: NumStr;
        expiry?: NumStr;
    }
) {
    const payload = await v3.requests.createSignedADL(
        maker,
        taker,
        makerPositionType,
        takerPositionType,
        perpetual,
        toBigNumberStr(quantity, SUI_NATIVE_BASE),
        { signer: options?.signer, ids: options?.ids, expiry: options?.expiry }
    );

    const sequenceHash = v3.simulator.computeSequenceHash(base64ToHex(payload.signature));

    await v3.sequencer.performADL(
        payload.serializedData,
        payload.signature,
        oraclePrices,
        sequenceHash,
        options?.execTime || Date.now(),
        { txBlock: txb, returnTxb: true }
    );
}
