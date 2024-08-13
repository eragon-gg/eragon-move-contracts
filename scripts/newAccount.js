require("dotenv").config();
const chalk = require("chalk");
const { Account, Aptos, AptosConfig, Network } = require("@aptos-labs/ts-sdk");
require("dotenv").config();

// Generate random account
(async () => {
  const acc = Account.generate();
  console.log(
    chalk.green(`
    PrivateKey: ${acc.privateKey}
    PublicKey: ${acc.publicKey}
    Address: ${acc.accountAddress}
  `)
  );

  const aptosConfig = new AptosConfig({ network: process.env.NETWORK });
  const aptos = new Aptos(aptosConfig);
  await aptos.fundAccount({
    accountAddress: acc.accountAddress,
    amount: 1000000000, // 10 APT
    options: {
      timeoutSecs: 10,
      waitForIndexer: false
    }
  });

  const resource = await aptos.getAccountResource({
    accountAddress: acc.accountAddress,
    resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
  });

  console.log(chalk.green("Account funded"), resource.coin.value);
})();
