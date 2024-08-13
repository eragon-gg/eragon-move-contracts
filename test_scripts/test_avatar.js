require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const dayjs = require("dayjs");
const { bcs } = require("@mysten/bcs");
const { sendTx, view, collectionData, ownedDigitalAssets, initCollectionV2, mintAndTransferNftV2 } = require("../scripts/utils");
const { createHash } = require("node:crypto");
const { readConfig } = require("../scripts/config");

//const collectionName = 'Dev-Eragon NFT Passport';
const collectionName = 'Dev-Eragon NFT Citizen';
const description = 'Using for test nft';
const uri = 'https://devnet.eragon.gg/';
//const token_prefix = 'Passport #';
const token_prefix = 'Eragon Token Name #';
const maximumNft = 100;
const tokenPropertyVersion = BigInt(0);

const creatorAddr = '4bc4e1709dc2aaa2dbb5e9c5c20c9721ab4a8849f789b244e46d025e268a0b6d';
const playerAddr = '10b5b07b43233b6fe88cf42a13948ff1b56a3c84ceacae150f1d333f6cae71ca';
const playerTestAddr = '9c10352d750e1f0e231665c1396d3c45c59f5bb2fdd4196df7257bba6e25fff6';

const sign = async (config, account, asset_type, ts,) => {

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

const createNftV1 = async () => {
    const config = await readConfig();
    const creator = config.creator.accountAddress.toString();
    console.log('Create collection...', process.env.NETWORK);
    // create legacy collection
    await sendTx(config.creator, `0x3::token::create_collection_script`, [
        collectionName,
        description,
        uri,
        BigInt(maximumNft),
        [true, true, true]
    ]);
    // create token
    const balance = BigInt(5);
    const maximum = BigInt(100);
    const royalty_payee_address = config.operator.accountAddress.toString();
    for (let index = 1; index <= maximumNft; index++) {
        let tokenName = getTokenName(index);
        let token_description = 'Chi minh tuan neo su dung-' + index;
        console.log('Create nft :', tokenName);
        await sendTx(config.creator, `0x3::token::create_token_script`, [
            collectionName,
            tokenName,
            token_description,
            balance,
            maximum,
            uri,
            royalty_payee_address,
            BigInt(100),//royalty_points_denominator
            BigInt(0), // royalty_points_numerator
            [true, true, true, true, true, true], //mutate_setting
            ["key1", "key2", "key3"], //property_keys
            [bcs.string().serialize('value1').toBytes(), bcs.string().serialize('value2').toBytes(), bcs.string().serialize('value3').toBytes()],
            ["String", "String", "String"] //property_types
        ]);
    }
}
const getTokenName = (index) => {
    return token_prefix + index;
}
const sendNftToPlayer = async () => {
    const config = await readConfig();
    // enable direct transfer
    await sendTx(config.player, `0x3::token::opt_in_direct_transfer`, [true]);
    const creator = config.creator.accountAddress.toString();
    const toAddr = config.player.accountAddress.toString();
    const amount = BigInt(1);
    for (let index = 1; index <= 2; index++) {
        let tokenName = getTokenName(index);
        await sendTx(config.creator, `0x3::token::transfer_with_opt_in`, [
            creator,
            collectionName,
            tokenName,
            tokenPropertyVersion,
            toAddr,
            amount]);
    }
    // view balance
    await viewAssetByOwner(toAddr);
}
const sendNft = async (fromName, toName, index) => {
    const config = await readConfig();
    // enable direct transfer
    await sendTx(config[toName], `0x3::token::opt_in_direct_transfer`, [true]);

    const creator = config.creator.accountAddress.toString();
    const toAddr = config[toName].accountAddress.toString();
    const amount = BigInt(1);
    let tokenName = getTokenName(index); // this token has been import to avatar
    await sendTx(config[fromName], `0x3::token::transfer_with_opt_in`, [
        creator,
        collectionName,
        tokenName,
        tokenPropertyVersion,
        toAddr,
        amount]);
    // view balance
    await viewAssetByOwner(config[toName].accountAddress.toString());
}
const viewCollection = async () => {

    const config = await readConfig();
    const creator = config.creator.accountAddress.toString();

    const collection = await collectionData(creator, collectionName);
    console.log("Collection:", collection);
    const assetCreator = await ownedDigitalAssets(creator);
    console.log('Creator owner assets:', assetCreator);

}
const viewAssetByOwner = async (accAddr) => {
    const assets = await ownedDigitalAssets(accAddr);
    console.log(`Owner:[${accAddr}] -Assets:`, assets);
    return assets;
}

const whilelistNft = async (creatorName) => {
    const config = await readConfig();
    const creator = config[creatorName].accountAddress.toString();
    await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_asset_type::add_asset_type`, [
        creator,
        collectionName
    ]);
    // get asset type
}
const viewAssetType = async () => {
    const config = await readConfig();
    const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_types`, []);
    console.log('Asset types:', data);
    return data;
}
const importNftV1 = async (ownerAccName, index, amountToken) => {
    const config = await readConfig();
    const creator = config.creator.accountAddress.toString();
    const tokenName = getTokenName(index);
    let amount = BigInt(1);
    if (amountToken) {
        amount = BigInt(amountToken);
    }
    const use_with_avatar = 2;
    //import by player
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::import_token_v1`, [
        creator,
        collectionName,
        tokenName,
        tokenPropertyVersion,
        amount, use_with_avatar]);
    const addr = config[ownerAccName].accountAddress.toString();
    viewAssetByOwner(addr);
}
const importNftV2 = async (creatorName, ownerAccName, index) => {
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
    //import by player
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::import_token_v2`, [
        token_data_id,
        use_with_avatar], [defaultAssetType]);
    //viewAssetByOwner(ownerAddr);
}

const exportNft = async (ownerAccName, index) => {
    const config = await readConfig();
    const creator = config.creator.accountAddress.toString();
    const tokenName = getTokenName(index);
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::claim_token_v1`, [
        creator,
        collectionName,
        tokenName,
        tokenPropertyVersion
    ]);
    const addr = config[ownerAccName].accountAddress.toString();
    viewAssetByOwner(addr);
}
const exportNftV2 = async (ownerAccName) => {
    const config = await readConfig();
    let assets = await getImportAsset(ownerAccName);
    let token_data_id = assets[0][0].object_id.vec[0];
    console.log(`Export token name: ${assets[0][0].name}-Id:`, token_data_id);

    const defaultAssetType = "0x4::token::Token";
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::claim_token_v2`, [
        token_data_id],
        [defaultAssetType]);
    const addr = config[ownerAccName].accountAddress.toString();
    viewAssetByOwner(addr);
}
const getAvatarImportNft = async (accName) => {
    const config = await readConfig();
    const playerAddr = config[accName].accountAddress.toString();
    const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_avatar::get_player_assets`, [playerAddr]);
    data[0].forEach(a => {
        console.log('Asset', a);
    });
    data[1].forEach(t => {
        console.log('Asset type:', t);
    });
    return data;
}
const getImportAsset = async (accName) => {
    const config = await readConfig();
    const playerAddr = config[accName].accountAddress.toString();
    const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset::get_import_asset`, [playerAddr]);
    data[0].forEach(a => {
        console.log('Asset:', a);
    });
    data[1].forEach(amt => {
        console.log('Amount:', amt);
    });
    return data;
}

const setProfileWeight = async (creatorName, collection_name) => {
    const config = await readConfig();
    const creator = config[creatorName].accountAddress.toString();
    const assetIds = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_type`, [
        creator,
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

    const { signature, recid } = await sign(config, config.player, asset_type, ts);

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
const getPlayerHolderAddr = async (accName) => {
    const config = await readConfig();
    const playerAddr = config[accName].accountAddress.toString();
    const result = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset::get_player_holder_asset`, [
        playerAddr
    ]);
    console.log('Holder asset addr:', result);
    return result;
}
const initNftCollectionV2 = async (accName) => {
    const config = await readConfig();
    await initCollectionV2(config[accName], collectionName, description, uri);
}
const mintNftV2 = async (creator, accName, index) => {
    const config = await readConfig();
    const addr = config[accName].accountAddress.toString();
    await mintAndTransferNftV2(config[creator], collectionName, index, addr);
}
const getAllAssetType = async () => {
    const config = await readConfig();
    const result = await view(`${config.GAME_CONTRACT_ADDR}::eragon_asset_type::get_asset_types`, []);
    console.log('All asset types:', result);
}
const unsetAsset = async (ownerAccName) => {
    const config = await readConfig();
    let assets = await getImportAsset(ownerAccName);
    let token_data_id = assets[0][0].object_id.vec[0];
    console.log(`Unset token name: ${assets[0][0].name}-Id:`, token_data_id);

    const defaultAssetType = "0x4::token::Token";
    await sendTx(config[ownerAccName], `${config.GAME_CONTRACT_ADDR}::eragon_asset::unset_asset_v2_with`, [
        token_data_id],
        [defaultAssetType]);
    const addr = config[ownerAccName].accountAddress.toString();
}
//0.--------- create v2 collection
//initNftCollectionV2('admin');
//1. --------- mint by admin and transfer to player with token name end with 2
//mintNftV2('admin', 'player', 5);
//2.---------- legacy nft
//createNftV1();
//viewCollection();
//sendNftToPlayer();
//sendNft('creator', 'player', 1);
//viewAssetByOwner(playerAddr);
//3.-----------set while list collection by creator: admin
//whilelistNft('admin');
//getAllAssetType();
//4.-----------set avatar weight for collection creat by admin and name
//setProfileWeight('admin', collectionName);
//5.-----------owner player import token v2(create by admin and token name 2) 
//importNftV2('admin', 'player', 5);
//6.-----------roll avatar
//rollProfileBy('player');
//7.-----------view asset has been import by player
//getImportAsset('player');
//8.-----------export token by player
//exportNftV2('player');
//9.-----------view all token has been import 
//getPlayerHolderAddr('player');
//viewAssetByOwner('player');
//10.----------asset has been set use for avatar -> unset
//unsetAsset('player');

