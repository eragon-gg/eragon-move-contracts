module eragon::eragon_manager {
    use std::signer;
    use std::vector;
    use std::error;
    use std::bcs;

    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_framework::aptos_coin::AptosCoin;

    friend eragon::eragon_lucky_wheel;
    friend eragon::eragon_claim;
    friend eragon::eragon_boost;
    friend eragon::eragon_toss;
    friend eragon::eragon_avatar;
    friend eragon::eragon_asset;

    const E_NOT_AUTHORIZED: u64 = 100;
    const E_INSUFFICIENT_BALANCE: u64 = 101;
    const E_INVALID_PUBLIC_KEY: u64 = 102;
    const E_OPERATOR_EXISTED: u64 = 200;
    const E_OPERATOR_NOT_EXISTED: u64 = 201;
    
    struct Operator has key, store {
        operator_addr: address,
        status: bool
    }

    struct OperatorResource has key, store {
        resource_addr: address,
        resource_cap: account::SignerCapability
    }

    struct EragonManager has key, store {
        admin_addr: address,
        operators: vector<Operator>,
        resource_addr: address,
        resource_cap: account::SignerCapability,
        pk: vector<u8>
    }

    fun init_module(deployer: &signer) {
        let (resource_acc, resource_cap) = account::create_resource_account(deployer, vector[0u8]);

        let resource_signer = account::create_signer_with_capability(&resource_cap);
        managed_coin::register<AptosCoin>(&resource_signer);

        move_to(deployer, EragonManager {
            admin_addr: @eragon,
            operators: vector::empty<Operator>(),
            resource_addr: signer::address_of(&resource_acc),
            resource_cap,
            pk: vector::empty<u8>()
        });
    }

    public entry fun set_pk(admin: &signer, pk: vector<u8>) acquires EragonManager {
        assert!(is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        assert!(vector::length(&pk) == 64, error::invalid_argument(E_INVALID_PUBLIC_KEY));
        let resource = borrow_global_mut<EragonManager>(@eragon);
        resource.pk = pk;
    }

    public entry fun add_operator(admin: &signer, operator_addr: address) acquires EragonManager {
        assert!(is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        assert!(!is_operator(operator_addr), error::permission_denied(E_OPERATOR_EXISTED));

        let resource = borrow_global_mut<EragonManager>(@eragon);

        vector::push_back<Operator>(&mut resource.operators, Operator {
            operator_addr,
            status: true
        });
    }

    public entry fun set_operator_status(admin: &signer, operator_addr: address, status: bool) acquires EragonManager {
        assert!(is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));
        

        let resource = borrow_global_mut<EragonManager>(@eragon);

        let (found, i) = vector::find<Operator>(&resource.operators, |o| {
            let operator : &Operator = o;
            operator.operator_addr == operator_addr
        });

        assert!(found, error::permission_denied(E_OPERATOR_NOT_EXISTED));
        let operator = vector::borrow_mut<Operator>(&mut resource.operators, i);
        operator.status = status;
    }

    public entry fun create_operator_resource(operator: &signer) acquires EragonManager {
        let operator_addr = signer::address_of(operator);
        assert!(is_operator(operator_addr), error::permission_denied(E_OPERATOR_NOT_EXISTED));
        if (!exists<OperatorResource>(operator_addr)) {
            let bytes = bcs::to_bytes(&@eragon);
            let (resource_acc, resource_cap) = account::create_resource_account(operator, bytes);
            let resource_signer = account::create_signer_with_capability(&resource_cap);
            managed_coin::register<AptosCoin>(&resource_signer);
            move_to(operator,
                OperatorResource {
                    resource_addr: signer::address_of(&resource_acc),
                    resource_cap
                }
            );
        };
    }

    public(friend) fun get_operator_resource_signer(operator_addr: address): signer acquires OperatorResource {
        let resource = borrow_global<OperatorResource>(operator_addr);
        account::create_signer_with_capability(&resource.resource_cap)
    }

    public(friend) fun get_operator_acc_addr(operator_addr: address): address acquires OperatorResource {
        let resource = borrow_global<OperatorResource>(operator_addr);
        resource.resource_addr
    }

    public entry fun withdraw_operator_resource(operator: &signer, amount: u64) acquires EragonManager, OperatorResource {
        let operator_addr = signer::address_of(operator);
        assert!(is_operator(operator_addr), error::permission_denied(E_NOT_AUTHORIZED));

        let resource = borrow_global_mut<OperatorResource>(operator_addr);
        assert!(
            coin::balance<AptosCoin>(resource.resource_addr) >= amount,
            error::invalid_state(E_INSUFFICIENT_BALANCE)
        );

        let coin = coin::withdraw<AptosCoin>(&get_operator_resource_signer(operator_addr), amount);
        coin::deposit<AptosCoin>(operator_addr, coin);
    }

    public entry fun deposit_operator_resource(operator: &signer, amount: u64) acquires OperatorResource {
        let operator_addr = signer::address_of(operator);
        let resource = borrow_global<OperatorResource>(operator_addr);
        assert!(
            coin::balance<AptosCoin>(operator_addr) >= amount,
            error::invalid_state(E_INSUFFICIENT_BALANCE)
        );

        let coin = coin::withdraw<AptosCoin>(operator, amount);
        coin::deposit<AptosCoin>(resource.resource_addr, coin);
    }

    public entry fun transfer_admin(admin: &signer, new_admin_addr: address) acquires EragonManager {
        assert!(is_admin(signer::address_of(admin)), error::permission_denied(E_NOT_AUTHORIZED));

        let resource = borrow_global_mut<EragonManager>(@eragon);
        resource.admin_addr = new_admin_addr;
    }

    public entry fun withdraw(admin: &signer, amount: u64) acquires EragonManager {
        let admin_addr = signer::address_of(admin);
        assert!(is_admin(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
        let resource = borrow_global_mut<EragonManager>(@eragon);
        assert!(
            coin::balance<AptosCoin>(resource.resource_addr) >= amount,
            error::invalid_state(E_INSUFFICIENT_BALANCE)
        );

        let resource_signer = account::create_signer_with_capability(&resource.resource_cap);

        coin::transfer<AptosCoin>(&resource_signer, admin_addr, amount);
    }

    public(friend) fun get_resource_signer(): signer acquires EragonManager {
        let resource = borrow_global<EragonManager>(@eragon);
        account::create_signer_with_capability(&resource.resource_cap)
    }

    public(friend) fun get_acc_addr(): address acquires EragonManager {
        let resource = borrow_global<EragonManager>(@eragon);
        resource.resource_addr
    }

    #[view]
    public fun is_admin(admin_addr: address): bool acquires EragonManager {
        let resource = borrow_global<EragonManager>(@eragon);
        resource.admin_addr == admin_addr
    }

    #[view]
    public fun is_operator(operator_addr: address): bool acquires EragonManager {
        let resource = borrow_global<EragonManager>(@eragon);
        let (found, _) = vector::find<Operator>(&resource.operators, |o| {
            let operator : &Operator = o;
            operator.operator_addr == operator_addr && operator.status == true
        });
        found
    }

    #[view]
    public fun get_operator_resource_addr(operator_addr: address): address acquires EragonManager, OperatorResource {
        assert!(is_operator(operator_addr), error::permission_denied(E_OPERATOR_NOT_EXISTED));
        let resource = borrow_global<OperatorResource>(operator_addr);
        resource.resource_addr
    }

    #[view]
    public fun get_operator_resource_balance(operator_addr: address): u64 acquires EragonManager, OperatorResource {
        let resource_addr = get_operator_resource_addr(operator_addr);
        coin::balance<AptosCoin>(resource_addr)
    }

    #[view]
    public fun get_pk(): vector<u8> acquires EragonManager {
        let resource = borrow_global<EragonManager>(@eragon);
        resource.pk
    }


    #[test(
        admin = @eragon,
        new_admin = @0x10b5b07b43233b6fe88cf42a13948ff1b56a3c84ceacae150f1d333f6cae71ca,
        aptos_framework = @0x1
    )]
    fun test_transfer_admin(admin: &signer, new_admin: &signer, aptos_framework: &signer) acquires EragonManager {
        init_module(admin);

        let new_admin_addr = signer::address_of(new_admin);

        transfer_admin(admin, new_admin_addr);
        assert!(is_admin(new_admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
       
    }
}