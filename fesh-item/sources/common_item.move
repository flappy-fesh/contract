module fesh_item::common_item {    
    use sui::object::{Self,UID};
    use std::string::{Self,String};
    use sui::tx_context::{Self, TxContext};
    use std::type_name::{Self, TypeName};
    use sui::balance::{Self,Balance};
    use sui::coin::{Self, Coin};
    use sui::event;
    use std::vector;
    use sui::transfer;
    // admin
    use fesh_item::admin::{Self, Admin, Pool};
    
    // error
    const EAdminOnly:u64 = 0;
    const EItemNotFound:u64 = 2001;

    struct CommonItem has store, drop, copy {
      type: String,
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

    struct AddCommonItemEvent has copy, drop {
        type: String,
        price: u64,
    }

    /***
    * @dev add_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    * @param price is price of item
    */
    public entry fun add_item(admin: &mut Admin, container: &mut Container, type: String, price: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        // admin only
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);
        vector::push_back(&mut container.common_items, CommonItem {
            type,
            price,
        });
        //event
        event::emit(AddCommonItemEvent{
            type,
            price,
        });
    }


    struct RemoveCommonItemEvent has copy,drop {
        type: String,
    }

    /***
    * @dev remove_item
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    public entry fun remove_item(admin: &mut Admin, container: &mut Container, type: String, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
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
                if(vector::borrow(&items, index).type == type) {
                        is_existed = true;
                        current_index = index;
                        break
                };

                index = index + 1;
        };
        // remove if exist
        assert!(is_existed == true, EItemNotFound);
        vector::remove(&mut items, current_index);
        //event
        event::emit(RemoveCommonItemEvent{
            type,
        });
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
        assert!(admin::is_admin(admin, sender) == true, EAdminOnly);
        container.enable = status;
    }

    

    /***
    * @dev get_item_buy_name
    * @param admin is admin id
    * @param container is container id
    * @param name is name of item
    */
    fun get_item_buy_name(container: &mut Container, type: String):(String, u64) {
        let index = 0;
        // get list item
        let items = container.common_items;
        let items_length = vector::length(&items);
        let current_index = 0;
        let is_existed = false;
        // loop to find index
        while(index < items_length) {
                if(vector::borrow(&items, index).type == type) {
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
        (current_item.type, current_item.price)
    }


    struct BuyCommonItemEvent has copy,drop {
        type: String,
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
    public entry fun make_buy_conmmon_item<C>(pool: &mut Pool<C>, container: &mut Container, coin: Coin<C>, amount: u64, type: String, ctx: &mut TxContext) {
       // get item
        let (current_type, price) = get_item_buy_name(container, type);
        let sender = tx_context::sender(ctx);
        // pay
        let balance: Balance<C> = balance::split(coin::balance_mut(&mut coin), price * amount);
        admin::pay(pool, coin::from_balance(balance, ctx), amount * price);
        //event
        event::emit(BuyCommonItemEvent{
            type: current_type,
            amount,
            coin: type_name::get<C>(),
        });

        // increase
        container.total_common_item_bought = container.total_common_item_bought + amount;

        transfer::public_transfer(coin, sender);
    }

}

