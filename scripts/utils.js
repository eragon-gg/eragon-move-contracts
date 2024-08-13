const { Account, Aptos, AptosConfig, Network, Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const chalk = require("chalk");

const aptosConfig = new AptosConfig({ network: process.env.NETWORK });
const aptos = new Aptos(aptosConfig);

/**
 * Sleep
 */
const sleep = async (ms = 2000) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
};

/**
 * Get balance of account
 */
const balanceOf = async (account) => {
  const resource = await aptos.getAccountResource({
    accountAddress: account.accountAddress,
    resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
  });

  return resource.coin.value;
};

const transferAll = async (creatorAcc, toAddr) => {
  const digitalAssets = await aptos.getOwnedDigitalAssets({
    ownerAddress: creatorAcc.accountAddress
  });
  for await (const asset of digitalAssets) {
    if (asset.token_standard != "v2") {
      console.log('Ignore v1 token:', asset.token_data_id);
      continue;
    }
    let token_data_id = asset.token_data_id;
    console.log('Transfer:', token_data_id);
    const transferTransaction = await aptos.transferDigitalAssetTransaction({
      sender: creatorAcc,
      digitalAssetAddress: token_data_id,
      recipient: toAddr,
    });
    const committedTxn = await aptos.signAndSubmitTransaction({ signer: creatorAcc, transaction: transferTransaction });
    const pendingTxn = await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  }
}

const initCollectionV2 = async (account, collectionName, collectionDescription, collectionURI) => {
  // Create the collection
  const createCollectionTransaction = await aptos.createCollectionTransaction({
    creator: account,
    description: collectionDescription,
    name: collectionName,
    uri: collectionURI,
  });
  console.log("\n=== Create the collection ===\n");
  let committedTxn = await aptos.signAndSubmitTransaction({ signer: account, transaction: createCollectionTransaction });

  let pendingTxn = await aptos.waitForTransaction({ transactionHash: committedTxn.hash });

  const collection = await aptos.getCollectionData({
    creatorAddress: account.accountAddress,
    collectionName,
    minimumLedgerVersion: BigInt(pendingTxn.version),
  });
  console.log(`Creator:${account.accountAddress}-Collection: ${JSON.stringify(collection, null, 4)}`);
}
const getTokenName = (index) => {
  return "Eragon Token Name #" + index;
}
const mintV2 = async (creatorAcc, collectionName, index) => {
  const tokenName = getTokenName(index);
  const tokenDescription = "Example asset description.";
  const tokenURI = "eragon/asset";

  console.log("\n=== Mints the digital asset ===\n", tokenName);
  const mintTokenTransaction = await aptos.mintDigitalAssetTransaction({
    creator: creatorAcc,
    collection: collectionName,
    description: tokenDescription,
    name: tokenName,
    uri: tokenURI,
  });

  let committedTxn = await aptos.signAndSubmitTransaction({ signer: creatorAcc, transaction: mintTokenTransaction });
  let pendingTxn = await aptos.waitForTransaction({ transactionHash: committedTxn.hash, options: { checkSuccess: true } });
  console.log(`Tx: ${pendingTxn.hash} -Status: ${pendingTxn.success}`);

}
const mintAndTransferNftV2 = async (creatorAcc, collectionName, index, toAddr) => {

  const tokenName = "Eragon Token Name #" + index;
  const tokenDescription = "Example asset description.";
  const tokenURI = "eragon/asset";

  console.log("\n=== Mints the digital asset ===\n");

  const mintTokenTransaction = await aptos.mintDigitalAssetTransaction({
    creator: creatorAcc,
    collection: collectionName,
    description: tokenDescription,
    name: tokenName,
    uri: tokenURI,
  });

  let committedTxn = await aptos.signAndSubmitTransaction({ signer: creatorAcc, transaction: mintTokenTransaction });
  let pendingTxn = await aptos.waitForTransaction({ transactionHash: committedTxn.hash, options: { checkSuccess: true } });
  const digitalAsset = await aptos.getOwnedDigitalAssets({
    ownerAddress: creatorAcc.accountAddress,
    minimumLedgerVersion: BigInt(pendingTxn.version),
    options: {
      limit: 100
    }
  });
  console.log(`Account:${creatorAcc.accountAddress}-digital assets balance: ${digitalAsset.length}`);
  console.log(digitalAsset);
  let tokenv2 = digitalAsset.find(d => d.token_standard == "v2");
  let token_data_id = tokenv2.token_data_id;
  console.log('Before transer:', token_data_id);

  console.log(`Account:${creatorAcc.accountAddress} digital asset: ${JSON.stringify(digitalAsset[0], null, 4)}`);

  const transferTransaction = await aptos.transferDigitalAssetTransaction({
    sender: creatorAcc,
    digitalAssetAddress: token_data_id,
    recipient: toAddr,
  });
  committedTxn = await aptos.signAndSubmitTransaction({ signer: creatorAcc, transaction: transferTransaction });
  pendingTxn = await aptos.waitForTransaction({ transactionHash: committedTxn.hash });

  const creatorDigitalAssetsAfter = await aptos.getOwnedDigitalAssets({
    ownerAddress: creatorAcc.accountAddress,
    minimumLedgerVersion: BigInt(pendingTxn.version),
  });
  console.log(`Account:${creatorAcc.accountAddress} digital assets balance: ${creatorDigitalAssetsAfter.length}`);

  const digitalAssetsAfter = await aptos.getOwnedDigitalAssets({
    ownerAddress: toAddr
  });
  console.log(`Acc:${toAddr} digital assets balance: ${digitalAssetsAfter.length}`);
  console.log(digitalAssetsAfter);
}

/**
 * Send tx
 */
const sendTx = async (sender, func, args, typeArgs = []) => {
  const transaction = await aptos.transaction.build.simple({
    sender: sender.accountAddress,
    data: {
      function: func,
      typeArguments: typeArgs,
      functionArguments: args,
    },
    options: {
      maxGasAmount: 10000
    }
  });

  const pendingTransaction = await aptos.signAndSubmitTransaction({
    signer: sender,
    transaction
  });
  await aptos.waitForTransaction({ transactionHash: pendingTransaction.hash, options: { checkSuccess: true } });

  console.log(chalk.green("[sendTx] txhash:"), pendingTransaction.hash);
};

const view = async (func, args) => {
  return await aptos.view({
    payload: {
      function: func,
      functionArguments: args,
    },
  });

};

/**
 * Get resource of account from module given by `resourceType`
 */
const getRes = async (account, resourceType) => {
  let resource;
  try {
    resource = await aptos.getAccountResource({
      accountAddress: account.accountAddress,
      resourceType,
    });
  } catch (err) {
    console.error(chalk.red("[getRes] ERR", err));
  }

  return resource;
};

/**
 * Fund to the account
 */
const funds = async (account, amount = 100000000) => {
  await aptos.fundAccount({ accountAddress: account.accountAddress, amount });
};
/**
 * Get getOwnedDigitalAssets
 */
const ownedDigitalAssets = async (ownerAddress) => {
  const digitalAssets = await aptos.getOwnedDigitalAssets({
    ownerAddress
  });
  return digitalAssets;
}
/**
 * Get collection info
 */
const collectionData = async (creatorAddress, collectionName) => {
  const collection = await aptos.getCollectionDataByCreatorAddressAndCollectionName({
    creatorAddress,
    collectionName
  });
  return collection;
}
module.exports = {
  sleep,
  balanceOf,
  sendTx,
  getRes,
  funds,
  view,
  collectionData,
  ownedDigitalAssets,
  initCollectionV2,
  mintAndTransferNftV2,
  transferAll,
  mintV2,
  getTokenName
};
