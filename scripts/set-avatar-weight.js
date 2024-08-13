require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey, AccountAddress } = require("@aptos-labs/ts-sdk");
const dayjs = require("dayjs");
const { bcs } = require("@mysten/bcs");
const { createHash } = require("node:crypto");
const { readConfig } = require("./config");
const { sendTx, view, initCollectionV2, mintAndTransferNftV2, transferAll, mintV2, ownedDigitalAssets, getTokenName } = require("./utils");

const setAvatarProfileWeight = async (creatorAddr, collection_name) => {
    const config = await readConfig();
    const assetIds = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_type`, [
        creatorAddr,
        collection_name
    ]);
    console.log('Asset type id:', assetIds);
    const type_id = BigInt(assetIds[0]);
    const weight_type = 1;//use for roll profile
    await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_avatar::set_weight`, [
        type_id,
        weight_type,
        [400, 200, 900, 900, 600, 500]]);
}
const setDefaultWeight = async () => {
    const config = await readConfig();
    await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_avatar::set_default_weight`, [
        [400, 200, 900, 900, 600, 500]]);
}
//setDefaultWeight();
setAvatarProfileWeight