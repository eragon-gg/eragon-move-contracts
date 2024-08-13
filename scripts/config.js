require("dotenv").config();
const YAML = require("yaml");
const fs = require("fs");
const { Account, Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");

const readConfig = async () => {
  const file = fs.readFileSync("../.aptos/config.yaml", "utf8");
  const config = YAML.parse(file);

  const GAME_CONTRACT_ADDR = config.profiles.default.account;
  const ADMIN_PRIV_KEY = config.profiles.default.private_key;
  const adminPrivKey = new Ed25519PrivateKey(ADMIN_PRIV_KEY);
  const admin = Account.fromPrivateKey({ privateKey: adminPrivKey });

  const PLAYER_PRIV_KEY = config.profiles.player.private_key;
  const playerPrivKey = new Ed25519PrivateKey(PLAYER_PRIV_KEY);
  const player = Account.fromPrivateKey({ privateKey: playerPrivKey });

  const OPERATOR_PRIV_KEY = config.profiles.operator.private_key;
  const operatorPrivKey = new Ed25519PrivateKey(OPERATOR_PRIV_KEY);
  const operator = Account.fromPrivateKey({ privateKey: operatorPrivKey });
  const SERVER_PRIV_KEY = config.profiles.server.private_key;

  const CREATOR_PRIV_KEY = config.profiles.creator.private_key;
  const creatorPrivKey = new Ed25519PrivateKey(CREATOR_PRIV_KEY);
  const creator = Account.fromPrivateKey({ privateKey: creatorPrivKey });

  const CREATOR_PRIV_KEY1 = config.profiles.creator1.private_key;
  const creatorPrivKey1 = new Ed25519PrivateKey(CREATOR_PRIV_KEY1);
  const creator1 = Account.fromPrivateKey({ privateKey: creatorPrivKey1 });

  const PLAYER_TEST_PRIV_KEY = config.profiles.player.private_key;
  const playerTestPrivKey = new Ed25519PrivateKey(PLAYER_TEST_PRIV_KEY);
  const playerTest = Account.fromPrivateKey({ privateKey: playerTestPrivKey });




  return {
    GAME_CONTRACT_ADDR,
    admin,
    player,
    operator,
    creator,
    creator1,
    playerTest,
    SERVER_PRIV_KEY
  }
};

module.exports = {
  readConfig,
};
