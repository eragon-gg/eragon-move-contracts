require("dotenv").config();
const { Aptos, AptosConfig } = require("@aptos-labs/ts-sdk");
const { getRes } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();

  let account_resource = await getRes(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_manager::EragonManager`);

  console.log("Contract Resource: ");
  console.log(account_resource);

  let operator_resource = await getRes(
    config.operator,
    `${config.GAME_CONTRACT_ADDR}::eragon_manager::OperatorResource`
  );

  console.log("Operator Resource: ");
  console.log(operator_resource);
};

main();
