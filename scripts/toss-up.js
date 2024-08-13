require("dotenv").config();
const dayjs = require("dayjs");
const { sendTx, view, getRes } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();
  const ts = dayjs().unix();
  
  let block_number = Math.floor(ts / 15);
  console.log(block_number);

  await sendTx(config.player, `${config.GAME_CONTRACT_ADDR}::eragon_toss::toss_up`, []);

  // const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_boost::get_block_counter`, [block_number]);
  // const data = await getRes(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_boost::EragonBoost`);
  // console.log(JSON.stringify(data, null, 4));
};

main();
