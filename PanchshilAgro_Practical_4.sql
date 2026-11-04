-- =====================================================================
-- DBMS Lab - Practical 4: Views, Stored Procedures, Functions, Triggers
--                         and Authorization (GRANT / REVOKE)
-- Database : PanchshilAgro (Practical 2(b))      Tool: MySQL Workbench 8.0
-- Run the full file (Ctrl+Shift+Enter) as the root / admin user.
-- Part E (users and privileges) needs an account that can create users.
-- Each SELECT / CALL opens its own result tab.
-- =====================================================================

-- ---------------------------------------------------------------------
-- SETUP: clears the 7 tables and reloads sample data (re-runnable).
-- Needs the PanchshilAgro tables from Practical 2(b) to exist.
-- ---------------------------------------------------------------------
USE PanchshilAgro;

-- Remove triggers/audit table from an earlier run so the sample data loads cleanly
DROP TRIGGER IF EXISTS trg_payment_before_insert;
DROP TRIGGER IF EXISTS trg_payment_after_insert;
DROP TRIGGER IF EXISTS trg_product_after_update;
DROP TRIGGER IF EXISTS trg_inventory_before_insert;
DROP TRIGGER IF EXISTS trg_credit_before_delete;
DROP TABLE IF EXISTS Price_Audit;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Warranty;
TRUNCATE TABLE Payment;
TRUNCATE TABLE Credit;
TRUNCATE TABLE Inventory;
TRUNCATE TABLE Product;
TRUNCATE TABLE Supplier;
TRUNCATE TABLE Customer;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO Customer (name, phone, address) VALUES
('Ramesh Patil',  '9822011111', 'Kamptee, Nagpur'),
('Suresh Wankhede','9822022222', 'Hingna, Nagpur'),
('Anita Deshmukh','9822033333', 'Katol, Nagpur'),
('Prakash Meshram','9822044444', 'Umred, Nagpur'),
('Rajendra Bhoyar','9822055555', 'Saoner, Nagpur'),
('Vijay Raut',    '9822066666', 'Kalmeshwar, Nagpur');

INSERT INTO Supplier (name, phone, email) VALUES
('IFFCO Distributors',      '9870011111', 'sales@iffcodist.example.com'),
('UPL Agro Supply',         '9870022222', 'orders@uplsupply.example.com'),
('Mahyco Seeds Agency',     '9870033333', 'info@mahycoseeds.example.com'),
('Kisan Tools & Equipment', '9870044444', 'contact@kisantools.example.com');

INSERT INTO Product (supplier_id, product_name, category, brand, purchase_price, selling_price, min_stock) VALUES
(1, 'Urea 45kg',                 'Fertilizer', 'IFFCO',   250.00,  300.00, 20),
(1, 'DAP 50kg',                  'Fertilizer', 'IFFCO',  1200.00, 1350.00, 15),
(2, 'Roundup Herbicide 1L',      'Pesticide',  'Bayer',   600.00,  720.00, 10),
(2, 'Confidor Insecticide 250ml','Pesticide',  'Bayer',   380.00,  450.00, 10),
(3, 'Cotton Seed BG-II 450g',    'Seed',       'Mahyco',  700.00,  810.00, 25),
(3, 'Soybean Seed 30kg',         'Seed',       'Mahyco', 2400.00, 2700.00, 10),
(4, 'Knapsack Sprayer 16L',      'Equipment',  'Kisan',  1500.00, 1800.00,  5),
(4, 'Drip Irrigation Kit',       'Equipment',  'Kisan',  3200.00, 3800.00,  3),
(2, 'NPK 19:19:19 1kg',          'Fertilizer', 'UPL',     140.00,  170.00, 30),
(2, 'Mancozeb Fungicide 500g',   'Pesticide',  'UPL',     210.00,  260.00, 12);

INSERT INTO Inventory (product_id, batch_no, expiry_date, shelf_qty, godown_qty) VALUES
(1,  'U-2607',      '2028-07-31', 10,  8),
(2,  'D-2605',      '2028-05-31', 20, 40),
(2,  'D-2609',      '2028-09-30',  0, 30),
(3,  'RU-2604',     '2027-04-30',  6, 10),
(4,  'CF-2605',     '2026-12-15',  4,  2),
(5,  'MH-CT-0926',  '2027-03-31', 15, 50),
(6,  'MH-SB-0926',  '2027-02-28',  5, 12),
(7,  'KS-2026-01',  NULL,          3,  6),
(8,  'KD-2026-03',  NULL,          1,  1),
(9,  'NPK-2608',    '2027-08-31', 25, 40),
(10, 'MZ-2606',     '2026-11-30',  8,  0);

INSERT INTO Credit (customer_id, total_due, amount_paid, due_date, status) VALUES
(1,  5000.00, 2000.00, '2026-11-15', 'Partial'),
(2, 12000.00,    0.00, '2026-10-05', 'Overdue'),
(3,  3500.00, 3500.00, '2026-10-10', 'Paid'),
(4,  8000.00,    0.00, '2026-12-01', 'Pending'),
(1,  2500.00,    0.00, '2026-11-30', 'Pending'),
(5, 15000.00, 6000.00, '2026-10-01', 'Overdue');

INSERT INTO Payment (customer_id, credit_id, amount, payment_date, mode) VALUES
(1, 1,    2000.00, '2026-10-01', 'UPI'),
(3, 3,    3500.00, '2026-10-10', 'Cash'),
(5, 6,    6000.00, '2026-09-20', 'Cash'),
(2, NULL, 1850.00, '2026-10-12', 'Cash'),
(4, NULL, 4500.00, '2026-10-14', 'UPI'),
(6, NULL,  810.00, '2026-10-15', 'Card'),
(1, NULL,  300.00, '2026-10-16', 'Cash'),
(3, NULL, 2700.00, '2026-10-17', 'UPI');

INSERT INTO Warranty (product_id, customer_id, batch_no, start_date, end_date, return_reason, supplier_status) VALUES
(7, 2, 'KS-2026-01', '2026-06-01', '2027-06-01', 'Pump leakage',              'Sent'),
(4, 1, 'CF-2605',    '2026-07-10', '2027-07-10', 'Expired product delivered', 'Replaced'),
(5, 4, 'MH-CT-0926', '2026-09-05', '2026-12-05', 'Low germination',           'Rejected'),
(8, 6, 'KD-2026-03', '2026-08-01', '2027-08-01', 'Damaged pipe',              'Sent');


SET SQL_SAFE_UPDATES = 0;   -- switched back on at the end of the file

-- =====================================================================
-- PART A: VIEWS
-- =====================================================================

-- 1. Product with its supplier (hides the join from the user)
CREATE OR REPLACE VIEW v_product_supplier AS
SELECT p.product_id, p.product_name, p.category, p.brand,
       p.selling_price, s.name AS supplier, s.phone AS supplier_phone
FROM Product p
JOIN Supplier s ON p.supplier_id = s.supplier_id;

SELECT * FROM v_product_supplier;

-- 2. Stock summary with colour-style status (Red / Amber / Green)
CREATE OR REPLACE VIEW v_stock_summary AS
SELECT p.product_id, p.product_name, p.category, p.min_stock,
       COALESCE(SUM(i.shelf_qty), 0)                AS shelf_qty,
       COALESCE(SUM(i.godown_qty), 0)               AS godown_qty,
       COALESCE(SUM(i.shelf_qty + i.godown_qty), 0) AS total_stock,
       CASE
           WHEN COALESCE(SUM(i.shelf_qty + i.godown_qty), 0) = 0          THEN 'Out of Stock (Red)'
           WHEN COALESCE(SUM(i.shelf_qty + i.godown_qty), 0) < p.min_stock THEN 'Low Stock (Amber)'
           ELSE 'Available (Green)'
       END AS stock_status
FROM Product p
LEFT JOIN Inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.category, p.min_stock;

SELECT * FROM v_stock_summary;

-- 3. Customers who still owe money
CREATE OR REPLACE VIEW v_customer_outstanding AS
SELECT c.customer_id, c.name, c.phone,
       SUM(cr.total_due - cr.amount_paid) AS outstanding
FROM Customer c
JOIN Credit cr ON c.customer_id = cr.customer_id
GROUP BY c.customer_id, c.name, c.phone
HAVING SUM(cr.total_due - cr.amount_paid) > 0;

SELECT * FROM v_customer_outstanding ORDER BY outstanding DESC;

-- 4. Batches expiring in the next 90 days
CREATE OR REPLACE VIEW v_expiring_batches AS
SELECT p.product_name, i.batch_no, i.expiry_date,
       (i.shelf_qty + i.godown_qty) AS qty_left,
       DATEDIFF(i.expiry_date, CURDATE()) AS days_left
FROM Inventory i
JOIN Product p ON i.product_id = p.product_id
WHERE i.expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 90 DAY);

SELECT * FROM v_expiring_batches;

-- 5. Updatable view with WITH CHECK OPTION (only fertilizers allowed through it)
CREATE OR REPLACE VIEW v_fertilizers AS
SELECT product_id, supplier_id, product_name, category, brand,
       purchase_price, selling_price, min_stock
FROM Product
WHERE category = 'Fertilizer'
WITH CHECK OPTION;

INSERT INTO v_fertilizers
       (supplier_id, product_name, category, brand, purchase_price, selling_price, min_stock)
VALUES (1, 'Ammonium Sulphate 50kg', 'Fertilizer', 'IFFCO', 700.00, 800.00, 10);

SELECT * FROM v_fertilizers;

-- This FAILS on purpose (Error 1369: CHECK OPTION failed). Uncomment to demonstrate.
-- INSERT INTO v_fertilizers (supplier_id, product_name, category, brand, purchase_price, selling_price, min_stock)
-- VALUES (3, 'Wheat Seed 10kg', 'Seed', 'Mahyco', 400.00, 480.00, 10);

DELETE FROM v_fertilizers WHERE product_name = 'Ammonium Sulphate 50kg';

-- List all views in the database
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- =====================================================================
-- PART B: STORED PROCEDURES
-- =====================================================================
DELIMITER $$

-- 1. IN and OUT parameters: add a customer and return the new id
DROP PROCEDURE IF EXISTS sp_add_customer$$
CREATE PROCEDURE sp_add_customer(
    IN  p_name        VARCHAR(100),
    IN  p_phone       VARCHAR(15),
    IN  p_address     VARCHAR(255),
    OUT p_customer_id INT)
BEGIN
    INSERT INTO Customer (name, phone, address)
    VALUES (p_name, p_phone, p_address);
    SET p_customer_id = LAST_INSERT_ID();
END$$

-- 2. No parameters: products that must be reordered
DROP PROCEDURE IF EXISTS sp_get_low_stock$$
CREATE PROCEDURE sp_get_low_stock()
BEGIN
    SELECT product_id, product_name, total_stock, min_stock,
           (min_stock - total_stock) AS reorder_qty
    FROM v_stock_summary
    WHERE total_stock < min_stock
    ORDER BY reorder_qty DESC;
END$$

-- 3. Condition checking and error handling: godown -> shelf transfer
DROP PROCEDURE IF EXISTS sp_move_to_shelf$$
CREATE PROCEDURE sp_move_to_shelf(IN p_inventory_id INT, IN p_qty INT)
BEGIN
    DECLARE v_godown INT;

    SELECT godown_qty INTO v_godown
    FROM Inventory
    WHERE inventory_id = p_inventory_id;

    IF v_godown IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory batch not found';
    ELSEIF p_qty <= 0 OR p_qty > v_godown THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid quantity: not enough stock in godown';
    ELSE
        UPDATE Inventory
        SET shelf_qty  = shelf_qty + p_qty,
            godown_qty = godown_qty - p_qty
        WHERE inventory_id = p_inventory_id;

        SELECT inventory_id, batch_no, shelf_qty, godown_qty
        FROM Inventory
        WHERE inventory_id = p_inventory_id;
    END IF;
END$$

-- 4. Record a payment (the credit balance is updated by a trigger in Part D)
DROP PROCEDURE IF EXISTS sp_record_payment$$
CREATE PROCEDURE sp_record_payment(
    IN p_customer_id INT,
    IN p_credit_id   INT,            -- pass NULL for a direct cash sale
    IN p_amount      DECIMAL(10,2),
    IN p_mode        VARCHAR(10))    -- Cash / UPI / Card
BEGIN
    INSERT INTO Payment (customer_id, credit_id, amount, payment_date, mode)
    VALUES (p_customer_id, p_credit_id, p_amount, CURDATE(), p_mode);

    SELECT 'Payment recorded' AS message, LAST_INSERT_ID() AS payment_id;
END$$

-- 5. Customer statement: credit accounts and payments (two result sets)
DROP PROCEDURE IF EXISTS sp_customer_statement$$
CREATE PROCEDURE sp_customer_statement(IN p_customer_id INT)
BEGIN
    SELECT credit_id, total_due, amount_paid,
           (total_due - amount_paid) AS balance, due_date, status
    FROM Credit
    WHERE customer_id = p_customer_id;

    SELECT payment_id, credit_id, amount, payment_date, mode
    FROM Payment
    WHERE customer_id = p_customer_id
    ORDER BY payment_date;
END$$

DELIMITER ;

-- ---- Demonstration ----
CALL sp_add_customer('Mohan Thakre', '9822077777', 'Ramtek, Nagpur', @new_id);
SELECT @new_id AS new_customer_id;

CALL sp_get_low_stock();
CALL sp_move_to_shelf(3, 10);        -- move 10 units of batch D-2609 to the shelf
CALL sp_customer_statement(1);

-- This FAILS on purpose (custom error 45000). Uncomment to demonstrate.
-- CALL sp_move_to_shelf(3, 9999);

SHOW PROCEDURE STATUS WHERE Db = 'PanchshilAgro';

-- =====================================================================
-- PART C: FUNCTIONS
-- =====================================================================
DELIMITER $$

-- 1. Profit margin (%) of a product
DROP FUNCTION IF EXISTS fn_profit_margin$$
CREATE FUNCTION fn_profit_margin(p_product_id INT)
RETURNS DECIMAL(6,2)
READS SQL DATA
BEGIN
    DECLARE v_margin DECIMAL(6,2);
    SELECT ROUND((selling_price - purchase_price) / purchase_price * 100, 2)
    INTO v_margin
    FROM Product
    WHERE product_id = p_product_id;
    RETURN v_margin;
END$$

-- 2. Total stock (shelf + godown) of a product
DROP FUNCTION IF EXISTS fn_total_stock$$
CREATE FUNCTION fn_total_stock(p_product_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT;
    SELECT COALESCE(SUM(shelf_qty + godown_qty), 0)
    INTO v_total
    FROM Inventory
    WHERE product_id = p_product_id;
    RETURN v_total;
END$$

-- 3. Outstanding credit balance of a customer
DROP FUNCTION IF EXISTS fn_customer_balance$$
CREATE FUNCTION fn_customer_balance(p_customer_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_balance DECIMAL(10,2);
    SELECT COALESCE(SUM(total_due - amount_paid), 0)
    INTO v_balance
    FROM Credit
    WHERE customer_id = p_customer_id;
    RETURN v_balance;
END$$

-- 4. Selling price after discount; the shop's maximum discount is 25% of MRP
DROP FUNCTION IF EXISTS fn_discounted_price$$
CREATE FUNCTION fn_discounted_price(p_product_id INT, p_discount_pct DECIMAL(5,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_price DECIMAL(10,2);
    SELECT selling_price INTO v_price
    FROM Product
    WHERE product_id = p_product_id;
    RETURN ROUND(v_price * (1 - LEAST(p_discount_pct, 25) / 100), 2);
END$$

-- 5. Stock status label (no table access, so DETERMINISTIC)
DROP FUNCTION IF EXISTS fn_stock_status$$
CREATE FUNCTION fn_stock_status(p_total INT, p_min INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_status VARCHAR(20);
    IF p_total = 0 THEN
        SET v_status = 'Out of Stock';
    ELSEIF p_total < p_min THEN
        SET v_status = 'Low Stock';
    ELSE
        SET v_status = 'Available';
    END IF;
    RETURN v_status;
END$$

DELIMITER ;

-- ---- Demonstration ----
SELECT product_name,
       fn_profit_margin(product_id)                          AS margin_pct,
       fn_total_stock(product_id)                            AS total_stock,
       fn_stock_status(fn_total_stock(product_id), min_stock) AS status
FROM Product;

SELECT customer_id, name, fn_customer_balance(customer_id) AS balance
FROM Customer;

-- 30% asked, but only 25% is allowed: Urea (300.00) becomes 225.00
SELECT product_name, selling_price,
       fn_discounted_price(product_id, 10) AS price_10_pct_off,
       fn_discounted_price(product_id, 30) AS price_30_asked_25_given
FROM Product
WHERE product_id = 1;

SHOW FUNCTION STATUS WHERE Db = 'PanchshilAgro';

-- =====================================================================
-- PART D: TRIGGERS
-- =====================================================================

-- Audit table used by the price-change trigger
DROP TABLE IF EXISTS Price_Audit;
CREATE TABLE Price_Audit (
    audit_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_id  INT NOT NULL,
    old_price   DECIMAL(10,2),
    new_price   DECIMAL(10,2),
    changed_on  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER $$

-- 1. BEFORE INSERT: block a payment larger than the credit balance
DROP TRIGGER IF EXISTS trg_payment_before_insert$$
CREATE TRIGGER trg_payment_before_insert
BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_balance DECIMAL(10,2);
    IF NEW.credit_id IS NOT NULL THEN
        SELECT total_due - amount_paid INTO v_balance
        FROM Credit
        WHERE credit_id = NEW.credit_id;
        IF NEW.amount > v_balance THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment exceeds outstanding credit balance';
        END IF;
    END IF;
END$$

-- 2. AFTER INSERT: update the credit account when a payment is made
--    (status is assigned first so it uses the amount_paid value from before this payment)
DROP TRIGGER IF EXISTS trg_payment_after_insert$$
CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    IF NEW.credit_id IS NOT NULL THEN
        UPDATE Credit
        SET status      = CASE WHEN amount_paid + NEW.amount >= total_due
                               THEN 'Paid' ELSE 'Partial' END,
            amount_paid = amount_paid + NEW.amount
        WHERE credit_id = NEW.credit_id;
    END IF;
END$$

-- 3. AFTER UPDATE: log every change of selling price
DROP TRIGGER IF EXISTS trg_product_after_update$$
CREATE TRIGGER trg_product_after_update
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    IF OLD.selling_price <> NEW.selling_price THEN
        INSERT INTO Price_Audit (product_id, old_price, new_price)
        VALUES (OLD.product_id, OLD.selling_price, NEW.selling_price);
    END IF;
END$$

-- 4. BEFORE INSERT: do not allow an already-expired batch into stock
DROP TRIGGER IF EXISTS trg_inventory_before_insert$$
CREATE TRIGGER trg_inventory_before_insert
BEFORE INSERT ON Inventory
FOR EACH ROW
BEGIN
    IF NEW.expiry_date IS NOT NULL AND NEW.expiry_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot stock an already expired batch';
    END IF;
END$$

-- 5. BEFORE DELETE: unpaid credit records cannot be deleted
DROP TRIGGER IF EXISTS trg_credit_before_delete$$
CREATE TRIGGER trg_credit_before_delete
BEFORE DELETE ON Credit
FOR EACH ROW
BEGIN
    IF OLD.status <> 'Paid' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unpaid credit record cannot be deleted';
    END IF;
END$$

DELIMITER ;

SHOW TRIGGERS;

-- ---- Demonstration ----
-- Trigger 1 + 2: part payment on credit 4 (due 8000) -> amount_paid 1500, status Partial
CALL sp_record_payment(4, 4, 1500.00, 'UPI');
SELECT credit_id, total_due, amount_paid, status FROM Credit WHERE credit_id = 4;

-- Full payment on credit 5 (due 2500) -> status becomes Paid
CALL sp_record_payment(1, 5, 2500.00, 'Cash');
SELECT credit_id, total_due, amount_paid, status FROM Credit WHERE credit_id = 5;

-- Trigger 3: change prices and read the audit log
UPDATE Product SET selling_price = 320.00  WHERE product_id = 1;
UPDATE Product SET selling_price = 1400.00 WHERE product_id = 2;
SELECT * FROM Price_Audit;

-- The three statements below FAIL on purpose (custom error 45000).
-- Uncomment ONE at a time to demonstrate the trigger.
-- CALL sp_record_payment(2, 2, 99999.00, 'Cash');                       -- trigger 1
-- INSERT INTO Inventory (product_id, batch_no, expiry_date, shelf_qty, godown_qty)
-- VALUES (1, 'OLD-2020', '2020-01-01', 5, 5);                           -- trigger 4
-- DELETE FROM Credit WHERE credit_id = 2;                               -- trigger 5

-- =====================================================================
-- PART E: AUTHORIZATION (users, GRANT, REVOKE, roles)
-- =====================================================================

-- 1. Create users
CREATE USER IF NOT EXISTS 'shop_owner'@'localhost'      IDENTIFIED BY 'Owner@2026';
CREATE USER IF NOT EXISTS 'shop_staff'@'localhost'      IDENTIFIED BY 'Staff@2026';
CREATE USER IF NOT EXISTS 'shop_accountant'@'localhost' IDENTIFIED BY 'Account@2026';

-- 2. Owner: full control of the PanchshilAgro database
GRANT ALL PRIVILEGES ON PanchshilAgro.* TO 'shop_owner'@'localhost';

-- 3. Staff (counter): see products and stock, record payments, move stock
GRANT SELECT ON PanchshilAgro.Product         TO 'shop_staff'@'localhost';
GRANT SELECT ON PanchshilAgro.Customer        TO 'shop_staff'@'localhost';
GRANT SELECT ON PanchshilAgro.v_stock_summary TO 'shop_staff'@'localhost';
GRANT INSERT ON PanchshilAgro.Payment         TO 'shop_staff'@'localhost';
GRANT EXECUTE ON PROCEDURE PanchshilAgro.sp_record_payment TO 'shop_staff'@'localhost';
GRANT EXECUTE ON PROCEDURE PanchshilAgro.sp_move_to_shelf  TO 'shop_staff'@'localhost';

-- 4. Accountant: read-only access to money-related data
GRANT SELECT ON PanchshilAgro.Credit                 TO 'shop_accountant'@'localhost';
GRANT SELECT ON PanchshilAgro.Payment                TO 'shop_accountant'@'localhost';
GRANT SELECT ON PanchshilAgro.v_customer_outstanding TO 'shop_accountant'@'localhost';

-- 5. View the privileges
SHOW GRANTS FOR 'shop_owner'@'localhost';
SHOW GRANTS FOR 'shop_staff'@'localhost';
SHOW GRANTS FOR 'shop_accountant'@'localhost';

-- 6. REVOKE: staff may no longer insert payments directly
REVOKE INSERT ON PanchshilAgro.Payment FROM 'shop_staff'@'localhost';
SHOW GRANTS FOR 'shop_staff'@'localhost';

-- 7. Roles (MySQL 8.0): a reusable read-only role given to the accountant
CREATE ROLE IF NOT EXISTS 'agro_report_viewer';
GRANT SELECT ON PanchshilAgro.* TO 'agro_report_viewer';
GRANT 'agro_report_viewer' TO 'shop_accountant'@'localhost';
SHOW GRANTS FOR 'shop_accountant'@'localhost' USING 'agro_report_viewer';

-- 8. Optional clean-up (uncomment to remove everything created in Part E)
-- DROP USER IF EXISTS 'shop_owner'@'localhost';
-- DROP USER IF EXISTS 'shop_staff'@'localhost';
-- DROP USER IF EXISTS 'shop_accountant'@'localhost';
-- DROP ROLE IF EXISTS 'agro_report_viewer';

SET SQL_SAFE_UPDATES = 1;
