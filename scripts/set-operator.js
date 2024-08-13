require("dotenv").config();
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {

  const config = await readConfig();

  await sendTx(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_manager::add_operator`, [config.operator.accountAddress]);
};

main();
