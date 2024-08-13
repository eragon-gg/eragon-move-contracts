module eragon::eragon_boost {
    use std::signer;
    use std::error;
    use std::simple_map::{Self, SimpleMap};
    use std::timestamp;

    use eragon::eragon_manager;

    const E_NOT_AUTHORIZED: u64 = 100;

    struct BlockCounter has key, store, copy, drop {
        block_number: u64,
        players: SimpleMap<address, u64>
    }

    struct EragonBoost has key, store {
        blocks: SimpleMap<u64, BlockCounter>
    }

    const BLOCK_TIME: u64 = 15;
    const HISTORY_LONG: u64 = 3600; // 1 hours

    fun init_module(deployer: &signer) {
        move_to(deployer, EragonBoost { blocks: simple_map::new() });
    }

    public entry fun toss_up(player: &signer) acquires EragonBoost {
        let player_addr = signer::address_of(player);

        let resource = borrow_global_mut<EragonBoost>(@eragon);
        let block_number = timestamp::now_seconds() / BLOCK_TIME;

        if (simple_map::contains_key<u64, BlockCounter>(&resource.blocks, &block_number)) {
            let block_counter = simple_map::borrow_mut(&mut resource.blocks, &block_number);
            if (simple_map::contains_key<address, u64>(&block_counter.players, &player_addr)) {
                let player_counter = simple_map::borrow_mut(&mut block_counter.players, &player_addr);
                *player_counter = *player_counter + 1;
            } else {
                simple_map::add<address, u64>(&mut block_counter.players, player_addr, 1);
            };

        } else {
            let block_counter = BlockCounter { block_number, players: simple_map::new() };

            simple_map::add<address, u64>(&mut block_counter.players, player_addr, 1);

            simple_map::add<u64, BlockCounter>(&mut resource.blocks, block_number,
                block_counter);
        }
    }

    public entry fun clean(admin: &signer) acquires EragonBoost {
        assert!(eragon_manager::is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        let resource = borrow_global_mut<EragonBoost>(@eragon);

        resource.blocks = simple_map::new();

    }

    #[view]
    public fun get_block_counter(block_number: u64): BlockCounter acquires EragonBoost {
        let resource = borrow_global_mut<EragonBoost>(@eragon);

         if (simple_map::contains_key<u64, BlockCounter>(&resource.blocks, &block_number)) {
            *simple_map::borrow(&resource.blocks, &block_number)
         } else {
            BlockCounter { block_number, players: simple_map::new() }
         }
    }
}
