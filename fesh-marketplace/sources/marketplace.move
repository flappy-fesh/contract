module fesh_marketplace::marketplace {
    use sui::object::{Self,ID,UID};
    use sui::tx_context::{Self, TxContext,sender};
    use std::vector;
    use sui::transfer;
    use sui::event;
    use sui::dynamic_object_field as ofield;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self,Balance};
    use std::type_name::{Self, TypeName};
    // kiosk
    use sui::kiosk::{Self, Kiosk};
    use sui::package;
    // constants
    const DEFAULT_MARKETPLACE_FEE:u64 = 2500;
    const MAXIMUM_CONTAINER_SIZE:u64 = 100;
    // error
    const EAdminOnly:u64 = 0;
    const EWrongSeller: u64 = 1001;
    const EMarketplaceNotAvailableNow: u64 = 1002;
    const ENftNotAvailableNow: u64 = 1003;


    
    struct Pool<phantom C>  has key {
        id: UID,
        admin: ID,
        coin_type: TypeName,
        coin: Coin<C>,
        total: u64,
    }

    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        pools: vector<ID>,
    }

    struct Status has store, drop {
        id: ID,
        can_deposit: bool
    }

    struct Marketplace has key {
        id: UID,
        containers : vector<Status>,
        maximum_size: u64,
        fee: u64,
        enable: bool,
        allow_types: vector<TypeName>
    }

    struct Container has key { 
        id: UID,
        count: u64
    }

    struct List has key, store {
        id: UID,
        container_id: ID,
        seller: address,
        nft_id: ID,
        nft_type: TypeName,
        price: u64,
        coin_type: TypeName,
    }

    // kiosk
    struct MARKETPLACE has drop {
	    dummy_field: bool
    }

    fun init(otw: MARKETPLACE,ctx:&mut TxContext) {
        package::claim_and_keep<MARKETPLACE>(otw, ctx);

        let (kiosk, cap) = kiosk::new(ctx);

        let admin_addresses = vector::empty();
        vector::push_back(&mut admin_addresses, sender(ctx));

        let admin = Admin{
            id: object::new(ctx),
            addresses: admin_addresses,
            pools: vector::empty(),
        };

        let container = Container{
            id: object::new(ctx),
            count: 0      
        };

        let marketplace =  Marketplace {
            id: object::new(ctx),
            containers : vector::empty(),
            maximum_size: MAXIMUM_CONTAINER_SIZE,
            fee: DEFAULT_MARKETPLACE_FEE,
            enable: false,
            allow_types: vector::empty()
        };

        //deposit new container in container list 
        vector::push_back(&mut marketplace.containers, Status{
            id: object::id(&container),
            can_deposit: true
        });

        ofield::add(&mut marketplace.id, object::id(&kiosk), cap);

        transfer::share_object(admin);
        transfer::share_object(container);
        transfer::share_object(marketplace);
        transfer::public_share_object(kiosk);
    }

    /***
    * @dev is_admin
    * @param admin is admin id
    * @param address
    */
    fun is_admin(admin: &mut Admin, address: address) : bool {
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
    * @dev is_available_type
    * @param marketplace is marketplace id
    */
    fun is_available_type<T: key + store>(marketplace: &mut Marketplace) : bool {
            let rs = false;
            let list = marketplace.allow_types;
            let length = vector::length(&list);

            let index = 0;

            while(index < length) {
            let current = vector::borrow<TypeName>(&list, index);
            if(*current == type_name::get<T>()) {
                    rs = true;
                    break
            };
            index = index + 1;
            };
            rs
    }

    /***
    * @dev make_add_allow_type
    * @param marketplace is marketplace id
    */
    public entry fun make_add_allow_type<T: key + store>(admin: &mut Admin, marketplace: &mut Marketplace, ctx:&mut TxContext){
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);
        vector::push_back<TypeName>(&mut marketplace.allow_types, type_name::get<T>());
    }


    /***
    * @dev make_remove_allow_type
    * @param marketplace is marketplace id
    */
    public entry fun make_remove_allow_type<T: key + store>(admin: &mut Admin, marketplace:&mut Marketplace, ctx:&mut TxContext){
            // check admin
            let sender = sender(ctx);
            assert!(is_admin(admin, sender) == true, EAdminOnly);

            let index = 0;
            let types = marketplace.allow_types;
            let types_length = vector::length(&types);
            let current_index = 0;
            let is_existed = false;
            while(index < types_length) {
                    if(*vector::borrow<TypeName>(&types, index) == type_name::get<T>()) {
                            is_existed = true;
                            current_index = index;
                    };

                    index = index + 1;
            };

            if(is_existed == true) {
                    vector::remove(&mut types, current_index);
            };
    }

    /***
    * @dev add_admin
    * @param admin is admin id
    * @param naddresses
    */
    public entry fun make_add_admin(admin:&mut Admin, naddresses: vector<address>, ctx:&mut TxContext){
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        vector::append(&mut admin.addresses, naddresses);
    }

    /***
    * @dev remove_admin
    * @param admin is admin id
    * @param delete_address
    */
    public entry fun make_remove_admin(admin:&mut Admin, delete_address: address, ctx:&mut TxContext){
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
                    };

                    index = index + 1;
            };

            if(is_existed == true) {
                    vector::remove(&mut admins, current_index);
            };
    }


    fun create_new_container(marketplace:&mut Marketplace, ctx:&mut TxContext):Container {
        let new_container = Container{
            id: object::new(ctx),
            count: 1
        };
        //deposit new container in container list 
        vector::push_back(&mut marketplace.containers, Status{
            id: object::id(&new_container),
            can_deposit: true
        });

        new_container
    }


    fun change_container_status(auction:&mut Marketplace, container: &mut Container, status : bool) {
        let containers = &mut auction.containers;
        let length = vector::length(containers);
        let index = 0;
        while(index < length){
        let current_container = vector::borrow_mut(containers, index);
            if(current_container.id == object::uid_to_inner(&container.id)){
                current_container.can_deposit = status;
                break
            };
            index = index + 1;
        };
    }


    struct ListEvent has copy, drop {
        list_id: ID,
        nft_id: ID,
        container_id: ID,
        marketplace_id: ID,
        price: u64,
        seller: address,
    }

    /***
    * @dev list
    * @param marketplace is marketplace id
    * @param container is container id
    * @param current_kiosk is current_kiosk id
    * @param item is nft 
    * @param price is nft price
    */
    fun list<T: store + key,C>(
        marketplace: &mut Marketplace, 
        container: &mut Container, 
        current_kiosk: &mut Kiosk, 
        item: T, 
        price: u64, 
        ctx: &mut TxContext
    ) {
        assert!(is_available_type<T>(marketplace) == true, ENftNotAvailableNow);
        assert!(marketplace.enable == true, EMarketplaceNotAvailableNow);
        // check if container is full
        if(container.count >= marketplace.maximum_size){
            let nft_id = object::id(&item);
            // change status is full false current container
            change_container_status(marketplace, container, false);
            // create new container
            let new_container = create_new_container(marketplace, ctx);
            // init new list
            let listing = List{
                id: object::new(ctx),
                container_id: object::id(&new_container),
                seller: tx_context::sender(ctx),
                coin_type: type_name::get<C>(),
                price: price,           
                nft_id,
                nft_type: type_name::get<T>()  
            };
            // event
            event::emit(ListEvent{
                list_id: object::id(&listing),
                nft_id: nft_id,
                container_id: object::id(&new_container),
                marketplace_id: object::id(marketplace),
                price: price,
                seller: tx_context::sender(ctx),
            });
            // add dof to container
            ofield::add(&mut new_container.id, nft_id, listing);
            // share
            transfer::share_object(new_container);
        } else{
            let nft_id = object::id(&item);
            // init new list
            let listing = List{
                id: object::new(ctx),
                container_id: object::id(container),
                seller: tx_context::sender(ctx),
                coin_type: type_name::get<C>(),
                price: price,   
                nft_id,
                nft_type: type_name::get<T>()        
            };
            // event
            event::emit(ListEvent{
                list_id: object::id(&listing),
                nft_id: nft_id,
                container_id: object::id(container),
                marketplace_id: object::id(marketplace),
                price: price,
                seller: tx_context::sender(ctx),
            });
            // check if full after list
            if(container.count + 1 == marketplace.maximum_size) {
                change_container_status(marketplace, container, false);
            };
            // increase count
            container.count = container.count + 1;
            // add dof to container
            ofield::add(&mut container.id, nft_id, listing);
        };
        // add to kiosk
        let cap = ofield::borrow(&mut marketplace.id, object::id(current_kiosk));
        kiosk::place<T>(current_kiosk, cap, item);
    }

    /***
    * @dev make_list
    * @param marketplace is marketplace id
    * @param container is container id
    * @param current_kiosk is current_kiosk id
    * @param item is nft 
    * @param price is nft price
    */
    public entry fun make_list<T: store + key,C>(
        marketplace: &mut Marketplace, 
        container: &mut Container, 
        current_kiosk: &mut Kiosk, 
        item: T, 
        price: u64, 
        ctx: &mut TxContext
    ) {
        list<T,C>(marketplace, container, current_kiosk, item, price, ctx);
    }

    struct DelistEvent has copy, drop {
        nft_id : ID,
        seller : address
    }

    /***
    * @dev make_delist
    * @param admin is admin id
    * @param marketplace is marketplace id
    * @param container is container id
    * @param current_kiosk is current_kiosk id
    * @param nft_id is nft_id 
    */
    public entry fun make_delist<T: key + store>(admin: &mut Admin, marketplace: &mut Marketplace, container: &mut Container, current_kiosk: &mut Kiosk, nft_id: ID, ctx: &TxContext) {
        assert!(marketplace.enable == true, EMarketplaceNotAvailableNow);
        let sender = sender(ctx);
        // remove in container
        let List {id, container_id:_, seller, price:_, nft_id: _, nft_type: _, coin_type: _} = ofield::remove(&mut container.id, nft_id);
        // check permission
        assert!(seller == sender || is_admin(admin, sender) == true, EWrongSeller);
        // change container status
        if(container.count == marketplace.maximum_size) {
            change_container_status(marketplace, container, true);
        };
        container.count = container.count - 1;
        // get nft from kiosk
        let cap = ofield::borrow(&mut marketplace.id, object::id(current_kiosk));
        let nft = kiosk::take<T>(current_kiosk, cap, nft_id);
        // event
        event::emit(DelistEvent{
            nft_id: nft_id,
            seller: seller
        });
        // transfer and end
        transfer::public_transfer(nft, seller);
        object::delete(id)
    }

    /***
    * @dev add_pool
    * @param admin is admin id
    */
    public entry fun make_add_pool<C>(admin: &mut Admin, ctx: &mut TxContext) {
        let sender = sender(ctx);
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
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);

        let money:Balance<C> = balance::split(coin::balance_mut(&mut pool.coin), pool.total);
        transfer::public_transfer(coin::from_balance(money, ctx), receive_address);
        pool.total = 0;
    }


    /***
    * @dev calculator_fee
    * @param marketplace is marketplace id
    * @param price is price of nft
    */
    fun calculator_fee(marketplace: &mut Marketplace, price: u64): u64 {
        (price * marketplace.fee) / (1000 * 100)
    }


    struct BuyEvent has copy,drop {
        nft_id : ID,
        seller : address,
        buyer: address,
    }

    /***
    * @dev make_buy
    * @param admin is admin id
    * @param pool is pool id
    * @param receive_address is who receive coin
    */
    public entry fun make_buy<T: key + store, C>(marketplace: &mut Marketplace, container: &mut Container, pool: &mut Pool<C>, coin: Coin<C>, current_kiosk: &mut Kiosk, nft_id: ID, ctx: &mut TxContext) {
        assert!(marketplace.enable == true, EMarketplaceNotAvailableNow);
        let sender = sender(ctx);
        // change container status
        if(container.count == marketplace.maximum_size) {
            change_container_status(marketplace, container, true);
        };
        container.count = container.count - 1;

        // remove from container
        let List {id, container_id:_, seller, price, nft_id: _, nft_type: _, coin_type: _} = ofield::remove(&mut container.id, nft_id);

        // get nft from kiosk
        let cap = ofield::borrow(&mut marketplace.id, object::id(current_kiosk));
        let nft = kiosk::take<T>(current_kiosk, cap, nft_id);
        // transfer nft to user
        transfer::public_transfer(nft, sender);
        
        // pay
        let fee = calculator_fee(marketplace, price);

        let fee_balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), fee);
        let money_for_user_balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), price - fee);
        coin::join(&mut pool.coin, coin::from_balance(fee_balance, ctx));
        pool.total = pool.total + fee;
        transfer::public_transfer(coin::from_balance(money_for_user_balance, ctx), seller);
        // event 
        event::emit(BuyEvent{
            nft_id : nft_id,
            seller : seller,
            buyer: sender,
        });
        // end
        transfer::public_transfer(coin, sender);
        object::delete(id)
    }

    /***
    * @dev change_maketplace_status
    * @param admin is admin id
    * @param marketplace is marketplace id
    * @param status is marketplace status
    */
    public entry fun change_marketplace_status(admin: &mut Admin, marketplace: &mut Marketplace, status: bool, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        marketplace.enable = status;
    }

    // only for kiosk

    public entry fun set_allow_extensions(admin: &mut Admin, status: bool, marketplace: &mut Marketplace, current_kiosk: &mut Kiosk, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        // change status
        let cap = ofield::borrow(&mut marketplace.id, object::id(current_kiosk));
        kiosk::set_allow_extensions(current_kiosk, cap, status);
    }

}