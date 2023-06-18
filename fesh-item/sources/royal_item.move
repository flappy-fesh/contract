module fesh_item::royal_item {
    use sui::object::{Self,UID};
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self,String,utf8};
    use sui::tx_context::{Self, TxContext};
    use sui::package;
    use sui::display;
    use std::vector;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self,Balance};
    // admin
    use fesh_item::admin::{Self, Admin, Pool};
    

    // error
    const EAdminOnly:u64 = 0;
    const EAttributeWrongLimit:u64 = 1;
    const EItemNotFound:u64 = 2001;
    const ECannotGetRoyalItem:u64 = 2002;


    struct Piece has store, copy, drop {
        royal_name: String,
        name: String,
        attributes: VecMap<String, String>,
        image_url: String,
        price: u64,
    }

    struct RoyalItem has store, copy, drop {
        name: String,
        attributes: VecMap<String, String>,
        image_url: String,
        fee: u64,
    }

    struct Container has key {
        id: UID,
        total_royal_item_compile: u64,
        total_royal_piece_bought: u64,
        royal_items: vector<RoyalItem>,
        peice_items: vector<Piece>,
        enable: bool
    }


    struct Nft has key,store {
        id: UID,
        name: String,
        image_url: String,
        attributes: VecMap<String, String>,
    }

    struct ROYAL_ITEM has drop {}

    fun init(otw: ROYAL_ITEM, ctx:&mut TxContext) {
        let container = Container {
            id: object::new(ctx),
            total_royal_item_compile: 0,
            total_royal_piece_bought: 0,
            royal_items: vector::empty(),
            peice_items: vector::empty(),
            enable: false
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
            utf8(b"{name}"),
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

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::share_object(container);
    }

    /***
    * @dev get_item_buy_name
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    fun get_royal_by_name(container: &mut Container, name: String):(String, VecMap<String, String>, String, u64) {
        let index = 0;
        // get list item
        let items = container.royal_items;
        let items_length = vector::length(&items);
        let current_index = 0;
        let is_existed = false;
        // loop to find index
        while(index < items_length) {
                if(vector::borrow(&items, index).name == name) {
                        is_existed = true;
                        current_index = index;
                };

                index = index + 1;
        };
        // check not found
        assert!(is_existed == true, EItemNotFound);
        // get
        let current_royal = vector::borrow(&mut items, current_index);
        // return
        (current_royal.name, current_royal.attributes, current_royal.image_url, current_royal.fee)
    }

    /***
    * @dev get_item_buy_name
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    fun get_peice_by_name(container: &mut Container, royal_name: String, item_name: String):(String, VecMap<String, String>, String, u64) {
        let index = 0;

        // get list item
        let items = container.peice_items;
        let items_length = vector::length(&items);
        let current_index = 0;
        let is_existed = false;
        // loop to find index
        while(index < items_length) {
                let current_item = vector::borrow(&items, index);
                if(current_item.name == item_name && current_item.royal_name == royal_name) {
                        is_existed = true;
                        current_index = index;
                        break
                };

                index = index + 1;
        };
        // check not found
        assert!(is_existed == true, EItemNotFound);
        // get
        let current_peice = vector::borrow(&mut items, current_index);
        // return
        (current_peice.name, current_peice.attributes, current_peice.image_url, current_peice.price)
    }


    /***
    * @dev get_item_buy_name
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    fun is_royal_peice(container: &mut Container, royal_name: String, item_name: String): bool {
        let index = 0;

        // get list item
        let items = container.peice_items;
        let items_length = vector::length(&items);
        let is_existed = false;
        // loop to find index
        while(index < items_length) {
                let current_item = vector::borrow(&items, index);
                if(current_item.name == item_name && current_item.royal_name == royal_name) {
                        is_existed = true;
                        break
                };

                index = index + 1;
        };
        is_existed == true
    }



    /***
    * @dev change_container_status
    * @param admin is admin id
    * @param container is container id
    * @param status is container status
    */
    public entry fun change_container_status(admin: &mut Admin, container: &mut Container, status: bool, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true,EAdminOnly);
        container.enable = status;
    }

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
    * @dev add_royal_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    * @param price is price of item
    */
    public entry fun add_royal_item(
        admin: &mut Admin, 
        container: &mut Container, 
        name: String,
        image_url: String, 
        fee: u64,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);

        let attributes: VecMap<String, String> = make_vec_map(attribute_keys, attribute_values);

        let new_royal = RoyalItem {
            name,
            image_url,
            attributes,
            fee
        };

        vector::push_back(&mut container.royal_items, new_royal);
    }

    /***
    * @dev remove_royal_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    * @param price is price of item
    */
    public entry fun remove_royal_item(
        admin: &mut Admin, 
        container: &mut Container, 
        name: String,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);

        // find and remove psss royal
        let royal_items = container.royal_items;
        let items_length = vector::length(&royal_items);
        let current_index = 0;
        let index = 0;
        let is_existed = false;
        // loop to find index
        while(index < items_length) {
                if(vector::borrow(&royal_items, index).name == name) {
                        is_existed = true;
                        current_index = index;
                        break
                };

                index = index + 1;
        };
        // remove if exist
        assert!(is_existed == true, EItemNotFound);
        vector::remove(&mut royal_items, current_index);
    }

    /***
    * @dev add_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    * @param price is price of item
    */
    public entry fun add_peice_item(
        admin: &mut Admin, 
        container: &mut Container, 
        name_of_royal: String,
        name_of_item: String,
        image_url: String, 
        price: u64, 
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);

        let attributes: VecMap<String, String> = make_vec_map(attribute_keys, attribute_values);

        vector::push_back(&mut container.peice_items, Piece {
            royal_name: name_of_royal,
            name: name_of_item,
            image_url,
            price,
            attributes
        })
    }

    /***
    * @dev remove_nft_for_random
    * @param admin is admin id
    * @param container is container id
    */
    public entry fun remove_peice_item(
        admin: &mut Admin, 
        container: &mut Container, 
        name_of_royal: String,
        name_of_item: String,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        //admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);
        let index = 0;
        let items = container.peice_items;
        let items_length = vector::length(&items);
        let current_index = 0;
        let is_existed = false;
        while(index < items_length) {
                let current_peice = vector::borrow(&items, index);
                if(current_peice.name == name_of_item && current_peice.royal_name == name_of_royal) {
                        is_existed = true;
                        current_index = index;
                        break
                };

                index = index + 1;
        };
        
        assert!(is_existed == true, EItemNotFound);
        vector::remove(&mut items, current_index);
    }

    /***
    * @dev buy_conmmon_item_with_sui
    * @param admin is admin id
    * @param container is container id
    * @param coin is coin id
    * @param amount is amount of item
    * @param name is name of item
    */
    public entry fun make_buy_peice_item<C>(
        pool: &mut Pool<C>,
        container: &mut Container, 
        coin: Coin<C>, 
        amount: u64, 
        royal_name: String,
        name: String, 
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // nft
        let index = 0;
        // get item
        let (current_name, current_attributes, current_image_url, current_price) = get_peice_by_name(container, royal_name, name);
        
        // mint and transfer with amount
        while(index < amount) {
            let new_nft = Nft{
                    id: object::new(ctx),
                    name: current_name,
                    image_url: current_image_url,
                    attributes: current_attributes,
            };
            transfer::public_transfer(new_nft, sender);
            index = index + 1;
            
        };

        // pay
        let balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), current_price * amount);
        admin::pay(pool, coin::from_balance(balance, ctx), amount * current_price);

        // increase
        container.total_royal_piece_bought = container.total_royal_piece_bought + amount;

        transfer::public_transfer(coin, sender);
    }

    fun burn(nft: Nft) {
        let Nft {
            id,
            name: _,
            image_url: _,
            attributes: _,
        } = nft;

        object::delete(id);
    }

    /***
    * @dev check_and_burn
    * @param container is container id
    * @param item is nft id
    ...
    */
    fun check_and_burn(
        container: &mut Container,
        item_1: Nft,
        item_2: Nft,
        item_3: Nft,
        item_4: Nft,
        item_5: Nft,
        item_6: Nft,
        item_7: Nft,
        item_8: Nft,
        royal_item_name: String,
    ) {


        // list of nft name
        let nft_names: vector<String> = vector::empty();
        vector::push_back(&mut nft_names, item_1.name);
        vector::push_back(&mut nft_names, item_2.name);
        vector::push_back(&mut nft_names, item_3.name);
        vector::push_back(&mut nft_names, item_4.name);
        vector::push_back(&mut nft_names, item_5.name);
        vector::push_back(&mut nft_names, item_6.name);
        vector::push_back(&mut nft_names, item_7.name);
        vector::push_back(&mut nft_names, item_8.name);

        // list off nft
        let nfts: vector<Nft> = vector::empty();
        vector::push_back(&mut nfts, item_1);
        vector::push_back(&mut nfts, item_2);
        vector::push_back(&mut nfts, item_3);
        vector::push_back(&mut nfts, item_4);
        vector::push_back(&mut nfts, item_5);
        vector::push_back(&mut nfts, item_6);
        vector::push_back(&mut nfts, item_7);
        vector::push_back(&mut nfts, item_8);

        // get item into container and count for check
        let index = 0;
        let nfts_length = vector::length(&nfts);
        let currrent_nft_names: vector<String> = vector::empty();
        // loop to check enough peice in royal list
        while(index < nfts_length) {
            let current_nft_name = vector::borrow(&nft_names, index);
            if((vector::contains(&currrent_nft_names, current_nft_name) == false) && is_royal_peice(container, royal_item_name, *current_nft_name) == true) {
                        vector::push_back(&mut currrent_nft_names, *current_nft_name);
            };
            index = index + 1;
        };
        // check enough 8 peice
        assert!(vector::length(&currrent_nft_names) == 8, ECannotGetRoyalItem);

        // burn
        let burn_index = 0;
        while(burn_index < nfts_length) {
            burn(vector::remove(&mut nfts, burn_index));
            burn_index = burn_index + 1;
        };
        // destroy
        vector::destroy_empty(nfts);
    }

    public entry fun get_royal_item<C>(
        container: &mut Container,
        pool: &mut Pool<C>,
        coin: Coin<C>,
        royal_item_name: String,
        item_1: Nft,
        item_2: Nft,
        item_3: Nft,
        item_4: Nft,
        item_5: Nft,
        item_6: Nft,
        item_7: Nft,
        item_8: Nft,
        ctx: &mut TxContext
    ) {
        // check and burn
        check_and_burn(container, item_1, item_2, item_3, item_4, item_5, item_6, item_7, item_8, royal_item_name);
        // get royal attributes
        let (name, attributes, image_url, fee)= get_royal_by_name(container, royal_item_name);

        // pay
        let balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), fee);
        admin::pay(pool, coin::from_balance(balance, ctx), fee);

        // create nft
        let new_nft = Nft{
            id: object::new(ctx),
            name: name,
            image_url: image_url,
            attributes: attributes,
        };

        // transfer
        transfer::public_transfer(new_nft, tx_context::sender(ctx));
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }


}

