require("dotenv").config();
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const EGON_WEIGHTS = [1000, 750, 500, 350, 150, 100, 75, 50, 37, 20];
const EGON_REWARDS = [1000000000, 1500000000, 2000000000, 2500000000, 5000000000, 7500000000, 10000000000, 15000000000, 20000000000, 75000000000];
const APT_WEIGHTS = [1000, 750, 500, 350, 150, 100, 75, 50, 37, 20];
const APT_REWARDS = [1000000, 1500000, 2000000, 5000000, 7500000, 10000000, 12500000, 20000000, 30000000, 45000000];

const main = async () => {
  const config = await readConfig();
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [1, EGON_WEIGHTS, EGON_REWARDS, 1, 750000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [2, EGON_WEIGHTS, EGON_REWARDS, 1, 1000000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [3, EGON_WEIGHTS, EGON_REWARDS, 1, 300000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [4, EGON_WEIGHTS, EGON_REWARDS, 1, 2500000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [5, EGON_WEIGHTS, EGON_REWARDS, 1, 750000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [6, EGON_WEIGHTS, EGON_REWARDS, 1, 500000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [7, EGON_WEIGHTS, EGON_REWARDS, 1, 300000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [8, EGON_WEIGHTS, EGON_REWARDS, 1, 1190000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [9, EGON_WEIGHTS, EGON_REWARDS, 1, 2000000000000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [10, APT_WEIGHTS, APT_REWARDS, 2, 2975000000]);
  await sendTx(config.operator, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_season_reward_setting`, [11, APT_WEIGHTS, APT_REWARDS, 2, 3000000000]);
};

main();
