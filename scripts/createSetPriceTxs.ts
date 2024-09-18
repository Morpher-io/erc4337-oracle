import {
    MetaTransaction,
    getFunctionSelector,
    createCallData
} from "abstractionkit";

import Web3 from 'web3';
import { secp256k1 } from "ethereum-cryptography/secp256k1";

// key is bytes32, price is uint in wei
const YOUR_DATA_PRICES: { key: `0x${string}`, price: number }[] = [];
const YOUR_PROVIDER_ADDRESS: string = "";
const YOUR_PROVIDER_PK: string = "";
const CHAIN_ID: number = 11155111;
const ORACLE_ADDRESS = "0x9F82E17fb4d5815cf261a9AafFE53A9834F55b9F"; // address on sepolia testnet

const createSetPriceMetaTxs = async () => {

    const metaTransactions: MetaTransaction[] = [];
    const priceFunctionSignature = 'setPrice(address,uint256,bytes32,uint256,bytes32,bytes32,uint8)';
    const priceFunctionSelector = getFunctionSelector(priceFunctionSignature);

    let nonce = 0; // it's 0 if you never called the Oracle Entrypoint, otherwise get it with OracleEntrypoint.nonces

    for (const { key, price } of YOUR_DATA_PRICES) {
        const priceChangeUnsignedData = [
            YOUR_PROVIDER_ADDRESS,
            nonce,
            key,
            price
        ];
        const priceChangePackedHexString = Web3.utils.encodePacked(
            { value: CHAIN_ID, type: 'uint256' },
            { value: YOUR_PROVIDER_ADDRESS, type: 'address' },
            { value: nonce, type: 'uint256' },
            { value: key, type: 'bytes32' },
            { value: price, type: 'uint256' }
        );
        const preamble = "\x19Oracle Signed Price Change:\n148";
        const signature = sign(Buffer.from(priceChangePackedHexString.slice(2), 'hex'), YOUR_PROVIDER_PK, preamble);
        const priceChangeTransactionCallData = createCallData(
            priceFunctionSelector,
            ["address", "uint256", "bytes32", "uint256", "bytes32", "bytes32", "uint8"],
            [...priceChangeUnsignedData, signature.r, signature.s, signature.v]
        );
        const priceChangeTransaction: MetaTransaction = {
            to: ORACLE_ADDRESS,
            value: 0n,
            data: priceChangeTransactionCallData,
        }
        metaTransactions.push(priceChangeTransaction);
    }

    return metaTransactions;
}

function sign(messageBuffer: Buffer, privateKey: string, preamble: string) {
    const preambleBuffer = Buffer.from(preamble);
    const message = Buffer.concat([preambleBuffer, messageBuffer]);
    const hash = Web3.utils.keccak256(message);
    const signaturePayload = secp256k1.sign(
        Buffer.from(hash.substring(2), 'hex'),
        Buffer.from(privateKey.substring(2), 'hex')
    );
    const r = '0x' + signaturePayload.r.toString(16).padStart(64, "0");
    const s = '0x' + signaturePayload.s.toString(16).padStart(64, "0");
    const v = 27 + signaturePayload.recovery;
    return { r, s, v };
}
