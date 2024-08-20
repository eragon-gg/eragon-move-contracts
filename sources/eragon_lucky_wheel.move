module eragon::eragon_lucky_wheel {
    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    use std::vector;
    use std::error;
    use std::hash;
    use std::bcs::to_bytes;
    use std::timestamp;
    use std::option::{Self, Option};
    use std::string::{String};
    use aptos_std::type_info::{Self};
    

    use aptos_std::secp256k1::{ecdsa_recover, ecdsa_signature_from_bytes, ecdsa_raw_public_key_from_64_bytes};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;

    use eragon::random;
    use eragon::eragon_manager;

    const E_NOT_AUTHORIZED: u64 = 100;
    const E_INSUFFICIENT_BALANCE: u64 = 101;
    const E_INVALID_SIGNATURE: u64 = 201;
    const E_TIMESTAMP_EXISTED: u64 = 202;
    const E_TIMESTAMP_EXPIRED: u64 = 203;
    const E_SEASON_EXISTED: u64 = 300;
    const E_SEASON_NOT_EXISTED: u64 = 301;
    const E_POOL_NOT_START: u64 = 302;
    const E_SEASON_NOT_ENABLED: u64 = 303;
    const E_REWARD_SETTING_EXISTED: u64 = 401;
    const E_REWARD_TYPE_ID_EXISTED: u64 = 402;
    const E_REWARD_TYPE_ID_NOT_EXISTED: u64 = 403;
    const E_INVALID_REWARD_SETTING: u64 = 404;

    const EXPIRED_TIME: u64 = 120; // 2 minutes

    struct Message has copy, drop {
        func: vector<u8>,
        addr: address,
        season_id: u64,
        pool_id: u64,
        start: u64,
        ts: u64
    }
    
    struct RewardResult has key, store, copy, drop {
        rand: u64,
        amount: u64,
        reward_type: RewardType
    }

    struct RewardType has key, store, copy, drop {
        type_id: u64,
        name: String,
        coin_name: Option<String>   
    }
    
    struct RollResult has key, store, copy, drop {
        season_id: u64,
        pool_id: u64,
        reward_results: vector<RewardResult>,
    }

    struct RollResults has key, store {
        roll_results: SimpleMap<u64, RollResult>,
    }

    struct RewardSetting has key, store, copy, drop {
        weights: vector<u64>,
        rewards: vector<u64>,
        fund_per_pool: u64,
        reward_type: RewardType
    }

    struct Pool has key, store, copy, drop {
        pool_id: u64,
        remain_funds: vector<u64>
    }

    struct Season has key, store, copy, drop {
        season_id: u64,
        reward_settings: vector<RewardSetting>,
        pools: SimpleMap<u64, Pool>,
        is_enabled: bool,
        operator_addr: address
    }

    struct EragonLuckyWheel has key, store {
        admin_addr: address,
        seasons: SimpleMap<u64, Season>,
        reward_types: SimpleMap<u64, RewardType>
    }

    #[event]
    struct EragonCreatingSeasonEvent has drop, store {
        operator_addr: address,
        season_id: u64
    }

    #[event]
    struct EragonRollingEvent has drop, store {
        player_addr: address,
        ts: u64,
        roll_result: RollResult
    }

    fun init_module(deployer: &signer) {

        move_to(deployer, EragonLuckyWheel {
            admin_addr: @eragon,
            seasons: simple_map::new(),
            reward_types: simple_map::new()
        });
    }

    public entry fun add_reward_type_offchain(admin: &signer, reward_type_id: u64, reward_name: String) acquires EragonLuckyWheel {
        assert!(eragon_manager::is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            !simple_map::contains_key<u64, RewardType>(&resource.reward_types, &reward_type_id),
            error::invalid_state(E_REWARD_TYPE_ID_EXISTED)
        );

        simple_map::add<u64, RewardType>(&mut resource.reward_types, reward_type_id, RewardType {
            type_id: reward_type_id,
            name: reward_name,
            coin_name: option::none()
        });
    }

    public entry fun add_reward_type_onchain<CoinType>(admin: &signer, reward_type_id: u64, reward_name: String) acquires EragonLuckyWheel {
        assert!(eragon_manager::is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            !simple_map::contains_key<u64, RewardType>(&resource.reward_types, &reward_type_id),
            error::invalid_state(E_REWARD_TYPE_ID_EXISTED)
        );

        simple_map::add<u64, RewardType>(&mut resource.reward_types, reward_type_id, RewardType {
            type_id: reward_type_id,
            name: reward_name,
            coin_name: option::some<String>(coin_name<CoinType>())
        });
    }

    public entry fun create_season(operator: &signer, season_id: u64) acquires EragonLuckyWheel {
        let operator_addr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));
        eragon_manager::create_operator_resource(operator);
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            !simple_map::contains_key<u64, Season>(&resource.seasons, &season_id),
            error::invalid_state(E_SEASON_EXISTED)
        );

        simple_map::add<u64, Season>(&mut resource.seasons, season_id, Season {
            season_id,
            reward_settings: vector::empty<RewardSetting>(),
            pools: simple_map::new(),
            is_enabled: true,
            operator_addr
        });

        event::emit(EragonCreatingSeasonEvent {
            operator_addr,
            season_id
        });
    }

    public entry fun add_season_reward_setting(operator: &signer, season_id: u64, weights: vector<u64>, rewards: vector<u64>, reward_type_id: u64, fund_per_pool: u64) acquires EragonLuckyWheel {
        let operator_addr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));
        
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            simple_map::contains_key<u64, Season>(&resource.seasons, &season_id),
            error::invalid_state(E_SEASON_NOT_EXISTED)
        );

        assert!(
            simple_map::contains_key<u64, RewardType>(&resource.reward_types, &reward_type_id),
            error::invalid_state(E_REWARD_TYPE_ID_NOT_EXISTED)
        );

        let reward_type = simple_map::borrow(&resource.reward_types, &reward_type_id);

        let season = simple_map::borrow_mut(&mut resource.seasons, &season_id);
        assert!(season.operator_addr == operator_addr, error::permission_denied(E_NOT_AUTHORIZED));

        vector::push_back<RewardSetting>(&mut season.reward_settings, RewardSetting {
            weights,
            rewards,
            fund_per_pool,
            reward_type: *reward_type
        });
    }

    public entry fun update_season_fund(operator: &signer, season_id: u64, reward_setting_id: u64, fund_per_pool: u64) acquires EragonLuckyWheel {
        let operator_addr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));
        
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            simple_map::contains_key<u64, Season>(&resource.seasons, &season_id),
            error::invalid_state(E_SEASON_NOT_EXISTED)
        );

        let season = simple_map::borrow_mut(&mut resource.seasons, &season_id);
        assert!(season.operator_addr == operator_addr, error::permission_denied(E_NOT_AUTHORIZED));

        let reward_length = vector::length<RewardSetting>(&season.reward_settings);
        assert!(reward_setting_id < reward_length, error::permission_denied(E_INVALID_REWARD_SETTING));

        let reward_setting = vector::borrow_mut<RewardSetting>(&mut season.reward_settings, reward_setting_id);

        reward_setting.fund_per_pool = fund_per_pool;
    }

    public entry fun update_season_reward_setting(operator: &signer, season_id: u64, reward_setting_id: u64, weights: vector<u64>, rewards: vector<u64>) acquires EragonLuckyWheel {
        let operator_addr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));
        
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            simple_map::contains_key<u64, Season>(&resource.seasons, &season_id),
            error::invalid_state(E_SEASON_NOT_EXISTED)
        );

        let season = simple_map::borrow_mut(&mut resource.seasons, &season_id);
        assert!(season.operator_addr == operator_addr, error::permission_denied(E_NOT_AUTHORIZED));

        let reward_length = vector::length<RewardSetting>(&season.reward_settings);
        assert!(reward_setting_id < reward_length, error::permission_denied(E_INVALID_REWARD_SETTING));

        let reward_setting = vector::borrow_mut<RewardSetting>(&mut season.reward_settings, reward_setting_id);

        reward_setting.weights = weights;
        reward_setting.rewards = rewards;
    }

    public entry fun set_season_enabled(operator: &signer, season_id: u64, is_enabled: bool) acquires EragonLuckyWheel {
        let operator_addr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));
        
        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);
        assert!(
            simple_map::contains_key<u64, Season>(&resource.seasons, &season_id),
            error::invalid_state(E_SEASON_NOT_EXISTED)
        );

        let season = simple_map::borrow_mut(&mut resource.seasons, &season_id);
        assert!(season.operator_addr == operator_addr, error::permission_denied(E_NOT_AUTHORIZED));

        season.is_enabled = is_enabled;
    }

    #[randomness]
    entry fun roll(
        player: &signer,
        season_id: u64,
        pool_id: u64,
        start: u64,
        ts: u64,
        rec_id: u8,
        signature: vector<u8>
    ) acquires EragonLuckyWheel, RollResults {
        let player_addr = signer::address_of(player);

        verify_signature(b"roll", player_addr, season_id, pool_id, start, ts, rec_id, signature);
        ensure_roll_result(player);
        let storage: &mut RollResults = borrow_global_mut<RollResults>(player_addr);
        assert!(
            !simple_map::contains_key<u64, RollResult>(&storage.roll_results, &ts),
            error::invalid_state(E_TIMESTAMP_EXISTED)
        );

        let resource = borrow_global_mut<EragonLuckyWheel>(@eragon);

        let season = simple_map::borrow_mut(&mut resource.seasons, &season_id);
        assert!(season.is_enabled, error::invalid_state(E_SEASON_NOT_ENABLED));

        let reward_length = vector::length<RewardSetting>(&season.reward_settings);

        // If pool is not existed, create a new pool with remain_fund of each reward is equal to fund_per_pool
        if (!simple_map::contains_key<u64, Pool>(&season.pools, &pool_id)) {
            let pool = Pool {
                pool_id,
                remain_funds: vector::empty()
            };
            for (i in 0..reward_length) {
                let reward_setting = vector::borrow<RewardSetting>(&season.reward_settings, i);
                vector::push_back<u64>(&mut pool.remain_funds, reward_setting.fund_per_pool);
            };

            simple_map::add<u64, Pool>(&mut season.pools, pool_id, pool);
        };

        let roll_result = RollResult {
            season_id,
            pool_id,
            reward_results: vector::empty()
        };
        
        let pool = simple_map::borrow_mut(&mut season.pools, &pool_id);

        for (i in 0..reward_length) {
            let reward_setting = vector::borrow<RewardSetting>(&season.reward_settings, i);
            let remain_fund = vector::borrow_mut<u64>(&mut pool.remain_funds, i);
            let random_value = random::random_by(reward_setting.weights);
            let base_amount = vector::borrow<u64>(&reward_setting.rewards, random_value);
            let halving = calculate_halving_per_6h(reward_setting.fund_per_pool, *remain_fund, start);
            let amount: u64 = *base_amount >> halving;
            let reward_result = RewardResult {
                rand: random_value,
                amount: amount,
                reward_type: reward_setting.reward_type
            };

            *remain_fund = *remain_fund - amount;
    
            let reward_type = reward_setting.reward_type;
            if (option::is_some<String>(&reward_type.coin_name)) {
                let type = option::borrow<String>(&reward_type.coin_name);
                if (*type == coin_name<AptosCoin>()) {
                    send_reward<AptosCoin>(season.operator_addr, player_addr, amount);
                };
                
            };

            vector::push_back(&mut roll_result.reward_results, reward_result)
        };

        simple_map::add<u64, RollResult>(&mut storage.roll_results, ts, roll_result);

        event::emit(EragonRollingEvent {
            player_addr: player_addr,
            ts,
            roll_result
        });
    }

    fun send_reward<CoinType>(operator_addr: address, player_addr: address, amount: u64) {
        assert!(
            coin::balance<CoinType>(eragon_manager::get_operator_acc_addr(operator_addr)) >= amount,
            error::invalid_state(E_INSUFFICIENT_BALANCE)
        );
        coin::transfer<CoinType>(&eragon_manager::get_operator_resource_signer(operator_addr), player_addr, amount);
    }

    fun calculate_halving_per_6h(fund_per_pool: u64, remain_fund: u64, start: u64) : u8 {
        let fund_per_6h = fund_per_pool / 4;
        let current_pool = get_current_remain(fund_per_pool, remain_fund, start);

        let halving = 0u8;
        let consider = fund_per_6h >> 1;
        while (consider > current_pool) {
            consider = consider >> 1;
            halving = halving + 1;
        };

        halving
    }

    fun get_current_remain(fund_per_pool: u64, remain_fund: u64, start: u64) : u64 {
        let now = timestamp::now_seconds();
        assert!(now > start, error::invalid_argument(E_POOL_NOT_START));
        let count_6h = (now - start) / 21600;
        let phase = if (count_6h > 3) 4 else count_6h + 1;
        let fund_per_6h = fund_per_pool / 4;
        let current_pool = remain_fund - fund_per_6h * (4 - phase);

        current_pool
    }

    fun calculate_halving(fund_per_pool: u64, remain_fund: u64) : u8 {
        let halving = 0u8;
        let consider = fund_per_pool >> 1;
        while (consider > remain_fund) {
            consider = consider >> 1;
            halving = halving + 1;
        };

        halving
    }

    fun verify_signature(
        func: vector<u8>,
        player_addr: address,
        season_id: u64,
        pool_id: u64,
        start: u64,
        ts: u64,
        rec_id: u8,
        signature: vector<u8>
    ) {
        let now = timestamp::now_seconds();
        assert!(now >= ts && now - ts <= EXPIRED_TIME, error::invalid_argument(E_TIMESTAMP_EXPIRED));
        let message: Message = Message {
            func: func,
            addr: player_addr,
            season_id,
            pool_id,
            start,
            ts: ts
        };
        let msg_bytes = to_bytes(&message);

        let pk = ecdsa_recover(
            hash::sha2_256(msg_bytes),
            rec_id,
            &ecdsa_signature_from_bytes(signature),
        );

        assert!(std::option::is_some(&pk), error::invalid_argument(E_INVALID_SIGNATURE));

        let ecdsaRawPk = std::option::extract(&mut pk);

        assert!(
            &ecdsaRawPk == &ecdsa_raw_public_key_from_64_bytes(eragon_manager::get_pk()),
            error::invalid_argument(E_INVALID_SIGNATURE)
        );
    }

    fun ensure_roll_result(player: &signer) {
        let player_addr = signer::address_of(player);
        if (exists<RollResults>(player_addr) == false) {
            move_to(player,
                RollResults {
                    roll_results: simple_map::new()
                }
            );
        };
    }

    #[view]
    public fun get_roll_result(player_addr: address, ts: u64): RollResult acquires RollResults {
        let storage: &RollResults = borrow_global(player_addr);
        let result = simple_map::borrow(&storage.roll_results, &ts);
        *result
    }

    #[view]
    public fun get_season_info(season_id: u64): Season acquires EragonLuckyWheel {
        let resource = borrow_global<EragonLuckyWheel>(@eragon);
        let season = simple_map::borrow(&resource.seasons, &season_id);
        *season
    }

    #[view]
    public fun get_pool_info(season_id: u64, pool_id: u64): Pool acquires EragonLuckyWheel {
        let resource = borrow_global<EragonLuckyWheel>(@eragon);
        let season = simple_map::borrow(&resource.seasons, &season_id);
        if (simple_map::contains_key<u64, Pool>(&season.pools, &pool_id)) {
            let pool = simple_map::borrow(&season.pools, &pool_id);
            *pool
        } else {
            let pool = Pool {
                pool_id,
                remain_funds: vector::empty()
            };
            let reward_length = vector::length<RewardSetting>(&season.reward_settings);
            for (i in 0..reward_length) {
                let reward_setting = vector::borrow<RewardSetting>(&season.reward_settings, i);
                vector::push_back<u64>(&mut pool.remain_funds, reward_setting.fund_per_pool);
            };

            pool
        }
    }

    #[view]
    public fun get_current_pool_info(season_id: u64, pool_id: u64, start: u64): Pool acquires EragonLuckyWheel {
        let pool = get_pool_info(season_id, pool_id);
        let season = get_season_info(season_id);
        let reward_length = vector::length<RewardSetting>(&season.reward_settings);
        let current_pool = Pool {
            pool_id,
            remain_funds: vector::empty()
        };
        for (i in 0..reward_length) {
            let reward_setting = vector::borrow<RewardSetting>(&season.reward_settings, i);
            let remain = vector::borrow<u64>(&pool.remain_funds, i);
            let current_remain = get_current_remain(reward_setting.fund_per_pool, *remain, start);
            vector::push_back<u64>(&mut current_pool.remain_funds, current_remain);
        };

        current_pool
    }

    #[view]
    public fun get_pool_reward(season_id: u64, pool_id: u64, start: u64): vector<vector<u64>> acquires EragonLuckyWheel {
        let season = get_season_info(season_id);
        let reward_length = vector::length<RewardSetting>(&season.reward_settings);
        let result = vector::empty<vector<u64>>();

        let pool = get_pool_info(season_id, pool_id);

        for (i in 0..reward_length) {
            let rewards = vector::empty<u64>();
            let reward_setting = vector::borrow<RewardSetting>(&season.reward_settings, i);
            let remain_fund = vector::borrow<u64>(&pool.remain_funds, i);

            let halving = calculate_halving_per_6h(reward_setting.fund_per_pool, *remain_fund, start);

            vector::for_each<u64>(reward_setting.rewards, | value | {
                let reward_after_halving: u64 = value >> halving;
                vector::push_back<u64>(&mut rewards, reward_after_halving);
            });
            vector::push_back<vector<u64>>(&mut result, rewards);
        };

        result
    }

    #[view]
    public fun get_reward_types(): vector<RewardType> acquires EragonLuckyWheel {
        let resource = borrow_global<EragonLuckyWheel>(@eragon);
        simple_map::values<u64, RewardType>(&resource.reward_types)
    }

    fun coin_name<CoinType>(): String {
        let type_info = type_info::type_name<CoinType>();
        type_info
    }
}