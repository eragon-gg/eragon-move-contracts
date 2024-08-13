module eragon::random {

    use std::vector;
    use aptos_framework::randomness;

    #[lint::allow_unsafe_randomness]
    public fun random_by_weights(weights: vector<u64>): u64 {
        let total_weights = 0u64;
        vector::for_each<u64>(weights, | value | {
            total_weights = total_weights + value;
        });

        let random_value = randomness::u64_range(1, total_weights + 1);

        let cursor = 0u64;
        let i = 0u64;
        loop {
            cursor = cursor + *vector::borrow<u64>(&weights, i);
            if (cursor >= random_value) break;
            i = i + 1;
        };

        i
    }
}
