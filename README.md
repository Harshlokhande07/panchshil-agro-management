# Panchshil Agro Agencies - Agro Shop Inventory & Credit Management System (DBMS Lab Practical 5)

A beginner-friendly web application built for the college DBMS Lab to demonstrate **Creation, Modification, Manipulation, Authorization and Views** of a MySQL database, with frontend-backend database connectivity. 

- **Database:** MySQL 8 (`PanchshilAgro`) - structure defined by `PanchshilAgro_MySQL.sql` (7 tables). No existing table structure was changed. Only the new table `app_user` was added for web login.
- **Backend:** Node.js + Express (`mysql2` with connection pool, **parameterized queries only**)
- **Frontend:** Plain HTML, CSS, JavaScript + Bootstrap 5 (no heavy framework)
- **Auth:** Session-based login with role-based access control (admin/staff/accountant)

## Tech Stack
- Node.js + Express
- mysql2
- express-session
- bcryptjs
- dotenv
- Bootstrap 5 + Chart.js (CDN)

## Folder Structure
```
.
├── .env.example
├── .gitignore
├── PanchshilAgro_MySQL.sql        # Creates DB + 7 tables (source of truth)
├── PanchshilAgro_Practical_4.sql # Views, Procedures, Functions, Triggers, Sample data, Users/Roles
├── package.json
├── README.md
├── server.js
├── db/
│   ├── app_user.sql
│   ├── pool.js
│   └── seedAppUsers.js
├── middleware/
│   └── auth.js
├── public/
│   ├── app.html
│   ├── login.html
│   ├── css/style.css
│   ├── js/app.js
│   ├── js/login.js
│   └── modules/*.html
└── routes/
    ├── credit.js
    ├── customers.js
    ├── dashboard.js
    ├── inventory.js
    ├── payments.js
    ├── privileges.js
    ├── products.js
    ├── routines.js
    ├── sql.js
    ├── suppliers.js
    └── warranty.js
```

## ER-to-Table Summary (with relationships)
**7 business tables (from `PanchshilAgro_MySQL.sql`):**
1. `Customer(customer_id PK, name, phone, address)`
2. `Supplier(supplier_id PK, name, phone, email)`
3. `Product(product_id PK, supplier_id FK -> Supplier, product_name, category(Fertilizer/Pesticide/Seed/Equipment), brand, purchase_price, selling_price, min_stock)`
4. `Inventory(inventory_id PK, product_id FK -> Product, batch_no, expiry_date NULL, shelf_qty, godown_qty)` - `UNIQUE(product_id,batch_no)`
5. `Credit(credit_id PK, customer_id FK -> Customer, total_due, amount_paid, due_date, status ENUM('Pending','Partial','Paid','Overdue'))`
6. `Payment(payment_id PK, customer_id FK -> Customer, credit_id FK NULL -> Credit, amount, payment_date, mode ENUM('Cash','UPI','Card'))` - `credit_id NULL` for direct cash sales
7. `Warranty(warranty_id PK, product_id FK -> Product, customer_id FK -> Customer, batch_no, start_date, end_date, return_reason, supplier_status ENUM('Sent','Replaced','Rejected'))`

**Additional tables/objects used:**
- `Price_Audit(audit_id PK, product_id, old_price, new_price, changed_on)` - created by `PanchshilAgro_Practical_4.sql` via trigger `trg_product_after_update`
- `app_user(user_id PK, username UNIQUE, password_hash(bcrypt), role ENUM('admin','staff','accountant'), created_at)` - **only new table added by this app**

**Relationships:**
- Supplier 1:N Product
- Product 1:N Inventory, Product 1:N Warranty
- Customer 1:N Credit, Customer 1:N Payment, Customer 1:N Warranty
- Credit 1:N Payment

## Setup Steps (Numbered)
1. **Start MySQL** (MySQL 8) and open MySQL Workbench / CLI as root/admin.
2. **Create database and base tables:** Run `PanchshilAgro_MySQL.sql` in MySQL. This creates database `PanchshilAgro` and the 7 tables.
3. **Create views, procedures, functions, triggers, sample data & MySQL users/roles:** Run `PanchshilAgro_Practical_4.sql`.  
   - *Note:* This file reloads sample data each time it runs (truncates tables).  
   - *Note:* Part E creates MySQL users/roles (`shop_owner`, `shop_staff`, `shop_accountant`, `agro_report_viewer`). If you don't have privileges to create users, you may skip that section - the app's **"DB Users & Privileges"** page will still display grants if users exist, or show errors gracefully.
4. **Install Node dependencies:** In this project folder, open terminal and run `npm install`.
5. **Configure environment:** Copy `.env.example` to `.env` and fill in `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME=PanchshilAgro`, `SESSION_SECRET` (long random string), `PORT` (default 3000).
6. **Create and seed app users:** Run `npm run seed:users`. This creates the `app_user` table (if missing) and seeds one user per role with **bcrypt** hashed passwords.
7. **Start the server:** Run `npm start` (or `npm run dev`). Open [http://localhost:3000](http://localhost:3000).

## Default Login Details
| Role | Username | Password | Permissions |
|------|----------|----------|-------------|
| Admin (shop_owner) | `admin` | `Admin@123` | Full access - create/update/delete everything, access "DB Users & Privileges", can manage all modules |
| Staff (counter) | `staff` | `Staff@123` | View products/stock, add customers, record payments, move stock to shelf. Cannot edit prices/restock/delete. |
| Accountant | `accountant` | `Account@123` | Read-only access to Credit/Payment, outstanding view and dashboard |

*Passwords are stored as bcrypt hashes in `app_user`. Never stored as plain text.*

## Features Implemented
1. **Login & Authorization** - Session login/logout, role checks in UI and server (403), Admin page for DB users/privileges with SHOW GRANTS and GRANT/REVOKE demo.
2. **Dashboard** - Summary cards, products per category, payments by mode, products per supplier, credit by status, outstanding per customer (HAVING), monthly payment chart (Chart.js).
3. **Master Data CRUD** - Suppliers/Products/Customers with validation, search/sort, FK/duplicate/trigger error messages, Price History from `Price_Audit`.
4. **Inventory** - Batch view with `v_stock_summary` badges (Red/Amber/Green), expiring batches via `v_expiring_batches`, add/delete batches (admin), move godown->shelf via `sp_move_to_shelf`.
5. **Credit** - Create entries, list with balance, "Mark overdue accounts" update, delete blocked by trigger for unpaid.
6. **Payments** - Record via `sp_record_payment`, filter/list, totals per customer, `v_customer_outstanding`.
7. **Warranty** - Add/update status, list with joins, returns by status, admin-only delete.
8. **Views & Routines** - Display all 5 views, call `sp_get_low_stock()`, `sp_add_customer`, `sp_customer_statement` (both result sets), test functions with discount capping demo, trigger demos.
9. **SQL Query Viewer** - Each section shows the SQL executed (parameterized form) for learning purposes.

## Notes on Triggers/Behavior
- `trg_payment_before_insert` blocks payment > credit balance (SQLSTATE 45000) - shown in UI.
- `trg_payment_after_insert` updates `Credit.amount_paid` and `Credit.status` automatically. **The app does NOT update Credit after inserting a payment.**
- `trg_product_after_update` writes to `Price_Audit` when `selling_price` changes.
- `trg_inventory_before_insert` blocks already-expired batches.
- `trg_credit_before_delete` blocks deleting unpaid credits.

## Security
- **Parameterized queries everywhere** using `?` placeholders (mysql2). No string concatenation of user input into SQL.
- Role checks enforced on server routes and hidden in UI.
- Passwords hashed with bcrypt.
- Sessions are httpOnly.

## Viva Q&A (10 Likely Questions & Answers)
1. **Q:** Why do triggers update the credit instead of the app?  
   **A:** To enforce business rules at the database level (data integrity). Even if someone inserts directly via SQL, the trigger ensures `amount_paid` and `status` stay correct.

2. **Q:** Difference between a View and a Table?  
   **A:** A table stores data physically. A view is a virtual table defined by a query - it doesn't store data, it shows data from base tables (can simplify joins/security).

3. **Q:** Difference between a Stored Procedure and a Function?  
   **A:** A procedure can return zero/many result sets and may use IN/OUT; called with `CALL`. A function must return a single value and is used in expressions/queries. Procedures are better for complex logic/actions, functions for calculations.

4. **Q:** How do GRANT/REVOKE and roles work?  
   **A:** `GRANT` gives privileges (SELECT/INSERT/EXECUTE etc.) on objects to users/roles. `REVOKE` removes them. Roles group privileges and can be granted to users (`GRANT role TO user`), making privilege management easier.

5. **Q:** What does WITH CHECK OPTION do in a view?  
   **A:** It prevents inserts/updates through the view that would make rows disappear from the view. For `v_fertilizers` (WHERE category='Fertilizer'), inserting a non-Fertilizer would fail.

6. **Q:** Why use parameterized queries?  
   **A:** They prevent SQL Injection by separating SQL code from data. The driver escapes values, so user input cannot change query structure.

7. **Q:** What is the purpose of UNIQUE(product_id, batch_no) in Inventory?  
   **A:** It prevents duplicate batches for the same product - each batch is identified uniquely per product.

8. **Q:** Why is credit_id NULL allowed in Payment?  
   **A:** To record direct cash sales not tied to any credit/udhari entry. The trigger only updates Credit if `credit_id` is NOT NULL.

9. **Q:** What does sp_customer_statement return?  
   **A:** Two result sets - first shows all credit accounts for the customer (with balance), second shows all payments made by that customer.

10. **Q:** Why is fn_discounted_price capped at 25%?  
   **A:** Business rule in the function uses `LEAST(p_discount_pct, 25)`, so even if 30% is requested, only 25% discount is applied.

## How to run (quick)
```bash
npm install
# copy .env.example to .env and set DB creds
npm run seed:users
npm start
# open http://localhost:3000
```

## Final Notes
- All table/view/procedure/function/trigger names match the SQL files exactly.
- No SQL built by string concatenation with user input - only `?` placeholders.
- Role checks exist in UI and server routes.
- App never updates `Credit` after payment - `trg_payment_after_insert` handles it.
- If MySQL isn't available in this environment, DB-dependent features couldn't be tested live, but the code follows all requirements from the SQL files.

# panchshil-agro-management
