require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const dayjs = require("dayjs");
const { bcs } = require("@mysten/bcs");
const { sendTx, view } = require("./utils");
const { createHash } = require("node:crypto");
const { readConfig } = require("./config");

const sign = async () => {
  const config = await readConfig();

  await sendTx(config.player, `${config.GAME_CONTRACT_ADDR}::eragon_checkin::check_in`, []);

  const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_checkin::get_player_checkins`, [
    config.player.accountAddress,
  ]);

  console.log(JSON.stringify(data));
};

sign();
