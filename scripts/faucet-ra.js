require("dotenv").config();
const { Aptos, AptosConfig } = require("@aptos-labs/ts-sdk");
const { getRes } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const aptosConfig = new AptosConfig({ network: process.env.NETWORK });
  const aptos = new Aptos(aptosConfig);
  const config = await readConfig();

  let account_resource = await getRes(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_manager::EragonManager`);

  console.log('Resource accout:', account_resource);

  await aptos.fundAccount({
    accountAddress: account_resource.resource_addr,
    amount: 100000000, // 1 APT
    options: {
      timeoutSecs: 10,
      waitForIndexer: false
    }
  });

  let operator_resource = await getRes(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_manager::OperatorResource`);

  console.log(operator_resource);

  await aptos.fundAccount({
    accountAddress: operator_resource.resource_addr,
    amount: 100000000, // 1 APT
    options: {
      timeoutSecs: 10,
      waitForIndexer: false
    }
  });


};

main();
