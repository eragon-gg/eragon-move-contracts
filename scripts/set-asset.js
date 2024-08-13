require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey, AccountAddress } = require("@aptos-labs/ts-sdk");
const dayjs = require("dayjs");
const { bcs } = require("@mysten/bcs");
const { createHash } = require("node:crypto");
const { readConfig } = require("./config");
const { sendTx, view, initCollectionV2, mintAndTransferNftV2, transferAll, mintV2, ownedDigitalAssets, getTokenName } = require("./utils");

const sign_roll = async (config, account, asset_type, ts,) => {

    const Message = bcs.struct("Message", {
        func: bcs.string(),
        addr: bcs.bytes(32),
        asset_type: bcs.u64(),
        ts: bcs.u64()
    });

    let msg = {
        func: "roll_profile_by",
        addr: account.accountAddress.toUint8Array(),
        asset_type: asset_type,
        ts
    };

    const message = Message.serialize(msg).toBytes();

    console.log("Message: ", Buffer.from(message).toString("hex"));

    const hash = createHash("sha256").update(message).digest();
    console.log("Hash: ", Buffer.from(hash).toString("hex"));

    const serverPrivKey = new Ed25519PrivateKey(config.SERVER_PRIV_KEY);
    let { signature, recid } = secp256k1.ecdsaSign(Uint8Array.from(hash), serverPrivKey.toUint8Array());
    let signatureString = Buffer.from(signature).toString("hex");

    console.log('Signature:', { signature: signatureString, recid: recid });
    return {
        signature: signature,
        recid: recid
    }
};

const sign_import_asset = async (config, account, assetAddr, ts) => {

    const MessageAsset = bcs.struct("MessageAsset", {
        func: bcs.string(),
        owner: bcs.bytes(32),
        asset_addr: bcs.bytes(32),
        is_import: bcs.bool(),
        ts: bcs.u64()
    });
    bcs.string().serialize('x',)
    let msg = {
        func: "import_sig_token_v2",
        owner: account.accountAddress.toUint8Array(),
        asset_addr: AccountAddress.fromStringStrict(assetAddr).toUint8Array(),
        is_import: true,
        ts
    };
    console.log(msg);

    const message = MessageAsset.serialize(msg).toBytes();

    console.log("Message: ", Buffer.from(message).toString("hex"));

    const hash = createHash("sha256").update(message).digest();
    console.log("Hash: ", Buffer.from(hash).toString("hex"));

    const serverPrivKey = new Ed25519PrivateKey(config.SERVER_PRIV_KEY);
    let { signature, recid } = secp256k1.ecdsaSign(Uint8Array.from(hash), serverPrivKey.toUint8Array());
    let signatureString = Buffer.from(signature).toString("hex");

    console.log('Signature:', { signature: signatureString, recid: recid });
    return {
        signature: signature,
        recid: recid
    }
};

const initNftCollectionV2 = async (creatorName, collectionName, description, uri) => {
    const config = await readConfig();
    await initCollectionV2(config[creatorName], collectionName, description, uri);
}
const mintNftV2 = async (creatorName, accName, index) => {
    const config = await readConfig();
    const addr = config[accName].accountAddress.toString();
    await mintAndTransferNftV2(config[creatorName], collectionName, index, addr);
}
const whilelistNft = async (creatorAddr, collectionName) => {
    const config = await readConfig();
    await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_asset_type::add_asset_type`, [
        creatorAddr,
        collectionName
    ]);
    // get asset type
}
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
        [600, 500, 800, 600, 800, 900]]);
}
const viewAssetType = async () => {
    const config = await readConfig();
    const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_types`, []);
    console.log('Asset types:', data);
    return data;
}
const viewAssetByOwner = async (accAddr) => {
    const assets = await ownedDigitalAssets(accAddr);
    console.log(`Owner:[${accAddr}] -Assets:`, assets);
    return assets;
}
const importSigNftV2 = async (creatorName, collectionName, ownerAccName, index) => {
    const config = await readConfig();
    const ownerAddr = config[ownerAccName].accountAddress.toString();
    const creator_address = config[creatorName].accountAddress.toString().toLocaleLowerCase();
    const assets = await viewAssetByOwner(ownerAddr);
    const assetV2 = assets.find(a => a.token_standard == 'v2' &&
        a.current_token_data.token_name == getTokenName(index) &&
        a.current_token_data.current_collection.creator_address.toLocaleLowerCase() == creator_address &&
        a.current_token_data.current_collection.collection_name.toLocaleLowerCase() == collectionName.toLocaleLowerCase());
    if (!assetV2) {
        console.error('Not found token id by name:', getTokenName(index));
        return;
    }
    const token_data_id = assetV2.token_data_id;
    console.log(`Import token V2: creator:[${creator_address}]- collectioName:[${collectionName}] with id:`, token_data_id);
    //
    const result = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_type`, [creator_address, collectionName]);
    console.log('Asset type id:', result);
    //
    const defaultAssetType = "0x4::token::Token";
    const use_with_avatar = 2;
    //sign by operator
    const ts = dayjs().unix();

    const { signature, recid } = await sign_import_asset(config, config[ownerAccName], token_data_id, ts);
    //import by player
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::import_sig_token_v2`, [
        token_data_id,
        use_with_avatar,
        ts,
        recid,
        signature
    ], [defaultAssetType]);
    //viewAssetByOwner(ownerAddr);
}
const rollProfileBy = async (accName) => {
    const config = await readConfig();
    const playerAddr = config[accName].accountAddress.toString();

    const assets = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset::get_import_asset`, [playerAddr]);
    console.log(assets);
    let type_id = assets[0][0].type_id;
    if (!type_id) {
        type_id = 0;
    }
    const asset_type = BigInt(type_id);
    console.log('Asset type:', asset_type);


    const ts = dayjs().unix();

    const { signature, recid } = await sign_roll(config, config[accName], asset_type, ts);

    await sendTx(config[accName], `${config.GAME_CONTRACT_ADDR}::eragon_avatar::roll_profile_by`, [
        asset_type,
        ts,
        recid,
        signature,
    ]);

    const result = await view(`${config.GAME_CONTRACT_ADDR}::eragon_avatar::get_profile_result`, [
        config[accName].accountAddress,
        ts,
    ]);
    console.log('Roll profile result:', JSON.stringify(result));
}
const main = async () => {
    const config = await readConfig();
    //const collection_name = 'Eragon-Tesnet-Neo';
    const collection_name = 'Eragon-Tesnet-Require Sign';
    const description = 'Using for Eragon test';
    const uri = 'https://testnet.eragon.gg';
    const creatorName = 'creator1';
    //await initCollectionV2(config[creatorName], collection_name, description, uri);

    const creator_address = config[creatorName].accountAddress.toString();

    //await whilelistNft(creator_address, collection_name);
    //await setAvatarProfileWeight(creator_address, collection_name);
    //await viewAssetType();
    //return;
    //------------Mint and transfer---------------
    const last_mint = 0;
    const startMint = last_mint + 1;
    for (let index = startMint; index <= last_mint + 10; index++) {
        //await mintV2(config[creatorName], collection_name, index);
    }
    //const ui= '0x00e39823a79f618641f659aba2b18436bc1a334989469dfa2eaff049439bde99';
    //const neo = '0x75ebe19b706c6e223cb2934f86abd611c436aa59be27e3551070d63764f1ec2a';
    //await transferAll(config[creatorName], config.playerTest.accountAddress.toString());
    //-------import with signer----------
    //await importSigNftV2(creatorName, collection_name, 'playerTest', 1);
    //--view assset type
    //await viewAssetType();
    //roll
    await rollProfileBy('playerTest');

}
main();