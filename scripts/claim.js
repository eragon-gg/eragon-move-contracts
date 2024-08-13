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
  const ts = dayjs().unix();
  const start = dayjs().subtract("1", "hour").unix();
  console.log(ts);

  const Message = bcs.struct("Message", {
    func: bcs.string(),
    addr: bcs.bytes(32),
    coin_type: bcs.string(),
    amount: bcs.u64(),
    ts: bcs.u64(),
  });

  let coin_type = "0x1::aptos_coin::AptosCoin";
  let amount = 100000;

  let msg = {
    func: "claim",
    addr: config.player.accountAddress.toUint8Array(),
    coin_type,
    amount,
    ts,
  };

  const message = Message.serialize(msg).toBytes();

  console.log("Message: ", Buffer.from(message).toString("hex"));

  const hash = createHash("sha256").update(message).digest();
  console.log("Hash: ", Buffer.from(hash).toString("hex"));

  const serverPrivKey = new Ed25519PrivateKey(config.SERVER_PRIV_KEY);
  let { signature, recid } = secp256k1.ecdsaSign(Uint8Array.from(hash), serverPrivKey.toUint8Array());
  let signatureString = Buffer.from(signature).toString("hex");

  console.log({ signature: signatureString, recid: recid });

  await sendTx(
    config.player,
    `${config.GAME_CONTRACT_ADDR}::eragon_claim::claim`,
    [amount, ts, recid, signature],
    [coin_type]
  );

  const data = await view(`${config.GAME_CONTRACT_ADDR}::eragon_claim::get_claim_result`, [
    config.player.accountAddress,
    ts,
  ]);

  console.log(JSON.stringify(data));
};

sign();
