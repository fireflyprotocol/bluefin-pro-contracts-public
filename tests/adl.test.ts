// import {
//     createPerpetual,
//     expect,
//     provideMarginToAccount,
//     setupADL,
//     setupTrade
// } from "./helpers/utils";
// import { ADMIN, bluefinV3, SIMULATOR, SUI_CLIENT } from "../env";
// import { SUI_NATIVE_BASE, TransactionBlock } from "../library-sui/dist";
// import {
//     toBigNumber,
//     toBigNumberStr,
//     getKeyPairFromSeed,
//     SuiBlocks,
//     ADDRESSES,
//     REQUEST_LIFESPAN,
//     Transaction,
//     IADLExecutedEvent
// } from "../library-sui/src";
// import { TEST_WALLETS } from "../library-sui/src/helpers";
// import { POSITION_TYPES } from "../library-sui/src/v3/enums";

// describe("ADL", () => {
//     const alice = getKeyPairFromSeed(TEST_WALLETS[2].phrase, "ED25519");
//     const bob = getKeyPairFromSeed(TEST_WALLETS[2].phrase, "Secp256k1");

//     const charlie = getKeyPairFromSeed(TEST_WALLETS[3].phrase, "Secp256k1");
//     const dorthy = getKeyPairFromSeed(TEST_WALLETS[3].phrase, "ED25519");

//     const btcPerp = `TEST_BTC`;
//     const ethPerp = `TEST_ETH`;
//     let txb: TransactionBlock;
//     let oraclePrices;

//     before(async () => {
//         await SIMULATOR.init();
//         await provideMarginToAccount(bluefinV3, SIMULATOR, alice.toSuiAddress(), {
//             exactAmount: 50
//         });
//         await provideMarginToAccount(bluefinV3, SIMULATOR, bob.toSuiAddress(), {
//             exactAmount: 10_000
//         });
//         await provideMarginToAccount(bluefinV3, SIMULATOR, charlie.toSuiAddress(), {
//             exactAmount: 100
//         });
//         await provideMarginToAccount(bluefinV3, SIMULATOR, dorthy.toSuiAddress(), {
//             exactAmount: 100
//         });

//         const imr = toBigNumberStr(0.05, SUI_NATIVE_BASE);
//         const mmr = toBigNumberStr(0.025, SUI_NATIVE_BASE);
//         const minTradeQty = toBigNumberStr(0.00001, SUI_NATIVE_BASE);
//         const stepSize = minTradeQty;

//         if ((await bluefinV3.getPerpetualFromIDS(btcPerp)) == undefined) {
//             await createPerpetual(bluefinV3, {
//                 symbol: btcPerp,
//                 imr,
//                 mmr,
//                 minTradeQty,
//                 stepSize,
//                 makerFee: 0,
//                 takerFee: 0
//             });
//         }

//         if ((await bluefinV3.getPerpetualFromIDS(ethPerp)) == undefined) {
//             await createPerpetual(bluefinV3, {
//                 symbol: ethPerp,
//                 imr,
//                 mmr,
//                 minTradeQty,
//                 stepSize,
//                 makerFee: 0,
//                 takerFee: 0
//             });
//         }
//     });

//     beforeEach(async () => {
//         txb = new TransactionBlock();
//         await bluefinV3.simulator.init();
//     });

//     describe("Reversions", async () => {
//         beforeEach(async () => {
//             txb = new TransactionBlock();
//             await bluefinV3.simulator.init();

//             await setupTrade(bluefinV3, txb, {
//                 oraclePrice: 60_000,
//                 executionPrice: 60_000,
//                 perpetual: btcPerp,
//                 quantity: 0.01,
//                 makerSide: "SHORT",
//                 maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//                 taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//             });

//             await setupTrade(bluefinV3, txb, {
//                 oraclePrice: 2_500,
//                 executionPrice: 2_500,
//                 perpetual: ethPerp,
//                 quantity: 0.1,
//                 makerSide: "SHORT",
//                 maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//                 taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//             });

//             await setupTrade(bluefinV3, txb, {
//                 oraclePrice: 60_000,
//                 executionPrice: 60_000,
//                 perpetual: btcPerp,
//                 quantity: 0.001,
//                 makerSide: "SHORT",
//                 maker: { signer: charlie, positionType: POSITION_TYPES.CROSS },
//                 taker: { signer: dorthy, positionType: POSITION_TYPES.CROSS }
//             });

//             oraclePrices = [
//                 {
//                     perpetual: btcPerp,
//                     price: toBigNumber(67_000, SUI_NATIVE_BASE)
//                 },
//                 {
//                     perpetual: ethPerp,
//                     price: toBigNumber(2_350, SUI_NATIVE_BASE)
//                 }
//             ];
//         });

//         it("should revert as self ADL is not allowed", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 alice.toSuiAddress(),
//                 ethPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.1
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1058");
//         });

//         it("should revert when trying to deleverage Alice's ETH position against Bob as Bob's ETH position does not have a positive Pnl", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 ethPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.1
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1053");
//         });

//         it("should revert when ADLing Alice's BTC and then ETH position as Alice is not bankrupt after BTC ADL", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01
//             );

//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 ethPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.1
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1012");
//         });

//         it("should revert as the signer of ADL payload is not the ADL operator", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01,
//                 { signer: bob }
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1014");
//         });

//         it("should revert as the signer of ADL payload is not the ADL operator", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01,
//                 { ids: ADDRESSES.ZERO }
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1006");
//         });

//         it("should revert as the ADL is signed more than 3 months ago (Exceeds Lifespan)", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01,
//                 { execTime: Date.now() + REQUEST_LIFESPAN + 10 } // moving time in future
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1046");
//         });

//         it("should revert as the ADL payload has expired", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01,
//                 { expiry: Date.now() - 1 }
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1027");
//         });

//         it("should revert as ADL quantity does not conform to step size", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.000001
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1030");
//         });

//         it("should revert as the maker being deleveraged is not bankrupt", async () => {
//             oraclePrices = [
//                 {
//                     perpetual: btcPerp,
//                     price: toBigNumber(61_000, SUI_NATIVE_BASE)
//                 },
//                 {
//                     perpetual: ethPerp,
//                     price: toBigNumber(2_350, SUI_NATIVE_BASE)
//                 }
//             ];

//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 bob.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1012");
//         });

//         it("should revert as both Alice and Charlie have SHORT position on BTC", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 charlie.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1025");
//         });

//         it("should revert as Dorthy does not have have enough position size to help deleverage Alice's BTC position", async () => {
//             await setupADL(
//                 bluefinV3,
//                 txb,
//                 oraclePrices,
//                 alice.toSuiAddress(),
//                 dorthy.toSuiAddress(),
//                 btcPerp,
//                 POSITION_TYPES.CROSS,
//                 POSITION_TYPES.CROSS,
//                 0.01
//             );

//             await expect(
//                 SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN)
//             ).to.be.eventually.rejectedWith("1052");
//         });
//     });

//     it("should successfully deleverage Alice's BTC position against Bob", async () => {
//         await setupTrade(bluefinV3, txb, {
//             oraclePrice: 60_000,
//             executionPrice: 60_000,
//             perpetual: btcPerp,
//             quantity: 0.01,
//             makerSide: "SHORT",
//             maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//             taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//         });

//         await setupTrade(bluefinV3, txb, {
//             oraclePrice: 2_500,
//             executionPrice: 2_500,
//             perpetual: ethPerp,
//             quantity: 0.1,
//             makerSide: "SHORT",
//             maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//             taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//         });

//         const oraclePrices = [
//             {
//                 perpetual: btcPerp,
//                 price: toBigNumber(67_000, SUI_NATIVE_BASE)
//             },
//             {
//                 perpetual: ethPerp,
//                 price: toBigNumber(2_350, SUI_NATIVE_BASE)
//             }
//         ];

//         await setupADL(
//             bluefinV3,
//             txb,
//             oraclePrices,
//             alice.toSuiAddress(),
//             bob.toSuiAddress(),
//             btcPerp,
//             POSITION_TYPES.CROSS,
//             POSITION_TYPES.CROSS,
//             0.01
//         );

//         const txResponse = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);
//         expect(Transaction.getStatus(txResponse) == "success").to.be.true;

//         const adlEvent = Transaction.getEvents(
//             txResponse,
//             "ADLExecuted"
//         )[0] as IADLExecutedEvent;

//         expect(adlEvent.maker_assets[0].quantity == "0").to.be.true;
//         expect(adlEvent.taker_assets[0].quantity == "10065000000000").to.be.true;
//     });

//     it("should successfully deleverage Alice's ETH position against Charlie and BTC against Bob", async () => {
//         await setupTrade(bluefinV3, txb, {
//             oraclePrice: 2_250,
//             executionPrice: 2_250,
//             perpetual: ethPerp,
//             quantity: 0.1,
//             makerSide: "LONG",
//             maker: { signer: charlie, positionType: POSITION_TYPES.CROSS },
//             taker: { signer: dorthy, positionType: POSITION_TYPES.CROSS }
//         });

//         await setupTrade(bluefinV3, txb, {
//             oraclePrice: 60_000,
//             executionPrice: 60_000,
//             perpetual: btcPerp,
//             quantity: 0.01,
//             makerSide: "SHORT",
//             maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//             taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//         });

//         await setupTrade(bluefinV3, txb, {
//             oraclePrice: 2_500,
//             executionPrice: 2_500,
//             perpetual: ethPerp,
//             quantity: 0.1,
//             makerSide: "SHORT",
//             maker: { signer: alice, positionType: POSITION_TYPES.CROSS },
//             taker: { signer: bob, positionType: POSITION_TYPES.CROSS }
//         });

//         const oraclePrices = [
//             {
//                 perpetual: btcPerp,
//                 price: toBigNumber(67_000, SUI_NATIVE_BASE)
//             },
//             {
//                 perpetual: ethPerp,
//                 price: toBigNumber(2_350, SUI_NATIVE_BASE)
//             }
//         ];

//         await setupADL(
//             bluefinV3,
//             txb,
//             oraclePrices,
//             alice.toSuiAddress(),
//             charlie.toSuiAddress(),
//             ethPerp,
//             POSITION_TYPES.CROSS,
//             POSITION_TYPES.CROSS,
//             0.1
//         );

//         await setupADL(
//             bluefinV3,
//             txb,
//             oraclePrices,
//             alice.toSuiAddress(),
//             bob.toSuiAddress(),
//             btcPerp,
//             POSITION_TYPES.CROSS,
//             POSITION_TYPES.CROSS,
//             0.01
//         );

//         const txResponse = await SuiBlocks.dryRunTxBlock(txb, SUI_CLIENT, ADMIN);
//         expect(Transaction.getStatus(txResponse) == "success").to.be.true;

//         const adlEvents = Transaction.getEvents(
//             txResponse,
//             "ADLExecuted"
//         ) as IADLExecutedEvent[];
//         const tradeEvents = Transaction.getEvents(
//             txResponse,
//             "TradeExecuted"
//         ) as IADLExecutedEvent[];

//         expect(adlEvents[0].maker_assets[0].quantity).to.be.equal("30000000000");
//         expect(adlEvents[0].taker_assets[0].quantity).to.be.equal("105000000000");

//         expect(adlEvents[1].maker_assets[0].quantity).to.be.equal("0");
//         expect(adlEvents[1].taker_assets[0].quantity).to.be.equal("10030000000000");
//     });
// });
