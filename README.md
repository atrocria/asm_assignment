# DeliGo School assignment project Y2S1

DeliGo is a food delivery and ordering system written in x86 assembly for MS-DOS. It runs as a classic text-mode terminal app: log in (or register a new account), then order food, manage a cart, check out, and look back through your order history — all from a set of numbered menus.

Repository: https://github.com/atrocria/asm_assignment

## Features

- **Login / Register** — sign in with an existing account or create a new one before the app lets you in.
- **Place Order** — browse a short food menu (Burger, Nasi Lemak, Egg Fried Rice, 2pcs Fried Chicken) and add items to your cart.
- **View Cart** — see what you've added, the quantities, and the running total, with the option to head to checkout.
- **Checkout** — a receipt with subtotal, tax, and total due; pay Cash on Delivery or by card (card payment asks for the cardholder name, card number, and CVV, and validates each one); enter a delivery location; see an estimated delivery time for the order.
- **Order History** — every order you've completed, listed out, plus a grand total across all of them.
- **Logout / Quit** — leave your account or exit the program.

## How it's put together

The app is split into small, single-purpose modules that main.asm ties together:

- `main.asm` — application entry point and top-level navigation between screens.
- `login.asm` — login, registration, and logout.
- `menu.asm` — the food menu and adding items to the cart.
- `cart.asm` — cart state and the "View Cart" screen.
- `checkout.asm` — the checkout flow (receipt, payment, delivery details) and order history.
- `tools.asm` — shared low-level helpers for screen and keyboard I/O used by the other modules.

## Requirements

DeliGo targets real 16-bit DOS, so running it today means either genuine DOS hardware or a DOS environment such as DOSBox. Building it from source requires an x86 assembler compatible with MASM-style syntax (this project was written against MASM 5.10) and a matching linker.

## Running it

Assemble each `.asm` source file into an object file, link the resulting objects together into a single `.EXE`, and run that executable in your DOS environment. The exact commands depend on the assembler and linker you have available.

## License

MIT — see [LICENSE](LICENSE).
