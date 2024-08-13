module eragon::eragon_claim {

    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    use std::error;
    use std::hash;
    use std::bcs::to_bytes;
    use std::timestamp;
    use std::string::{String};
    use aptos_std::type_info::{Self};

    use aptos_std::secp256k1::{
        ecdsa_recover,
        ecdsa_signature_from_bytes,
        ecdsa_raw_public_key_from_64_bytes
    };
    use aptos_framework::coin;

    use eragon::eragon_manager;

    const E_NOT_AUTHORIZED: u64 = 100;
    const E_INSUFFICIENT_BALANCE: u64 = 101;
    const E_INVALID_SIGNATURE: u64 = 201;
    const E_TIMESTAMP_EXISTED: u64 = 202;
    const E_TIMESTAMP_EXPIRED: u64 = 203;

    const EXPIRED_TIME: u64 = 120; // 2 minutes

    struct Message has copy, drop {
        func: vector<u8>,
        addr: address,
        coin_type: String,
        amount: u64,
        ts: u64
    }

    struct ClaimResult has key, store, copy {
        ts: u64,
        amount: u64,
        coin_type: String
    }

    struct ClaimResults has key, store {
        claim_results: SimpleMap<u64, ClaimResult>
    }

    public entry fun claim<CoinType>(player: &signer, amount: u64, ts: u64, rec_id: u8, signature: vector<u8>) acquires ClaimResults {
        let player_addr = signer::address_of(player);
        let coin_type = type_info::type_name<CoinType>();
        verify_signature(b"claim", player_addr, coin_type, amount, ts, rec_id, signature);

        if (exists<ClaimResults>(player_addr) == false) {
            move_to(player,
                ClaimResults {
                    claim_results: simple_map::new()
                }
            );
        };

        let storage = borrow_global_mut<ClaimResults>(player_addr);

        assert!(
            !simple_map::contains_key<u64, ClaimResult>(&storage.claim_results, &ts),
            error::invalid_state(E_TIMESTAMP_EXISTED)
        );

        assert!(
            coin::balance<CoinType>(eragon_manager::get_acc_addr()) >= amount,
            error::invalid_state(E_INSUFFICIENT_BALANCE)
        );
        coin::transfer<CoinType>(&eragon_manager::get_resource_signer(), player_addr, amount);

        simple_map::add<u64, ClaimResult>(&mut storage.claim_results, ts, ClaimResult {
            amount,
            ts,
            coin_type
        });
    }

    fun verify_signature(
        func: vector<u8>,
        player_addr: address,
        coin_type: String,
        amount: u64,
        ts: u64,
        rec_id: u8,
        signature: vector<u8>
    ) {
        let now = timestamp::now_seconds();
        assert!(now >= ts && now - ts <= EXPIRED_TIME,
            error::invalid_argument(E_TIMESTAMP_EXPIRED));
        let message: Message = Message { func: func, addr: player_addr, coin_type: coin_type, amount, ts: ts };
        let msg_bytes = to_bytes(&message);

        let pk = ecdsa_recover(hash::sha2_256(msg_bytes), rec_id, &ecdsa_signature_from_bytes(
                signature
            ),);

        assert!(std::option::is_some(&pk), error::invalid_argument(E_INVALID_SIGNATURE));

        let ecdsaRawPk = std::option::extract(&mut pk);

        assert!(&ecdsaRawPk == &ecdsa_raw_public_key_from_64_bytes(eragon_manager::get_pk()),
            error::invalid_argument(E_INVALID_SIGNATURE));
    }

    #[view]
    public fun get_claim_result(player_addr: address, ts: u64): ClaimResult acquires ClaimResults {
        let storage: &ClaimResults = borrow_global(player_addr);
        let result = simple_map::borrow(&storage.claim_results, &ts);
        *result
    }
}
