module eragon::eragon_asset {
    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    use std::string::String;
    use std::string::utf8;
    use std::option::{Self,Option};
    use std::error;
    use std::timestamp;
    use std::hash;
    use std::bcs::to_bytes;
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::object::{Self,Object, ObjectCore};
    use aptos_token_objects::aptos_token;
    use aptos_token_objects::token::{Self as tokenv2, Token as TokenV2};
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token::token:: {Self as tokenv1, TokenId,TokenDataId};
    use aptos_std::secp256k1::{ecdsa_recover, ecdsa_signature_from_bytes, ecdsa_raw_public_key_from_64_bytes};

    use eragon::eragon_asset_type::{Self,CollectionId};
    use eragon::eragon_avatar;
    use eragon::eragon_manager;

    const PROFILE_WEIGHT :u8=1;
    const EQUIMENT_WEIGHT :u8=2;

    const TOKEN_V1 : u64=1;
    const TOKEN_V2: u64 =2;
    
    const SET_ASSET_FOR_NONCE: u64 =0;
    const SET_ASSET_FOR_AVATAR: u64 =2;
    

    const E_NOT_AUTHORIZED: u64 = 200;
    const E_NOT_SUPPORT_NFT: u64 = 201;
    const E_SEED_EXISTED: u64 = 205;
    const E_AVATAR_EXIST: u64 = 300;
    const E_AVATAR_NOT_EXIST: u64 = 301;
    const E_WHITELIST_NOT_EXIST: u64 = 403;
    const E_COLLECTION_NOT_FOUND: u64 = 404;
    const E_INVALID_PUBLIC_KEY: u64 = 501;
    const E_INVALID_SIGNATURE: u64 = 502;
    const E_TIMESTAMP_EXISTED: u64 = 503;
    const E_TIMESTAMP_EXPIRED: u64 = 504;

    const E_TOKEN_IMPORT_NOT_EXIST:u64 = 505;
    const E_NOT_OWNER_TOKEN:u64 =   506;
    const E_ASSET_NOT_WHILE_LIST: u64 = 507;

    const E_ASSET_TYPE_NOT_EXSIST:u64 =508;
    const E_TOKEN_AMOUNT_NOT_ENOUGHT: u64 =509;
    const E_ASSET_NOT_IMPORT:u64 =510;
    const E_ASSET_NOT_FOUND: u64 =511;

    const EXPIRED_TIME: u64 = 120; // 2 minutes


    struct AssetId has key,copy,store,drop {
        //asset type id
        type_id: u64,
        name: String,
        /// The version of the property map; when a fungible token v1 is mutated, a new property version is created and assigned to the token to make it an NFT
        property_version: u64,
        //store address of token v2
        object_id: Option<address>
    }
    struct AssetVault has key,store {
        //token id ->  using for module such as avatar,game
        tracking: SimpleMap<AssetId,u64>,
        //from asset type->count
        quantity: SimpleMap<u64,u64>,
        //addr
        resource_addr: address,
        //hold asset
        resource_cap: account::SignerCapability
    }
    struct MessageAsset has copy, drop {
        func: vector<u8>,
        owner: address,
        asset_addr:address,
        is_import: bool,
        ts: u64
    }

    #[event]
    struct AssetEvent has drop,store {
        owner: address,
        asset: AssetId,
        use_for: u64,
        is_import:bool
    }

    fun initialize_player_vault(player: &signer) {
        let v = to_bytes(&@eragon);
        let (resource_acc, resource_cap) = account::create_resource_account(player, v);
        move_to(
            player,
            AssetVault {
                tracking: simple_map::new(),
                quantity: simple_map::new(),
                resource_addr: signer::address_of(&resource_acc),
                resource_cap
            }
        )
    }
     // case asset require whilelist before import
    public entry fun import_token_v1(
        player: signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        amount: u64,
        use_for: u64
    ) acquires AssetVault {
        let token_id = tokenv1::create_token_id_raw(creator, collection_name, token_name, property_version);
        let asset_id = create_asset_id(creator,collection_name,token_name,property_version,option::none());

        assert!(asset_id.type_id>0, error::permission_denied(E_ASSET_NOT_WHILE_LIST));

        import_v1(&player,asset_id,token_id,amount,use_for);
    }
    // case asset require whilelist before import
    public entry fun import_token_v2<T: key>(player: &signer,token: Object<T>,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(object::owner(token) == player_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let asset_id = get_asset_id(token);
        //require while list
        assert!(asset_id.type_id>0, error::permission_denied(E_ASSET_NOT_WHILE_LIST));
        //transfer ownership
        import_v2<T>(player,token,use_for); 

        if(use_for == SET_ASSET_FOR_AVATAR) {
            eragon_avatar::set_asset(player,asset_id.type_id);
        };       
    }
    // case token has been whilelist by backend
    public entry fun import_sig_token_v2<T: key>(player: &signer,token: Object<T>,use_for: u64,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {
        
        let  player_addr = signer::address_of(player);
        
        assert!(object::owner(token) == player_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let token_addr = object::object_address(&token);

        verify_signature(b"import_sig_token_v2",player_addr,token_addr,true,ts,rec_id,signature);

        //first check token has been exist in asset type
        let creator  = tokenv2::creator(token);
        let collection_name = tokenv2::collection_name(token);
        //add asset type for mgmt later
        let asset_type_id=eragon_asset_type::upsert_asset_type(creator,collection_name);
        
        //transfer ownership
        import_v2<T>(player,token,use_for); 
        // use for avatar
        if(use_for == SET_ASSET_FOR_AVATAR) {
            let asset_id = get_asset_id(token);
            eragon_avatar::set_asset(player,asset_id.type_id);
        };         
    }
    public entry fun set_asset_v2_with<T: key>(player: &signer,token: Object<T>,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(exists<AssetVault>(player_addr),error::invalid_state(E_ASSET_NOT_IMPORT));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let asset_id = get_asset_id(token);
        
        let found = simple_map::contains_key<AssetId,u64>(&assetVault.tracking, &asset_id);

        assert!(found,error::invalid_state(E_ASSET_NOT_FOUND));

        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);

        if(use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::set_asset(player,asset_id.type_id);
        }
    }
    public entry fun unset_asset_v2_with<T: key>(player: &signer,token: Object<T>) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(exists<AssetVault>(player_addr),error::invalid_state(E_ASSET_NOT_IMPORT));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let asset_id = get_asset_id(token);
        
        let found = simple_map::contains_key<AssetId,u64>(&assetVault.tracking, &asset_id);

        assert!(found,error::invalid_state(E_ASSET_NOT_FOUND));

        let use_for = simple_map::borrow_mut<AssetId,u64>(&mut assetVault.tracking, &asset_id);

        if(*use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::unset_asset(player,asset_id.type_id);
        };
        *use_for = 0;
    }
    fun import_v2<T: key>(player: &signer,token:Object<T>,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);

        if (!exists<AssetVault>(player_addr)) {
            initialize_player_vault(player)
        };

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let recipient = assetVault.resource_addr;
        //transfer
        object::transfer(player, token, recipient);
        let asset_id = get_asset_id(token);
        //add tracking
        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);
        //update quantity 
        let quantity = &mut assetVault.quantity;
        let amount= update_quantity(quantity,asset_id.type_id,false);

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                is_import: true
            }
        );
    }
    public fun import_v1(player:  &signer,asset_id: AssetId,token_id: TokenId,amount: u64,use_for: u64) acquires AssetVault {
        let  player_addr = signer::address_of(player);
        
        let token = tokenv1::withdraw_token(player, token_id, amount);

        if (!exists<AssetVault>(player_addr)) {
            initialize_player_vault(player)
        };
        let assetVault = borrow_global_mut<AssetVault>(player_addr);
        let resource_signer = account::create_signer_with_capability(&assetVault.resource_cap);
        tokenv1::deposit_token(&resource_signer,token);
        //kep track
        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);

        let quantity = &mut assetVault.quantity;
        let amount= update_quantity(quantity,asset_id.type_id,false);

        if(use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::set_asset(player,asset_id.type_id);
        };
        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                is_import: true
            }
        );
    }

    public entry fun claim_token_v1(
        player: signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
    ) acquires AssetVault {
        let token_id = tokenv1::create_token_id_raw(creator, collection_name, token_name, property_version);
        let asset_id = create_asset_id(creator,collection_name,token_name,property_version,option::none());
        claim_v1(&player,asset_id, token_id);
    }
    public entry fun claim_token_v2<T: key>(player: &signer,token: Object<T>) acquires AssetVault {
        claim_v2<T>(player,token);
    }
    public entry fun claim_sig_token_v2<T: key>(player: &signer,token: Object<T>,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {
        
        let  player_addr = signer::address_of(player);
        let token_addr = object::object_address(&token);

        verify_signature(b"claim_sig_token_v2",player_addr,token_addr,false,ts,rec_id,signature);

        claim_v2<T>(player,token);
    }
    public fun claim_v1(player: &signer,asset_id: AssetId, token_id: TokenId) acquires AssetVault {
        let player_addr =signer::address_of(player);
        assert!(exists<AssetVault>(player_addr), error::invalid_state(E_TOKEN_IMPORT_NOT_EXIST));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);
        let tracking = &mut assetVault.tracking;

        let amount = tokenv1::balance_of(assetVault.resource_addr,token_id);

        assert!(amount>0,error::invalid_state(E_TOKEN_AMOUNT_NOT_ENOUGHT));

        let resource_signer = account::create_signer_with_capability(&assetVault.resource_cap);

        let tokens = tokenv1::withdraw_token(&resource_signer, token_id,amount);
        tokenv1::deposit_token(player, tokens);

        let quantity = &mut assetVault.quantity;
        let amount= update_quantity(quantity,asset_id.type_id,true);

        let (_,use_for) = simple_map::remove<AssetId,u64>(tracking,&asset_id);
        
        if(amount==0 && use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::unset_asset(player,asset_id.type_id);
        };
        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                is_import: false
            }
        );
    }
    fun claim_v2<T: key>(player: &signer,token: Object<T>) acquires AssetVault {
        
        let player_addr =signer::address_of(player);
        assert!(exists<AssetVault>(player_addr), error::invalid_state(E_TOKEN_IMPORT_NOT_EXIST));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);
        assert!(object::owner(token) == assetVault.resource_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let resource_signer = account::create_signer_with_capability(&assetVault.resource_cap);
        object::transfer(&resource_signer, token, player_addr);
        //remove
        let creator  = tokenv2::creator(token);
        let collection_name = tokenv2::collection_name(token);
        let token_name = tokenv2::name(token);
        let index = tokenv2::index(token);
        let token_addr = object::object_address(&token);
        //alway v2
        let asset_id = create_asset_id(creator, collection_name, token_name, index,option::some<address>(token_addr));
        //remove use asset for
        let(_,use_for) = simple_map::remove<AssetId,u64>(&mut assetVault.tracking, &asset_id);

        let quantity = &mut assetVault.quantity;
        let amount= update_quantity(quantity,asset_id.type_id,true);

        if(amount==0 && use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::unset_asset(player,asset_id.type_id);
        };

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                is_import: false
            }
        );
        
    }
    fun get_asset_id<T: key>(token: Object<T>): AssetId {
        let creator  = tokenv2::creator(token);
        let collection_name = tokenv2::collection_name(token);
        let token_name = tokenv2::name(token);
        let index = tokenv2::index(token);
        let token_addr = object::object_address(&token);
        //alway v2
        let asset_id = create_asset_id(creator, collection_name, token_name, index,option::some<address>(token_addr));
        asset_id
    }
    fun update_quantity(quantity: &mut SimpleMap<u64,u64>, type_id: u64,decreate:bool): u64 {
        let final =0;
        if(decreate){
            let amount = simple_map::borrow_mut<u64,u64>(quantity,&type_id);
            if(*amount>0){
                *amount =*amount - 1;
            };
            final=*amount;
        } else {
            let found = simple_map::contains_key<u64,u64>(quantity,&type_id);
            if(found){
                let amount = simple_map::borrow_mut<u64,u64>(quantity,&type_id);
                *amount =*amount +1;
                final = *amount;
            } else {
                final =1;
                simple_map::upsert<u64,u64>(quantity, type_id, final);
            };
        };
        final
    }

    fun verify_signature(
        func: vector<u8>,
        owner_addr: address,
        asset_addr: address,
        is_import: bool,
        ts: u64,
        rec_id: u8,
        signature: vector<u8>
    ) {
        let now = timestamp::now_seconds();
        assert!(now >= ts && now - ts <= EXPIRED_TIME, error::invalid_argument(E_TIMESTAMP_EXPIRED));
        let message: MessageAsset = MessageAsset {
            func: func,
            owner: owner_addr,
            asset_addr,
            is_import,
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
    public fun get_import_asset(player_addr: address): (vector<AssetId>,vector<u64>) acquires AssetVault {
        let assetIds:vector<AssetId> = vector::empty();
        let amounts : vector<u64> = vector::empty();
        if(exists<AssetVault>(player_addr)){
            let assetVault = borrow_global<AssetVault>(player_addr);
            let tracking = assetVault.tracking;
            let holderAddr = assetVault.resource_addr;
            (assetIds,_) = simple_map::to_vec_pair<AssetId,u64>(tracking);
            let index = 0;
            let len = vector::length<AssetId>(&assetIds);
            while (index < len) {
                let aId = vector::borrow<AssetId>(&assetIds, index);
                let amount =1;
                //token v1
                if(option::is_none<address>(&aId.object_id)){
                    let (creator,collection) = eragon_asset_type::find_by_asset_type(aId.type_id);
                    let token_id=tokenv1::create_token_id_raw(creator, collection, aId.name, aId.property_version);
                    amount = tokenv1::balance_of(holderAddr,token_id);
                };
                vector::push_back<u64>(&mut amounts,amount);
                index = index + 1;
            };
        };
        (assetIds,amounts)
    }
    #[view] 
    public fun get_player_holder_asset(player_addr:address): address acquires AssetVault {
        let addr =@0x0;
        if(exists<AssetVault>(player_addr)){
            addr = borrow_global<AssetVault>(player_addr).resource_addr;
        };
        addr
    }
    #[view]
    public fun create_asset_id(creator: address,collection: String, name: String,property_version:u64,object_id: Option<address>): AssetId {
        let type_id = eragon_asset_type::get_asset_type(creator,collection);
        AssetId {
            type_id,
            name,
            property_version,
            object_id
        }
    }
    #[test(creator = @0x1, owner = @0x2,owner2 =@0x3)]
    public fun test_nft(creator: signer, owner: signer, owner2:signer) acquires AssetVault {
        let (token_data_id, token_id,token_data_id2,token_id2) = create_token(&creator, 1);
        let creator_addr = signer::address_of(&creator);
        let creator_bal = tokenv1::balance_of(creator_addr,token_id);
        std::debug::print(&utf8(b"-----Balance of creator -----"));
        std::debug::print(&creator_bal);
        
        let owner_addr = signer::address_of(&owner);
        aptos_framework::account::create_account_for_test(owner_addr);
        //transfer
        tokenv1::direct_transfer(&creator, &owner, token_id, 1);
        //token id 2
        tokenv1::direct_transfer(&creator, &owner, token_id2, 1);
        //---
        creator_bal = tokenv1::balance_of(creator_addr,token_id);
        std::debug::print(&utf8(b"-----Balance of creator after transfer -----"));
        std::debug::print(&creator_bal);
        //--
        let owner_bal = tokenv1::balance_of(owner_addr,token_id);
        std::debug::print(&utf8(b"-----Balance of owner -----"));
        std::debug::print(&owner_bal);
        //
        import_v1(&owner, token_id, 1,2);
        import_v1(&owner, token_id2, 1,2);
        let (tokenIds,amounts) = get_import_asset(owner_addr);
        std::debug::print(&utf8(b"-----Owner import asset list -----"));
        std::debug::print(&tokenIds);
        std::debug::print(&amounts);
        //
        owner_bal = tokenv1::balance_of(owner_addr,token_id);
        std::debug::print(&utf8(b"-----Balance of owner after import -----"));
        std::debug::print(&owner_bal);
        //
        claim_v1(&owner, token_id);
        owner_bal = tokenv1::balance_of(owner_addr,token_id);
        std::debug::print(&utf8(b"-----Balance of owner after claim -----"));
        std::debug::print(&owner_bal);

        create_token_v2(&creator,&owner,&owner2);
        
    }
    #[test_only]
    public fun create_token_v2(creator: &signer, owner1: &signer,owner2: &signer) acquires AssetVault {
        use std::string::{Self, String};

        let collection_name = string::utf8(b"Collectio name:Thongvv");
        let collection_mutation_setting = vector<bool>[false, false, false];
        
        let creator_address = signer::address_of(creator);
        aptos_framework::account::create_account_for_test(creator_address);
        //---------------token v2
        //create collection
       // collection::create_fixed_collection(creator, string::utf8(b""), 1, collection_name, option::none(), string::utf8(b""));
        // re check
        //let collection_address = collection::create_collection_address(&creator_address, &collection_name);
        //let collectionObj = object::address_to_object<Collection>(collection_address);
        //let foundv2 = collection::creator(collectionObj);
        //std::debug::print(&utf8(b"-----Check collection V2 by  creator addr and collection name ? -----"));
        //std::debug::print(&foundv2);
        //now create aptos collection
        let flag =true;
        aptos_token::create_collection_object(
            creator,
            string::utf8(b"collection description"),
            100, // max supply
            collection_name,
            string::utf8(b"collection uri"),
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            1,
            100,
        );
        //mint token
        let token_name = string::utf8(b"Token v2 name");
        let token = aptos_token::mint_token_object(
            creator,
            collection_name,
            string::utf8(b"description"),
            token_name,
            string::utf8(b"uri"),
            vector[string::utf8(b"bool")],
            vector[string::utf8(b"bool")],
            vector[vector[0x01]],
        );
        let token_addr = object::object_address(&token);
        std::debug::print(&utf8(b"-----Before--Addr of token -----"));
        std::debug::print(&token_addr);

        assert!(object::owner(token) == signer::address_of(creator), 1);
        let ownerAddr1 = signer::address_of(owner1);
        //transfer
        object::transfer(creator, token, ownerAddr1);

        token_addr = object::object_address(&token);
        std::debug::print(&utf8(b"-----After---Addr of token -----"));
        std::debug::print(&token_addr);

        let currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----Current owner of token -----"));
        std::debug::print(&currentOwner);

        //import
        import_token_v2(owner1,token,1);
        currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----After import: owner of token -----"));
        std::debug::print(&currentOwner);
        let addr = get_player_holder_asset(ownerAddr1);
        std::debug::print(&utf8(b"-----Hold(RA): -----"));
        std::debug::print(&addr);
        //export
        claim_token_v2(owner1,token);
        currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----After export: owner of token -----"));
        std::debug::print(&currentOwner);
        //let tokenAddr = tokenv2::create_token_address(&creator_address,&collection_name,&token_name);
        

        //let constructor_ref = object::create_object(creator_address);
        //let obj= object::object_from_constructor_ref(&constructor_ref);
        //let addr=object::object_address(&obj);
        // aptos_token_addr = object::address_from_constructor_ref(&constructor_ref);

        //std::debug::print(&utf8(b"-----Generate addr of token -----"));
        //std::debug::print(&addr);
        
    }
    #[test_only]
    public fun create_token(creator: &signer, amount: u64): (TokenDataId,TokenId,TokenDataId,TokenId) {
        use std::string::{Self, String};

        let collection_name = string::utf8(b"Collectio name:Thongvv");
        let collection_mutation_setting = vector<bool>[false, false, false];
        
        let creator_address = signer::address_of(creator);
        aptos_framework::account::create_account_for_test(creator_address);
        
        tokenv1::create_collection(
            creator,
            collection_name,
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"https://aptos.dev"),
            2, // max nft in collection
            collection_mutation_setting,
        );
        //check exit
        let foundv1 = tokenv1::check_collection_exists(creator_address,collection_name);
        std::debug::print(&utf8(b"-----Check collection V1 by  creator addr and collection name ? -----"));
        std::debug::print(&foundv1);
        //
        let token_mutation_setting = vector<bool>[false, false, false, false, true];
        let default_keys = vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")];
        let default_vals = vector<vector<u8>>[b"10", b"5"];
        let default_types = vector<String>[string::utf8(b"integer"), string::utf8(b"integer")];
        tokenv1::create_token_script(
            creator,
            collection_name,
            string::utf8(b"Token Name:Token 1"), //token name
            string::utf8(b"Hello, Token"), //description
            amount, //  balance
            amount, // max allow( 1 -> nft)
            string::utf8(b"https://aptos.dev"),
            signer::address_of(creator),
            100,
            0,
            token_mutation_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let tokenId1=tokenv1::create_token_id_raw(
            signer::address_of(creator),
            collection_name,
            string::utf8(b"Token Name:Token 1"),
            0
        );
        let token_data_id1 = tokenv1::create_token_data_id(signer::address_of(creator),collection_name,string::utf8(b"Token Name:Token 1"));
        tokenv1::create_token_script(
            creator,
            collection_name,
            string::utf8(b"Token Name:Token 2"),
            string::utf8(b"Hello, Token"),
            amount,
            amount,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(creator),
            100,
            0,
            token_mutation_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let token_data_id2 = tokenv1::create_token_data_id(signer::address_of(creator),collection_name,string::utf8(b"Token Name:Token 2"));
        let tokenId2=tokenv1::create_token_id_raw(
            signer::address_of(creator),
            collection_name,
            string::utf8(b"Token Name:Token 2"),
            0
        );
        (token_data_id1, tokenId1,token_data_id2,tokenId2)
    }
}