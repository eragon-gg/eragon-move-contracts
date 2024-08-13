module eragon::eragon_asset_type {
    use std::simple_map::{Self, SimpleMap};
    use std::signer;
    use std::string::{Self,utf8,String};
    use std::error;
    //use std::timestamp;
    use std::vector;
    
    use eragon::eragon_manager;
    friend eragon::eragon_asset;

    const E_NOT_AUTHORIZED: u64 = 400;
    const E_ASSET_TYPE_NOT_INIT: u64 =500;

    struct CollectionId has key,store,copy,drop {
        creator:address,
        name: String
    }
    struct AssetType has key,store,copy,drop {
        types: SimpleMap<CollectionId,u64>,
        current_id: u64
    }
    fun init_module(deployer: &signer) {
        move_to(
            deployer,
            AssetType {
                types: simple_map::new(),
                current_id: 10 //generic and reserve for later
            }
        );
    }
    public entry fun add_asset_type(operator: &signer,creator: address, collection_name: String) acquires AssetType {
        let operatorAddr = signer::address_of(operator);
        assert!(eragon_manager::is_operator(operatorAddr), error::permission_denied(E_NOT_AUTHORIZED));
        upsert(creator,collection_name);
    }
    
    //add new type asset before token import
    public(friend) fun upsert_asset_type(creator: address, collection_name: String):u64 acquires AssetType {
        upsert(creator,collection_name)
    }

    fun upsert(creator: address, collection_name: String):u64 acquires AssetType{
        //add asset type
        assert!(exists<AssetType>(@eragon), E_ASSET_TYPE_NOT_INIT);

        let collectionId : CollectionId = CollectionId {
            creator: creator,
            name: collection_name
        };
        let asset_type = borrow_global_mut<AssetType>(@eragon);

        let found = simple_map::contains_key<CollectionId,u64>(&mut asset_type.types,&collectionId);
        if(!found) {
            //incremental
            let current_id = &mut asset_type.current_id;
            *current_id = *current_id + 1;
            simple_map::add<CollectionId,u64>(&mut asset_type.types,collectionId , *current_id);
            *current_id
        } else {
            let type_id = simple_map::borrow<CollectionId,u64>(&asset_type.types,&collectionId);
            *type_id
        }
    }
    #[view]
    public fun get_collection_id(creator: address, collection_name: String): CollectionId {
        CollectionId {
            creator,
            name: collection_name
        }
    }
    #[view] 
    public fun get_asset_types(): (vector<CollectionId>,vector<u64>) acquires AssetType {

        let asset_type = borrow_global<AssetType>(@eragon);
        let (collectionId,types)= simple_map::to_vec_pair<CollectionId,u64>(asset_type.types);
        (collectionId,types)
    }
    #[view] 
    public fun get_asset_type(creator: address, collection_name: String): u64 acquires AssetType {

        let asset_type = borrow_global<AssetType>(@eragon);
        let collectionId = get_collection_id(creator,collection_name);
        let type_id = 0;
        let found = simple_map::contains_key<CollectionId,u64>(&asset_type.types,&collectionId);
        if(found){
            type_id= *simple_map::borrow<CollectionId,u64>(&asset_type.types,&collectionId);
        };
        type_id
    }
     #[view] 
    public fun find_by_asset_type(asset_type_id: u64): (address,String) acquires AssetType {
        let asset_types = borrow_global<AssetType>(@eragon);
        let keys = simple_map::keys<CollectionId,u64>(&asset_types.types);
        let (creator,name)=(@0x0,utf8(b""));
        vector::for_each<CollectionId>(keys,|key|{
            let val = simple_map::borrow<CollectionId,u64>(&asset_types.types,&key);
            if(*val==asset_type_id){
                creator = key.creator;
                name = key.name;
            }
        });
        (creator,name)
    }
}