module fesh_nft::nft {
    //import module
    use std::string::{Self,String,utf8};
    use sui::tx_context::{Self, TxContext,sender};
    use sui::transfer;
    use std::vector;
    use sui::object::{Self,ID,UID};
    use sui::coin::{Self,Coin};
    use sui::balance::{Self,Balance};
    use std::type_name::{Self, TypeName};
    use sui::package;
    use sui::display;
    use sui::vec_map::{Self, VecMap};
    use sui::event;

    // constant
    const ONE_SUI:u64 = 1000000000;


    // custom pakcgae
    use fesh_nft::random;

    // error
    const EAdminOnly:u64 = 0;
    const EAttributeWrongLimit:u64 = 1;
    const ERandomNotEnable:u64 = 2;
    const ENotHavePermission:u64 = 3;

    // --------------------------------------------------Struct----------------------------------------------


    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        pools: vector<ID>,
        minters: vector<address>,
    }

   struct Pool<phantom C>  has key {
        id: UID,
        admin: ID,
        coin_type: TypeName,
        coin: Coin<C>,
        total: u64,
    }

    struct Nft has key,store {
        id: UID,
        name: String,
        image_url: String,
        attributes: VecMap<String, String>,
        index: u64,
    }

    struct NftAttribute has store, copy, drop {
        name: String,
        attributes: VecMap<String, String>,
        image_url: String,
        rate: u64,
    }

    struct Container has key {
        id: UID,
        total_minted: u64,
        is_enable_random_mint: bool,
        random_mint_fee: u64,
        nfts_for_random: vector<NftAttribute>,
    }

    struct NFT has drop {}

    // --------------------------------------------------Init----------------------------------------------


    fun init(otw: NFT,ctx:&mut TxContext) {

        let sender = sender(ctx);
        let enable_addresses = vector::empty();
        vector::push_back(&mut enable_addresses, sender);

        let admin = Admin{
            id: object::new(ctx),
            addresses: enable_addresses,
            pools: vector::empty(),
            minters: vector::empty(),
        };
        

        let keys = vector[
            utf8(b"name"),
            utf8(b"description"),
            utf8(b"url"),
            utf8(b"project_url"),
            utf8(b"image_url"),
            utf8(b"img_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            utf8(b"{name} #{index}"),
            utf8(b"description"),
            utf8(b"{image_url}"),
            utf8(b"website"),
            utf8(b"{image_url}"),
            utf8(b"{image_url}"),
            utf8(b"creator")
        ];

        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);

        // Get a new `Display` object for the `Nft` type.
        let display = display::new_with_fields<Nft>(
            &publisher, keys, values, ctx
        );

        // Commit first version of `Display` to apply changes.
        display::update_version(&mut display);       
 
        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(display, sender(ctx));

        // Admin,Round objects will be saved on global storage
        // after the smart contract deployment we will get the ID to access it
        transfer::share_object(admin);


        // create container 
        let container = Container{
            id: object::new(ctx),
            total_minted: 0,
            is_enable_random_mint: false,
            random_mint_fee: 10000,  //0.001 * ONE_SUI
            nfts_for_random: vector::empty(),
        };

        transfer::share_object(container);

    }

    // --------------------------------------------------Pool----------------------------------------------

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
    * @dev pay_with_sui
    * @param admin is admin id
    * @param coin
    * @param amount
    */
    public fun pay<C>(pool: &mut Pool<C>, coin: Coin<C>, amount: u64) {
          coin::join(&mut pool.coin, coin);
          pool.total = pool.total + amount;
    }

    // --------------------------------------------------Permission for admin and minters----------------------------------------------

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
    * @dev is_minter
    * @param admin is admin id
    * @param address
    */
    public fun is_minter(admin: &mut Admin, address : address) : bool {
            let rs = false;
            let list = admin.minters;

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
    * @dev add_minter
    * @param admin is admin id
    * @param new_addresses
    */
    public entry fun add_minters(admin:&mut Admin, new_addresses: vector<address>, ctx:&mut TxContext){
        let sender = sender(ctx);
        // admin only
        assert!(is_admin(admin, sender) == true,EAdminOnly);
        vector::append(&mut admin.minters, new_addresses);
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
    * @dev remove_minter
    * @param admin is admin id
    * @param delete_address
    */
    public entry fun remove_minter(admin:&mut Admin, delete_address: address, ctx:&mut TxContext){
            // check admin
            let sender = sender(ctx);
            assert!(is_admin(admin, sender) == true, EAdminOnly);

            let index = 0;
            let admins = admin.minters;
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


    // --------------------------------------------------mint----------------------------------------------

    /***
    * @dev isAdmin
    * @param admin is admin id
    * @param new_address
    */
    public entry fun change_enable_random_status(admin: &mut Admin, container: &mut Container, status: bool, ctx: &mut TxContext) {
        // check admin
        let sender = sender(ctx);
        assert!(is_admin(admin, sender) == true, EAdminOnly);

        container.is_enable_random_mint = status;
    }


    /***
    * @dev isAdmin
    * @param admin is admin id
    * @param new_address
    */
    public entry fun change_random_mint_fee(admin: &mut Admin, container: &mut Container, fee: u64, ctx: &mut TxContext) {
        // check admin
        let sender = sender(ctx);
        assert!(is_admin(admin, sender) == true, EAdminOnly);

        container.random_mint_fee = fee;
    }


    struct AddNftForRandomEvent has copy,drop {
        name: String,
        image_url: String,
        rate: u64, 
        attributes: VecMap<String, String>
    }

    /***
    * @dev make_vec_map
    * @param attribute_keys vector attribute keys
    * @param attribute_keys vector attribute keys
    */
    fun make_vec_map(attribute_keys: vector<String>, attribute_values: vector<String>):VecMap<String, String>  {
        let attribute_keys_lenght = vector::length(&attribute_keys);
        let attribute_values_lenght = vector::length(&attribute_values);
        assert!(attribute_keys_lenght == attribute_values_lenght, EAttributeWrongLimit);
        let loop_index = 0;

        let attributes: VecMap<String, String> = vec_map::empty();
        while(loop_index < attribute_keys_lenght) {
            let current_attribute_key = vector::pop_back<String>(&mut attribute_keys);
            let current_attribute_value = vector::pop_back<String>(&mut attribute_values);
            vec_map::insert(&mut attributes, current_attribute_key, current_attribute_value);
            loop_index = loop_index + 1;
        };
        attributes
    }

    /***
    * @dev add_nft_for_random
    * @param admin is admin id
    * @param container is container id
    * @param round_id is round id
    * @param name is name of nft
    * @param image_url is nft image url
    * @param rate is rate wit range 1 => 100
    * @param attribute_keys vector attribute keys
    * @param attribute_keys vector attribute keys
    */
    public entry fun add_nft_for_random(
        admin: &mut Admin, 
        container: &mut Container, 
        name: String,
        image_url: String,
        rate: u64, 
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: &mut TxContext
    ) {
        let sender = sender(ctx);
        //admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);

        let attributes: VecMap<String, String> = make_vec_map(attribute_keys, attribute_values);

        vector::push_back(&mut container.nfts_for_random, NftAttribute {
            name,
            attributes,
            image_url,
            rate,
        });

        //event
        event::emit(AddNftForRandomEvent{
            name,
            image_url,
            rate, 
            attributes
        });
    } 


    struct RemoveNftForRandomEvent has copy,drop {}    

    /***
    * @dev remove_nft_for_random
    * @param admin is admin id
    * @param container is container id
    */
    public entry fun remove_nft_for_random(
        admin: &mut Admin, 
        container: &mut Container, 
        ctx: &mut TxContext
    ) {
        let sender = sender(ctx);
        //admin only
        assert!(is_admin(admin, sender) == true, EAdminOnly);
        container.nfts_for_random = vector::empty();
        event::emit(RemoveNftForRandomEvent{});
    } 


    struct MintNftEvent has copy,drop {
         nft_ids: vector<ID>
    }

    /***
    * @dev mint_random
    * @param admin is admin id
    * @param container is container id
    * @param amount is amount of nft
    * @param coin is sui coin
    */
    public entry fun mint_random<C>(admin: &mut Admin, pool: &mut Pool<C>, container: &mut Container, amount: u64, coin: Coin<C>, ctx: &mut TxContext) {
        // check enable random mint
        let sender = sender(ctx);
        assert!(container.is_enable_random_mint == true || is_admin(admin, sender) == true , ERandomNotEnable);
        // start
        let index = 0;
        let sender = sender(ctx);
        let current_index = container.total_minted;
        let nft_ids = vector::empty();
        // for loop amount
        while(index < amount) {
            let loop_index = 0;
            let nft_attributes = &mut container.nfts_for_random;
            let nft_attributes_length = vector::length(nft_attributes);
            let result = 0;
            // get random number
            let random_number = random::next_u64(&mut random::create_random_object(ctx), 99) + 1;
            // get nft from random number
            while(loop_index < nft_attributes_length) {
                let current_nft_attribute = vector::borrow(nft_attributes, loop_index);
                if(current_nft_attribute.rate >= random_number) {
                    result = loop_index;
                    break
                };
                loop_index = loop_index + 1;
            };
            let current_attribute = vector::borrow(nft_attributes, result); 
            // create nft           
            let new_nft = Nft{
                    id: object::new(ctx),
                    name: current_attribute.name,
                    image_url: current_attribute.image_url,
                    attributes: current_attribute.attributes,
                    index: current_index,
            };
            vector::push_back(&mut nft_ids, object::id(&new_nft));
            // transfer to sender
            transfer::public_transfer(new_nft, sender);
            current_index = current_index + 1;
            index = index + 1;
            
        };
        // emit event
        event::emit(MintNftEvent{
            nft_ids
        });

        // add coin to pool
        let balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), container.random_mint_fee * amount);
        pay(pool, coin::from_balance(balance, ctx), amount * container.random_mint_fee);
        container.total_minted = container.total_minted + amount;
        transfer::public_transfer(coin, sender);

    }

    /***
    * @dev mint_random
    * @param admin is admin id
    * @param container is container id
    * @param amount is amount of nft
    * @param coin is sui coin
    */
    public entry fun mint_with_name<c>(admin: &mut Admin, container: &mut Container, name: String, amount: u64, ctx: &mut TxContext) {
        // check permission
        let sender = sender(ctx);
        assert!(is_admin(admin, sender) == true || is_minter(admin, sender) == true , ENotHavePermission);
        let index = 0;
        let sender = sender(ctx);
        let current_index = container.total_minted;
        let nft_ids = vector::empty();
        // for loop amount
        while(index < amount) {
            let loop_index = 0;
            let nft_attributes = &mut container.nfts_for_random;
            let nft_attributes_length = vector::length(nft_attributes);
            let result = 0;
            // get nft from random number
            while(loop_index < nft_attributes_length) {
                let current_nft_attribute = vector::borrow(nft_attributes, loop_index);
                if(current_nft_attribute.name == name) {
                    result = loop_index;
                    break
                };
                loop_index = loop_index + 1;
            };
            let current_attribute = vector::borrow(nft_attributes, result); 
            // create nft           
            let new_nft = Nft{
                    id: object::new(ctx),
                    name: current_attribute.name,
                    image_url: current_attribute.image_url,
                    attributes: current_attribute.attributes,
                    index: current_index,
            };
            vector::push_back(&mut nft_ids, object::id(&new_nft));
            // transfer to sender
            transfer::public_transfer(new_nft, sender);
            current_index = current_index + 1;
            index = index + 1;
            
        };
        // emit event
        event::emit(MintNftEvent{
            nft_ids
        });

        container.total_minted = container.total_minted + amount;

    }
}