module fesh_token::fesh {
  use std::option;

  use sui::object::{Self, UID};
  use sui::tx_context::{TxContext};
  use sui::balance::{Self, Supply};
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::url;
  use sui::tx_context;
  use sui::event::{emit};

  const ERROR_INVALID_SUPPLY: u64 = 1;
  const ERROR_NO_ZERO_ADDRESS: u64 = 2;

  // currency
  struct FESH has drop {}

  // Shared object
  struct Storage has key {
    id: UID,
    supply: Supply<FESH>,
    limit: u64, // 1000000000 * limit
  }

  // The owner of this object can add and remove minters
  struct AdminCap has key {
    id: UID
  }

  struct NewAdmin has copy, drop {
    admin: address
  }


  fun init(witness: FESH, ctx: &mut TxContext) {
      // Create the FESH token
      let (treasury, metadata) = coin::create_currency<FESH>(
            witness, 
            9,
            b"FESH",
            b"FESH TOKEN",
            b"description",
            // icon url
            option::some(url::new_unsafe_from_bytes(b"icon url")),
            ctx
        );

      // Transform the treasury_cap into a supply struct to allow this contract to mint/burn
      let supply = coin::treasury_into_supply(treasury);

      // Share the SuiDollarStorage Object with the Sui network
      transfer::share_object(
        Storage {
          id: object::new(ctx),
          supply,
          limit: 1000000000 * 1000000000000000,
        }
      );

      // Send the AdminCap to the deployer
      transfer::transfer(
        AdminCap {
          id: object::new(ctx)
        },
        tx_context::sender(ctx)
      );

      // Freeze the metadata object, since we cannot update without the TreasuryCap
      transfer::public_freeze_object(metadata);
  }

  /**
  * @dev Only packages can mint dinero by passing the storage publisher
  * @param storage The Storage
  * @param publisher The Publisher object of the package who wishes to mint FESH
  * @return Coin<FESH> New created FESH coin
  */
  public fun mint(_: &AdminCap, storage: &mut Storage, value: u64, ctx: &mut TxContext): Coin<FESH> {
    assert!(storage.limit > total_supply(storage) + value, ERROR_INVALID_SUPPLY);
    coin::from_balance(balance::increase_supply(&mut storage.supply, value), ctx)
  }

  /**
  * @dev This function allows anyone to burn their own FESH.
  * @param storage The Storage shared object
  * @param coin_dnr The dinero coin that will be burned
  */
  public fun burn(storage: &mut Storage, coin_fesh: Coin<FESH>): u64 {
    balance::decrease_supply(&mut storage.supply, coin::into_balance(coin_fesh))
  }

  /**
  * @dev Utility function to transfer Coin<FESH>
  * @param The coin to transfer
  * @param recipient The address that will receive the Coin<FESH>
  */
  public entry fun transfer(coin_fesh: coin::Coin<FESH>, recipient: address) {
    transfer::public_transfer(coin_fesh, recipient);
  }

  /**
  * It allows anyone to know the total value in existence of FESH
  * @storage The shared Storage
  * @return u64 The total value of FESH in existence
  */
  public fun total_supply(storage: &Storage): u64 {
    balance::supply_value(&storage.supply)
  }


 /**
  * @dev It gives the admin rights to the recipient. 
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  *
  * It emits the NewAdmin event with the new admin address
  *
  */
  entry public fun transfer_admin(admin_cap: AdminCap, recipient: address) {
    assert!(recipient != @0x0, ERROR_NO_ZERO_ADDRESS);
    transfer::transfer(admin_cap, recipient);

    emit(NewAdmin {
      admin: recipient
    });
  } 
}

