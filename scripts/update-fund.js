require("dotenv").config();
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const EGON_WEIGHTS = [1000, 750, 500, 350, 150, 100, 75, 50, 37, 20];
const EGON_REWARDS = [10000000000, 15000000000, 20000000000, 25000000000, 50000000000, 75000000000, 100000000000, 150000000000, 200000000000, 750000000000];
const APT_WEIGHTS = [1000, 750, 500, 350, 150, 100, 75, 50, 37, 20];
const APT_REWARDS = [1000000, 1500000, 2000000, 5000000, 7500000, 10000000, 12500000, 20000000, 30000000, 45000000];

const main = async () => {
  const config = await readConfig();
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [1, 0, 750000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [2, 0, 1000000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [3, 0, 750000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [4, 0, 2500000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [5, 0, 750000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [6, 0, 500000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [7, 0, 750000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [8, 0, 1190000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [9, 0, 2000000000000000]);
//   await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::update_season_fund`, [10, 0, 2975000000]);
};

main();
