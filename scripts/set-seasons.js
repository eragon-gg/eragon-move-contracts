require("dotenv").config();
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [1]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [2]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [3]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [4]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [5]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [6]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [7]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [8]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [9]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [10]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::create_season`, [11]);
};

main();
