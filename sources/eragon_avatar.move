module eragon::eragon_avatar {
    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    use std::string::String;
    use std::error;
    use std::hash;
    use std::bcs::to_bytes;
    use std::timestamp;
    use std::vector;
    use std::smart_table::{Self,SmartTable};
    use aptos_std::secp256k1::{ecdsa_recover, ecdsa_signature_from_bytes, ecdsa_raw_public_key_from_64_bytes};

    use eragon::random;
    use eragon::eragon_manager;

    friend eragon::eragon_asset;

    const PROFILE_WEIGHT :u8=1;
    const EQUIMENT_WEIGHT :u8=2;

    const ASSET_TYPE_TOKEN :u64 = 10;

    const ASSET_TYPE_NFT_PASSPORT :u64 = 100;
    const ASSET_TYPE_NFT_CITIZEN :u64 = 101;
    
    const E_NOT_AUTHORIZED: u64 = 100;
    const E_NOT_SUPPORT_NFT: u64 = 101;
    const E_ROLL_TIME_EXISTED: u64 = 105;
    const E_AVATAR_EXIST: u64 = 200;
    const E_AVATAR_NOT_EXIST: u64 = 201;
    const E_CONFIG_NOT_EXIST: u64 = 203;
    const E_COLLECTION_NOT_FOUND: u64 = 204;
    const E_DEFAULT_CONFIG_NOT_EXIST:u64 =205;
    const E_INVALID_PUBLIC_KEY: u64 = 301;
    const E_INVALID_SIGNATURE: u64 = 302;
    const E_TIMESTAMP_EXISTED: u64 = 303;
    const E_TIMESTAMP_EXPIRED: u64 = 304;

    const E_TOKEN_IMPORT_NOT_EXIST:u64 = 401;



    const E_ASSET_UNSUPPORT:u64 =600;
    const E_ASSET_TYPE_NOT_CONFIG: u64 =601;
    const E_ASSET_NOT_SET:u64 = 602;
    const E_PLAYER_ASSET_NOT_SET:u64 = 700;
    const E_PLAYER_ASSET_TYPE_NOT_FOUND: u64 =701;
    const EXPIRED_TIME: u64 = 120; // 2 minutes

    
    struct NftConfig has key,store {
        //from type id  -> weight config
        profile_weights: SimpleMap<u64,vector<u64>>,
        equipment_weights: SimpleMap<u64,vector<u64>>
    }
    struct DefaultConfig has key,store {
        //from type id  -> weight config
        weight: vector<u64>
    }
    struct PlayerAsset has key,store,drop {
        // asset type id -> number of asset type(i.e: collection Passport,token 1,token 2)
        assets: SimpleMap<u64,u64>
    }
    
    struct Message has copy, drop {
        func: vector<u8>,
        addr: address,
        asset_type:u64,
        ts: u64
    }

    struct RollResult has key {
        //time -> row id of config
        profile: SmartTable<u64, u64>,
        equipment: SmartTable<u64, u64>,
        //time -> asset type id
        tracking: SmartTable<u64,u64>
    }

    fun init_module(deployer: &signer) {

        move_to(deployer,NftConfig{
            profile_weights: simple_map::new<u64,vector<u64>>(),
            equipment_weights: simple_map::new<u64,vector<u64>>(),
        });
        move_to(deployer, DefaultConfig {
                weight: vector::empty()
        });
    }

    fun initialize_player_asset(player: &signer){
        move_to(player, PlayerAsset {
            assets: simple_map::new<u64,u64>()
        });
    }
    //using with case trusted by backend
    public entry fun set_default_weight(operator: &signer,default_weight: vector<u64>) acquires DefaultConfig {
        
        let operatorAddr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operatorAddr), error::permission_denied(E_NOT_AUTHORIZED));
        assert!(exists<DefaultConfig>(@eragon),error::invalid_state(E_DEFAULT_CONFIG_NOT_EXIST));
        let weight = &mut borrow_global_mut<DefaultConfig>(@eragon).weight;
        *weight = default_weight;

    }
    public entry fun set_weight(operator: &signer,type_id: u64,weight_type:u8,weight: vector<u64>) acquires  NftConfig {
        
        let operatorAddr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operatorAddr), error::permission_denied(E_NOT_AUTHORIZED));

        assert!(exists<NftConfig>(@eragon), error::invalid_state(E_CONFIG_NOT_EXIST));
       
        let nftConfig = borrow_global_mut<NftConfig>(@eragon);
        
        if(weight_type == PROFILE_WEIGHT){
            simple_map::upsert<u64,vector<u64>>(&mut nftConfig.profile_weights, type_id,weight);
        };
        if(weight_type == EQUIMENT_WEIGHT){
            simple_map::upsert<u64,vector<u64>>(&mut nftConfig.equipment_weights, type_id,weight);
        }
    }
    public(friend) fun set_asset(player: &signer,type_id: u64) acquires PlayerAsset {

        let playerAddr = signer::address_of(player);

        if(!exists<PlayerAsset>(playerAddr)){
            initialize_player_asset(player);
        };

        let playerAsset = borrow_global_mut<PlayerAsset>(playerAddr);
        simple_map::upsert<u64,u64>(&mut playerAsset.assets, type_id, 1);
        
    }
    public(friend) fun unset_asset(player: &signer,type_id: u64) acquires PlayerAsset {

        //
        let playerAddr = signer::address_of(player);

        assert!(exists<PlayerAsset>(playerAddr),error::invalid_state(E_ASSET_NOT_SET));

        let playerAsset = borrow_global_mut<PlayerAsset>(playerAddr);
        let found = simple_map::contains_key<u64,u64>(&playerAsset.assets,&type_id);
        assert!(found,error::invalid_state(E_ASSET_NOT_SET));
        //remove
        simple_map::remove<u64,u64>(&mut playerAsset.assets, &type_id);
    }
    
    #[randomness]
    entry fun roll_profile_by(player: &signer, asset_type_id: u64,ts: u64,rec_id: u8, signature: vector<u8>) acquires DefaultConfig, NftConfig, RollResult, PlayerAsset {

        let player_addr = signer::address_of(player);

        assert!(exists<PlayerAsset>(player_addr),error::invalid_state(E_ASSET_NOT_SET));

        //check asset type id has set for avatar
        let playerAsset = borrow_global<PlayerAsset>(player_addr);

        let found = simple_map::contains_key<u64,u64>(&playerAsset.assets,&asset_type_id);

        assert!(found, error::invalid_argument(E_ASSET_NOT_SET));

        let nftConfig = borrow_global<NftConfig>(@eragon);

        let current_weight :& vector<u64>;

        found = simple_map::contains_key<u64,vector<u64>>(&nftConfig.profile_weights,&asset_type_id);
        
        
        if(found){
            current_weight = simple_map::borrow<u64,vector<u64>>(&nftConfig.profile_weights,&asset_type_id);
        } else {
            //get by default
            assert!(exists<DefaultConfig>(@eragon),error::invalid_state(E_DEFAULT_CONFIG_NOT_EXIST));

            let config = borrow_global<DefaultConfig>(@eragon);
            current_weight = &config.weight;
        };
        
        verify_signature(b"roll_profile_by", player_addr, asset_type_id, ts, rec_id, signature);

        //row index of weight
        let randValue = random::random_by_weights(*current_weight);

        ensure_rand_result(player);

        let storage: &mut RollResult = borrow_global_mut(player_addr);
        assert!(!smart_table::contains<u64, u64>(&storage.profile, ts), error::invalid_state(E_ROLL_TIME_EXISTED));
        smart_table::upsert<u64, u64>(&mut storage.profile, ts, randValue);
        smart_table::upsert<u64, u64>(&mut storage.tracking, ts, asset_type_id);
    }

    fun ensure_rand_result(player: &signer) {
        let player_addr = signer::address_of(player);
        if (exists<RollResult>(player_addr) == false) {
            move_to(player,
                RollResult {
                    profile: smart_table::new(),
                    equipment: smart_table::new(),
                    tracking: smart_table::new()
                }
            );
        };
    }

    fun verify_signature(
        func: vector<u8>,
        player_addr: address,
        asset_type: u64,
        ts: u64,
        rec_id: u8,
        signature: vector<u8>
    ) {
        let now = timestamp::now_seconds();
        assert!(now >= ts && now - ts <= EXPIRED_TIME, error::invalid_argument(E_TIMESTAMP_EXPIRED));
        let message: Message = Message {
            func: func,
            addr: player_addr,
            asset_type,
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

        let operatorPk = eragon_manager::get_pk();
    
        assert!(
            &ecdsaRawPk == &ecdsa_raw_public_key_from_64_bytes(operatorPk),
            error::invalid_argument(E_INVALID_SIGNATURE)
        );
    }
    #[view]
    public fun get_associate_assets(player_addr: address): (vector<u64>) acquires PlayerAsset {

        let asset_type_ids = vector::empty();
        if(exists<PlayerAsset>(player_addr)){
            //check asset type id has set for avatar
            let playerAsset = borrow_global<PlayerAsset>(player_addr);
            (asset_type_ids,_) = simple_map::to_vec_pair<u64,u64>(playerAsset.assets);
        };
        asset_type_ids
    }
    #[view]
    public fun get_profile_result(player_addr: address, timestamp: u64): (u64,u64) acquires RollResult {
        let storage: &RollResult = borrow_global(player_addr);
        let rand = smart_table::borrow(&storage.profile, timestamp);
        let asset_type = smart_table::borrow(&storage.tracking, timestamp);
        (*rand,*asset_type)
    }
    #[view]
    public fun get_profile_all_result(player_addr: address): (vector<u64>,vector<u64>,vector<u64>) acquires RollResult {
        let storage: &RollResult = borrow_global(player_addr);
        let (ts,rand_id) = simple_map::to_vec_pair<u64,u64>(smart_table::to_simple_map<u64,u64>(&storage.profile));
        let (_,asset_types) = simple_map::to_vec_pair<u64,u64>(smart_table::to_simple_map<u64,u64>(&storage.tracking));
        (ts,rand_id,asset_types)
    }

    #[view]
    public fun get_equipment_result(player_addr: address, timestamp: u64): u64 acquires RollResult {
        let storage: &RollResult = borrow_global(player_addr);
        let rand = smart_table::borrow(&storage.equipment, timestamp);
        *rand
    }
}