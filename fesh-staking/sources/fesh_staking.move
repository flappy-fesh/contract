module fesh_staking::staking {    

    use sui::object::{Self,ID,UID};
    use sui::tx_context::{Self, TxContext,sender};
    use std::vector;
    use sui::transfer;
    use sui::dynamic_object_field as ofield;
    use std::string::{Self,String, utf8};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self,Balance};
    use sui::sui::SUI;
    use std::type_name::{Self};
    // another
    use fesh_token::fesh::{Self, FESH};

    // error
    const EAdminOnly:u64 = 0;

    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        pool: Coin<FESH>,
        total_pool: u64,
    }
    
    struct Status has store, drop {
        id: ID,
        can_deposit: bool
    } 

    struct Container has key { 
        id: UID,
        count: u64
    }

    struct StakeType has store, drop, copy {
      name: String,
      apr: u64,
    } 

    struct StakingContainer has key {
        id: UID,
        enable: bool,
        containers: vector<Status>,
        container_maximum_size: u64,
        stake_types: vector<StakeType>,
    }


    fun init(ctx:&mut TxContext) {
        let sender = sender(ctx);
        let enable_addresses = vector::empty();
        vector::push_back(&mut enable_addresses, sender);
    
        let admin = Admin{
            id: object::new(ctx),
            addresses: enable_addresses,
            pool: coin::from_balance(balance::zero<FESH>(), ctx),
            total_pool: 0,
        };

        let staking_container = StakingContainer{
            id: object::new(ctx),
            enable: false,
            containers: vector::empty(),
            container_maximum_size: 100,
            stake_types: vector::empty(),
        };

        let container = Container{
            id: object::new(ctx),
            count: 0      
        };

        vector::push_back(&mut staking_container.containers, Status{
            id: object::id(&container),
            can_deposit: true
        });


        vector::push_back(&mut staking_container.stake_types, StakeType{
            name: utf8(b"Lock"),
            apr: 135,
        });

        vector::push_back(&mut staking_container.stake_types, StakeType{
            name: utf8(b"flexible"),
            apr: 35,
        });

        transfer::share_object(container);
        transfer::share_object(staking_container);
        transfer::share_object(admin);
    }

    /***
    * @dev change_container_status
    * @param admin is admin id
    * @param container is container id
    * @param status is container status
    */
    public entry fun change_staking_container_status(admin: &mut Admin, container: &mut StakingContainer, status: bool, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);
        container.enable = status;
    }


    /***
    * @dev isAdmin
    * @param admin is admin id
    * @param address
    */
    public fun is_admin(admin: &mut Admin, address : address) : bool {
            let rs = false;
            let list = admin.addresses;

            let length = vector::length(&list);

            let index = 0;

            while(index < length) {
            let current = vector::borrow(&list, index);
            if(*current == address) {
                    rs = true;
                    break
            };
            index = index + 1;
            };
            rs
    }

    /***
    * @dev add_admin
    * @param admin is admin id
    * @param new_addresses
    */
    public entry fun add_admin(admin:&mut Admin, new_addresses: vector<address>, ctx:&mut TxContext){
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        vector::append(&mut admin.addresses, new_addresses);
    }


    /***
    * @dev remove_admin
    * @param admin is admin id
    * @param delete_address
    */
    public entry fun remove_admin(admin:&mut Admin, delete_address: address, ctx:&mut TxContext){
            // check admin
            let sender = sender(ctx);
            assert!(is_admin(admin, sender) == true, EAdminOnly);

            let index = 0;
            let admins = admin.addresses;
            let admins_length = vector::length(&admins);
            let current_index = 0;
            let is_existed = false;
            while(index < admins_length) {
                    if(*vector::borrow(&admins, index) == delete_address) {
                            is_existed = true;
                            current_index = index;
                            break
                    };

                    index = index + 1;
            };

            if(is_existed == true) {
                    vector::remove(&mut admins, current_index);
            };
    }

    public entry fun deposit 


}

