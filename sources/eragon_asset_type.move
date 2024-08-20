module eragon::eragon_asset_type {
    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    //use std::string::{Self,utf8,String};
    use std::error;
    //use std::timestamp;
    //use std::vector;
    use aptos_framework::object::{Self,Object};
    use eragon::eragon_manager;
    friend eragon::eragon_asset;


    const NFT_ASSET:u64 = 1;
    const TOKEN_ASSET:u64 =2 ;

    const E_NOT_AUTHORIZED: u64 = 400;
    const E_ASSET_TYPE_NOT_INIT: u64 =500;

    struct AssetType has key,store,copy,drop {
        //from collection id or metata -> type
        types: SimpleMap<address,u64>,
        // from collection id or metata -> category id: 1-> nft,2-> token
        categories: SimpleMap<address,u64>,
        current_id: u64
    }
    fun init_module(deployer: &signer) {
        move_to(
            deployer,
            AssetType {
                types: simple_map::new(),
                categories: simple_map::new(),
                current_id: 10 //generic and reserve for later
            }
        );
    }
    #[test_only]
    public fun initial_test(deployer:&signer){
        move_to(
            deployer,
            AssetType {
                types: simple_map::new(),
                categories: simple_map::new(),
                current_id: 10 //generic and reserve for later
            }
        );
    }
    public entry fun add_asset_by_id<T: key>(operator: &signer,objCollection: Object<T>,category_id:u64) acquires AssetType {
        
        let operatorAddr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operatorAddr), error::permission_denied(E_NOT_AUTHORIZED));
        
        let addr = object::object_address(&objCollection);
        upsert(addr,category_id);
    }
    
    public(friend) fun upsert_collection_by_id<T: key>(objCollection: Object<T>):u64 acquires AssetType {

        let addr = object::object_address(&objCollection);
        upsert(addr,NFT_ASSET)
    }
    public(friend) fun upsert_token_metadata<T: key>(metadata: Object<T>):u64 acquires AssetType {

        let addr = object::object_address(&metadata);
        upsert(addr,TOKEN_ASSET)
    }

    fun upsert(object_id: address,category_id:u64):u64 acquires AssetType{
        //add asset type
        assert!(exists<AssetType>(@eragon), E_ASSET_TYPE_NOT_INIT);

        let asset_type = borrow_global_mut<AssetType>(@eragon);

        let found = simple_map::contains_key<address,u64>(&mut asset_type.types,&object_id);
        if(!found) {
            //
            //incremental
            let current_id = &mut asset_type.current_id;
            *current_id = *current_id + 1;
            simple_map::add<address,u64>(&mut asset_type.types,object_id , *current_id);
            simple_map::add<address,u64>(&mut asset_type.categories,object_id , category_id);
            *current_id
        } else {
            let type_id = simple_map::borrow<address,u64>(&asset_type.types,&object_id);
            *type_id
        }
    }
    
    #[view] 
    public fun get_asset_types(): (vector<address>,vector<u64>) acquires AssetType {

        let asset_type = borrow_global<AssetType>(@eragon);
        let (object_ids,types)= simple_map::to_vec_pair<address,u64>(asset_type.types);
        (object_ids,types)
    }
    #[view] 
    public fun get_asset_type(object_id: address): u64 acquires AssetType {

        let asset_type = borrow_global<AssetType>(@eragon);
        let type_id = 0;
        let found = simple_map::contains_key<address,u64>(&asset_type.types,&object_id);
        if(found){
            type_id= *simple_map::borrow<address,u64>(&asset_type.types,&object_id);
        };
        type_id
    }
}