require("dotenv").config();
const dayjs = require("dayjs");
const { sendTx, view, getRes } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();
  await sendTx(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_toss::create_resource`, []);
};

main();
