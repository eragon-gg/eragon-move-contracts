require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey, AccountAddress } = require("@aptos-labs/ts-sdk");
const dayjs = require("dayjs");
const { bcs } = require("@mysten/bcs");
const { createHash } = require("node:crypto");
const { readConfig } = require("./config");
const { sendTx, view, initCollectionV2, mintAndTransferNftV2, transferAll, mintV2, ownedDigitalAssets, getTokenName } = require("./utils");

const whilelistNft = async (creatorAddr, collectionName) => {
    const config = await readConfig();
    await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_asset_type::add_asset_type`, [
        creatorAddr,
        collectionName
    ]);
    // get asset type
}
whilelistNft();