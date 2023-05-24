module fesh_item::admin {
    // custom token
    use fesh_token::fesh::{Self, FESH};

    // another token
    use sui::sui::SUI;
    use sui::object::{Self,UID};
    use std::type_name::{Self};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self,Balance};
    use std::string::{Self,String,utf8};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::transfer;
    use std::vector;
    // error
    const EAdminOnly:u64 = 0;
    const EPayTokenInvalid:u64 = 2001;


    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        sui_pool: Coin<SUI>,
        total_sui_pool: u64,
        fesh_pool: Coin<FESH>,
        total_fesh_pool: u64,
    }

    fun init(ctx:&mut TxContext) {
        let sender = sender(ctx);
        let enable_addresses = vector::empty();
        vector::push_back(&mut enable_addresses, sender);

        let admin = Admin{
            id: object::new(ctx),
            addresses: enable_addresses,
            sui_pool: coin::from_balance(balance::zero<SUI>(), ctx),
            total_sui_pool: 0,
            fesh_pool: coin::from_balance(balance::zero<FESH>(), ctx),
            total_fesh_pool: 0,
        };

        transfer::share_object(admin);
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

    /***
    * @dev withdraw
    * @param admin is admin id
    * @param receive_address
    */
    public entry fun withdraw(admin: &mut Admin, receive_address: address, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);
        let sui_money:Balance<SUI> = balance::split(coin::balance_mut(&mut admin.sui_pool), admin.total_sui_pool);
        let fesh_money:Balance<FESH> = balance::split(coin::balance_mut(&mut admin.fesh_pool), admin.total_fesh_pool);

        transfer::public_transfer(coin::from_balance(sui_money, ctx), receive_address);
        transfer::public_transfer(coin::from_balance(fesh_money, ctx), receive_address);

        admin.total_sui_pool = 0;
        admin.total_fesh_pool = 0;

    }

    /***
    * @dev pay_with_sui
    * @param admin is admin id
    * @param coin
    * @param amount
    */
    public fun pay_with_sui(admin: &mut Admin, coin: Coin<SUI>, amount: u64) {
          coin::join(&mut admin.sui_pool, coin);
          admin.total_sui_pool = admin.total_sui_pool + amount;
    }

    /***
    * @dev pay_with_fesh
    * @param admin is admin id
    * @param coin
    * @param amount
    */
    public fun pay_with_fesh(admin: &mut Admin, coin: Coin<FESH>, amount: u64) {
          coin::join(&mut admin.fesh_pool, coin);
          admin.total_sui_pool = admin.total_fesh_pool + amount;
    }


}

