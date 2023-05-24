module fesh_nft::nft {
    //import module
    use std::string::{Self,String,utf8};
    use sui::tx_context::{TxContext,sender};
    use sui::transfer;
    use std::vector;
    use sui::object::{Self,ID,UID};
    use sui::coin::{Self,Coin};
    use sui::sui::SUI;
    use sui::balance::{Self,Balance};
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


    struct Admin has key {
        id: UID,
        addresses: vector<address>,
        pool: Coin<SUI>,
        total_pool: u64,
        minters: vector<address>,
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

    fun init(otw: NFT,ctx:&mut TxContext) {

        let sender = sender(ctx);
        let enable_addresses = vector::empty();
        vector::push_back(&mut enable_addresses, sender);

        let admin = Admin{
            id: object::new(ctx),
            addresses: enable_addresses,
            pool: coin::from_balance(balance::zero<SUI>(), ctx),
            total_pool: 0,
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
            random_mint_fee: 2 * ONE_SUI,
            nfts_for_random: vector::empty(),
        };

        transfer::share_object(container);

    }

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
        let money:Balance<SUI> = balance::split(coin::balance_mut(&mut admin.pool), admin.total_pool);
        transfer::public_transfer(coin::from_balance(money, ctx), receive_address);
        admin.total_pool = 0;
    }


    struct AddNftForRandomEvent has copy,drop {
        name: String,
        image_url: String,
        rate: u64, 
        attributes: VecMap<String, String>
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

        let attribute_keys_lenght = vector::length(&attribute_keys);
        let attribute_values_lenght = vector::length(&attribute_values);
        assert!(attribute_keys_lenght == attribute_values_lenght, EAttributeWrongLimit);
        let loop_index = 0;

        let attributes: VecMap<String, String> = vec_map::empty();
        while(loop_index < attribute_keys_lenght) {
            let current_attribute_key = vector::remove<String>(&mut attribute_keys, loop_index);
            let current_attribute_value = vector::remove<String>(&mut attribute_values, loop_index);
            let current_map_value: VecMap<String, String> = vec_map::empty();
            vec_map::insert(&mut current_map_value, current_attribute_key, current_attribute_value);
            loop_index = loop_index + 1;
        };

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
    public entry fun mint_random(admin: &mut Admin, container: &mut Container, amount: u64, coin: Coin<SUI>, ctx: &mut TxContext) {
        // check enable random mint
        assert!(container.is_enable_random_mint == true, ERandomNotEnable);
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
                if(current_nft_attribute.rate > random_number) {
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
            
        };
        // emit event
        event::emit(MintNftEvent{
            nft_ids
        });

        // add coin to pool
        let price_balance:Balance<SUI> = balance::split(coin::balance_mut(&mut coin), container.random_mint_fee * amount);
        coin::join(&mut admin.pool, coin::from_balance(price_balance, ctx));
        admin.total_pool = admin.total_pool + container.random_mint_fee * amount;
        container.total_minted = container.total_minted + amount;
        transfer::public_transfer(coin, sender);

    }

    /***
    * @dev mint_random
    * @param admin is admin id
    * @param container is container id
    * @param amount is amount of nft
    * @param name is name of nft
    * @param image_url is nft image
    * @param attribute_keys vector attribute keys
    * @param attribute_keys vector attribute keys
    * @param transfer_to is address to transfer nft
    */
    public entry fun mint_with_attribute(
        admin: &mut Admin, 
        container: &mut Container, 
        amount: u64, 
        name: String, 
        image_url: String, 
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        transfer_to: address,
        ctx: &mut TxContext
    ) {
        // check permission
        let sender = sender(ctx);
        assert!(is_admin(admin, sender) == true || is_minter(admin, sender) == true , ENotHavePermission);

        // map attributes
        let index = 0;
        let current_index = container.total_minted;

        let attribute_keys_lenght = vector::length(&attribute_keys);
        let attribute_values_lenght = vector::length(&attribute_values);
        assert!(attribute_keys_lenght == attribute_values_lenght, EAttributeWrongLimit);
        let loop_index = 0;
        let nft_ids = vector::empty();

        let attributes: VecMap<String, String> = vec_map::empty();
        while(loop_index < attribute_keys_lenght) {
            let current_attribute_key = vector::remove<String>(&mut attribute_keys, loop_index);
            let current_attribute_value = vector::remove<String>(&mut attribute_values, loop_index);
            let current_map_value: VecMap<String, String> = vec_map::empty();
            vec_map::insert(&mut current_map_value, current_attribute_key, current_attribute_value);
            loop_index = loop_index + 1;
        };
        // mint and transfer with amount
        while(index < amount) {
            let new_nft = Nft{
                    id: object::new(ctx),
                    name,
                    image_url,
                    attributes,
                    index: current_index,
            };
            vector::push_back(&mut nft_ids, object::id(&new_nft));
            transfer::public_transfer(new_nft, transfer_to);
            current_index = current_index + 1;
            
        };
        // emit event
        event::emit(MintNftEvent{
            nft_ids
        });
        // add total minted
        container.total_minted = container.total_minted + amount;

    }
}