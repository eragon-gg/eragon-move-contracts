module eragon::eragon_toss {
    use std::signer;

    struct EragonTossUp has key, store {
        total: u64
    }

    public entry fun toss_up(player: &signer) acquires EragonTossUp {
        let player_addr = signer::address_of(player);
        if (exists<EragonTossUp>(player_addr)) {
            let resource = borrow_global_mut<EragonTossUp>(player_addr);
            resource.total = resource.total + 1
        } else {
            move_to(player, EragonTossUp { total: 1 })
        };

        if (exists<EragonTossUp>(@eragon)) {
            let resource = borrow_global_mut<EragonTossUp>(@eragon);
            resource.total = resource.total + 1
        };
    }

    public entry fun create_resource(player: &signer) {
        let player_addr = signer::address_of(player);
        if (!exists<EragonTossUp>(player_addr)) {
            move_to(player, EragonTossUp { total: 0 });
        };
    }

    #[view]
    public fun get_toss_count(player_addr: address): u64 acquires EragonTossUp {
        if (exists<EragonTossUp>(player_addr)) {
            let resource = borrow_global<EragonTossUp>(player_addr);
            resource.total
        } else { 0 }
    }
}
