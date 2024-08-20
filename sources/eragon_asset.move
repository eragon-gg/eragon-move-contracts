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
    use aptos_framework::object::{Self,Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_token_objects::token::{Self as tokenv2};
    use aptos_token_objects::collection::{Self,Collection};
    //use aptos_token::token:: {Self as tokenv1, TokenId};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset};
    use aptos_std::secp256k1::{ecdsa_recover, ecdsa_signature_from_bytes, ecdsa_raw_public_key_from_64_bytes};

    use eragon::eragon_asset_type::{Self};
    use eragon::eragon_avatar;
    use eragon::eragon_manager;

    const PROFILE_WEIGHT :u8=1;
    const EQUIMENT_WEIGHT :u8=2;

    const TOKEN_V1 : u64=1;
    const TOKEN_V2: u64 =2;
    
    const SET_ASSET_FOR_NONCE: u64 =0;
    const SET_ASSET_FOR_AVATAR: u64 =2;

    const NFT_IMPORT: u64 =1;
    const NFT_EXPORT: u64 =2;
    const SET_NFT_ASSET: u64 =3;
    const UNSET_NFT_ASSET: u64 =4;
    const FA_IMPORT: u64 =5;
    const FA_EXPORT: u64 =6;
    

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
    const E_FA_IMPORT_NOT_EXIST :u64 =512;
    const E_FA_IMPORT_NOT_ENOUGHT:u64 =513;
    const E_FA_BALANCE_NOT_ENOUGHT: u64 =514;
    const E_RA_BALANCE_NOT_ENOUGHT:u64 =515;
    const EXPIRED_TIME: u64 = 120; // 2 minutes


    struct AssetId has key,copy,store,drop {
        //asset type id
        type_id: u64,
        //store address of token nft or fungible
        object_id: address
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
        sig_type: u64,
        ts: u64
    }

    #[event]
    struct AssetEvent has drop,store {
        owner: address,
        asset: AssetId,
        use_for: u64,
        event_type:u64
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
    public entry fun import_digital_asset<T: key>(player: &signer,token: Object<T>,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(object::owner(token) == player_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let asset_id = get_nft_asset_id(token);
        //require while list
        assert!(asset_id.type_id>0, error::permission_denied(E_ASSET_NOT_WHILE_LIST));
        //transfer ownership
        import_nft<T>(player,token,use_for); 

        let token_addr = object::object_address(&token);

        if(use_for == SET_ASSET_FOR_AVATAR) {
            eragon_avatar::set_asset(player,asset_id.type_id,token_addr);
        };       
    }
    // case token has been whilelist by backend token: 0x4::token::Token 
    public entry fun import_digital_asset_sig<T: key>(player: &signer,token: Object<T>,use_for: u64,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {
        
        let  player_addr = signer::address_of(player);
        
        assert!(object::owner(token) == player_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let token_addr = object::object_address(&token);

        verify_signature(b"import_digital_asset_sig",player_addr,token_addr,NFT_IMPORT,ts,rec_id,signature);
        
        let collectionObj = tokenv2::collection_object(token);
        //add to asset type
        let asset_type_id = eragon_asset_type::upsert_collection_by_id<Collection>(collectionObj);
        
        //transfer ownership
        import_nft<T>(player,token,use_for); 
        // use for avatar
        if(use_for == SET_ASSET_FOR_AVATAR) {
            eragon_avatar::set_asset(player,asset_type_id,token_addr);
        };         
    }
    //import fungible token T : 0x1::fungible_asset::Metadata
    public entry fun import_fungible_asset_dispatch<T: key>(player: &signer,metadata: Object<T>,amount:u64,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);

        let balance = primary_fungible_store::balance(player_addr, metadata);

        assert!(balance >= amount,error::invalid_argument(E_FA_BALANCE_NOT_ENOUGHT));

        let asset_id = get_fungible_asset_id(metadata);
        //require while list
        assert!(asset_id.type_id>0, error::permission_denied(E_ASSET_NOT_WHILE_LIST));
        
        //transfer ownership
        import_fa_dispatch(player,metadata,amount,use_for);

        let token_addr = object::object_address(&metadata);
        // use for avatar
        if(use_for == SET_ASSET_FOR_AVATAR) {
            eragon_avatar::set_asset(player,asset_id.type_id,token_addr);
        }; 
    }
    // imported then set use with avatar
    public entry fun set_digital_asset_with<T: key>(player: &signer,token: Object<T>,use_for: u64,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(exists<AssetVault>(player_addr),error::invalid_state(E_ASSET_NOT_IMPORT));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let asset_id = get_nft_asset_id(token);
        
        let found = simple_map::contains_key<AssetId,u64>(&assetVault.tracking, &asset_id);

        assert!(found,error::invalid_state(E_ASSET_NOT_FOUND));

        let token_addr = object::object_address(&token);

        verify_signature(b"set_digital_asset_with",player_addr,token_addr,SET_NFT_ASSET,ts,rec_id,signature);

        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);

        
        if(use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::set_asset(player,asset_id.type_id,token_addr);
        }
    }
    public entry fun unset_digital_asset_with<T: key>(player: &signer,token: Object<T>,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {

        let  player_addr = signer::address_of(player);
        assert!(exists<AssetVault>(player_addr),error::invalid_state(E_ASSET_NOT_IMPORT));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let asset_id = get_nft_asset_id(token);
        
        let found = simple_map::contains_key<AssetId,u64>(&assetVault.tracking, &asset_id);

        assert!(found,error::invalid_state(E_ASSET_NOT_FOUND));

        let token_addr = object::object_address(&token);

        verify_signature(b"unset_digital_asset_with",player_addr,token_addr,UNSET_NFT_ASSET,ts,rec_id,signature);

        let use_for = simple_map::borrow_mut<AssetId,u64>(&mut assetVault.tracking, &asset_id);

        if(*use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::unset_asset(player,asset_id.type_id,token_addr);
        };
        *use_for = 0;
    }
    public entry fun claim_digital_asset<T: key>(player: &signer,token: Object<T>) acquires AssetVault {
        claim_nft<T>(player,token);
    }
    public entry fun claim_digital_asset_sig<T: key>(player: &signer,token: Object<T>,ts: u64,rec_id: u8, signature: vector<u8>) acquires AssetVault {
        
        let  player_addr = signer::address_of(player);
        let token_addr = object::object_address(&token);

        verify_signature(b"claim_digital_asset_sig",player_addr,token_addr,NFT_EXPORT,ts,rec_id,signature);

        claim_nft<T>(player,token);
    }
    public entry fun claim_fungible_asset_dispatch<T: key>(player: &signer,metadata: Object<T>,amount: u64) acquires AssetVault {
        claim_fa_dispatch<T>(player,metadata,amount);
    }
    fun import_nft<T: key>(player: &signer,token:Object<T>,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);

        if (!exists<AssetVault>(player_addr)) {
            initialize_player_vault(player)
        };

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let recipient = assetVault.resource_addr;
        //transfer
        object::transfer(player, token, recipient);
        let asset_id = get_nft_asset_id(token);
        //add tracking
        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);
        //update quantity 
        let quantity = &mut assetVault.quantity;
        update_quantity(quantity,asset_id.type_id,1,false);

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                event_type: NFT_IMPORT
            }
        );
    }
    fun import_fa_dispatch<T: key>(player: &signer,metadata: Object<T>,amount: u64,use_for: u64) acquires AssetVault {

        let  player_addr = signer::address_of(player);

        if (!exists<AssetVault>(player_addr)) {
            initialize_player_vault(player)
        };

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let receiver_address = assetVault.resource_addr;
        
        // transfer from player to RA addr
        let player_store = primary_fungible_store::ensure_primary_store_exists(player_addr, metadata);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(receiver_address, metadata);
        dispatchable_fungible_asset::transfer(player, player_store, receiver_store, amount);

        let asset_id = get_fungible_asset_id(metadata);
        //add tracking
        simple_map::upsert<AssetId,u64>(&mut assetVault.tracking, asset_id, use_for);
        //update quantity 
        let quantity = &mut assetVault.quantity;
        update_quantity(quantity,asset_id.type_id,amount,false);

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                event_type: FA_IMPORT
            }
        );
    }
    fun claim_nft<T: key>(player: &signer,token: Object<T>) acquires AssetVault {
        
        let player_addr =signer::address_of(player);
        assert!(exists<AssetVault>(player_addr), error::invalid_state(E_TOKEN_IMPORT_NOT_EXIST));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);
        assert!(object::owner(token) == assetVault.resource_addr, error::invalid_state(E_NOT_OWNER_TOKEN));

        let resource_signer = account::create_signer_with_capability(&assetVault.resource_cap);
        object::transfer(&resource_signer, token, player_addr);
        //remove
        let token_addr = object::object_address(&token);
        //alway v2
        let asset_id = get_nft_asset_id(token);
        //remove use asset for
        let(_,use_for) = simple_map::remove<AssetId,u64>(&mut assetVault.tracking, &asset_id);

        let quantity = &mut assetVault.quantity;
        update_quantity(quantity,asset_id.type_id,1,true);

        if(use_for == SET_ASSET_FOR_AVATAR){
            eragon_avatar::unset_asset(player,asset_id.type_id,token_addr);
        };

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                event_type: NFT_EXPORT
            }
        );
        
    }
    fun claim_fa_dispatch<T: key>(player: &signer,metadata: Object<T>,amount: u64) acquires AssetVault {
        
        let player_addr =signer::address_of(player);
        assert!(exists<AssetVault>(player_addr), error::invalid_state(E_FA_IMPORT_NOT_EXIST));

        let assetVault = borrow_global_mut<AssetVault>(player_addr);

        let balance = primary_fungible_store::balance(assetVault.resource_addr, metadata);

        assert!(balance>=amount, error::invalid_state(E_RA_BALANCE_NOT_ENOUGHT));

        //get id
        let asset_id = get_fungible_asset_id(metadata);

        let importAmount = simple_map::borrow<u64,u64>(&assetVault.quantity,&asset_id.type_id);
        assert!(*importAmount>=amount, error::invalid_state(E_FA_IMPORT_NOT_ENOUGHT));

        //check player import

        let resource_signer = account::create_signer_with_capability(&assetVault.resource_cap);

        // transfer from RA to player
        let ra_store = primary_fungible_store::ensure_primary_store_exists(assetVault.resource_addr, metadata);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(player_addr, metadata);
        dispatchable_fungible_asset::transfer(&resource_signer, ra_store, receiver_store, amount);

        let quantity = &mut assetVault.quantity;
        let currentAmount = update_quantity(quantity,asset_id.type_id,amount,true);
        
        let use_for: u64 =0;
        if(currentAmount == 0 ){
            //remove
            //remove use asset for if claim all
            (_,use_for) = simple_map::remove<AssetId,u64>(&mut assetVault.tracking, &asset_id);

            let token_addr = object::object_address(&metadata);
            if(use_for == SET_ASSET_FOR_AVATAR){
                eragon_avatar::unset_asset(player,asset_id.type_id,token_addr);
            };
        };

        0x1::event::emit( 
            AssetEvent {
                owner: player_addr,
                asset: asset_id,
                use_for: use_for,
                event_type: FA_EXPORT
            }
        );
    }
    // NFT or Fungible Metatada
    fun get_nft_asset_id<T: key>(token: Object<T>): AssetId {

        let token_addr = object::object_address(&token);
        let collectionObj = tokenv2::collection_object(token);
        let collection_addr = object::object_address(&collectionObj);
        let type_id = eragon_asset_type::get_asset_type(collection_addr);
        AssetId {
            type_id,
            object_id: token_addr
        }
    }
    fun get_fungible_asset_id<T:key>(metadata: Object<T>): AssetId {

        let token_addr = object::object_address(&metadata);
        let type_id = eragon_asset_type::get_asset_type(token_addr);
        AssetId {
            type_id,
            object_id: token_addr
        }
    }
    fun update_quantity(quantity: &mut SimpleMap<u64,u64>, type_id: u64, qtity: u64, decreate:bool): u64 {
        let final:u64;
        if(decreate){
            let amount = simple_map::borrow_mut<u64,u64>(quantity,&type_id);
            assert!( *amount >= qtity , error::invalid_argument(E_FA_IMPORT_NOT_ENOUGHT));
            *amount =*amount - qtity;
            final=*amount;
        } else {
            let found = simple_map::contains_key<u64,u64>(quantity,&type_id);
            if(found){
                let amount = simple_map::borrow_mut<u64,u64>(quantity,&type_id);
                *amount =*amount +qtity;
                final = *amount;
            } else {
                final =qtity;
                simple_map::upsert<u64,u64>(quantity, type_id, final);
            };
        };
        final
    }

    fun verify_signature(
        func: vector<u8>,
        owner_addr: address,
        asset_addr: address,
        sig_type: u64,
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
            sig_type,
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
    // return
    // first : array asset type id
    // second: amount of each asset type id
    // third : detail asset id
    public fun get_import_asset(player_addr: address): (vector<u64>,vector<u64>,vector<AssetId>) acquires AssetVault {
        let assetIds:vector<AssetId> = vector::empty();
        let typeIds : vector<u64> = vector::empty();
        let amounts : vector<u64> = vector::empty();
        if(exists<AssetVault>(player_addr)){
            let assetVault = borrow_global<AssetVault>(player_addr);
            (assetIds,_) = simple_map::to_vec_pair<AssetId,u64>(assetVault.tracking);
            (typeIds,amounts) = simple_map::to_vec_pair<u64,u64>(assetVault.quantity);
        };
        (typeIds,amounts,assetIds)
    }
    #[view] 
    public fun get_player_holder_asset(player_addr:address): address acquires AssetVault {
        let addr =@0x0;
        if(exists<AssetVault>(player_addr)){
            addr = borrow_global<AssetVault>(player_addr).resource_addr;
        };
        addr
    }
    #[test_only]
    use eragon::eragon_coin::{Self};

    #[test_only]
    fun mint_fungible(creator: &signer, owner_address: address,owner_address1: address,amount:u64){
        eragon_coin::initial_test(creator);
        let creator_address = signer::address_of(creator);
    
        //mint
        let max=10000;
        eragon_coin::mint(creator, creator_address, max);

        //get metadata
        let asset = eragon_coin::get_metadata();

        assert!(primary_fungible_store::balance(creator_address, asset) == max, 4);
        //transfer
        eragon_coin::transfer(creator, creator_address, owner_address, amount);
        assert!(primary_fungible_store::balance(owner_address, asset) == amount, 6);
        eragon_coin::transfer(creator, creator_address, owner_address1, amount);

    }
   #[test(admin=@eragon,creator = @0x2, owner1 = @0x3,owner2 =@0x4)]
    public fun test_import_claim(admin: &signer,creator: &signer, owner1: &signer,owner2: &signer) acquires AssetVault {
        use std::string::{Self, String};
        use aptos_token_objects::aptos_token::{Self};

        eragon_asset_type::initial_test(admin);

        let collection_name = string::utf8(b"Collectio name:Thongvv");
        let collection_mutation_setting = vector<bool>[false, false, false];
        
        let creator_address = signer::address_of(creator);
        aptos_framework::account::create_account_for_test(creator_address);
        //---------------token v2

        let flag =true;
        let collectionObj = aptos_token::create_collection_object(
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
        //add to whilelist
        //eragon_asset_type::upsert_collection_by_id(collectionObj);
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
        
        let ownerAddr1 = signer::address_of(owner1);
        let ownerAddr2 = signer::address_of(owner2);
        //transfer
        object::transfer(creator, token, ownerAddr1);

        token_addr = object::object_address(&token);
        
        let currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----Current owner of token -----"));
        std::debug::print(&currentOwner);

        //import
        //import_digital_asset(owner1,token,1);
        import_digital_asset_sig(owner1,token,SET_ASSET_FOR_AVATAR,0,0,vector::empty());
        currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----After import: owner of token -----"));
        std::debug::print(&currentOwner);
        
        //export
        //claim_digital_asset(owner1,token);
        

        currentOwner = object::owner(token);
        std::debug::print(&utf8(b"-----After export: owner of token -----"));
        std::debug::print(&currentOwner);
        

        //fungible token
        //get metadata
        mint_fungible(admin,ownerAddr1,ownerAddr2,15);

        let asset = eragon_coin::get_metadata();

        let owner1Balance = primary_fungible_store::balance(ownerAddr1, asset);
        std::debug::print(&utf8(b"-----Fungible asset: balance -----"));
        std::debug::print(&owner1Balance);

        //import
        import_fungible_asset_dispatch(owner1,asset,10,SET_ASSET_FOR_AVATAR);
        import_fungible_asset_dispatch(owner2,asset,10,SET_ASSET_FOR_AVATAR);

        owner1Balance = primary_fungible_store::balance(ownerAddr1, asset);
        std::debug::print(&utf8(b"-----Fungible asset: balance after import -----"));
        std::debug::print(&owner1Balance);
        //export
        claim_fa_dispatch(owner1,asset,10);

        owner1Balance = primary_fungible_store::balance(ownerAddr1, asset);
        std::debug::print(&utf8(b"-----Fungible asset: balance after claim -----"));
        std::debug::print(&owner1Balance);


        // transfer from minter to receiver, check balance
        //let minter_store = primary_fungible_store::ensure_primary_store_exists(minter_address, asset);
    

        //let receiver_store = primary_fungible_store::ensure_primary_store_exists(receiver_address, asset);
        //dispatchable_fungible_asset::transfer(minter, minter_store, receiver_store, 10);
        
    }
}