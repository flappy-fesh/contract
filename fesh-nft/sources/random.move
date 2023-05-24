module fesh_nft::random {
        use std::hash;
        use std::vector;
        use sui::object;
        use sui::tx_context::{Self, TxContext};

        struct Random has store, drop, copy {
                state: vector<u8>,
        }

        fun init(_: &mut TxContext) {}

        public fun create_random_object(ctx: &mut TxContext): Random {
            let random_state_uid = object::new(ctx);
            let random = Random {
                    state: object::uid_to_bytes(&random_state_uid),
            };

            object::delete(random_state_uid);
            random
        }
           

        fun next_digest(random: &mut Random): vector<u8> {
                random.state = hash::sha3_256(random.state);
                random.state
        }

        fun next_u256(random: &mut Random): u256 {
                let bytes = next_digest(random);
                let (value, i) = (0u256, 0u8);
                while (i < 32) {
                let byte = (vector::pop_back(&mut bytes) as u256);
                value = value + (byte << 8*i);
                i = i + 1;
                };
                value
        }

        fun next_u256_in_range(random: &mut Random, upper_bound: u256): u256 {
                assert!(upper_bound > 0, 0);
                next_u256(random) % upper_bound
        }

        public fun next_u64(random: &mut Random, upper_bound: u64): u64 {
                assert!(upper_bound > 0, 0);
                (next_u256_in_range(random, 1 << 64) as u64) % upper_bound
        }
        
}
