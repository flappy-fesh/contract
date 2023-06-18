module fesh_item::admin {

    // another token
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self,Balance};
    use sui::tx_context::{Self, TxContext};
    use std::type_name::{Self, TypeName};
    use sui::transfer;
    use std::vector;
    // error
    const EAdminOnly:u64 = 0;
    const EPayTokenInvalid:u64 = 2001;


    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        pools: vector<ID>,
    }

    struct Pool<phantom C>  has key {
        id: UID,
        admin: ID,
        coin_type: TypeName,
        coin: Coin<C>,
        total: u64,
    }

    fun init(ctx:&mut TxContext) {
        let sender = tx_context::sender(ctx);
        let enable_addresses = vector::empty();
        vector::push_back(&mut enable_addresses, sender);

        let admin = Admin{
            id: object::new(ctx),
            addresses: enable_addresses,
            pools: vector::empty(),
        };

        transfer::share_object(admin);
    }


    /***
    * @dev add_pool
    * @param admin is admin id
    */
    public entry fun make_add_pool<C>(admin: &mut Admin, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        // new pool
        let pool = Pool<C> {
            id: object::new(ctx),
            admin: object::id(admin),
            coin: coin::from_balance(balance::zero<C>(), ctx),
            coin_type: type_name::get<C>(),
            total: 0,
        };

        // push id to list
        vector::push_back(&mut admin.pools, object::id(&pool));
        // share
        transfer::share_object(pool);
    }


    /***
    * @dev withdraw
    * @param admin is admin id
    * @param pool is pool id
    * @param receive_address is who receive coin
    */
    public entry fun make_withdraw<C>(admin: &mut Admin, pool: &mut Pool<C>, receive_address: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);

        let money:Balance<C> = balance::split(coin::balance_mut(&mut pool.coin), pool.total);
        transfer::public_transfer(coin::from_balance(money, ctx), receive_address);
        pool.total = 0;
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
        let sender = tx_context::sender(ctx);
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
            let sender = tx_context::sender(ctx);
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
    * @dev pay_with_sui
    * @param admin is admin id
    * @param coin
    * @param amount
    */
    public fun pay<C>(pool: &mut Pool<C>, coin: Coin<C>, amount: u64) {
          coin::join(&mut pool.coin, coin);
          pool.total = pool.total + amount;
    }


}

