module eragon::eragon_checkin {
    use std::signer;
    use std::vector;
    use std::timestamp;

    struct EragonCheckIn has key, store {
        times: vector<u64>
    }

    public entry fun check_in(player: &signer) acquires EragonCheckIn {
        let player_addr = signer::address_of(player);

        if (!exists<EragonCheckIn>(player_addr)) {
            move_to(player, EragonCheckIn { times: vector::empty() })
        };

        let now = timestamp::now_seconds();
        let resource = borrow_global_mut<EragonCheckIn>(player_addr);
        vector::push_back<u64>(&mut resource.times, now);
    }

    #[view]
    public fun get_player_checkins(player_addr: address): vector<u64> acquires EragonCheckIn {
        if (exists<EragonCheckIn>(player_addr)) {
            let resource = borrow_global<EragonCheckIn>(player_addr);
            resource.times
        } else {
            vector::empty<u64>()
        }
    }
}
