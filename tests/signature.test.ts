import { DEPLOYMENT, ENV, PARSER, SUI_CLIENT } from "../env";
import {
    Address,
    SUI_NATIVE_BASE,
    TEST_WALLETS,
    USDC_BASE_DECIMALS,
    getKeyPairFromSeed,
    toBigNumberStr
} from "../library-sui";
import { BluefinV3 } from "../library-sui/src/v3/bluefin-v3";
import {
    ASSUME_AS,
    PAYLOAD_REQUEST_TYPE,
    POSITION_TYPES,
    PRUNE_TABLES_INDEX
} from "../library-sui/src/v3/enums";
import { SignatureUtils } from "../library-sui/src/v3/utils";
import { expect } from "./helpers/utils";

describe("Signature", () => {
    describe("ED25519 Wallet", () => {
        let bluefinV3: BluefinV3;
        before(() => {
            const signer = getKeyPairFromSeed(TEST_WALLETS[0].phrase, "ED25519");
            bluefinV3 = new BluefinV3(ENV.DEPLOY_ON, SUI_CLIENT, DEPLOYMENT, signer);
        });

        it("should create withdrawal signature and verify it off-chain", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            console.dir(payload.rawData, { depth: null });
            console.log(payload.signature);

            const result = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                bluefinV3.signer.toSuiAddress()
            );

            expect(result).to.be.true;
        });

        it("should verify signature created by UI wallet - off-chain", async () => {
            const data = {
                type: "Bluefin Pro Withdrawal",
                eds: "0x39a682b466a442b25df59d54a0dc12f85de738cb9e3f41172d8b8f28c3931450",
                assetSymbol: "USDC",
                account:
                    "0x76a831f3a961579e5fd34b6cda412409dd41ba18fe0f10e149ecdad413af4050",
                amount: "1500000",
                salt: 1738213921838,
                signedAt: 1738215080364
            };

            const signature =
                "AIBChRYw5cWlLaiHahthaUP5gPAclNezLOCWWqdhrTD5JINGF/5vGAhD/wuoBRNpPhpsAJoh8PsJMq+e7pzcvwjjACr8zPOiEw9/EtlRYBZRh+rIJQntYcupJx665tjB9Q==";

            const signer =
                "0xa6b939f57595fed2ae10ae4f3a37a410c94e5bdb7dde2e547022d1fe1b9791d0";

            const result = await SignatureUtils.verifyRequestSignature(
                data,
                signature,
                signer
            );

            expect(result).to.be.true;
        });

        it("should create withdrawal signature and verify it on-chain", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(result).to.be.true;
        });

        it("should revert when verifying incorrect signature on-chain - I", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const payload2 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload2.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(result).to.be.false;
        });

        it("should revert when verifying incorrect signature on-chain - II", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const payload2 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload2.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(result).to.be.false;
        });
    });

    describe("Secp256k1 Wallet", () => {
        let bluefinV3: BluefinV3;
        before(() => {
            const signer = getKeyPairFromSeed(TEST_WALLETS[0].phrase, "Secp256k1");
            bluefinV3 = new BluefinV3(ENV.DEPLOY_ON, SUI_CLIENT, DEPLOYMENT, signer);
        });

        it("should create withdrawal signature and verify it off-chain", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                bluefinV3.signer.toSuiAddress()
            );

            expect(result).to.be.true;
        });

        it("should create withdrawal signature and verify it on-chain", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );

            expect(result).to.be.true;
        });

        it("should revert when verifying incorrect signature on-chain - I", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const payload2 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload2.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(result).to.be.false;
        });

        it("should revert when verifying incorrect signature on-chain - II", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const payload2 = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const result = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload2.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                bluefinV3.signer.toSuiAddress(),
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(result).to.be.false;
        });
    });

    describe("Payload Signature Verifications", () => {
        let bluefinV3: BluefinV3;
        let signerAddress: Address;
        before(() => {
            const signer = getKeyPairFromSeed(TEST_WALLETS[0].phrase, "ED25519");
            signerAddress = signer.toSuiAddress();
            bluefinV3 = new BluefinV3(ENV.DEPLOY_ON, SUI_CLIENT, DEPLOYMENT, signer);
        });

        it("should create and verify withdrawal signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.withdrawal(
                "USDC",
                toBigNumberStr(1.5, USDC_BASE_DECIMALS)
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.WITHDRAWAL,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify order signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.createSignedOrder({
                price: 100
            });

            // remove these 2 fields from order payload as they are not signed on
            delete (payload.rawData as any)["hash"];
            delete (payload.rawData as any)["signature"];

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.ORDER,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );
            expect(onChain).to.be.true;
        });

        it("should create and verify authorize account signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.authorizeUser(
                TEST_WALLETS[5].address,
                true
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.AUTHORIZE_ACCOUNT,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify liquidation signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.createSignedLiquidation(
                TEST_WALLETS[5].address,
                "ETH-PERP",
                POSITION_TYPES.ISOLATED,
                ASSUME_AS.ISOLATED,
                toBigNumberStr(1, SUI_NATIVE_BASE)
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.serializedData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.LIQUIDATE,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify adjust margin signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.adjustMargin(
                "ETH-PERP",
                true,
                toBigNumberStr(1)
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.ADJUST_MARGIN,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify adjust leverage signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.adjustLeverage(
                "ETH-PERP",
                toBigNumberStr(1, SUI_NATIVE_BASE)
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.ADJUST_LEVERAGE,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify set funding-rate signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.setFundingRate([
                {
                    market: "ETH-PERP",
                    value: toBigNumberStr(0.001, SUI_NATIVE_BASE),
                    sign: true,
                    oraclePrice: 1
                },
                {
                    market: "BTC-PERP",
                    value: toBigNumberStr(0.001, SUI_NATIVE_BASE),
                    sign: true,
                    oraclePrice: 1
                }
            ]);

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.serializedData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.SET_FUNDING_RATE,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify table pruning signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.pruneTable(
                [Uint8Array.from([1, 2, 3])],
                PRUNE_TABLES_INDEX.HISTORY
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.serializedData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.PRUNING_TABLE,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                }
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify authorizing liquidator signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.authorizeLiquidator(
                TEST_WALLETS[0].address,
                true
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.serializedData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.AUTHORIZE_LIQUIDATOR,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify set fee tier signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.setFeeTier(
                TEST_WALLETS[0].address,
                0.5,
                0.1,
                true
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.serializedData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.SET_FEE_TIER,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );

            expect(onChain).to.be.true;
        });

        it("should create and verify close position signature off-chain and on-chain", async () => {
            const payload = await bluefinV3.requests.closePosition(
                TEST_WALLETS[0].address,
                POSITION_TYPES.ISOLATED
            );

            const offChain = await SignatureUtils.verifyRequestSignature(
                payload.rawData,
                payload.signature,
                signerAddress
            );

            expect(offChain).to.be.true;

            const onChain = await SignatureUtils.verifyRequestSignatureOnChain(
                payload.serializedData,
                payload.signature,
                PAYLOAD_REQUEST_TYPE.CLOSE_POSITION,
                signerAddress,
                {
                    pkg: PARSER.getPackageId(),
                    client: SUI_CLIENT
                },
                true
            );

            expect(onChain).to.be.true;
        });
    });
});
