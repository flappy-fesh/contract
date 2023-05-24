module fesh_item::common_item {    
    use sui::object::{Self,UID};
    use std::string::{Self,String};
    use sui::tx_context::{Self, TxContext, sender};
    use std::type_name::{Self, TypeName};
    use sui::balance::{Self,Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use std::vector;
    use sui::transfer;
    // admin
    use fesh_item::admin::{Self, Admin};
    // custom token
    use fesh_token::fesh::{Self, FESH};
    
    // error
    const EAdminOnly:u64 = 0;
    const EItemNotFound:u64 = 2001;

    struct CommonItem has store, drop, copy {
      name: String,
      price: u64,
    } 

    struct Container has key {
        id: UID,
        total_common_item_bought: u64,
        common_items: vector<CommonItem>,
        enable: bool
    }

    fun init(ctx:&mut TxContext) {
        let container = Container {
            id: object::new(ctx),
            total_common_item_bought: 0,
            common_items: vector::empty(),
            enable: false
        };

        transfer::share_object(container);
    }

    /***
    * @dev add_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    * @param price is price of item
    */
    public entry fun add_item(admin: &mut Admin, container: &mut Container, name: String, price: u64, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);
        vector::push_back(&mut container.common_items, CommonItem {
            name,
            price,
        });
    }

    /***
    * @dev remove_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    public entry fun remove_item(admin: &mut Admin, container: &mut Container, name: String, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);

        let index = 0;
        // get list item
        let items = container.common_items;
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
        // remove if exist
        if(is_existed == true) {
                vector::remove(&mut items, current_index);
        };
    }

    /***
    * @dev change_container_status
    * @param admin is admin id
    * @param container is container id
    * @param status is container status
    */
    public entry fun change_container_status(admin: &mut Admin, container: &mut Container, status: bool, ctx: &mut TxContext) {
        let sender = sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);
        container.enable = status;
    }

    /***
    * @dev get_item_buy_name
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    fun get_item_buy_name(container: &mut Container, name: String):(String, u64) {
        let index = 0;
        // get list item
        let items = container.common_items;
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
        let current_item = vector::borrow(&mut items, current_index);
        // return
        (current_item.name, current_item.price)
    }


    struct BuyCommonItemEvent has copy,drop {
        name: String,
        amount: u64,
        coin: TypeName
    }

    /***
    * @dev buy_conmmon_item_with_sui
    * @param admin is admin id
    * @param container is container id
    * @param coin is coin id
    * @param amount is amount of item
    * @param name is name of item
    */
    public entry fun make_buy_conmmon_item_with_sui(admin: &mut Admin, container: &mut Container, coin: Coin<SUI>, amount: u64, name: String, ctx: &mut TxContext) {
       // get item
        let (current_name, price) = get_item_buy_name(container, name);
        let sender = sender(ctx);
        // pay
        let balance: Balance<SUI> = balance::split(coin::balance_mut(&mut coin), price * amount);
        admin::pay_with_sui(admin, coin::from_balance(balance, ctx), amount * price);
        //event
        event::emit(BuyCommonItemEvent{
            name: current_name,
            amount,
            coin: type_name::get<SUI>(),
        });

        // increase
        container.total_common_item_bought = container.total_common_item_bought + amount;

        transfer::public_transfer(coin, sender);
    }

    /***
    * @dev buy_conmmon_item_with_fesh
    * @param admin is admin id
    * @param container is container id
    * @param coin is coin id
    * @param amount is amount of item
    * @param name is name of item
    */
    public entry fun make_buy_conmmon_item_with_fesh(admin: &mut Admin, container: &mut Container, coin: Coin<FESH>, amount: u64, name: String, ctx: &mut TxContext) {
       // get item
        let (current_name, price) = get_item_buy_name(container, name);
        let sender = sender(ctx);
        // pay
        let balance: Balance<FESH> = balance::split(coin::balance_mut(&mut coin), price * amount);
        admin::pay_with_fesh(admin, coin::from_balance(balance, ctx), amount * price);
        //event
        event::emit(BuyCommonItemEvent{
            name: current_name,
            amount,
            coin: type_name::get<FESH>(),
        });

        // increase
        container.total_common_item_bought = container.total_common_item_bought + amount;

        transfer::public_transfer(coin, sender);
    }
}

