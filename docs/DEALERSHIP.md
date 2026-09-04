# Vehicle dealership

Premium Deluxe Motorsport is located at `-56.74, -1096.62, 26.42`. Enter the orange marker and press `E`.

Players can search and filter the live catalog by category and brand, inspect a 3D preview, rotate it, take an authorized 60-second test drive, and buy an in-stock vehicle. Purchases prefer bank balance, fall back to cash, decrement stock server-side, generate a unique plate, and store the owned vehicle at Legion Garage.

Admins level 3+ use `/dealershipadmin` to add vehicles or edit their display name, brand, category, price, stock, availability, test-drive setting, and display order. Selecting **DELETE SELECTED** removes only the catalog entry; vehicles already owned by players are preserved. Administrative changes are recorded in `dealership_admin_log`.

Database tables and starter stock are created by `sql/12-dealership.sql`. The migration is idempotent: existing catalog rows and admin changes are not overwritten by later deployments.
