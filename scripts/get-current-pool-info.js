require("dotenv").config();
const dayjs = require("dayjs");
const { view } = require("./utils");
const { readConfig } = require("./config");

const sign = async () => {
  const config = await readConfig();
  const start = dayjs().subtract("1", "hour").unix();

  let season_id = 1;
  let pool_id = 1;

  const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::get_current_pool_info`, [season_id, pool_id, start]);

  console.log(JSON.stringify(data));
};

sign();
