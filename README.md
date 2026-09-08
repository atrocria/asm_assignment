# DeliGo School assignment project Y2S1

DeliGo is a food delivery and ordering system written in x86 assembly for MS-DOS. It runs as a classic text-mode terminal app: log in (or register a new account), then order food, manage a cart, check out, and look back through your order history — all from a set of numbered menus.

Repository: https://github.com/atrocria/asm_assignment

## Features

- **Login / Register** — sign in with an existing account, or register a new one by choosing a username/password and one of 3 fixed delivery addresses.
- **10% Proximity Discount** — two of the three delivery addresses offered at registration (plus the built-in `admin` account) carry a standing 10% discount; the third one doesn't. It's a fixed, hardcoded fact per address/account — nothing is calculated to decide who qualifies — and once set at registration it's applied automatically everywhere a price is shown: the menu, the cart, and the checkout receipt.
- **Place Order** — browse a short food menu (Burger, Nasi Lemak, Egg Fried Rice, 2pcs Fried Chicken) and add items to your cart, discount already reflected in the price shown.
- **View Cart** — see what you've added, the quantities, and the running total, with the option to head to checkout.
- **Checkout** — a receipt with subtotal, discount (if any), tax, and total due; pay Cash on Delivery or by card (card payment asks for the cardholder name, card number, and CVV, and validates each one); delivers to the address saved on your account, with an estimated delivery time.
- **Order History** — every order you've completed, listed out, plus a grand total across all of them.
- **Logout / Quit** — leave your account or exit the program.

## How it's put together

The app is split into small, single-purpose modules that main.asm ties together:

- `main.asm` — application entry point and top-level navigation between screens.
- `login.asm` — login, registration (including the 3 fixed delivery addresses and which ones carry the 10% discount), and logout.
- `menu.asm` — the food menu and adding items to the cart.
- `cart.asm` — cart state, prices, and the 10% discount applied per item.
- `checkout.asm` — the checkout flow (receipt, payment, delivery details) and order history.
- `tools.asm` — shared low-level helpers for screen and keyboard I/O used by the other modules.

Heavily commented throughout, on purpose: most of the pricing/discount logic is written as plain, hardcoded if/else cases rather than generic loops or lookup tables, so it's easy to read and explain line by line.

## Requirements

DeliGo targets real 16-bit DOS, so running it today means either genuine DOS hardware or a DOS environment such as DOSBox. Building it from source requires an x86 assembler compatible with MASM-style syntax (this project was written against MASM 5.10) and a matching linker — both are bundled in this repo (`MASM.EXE`, `LINK.EXE`).

## Running it

On Windows with [DOSBox](https://www.dosbox.com/) (or DOSBox-X) installed, just run `build.cmd` (or `build.ps1` directly) from the project root. It assembles every module in `src/` with the bundled `MASM.EXE`, links them into `main.exe`, and launches it in DOSBox automatically. Assembly/link output goes to `BUILD.LOG`, and `BUILD.OK` / `BUILD.FAI` mark whether the build succeeded.

Building by hand (or on another platform) works the same way any MASM 5.10 project does: assemble each `.asm` file in `src/` into an object file, link the objects together into a single `.EXE`, and run that in any DOS environment.

## License

MIT — see [LICENSE](LICENSE).
