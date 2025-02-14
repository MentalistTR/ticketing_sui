#[allow(duplicate_alias)]
module ticketing::ticketing {

    // Imports
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{ TxContext};

    // Error section
    const ERR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERR_TICKET_ALREADY_PAID: u64 = 0;


    // Customer struct to hold customer details
    public struct Customer has key, store {
        id: UID,
        name: vector<u8>,
        balance: Balance<SUI>,
        loyalty_points: u64,
    }

    // EventTicket struct
    public struct EventTicket has key, store {
        id: UID,
        event_name: vector<u8>,
        price: u64,
    }

      // TicketOrder struct
    public struct TicketOrder has key, store {
        id: UID,
        customer: ID,
        tickets: vector<EventTicket>,
        total_price: u64,
        is_paid: bool,
        discount: u64,
    }

     // Function to register a new customer
    public fun register_customer(
        name: vector<u8>,
        ctx: &mut TxContext,
    ): Customer {
        let customer_id = object::new(ctx);
        let customer = Customer {
            id: customer_id,
            name,
            balance: balance::zero(),
            loyalty_points: 0,
        };
        customer
    }

    // Function to get customer details
    public fun get_customer_details(customer: &Customer): (vector<u8>, &Balance<SUI>, u64) {
        (customer.name, &customer.balance, customer.loyalty_points)
    }

    // Function to add balance to the customer's account
    public fun add_balance(customer: &mut Customer, amount: Coin<SUI>) {

        let balance_to_add = coin::into_balance(amount);
        customer.balance.join(balance_to_add);
    }

    // Function to add loyalty points to the customer's account
    public fun add_loyalty_points(customer: &mut Customer, points: u64) {
        customer.loyalty_points = customer.loyalty_points + points;
    }

     // Function to create an event ticket
    public fun create_event_ticket(
        event_name: vector<u8>,
        price: u64,
        ctx: &mut TxContext,
    ): EventTicket {
        let ticket_id = object::new(ctx);
        let ticket = EventTicket {
            id: ticket_id,
            event_name,
            price,
        };
        ticket
    }



     // Function to place a ticket order
    public fun place_ticket_order(
        customer: &mut Customer,
        tickets: vector<EventTicket>,
        discount: u64,
        total_price: u64,
        ctx: &mut TxContext,
    ): TicketOrder {
        let order_id = object::new(ctx);
        let order = TicketOrder {
            id: order_id,
            customer: object::uid_to_inner(&customer.id),
            tickets,
            total_price,
            is_paid: false,
            discount,
        };
        order
    }


    // Function to get ticket order details
    public fun get_ticket_order_details(order: &TicketOrder): (&ID, &vector<EventTicket>, u64, bool, u64) {
        (&order.customer, &order.tickets, order.total_price, order.is_paid, order.discount)
    }

    // Function to process payment for a ticket order using balance
    public fun process_payment_with_balance(
        customer: &mut Customer,
        order: &mut TicketOrder,
        reciepient: address,
        ctx : &mut TxContext,
    ) {
        assert!(!order.is_paid, ERR_TICKET_ALREADY_PAID);
        assert!(customer.balance.value() >= order.total_price, ERR_INSUFFICIENT_BALANCE);

        let total_pay = coin::take(&mut customer.balance, order.total_price,ctx);
        transfer::public_transfer(total_pay, reciepient);
        order.is_paid = true;

        // Add loyalty points
        let points = order.total_price / 10;
        add_loyalty_points(customer, points);
    }


    // Function to process payment for a ticket order using loyalty points
    public fun process_payment_with_loyalty_points(
        customer: &mut Customer,
        order: &mut TicketOrder,
        reciepient: address,
        ctx : &mut TxContext,
    ) {
        assert!(!order.is_paid, ERR_TICKET_ALREADY_PAID);
        assert!(customer.loyalty_points >= order.total_price, ERR_INSUFFICIENT_BALANCE);

        customer.loyalty_points = customer.loyalty_points - order.total_price;
        order.is_paid = true;

        let loyalty_points_pay = coin::take(&mut customer.balance, customer.loyalty_points,ctx);
        transfer::public_transfer(loyalty_points_pay, reciepient);
    }

     // Function to apply a discount to a ticket order
    public fun apply_discount(order: &mut TicketOrder, discount: u64) {
        order.discount = discount;
        order.total_price = order.total_price - discount;
    }

     // Function to handle partial payments for ticket orders
    public fun process_partial_payment(
        customer: &mut Customer,
        order: &mut TicketOrder,
        reciepient: address,
        ctx : &mut TxContext,
        amount: u64,
    ) {
        assert!(!order.is_paid, ERR_TICKET_ALREADY_PAID);
        assert!(customer.balance.value() >= amount, ERR_INSUFFICIENT_BALANCE);

        let pay_amount = coin::take(&mut customer.balance, amount, ctx);

        let paid: u64 = pay_amount.value();
        order.total_price = order.total_price - paid;

        if (order.total_price == 0) {
            order.is_paid = true;

            // Add loyalty points
            let points = amount / 10;
            add_loyalty_points(customer, points);
        };
        transfer::public_transfer(pay_amount,reciepient);
    }



}
