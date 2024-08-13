require("dotenv").config();
const secp256k1 = require("secp256k1");
const { Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const { sendTx } = require("./utils");
const { readConfig } = require("./config");

const main = async () => {
  const config = await readConfig();

  const serverPrivKey = new Ed25519PrivateKey(config.SERVER_PRIV_KEY);
  let publicKey = secp256k1.publicKeyCreate(serverPrivKey.toUint8Array(), false);
  console.log("Server Public Key: ", Buffer.from(publicKey).toString("hex"));

  // Need to remove 04 at begining of the public key, that prefix means "not compressed"
  let pk = publicKey.slice(1);
  console.log("Trim Public Key: ", Buffer.from(pk).toString("hex"));
  await sendTx(config.admin, `${config.GAME_CONTRACT_ADDR}::eragon_manager::set_pk`, [pk]);
};

main();
