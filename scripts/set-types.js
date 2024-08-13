require("dotenv").config();
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();
  await sendTx(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_reward_type_offchain`, [1, "EGON"]);
  await sendTx(
    config.admin,
    `${config.GAME_CONTRACT_ADDR}::eragon_lucky_wheel::add_reward_type_onchain`,
    [2, "APT"],
    ["0x1::aptos_coin::AptosCoin"]
  );
};

main();
