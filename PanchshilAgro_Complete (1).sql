-- Panchshil Agro | MySQL 8.0.16+ (not MariaDB)
-- Educational / web-application starter. All people and contact data are synthetic.
-- WARNING: rebuilding this database PERMANENTLY DELETES its existing data.
-- Run using MySQL Workbench (execute whole script) or mysql CLI; DELIMITER is a client directive.
SET NAMES utf8mb4;
DROP DATABASE IF EXISTS PanchshilAgro;
CREATE DATABASE PanchshilAgro CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE PanchshilAgro;
CREATE TABLE customers (
customer_id INT AUTO_INCREMENT PRIMARY KEY, customer_code VARCHAR(20) NOT NULL UNIQUE, first_name VARCHAR(60) NOT NULL, last_name VARCHAR(60) NOT NULL, email VARCHAR(254) NOT NULL UNIQUE, phone VARCHAR(25), customer_type ENUM('FARMER','RETAILER','WHOLESALER') NOT NULL DEFAULT 'FARMER', is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE customer_addresses (
address_id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT NOT NULL, address_type ENUM('BILLING','SHIPPING') NOT NULL, address_line VARCHAR(255) NOT NULL, city VARCHAR(80) NOT NULL, state_name VARCHAR(80) NOT NULL, postal_code VARCHAR(12) NOT NULL, country_code CHAR(2) NOT NULL DEFAULT 'IN', UNIQUE(customer_id,address_type), FOREIGN KEY(customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE employees (
employee_id INT AUTO_INCREMENT PRIMARY KEY, full_name VARCHAR(120) NOT NULL, job_title VARCHAR(80) NOT NULL, email VARCHAR(254) UNIQUE, hired_on DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE categories (
category_id INT AUTO_INCREMENT PRIMARY KEY, category_name VARCHAR(80) NOT NULL UNIQUE, description VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE units (
unit_id INT AUTO_INCREMENT PRIMARY KEY, unit_code VARCHAR(15) NOT NULL UNIQUE, unit_name VARCHAR(60) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE products (
product_id INT AUTO_INCREMENT PRIMARY KEY, sku VARCHAR(30) NOT NULL UNIQUE, product_name VARCHAR(120) NOT NULL, category_id INT NOT NULL, unit_id INT NOT NULL, sale_price DECIMAL(12,2) NOT NULL, reorder_level DECIMAL(12,3) NOT NULL DEFAULT 10, is_active BOOLEAN NOT NULL DEFAULT TRUE, CHECK(sale_price>=0), CHECK(reorder_level>=0), FOREIGN KEY(category_id) REFERENCES categories(category_id), FOREIGN KEY(unit_id) REFERENCES units(unit_id)
) ENGINE=InnoDB;

CREATE TABLE suppliers (
supplier_id INT AUTO_INCREMENT PRIMARY KEY, supplier_name VARCHAR(120) NOT NULL, email VARCHAR(254) UNIQUE, phone VARCHAR(25), city VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE product_suppliers (
product_id INT NOT NULL, supplier_id INT NOT NULL, quoted_cost DECIMAL(12,2) NOT NULL, PRIMARY KEY(product_id,supplier_id), CHECK(quoted_cost>=0), FOREIGN KEY(product_id) REFERENCES products(product_id), FOREIGN KEY(supplier_id) REFERENCES suppliers(supplier_id)
) ENGINE=InnoDB;

CREATE TABLE warehouses (
warehouse_id INT AUTO_INCREMENT PRIMARY KEY, warehouse_name VARCHAR(100) NOT NULL UNIQUE, city VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE inventory (
warehouse_id INT NOT NULL, product_id INT NOT NULL, quantity DECIMAL(12,3) NOT NULL DEFAULT 0, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY(warehouse_id,product_id), CHECK(quantity>=0), FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id), FOREIGN KEY(product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

CREATE TABLE purchase_orders (
purchase_order_id INT AUTO_INCREMENT PRIMARY KEY, supplier_id INT NOT NULL, warehouse_id INT NOT NULL, ordered_on DATE NOT NULL, status ENUM('DRAFT','RECEIVED','CANCELLED') NOT NULL DEFAULT 'DRAFT', FOREIGN KEY(supplier_id) REFERENCES suppliers(supplier_id), FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id)
) ENGINE=InnoDB;

CREATE TABLE purchase_order_items (
purchase_order_id INT NOT NULL, product_id INT NOT NULL, quantity DECIMAL(12,3) NOT NULL, unit_cost DECIMAL(12,2) NOT NULL, PRIMARY KEY(purchase_order_id,product_id), CHECK(quantity>0), CHECK(unit_cost>=0), FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(purchase_order_id), FOREIGN KEY(product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

CREATE TABLE sales_orders (
order_id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT NOT NULL, warehouse_id INT NOT NULL, order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, status ENUM('DRAFT','CONFIRMED','SHIPPED','DELIVERED','CANCELLED') NOT NULL DEFAULT 'DRAFT', shipping_address_snapshot JSON NOT NULL, notes VARCHAR(255), FOREIGN KEY(customer_id) REFERENCES customers(customer_id), FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id), INDEX idx_orders_customer_date(customer_id,order_date), INDEX idx_orders_status_date(status,order_date)
) ENGINE=InnoDB;

CREATE TABLE sales_order_items (
order_id INT NOT NULL, product_id INT NOT NULL, quantity DECIMAL(12,3) NOT NULL, unit_price DECIMAL(12,2) NOT NULL, discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0, tax_percent DECIMAL(5,2) NOT NULL DEFAULT 0, line_total DECIMAL(14,2) GENERATED ALWAYS AS (ROUND(quantity*unit_price*(1-discount_percent/100)*(1+tax_percent/100),2)) STORED, PRIMARY KEY(order_id,product_id), CHECK(quantity>0), CHECK(unit_price>=0), CHECK(discount_percent BETWEEN 0 AND 100), CHECK(tax_percent BETWEEN 0 AND 100), FOREIGN KEY(order_id) REFERENCES sales_orders(order_id), FOREIGN KEY(product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

CREATE TABLE payments (
payment_id INT AUTO_INCREMENT PRIMARY KEY, order_id INT NOT NULL, reference_code VARCHAR(80) NOT NULL UNIQUE, amount DECIMAL(14,2) NOT NULL, method ENUM('CASH','UPI','CARD','BANK') NOT NULL, status ENUM('PENDING','SUCCESS','FAILED','REFUNDED') NOT NULL DEFAULT 'PENDING', paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, CHECK(amount>0), FOREIGN KEY(order_id) REFERENCES sales_orders(order_id), INDEX idx_payments_order_status(order_id,status)
) ENGINE=InnoDB;

CREATE TABLE shipments (
shipment_id INT AUTO_INCREMENT PRIMARY KEY, order_id INT NOT NULL UNIQUE, carrier VARCHAR(80) NOT NULL, tracking_number VARCHAR(100) NOT NULL UNIQUE, shipped_at DATETIME NOT NULL, delivered_at DATETIME NULL, CHECK(delivered_at IS NULL OR delivered_at>=shipped_at), FOREIGN KEY(order_id) REFERENCES sales_orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE inventory_movements (
movement_id BIGINT AUTO_INCREMENT PRIMARY KEY, warehouse_id INT NOT NULL, product_id INT NOT NULL, quantity_delta DECIMAL(12,3) NOT NULL, reason ENUM('OPENING','SALE','PURCHASE','ADJUSTMENT') NOT NULL, order_id INT NULL, purchase_order_id INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, CHECK(quantity_delta<>0), FOREIGN KEY(warehouse_id,product_id) REFERENCES inventory(warehouse_id,product_id), FOREIGN KEY(order_id) REFERENCES sales_orders(order_id), FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(purchase_order_id)
) ENGINE=InnoDB;

-- Credit: customers may buy on account up to a limit; every movement is a ledger row.
CREATE TABLE credit_accounts (
credit_account_id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT NOT NULL UNIQUE, credit_limit DECIMAL(14,2) NOT NULL DEFAULT 0, payment_terms_days SMALLINT NOT NULL DEFAULT 30, is_active BOOLEAN NOT NULL DEFAULT TRUE, opened_on DATE NOT NULL, CHECK(credit_limit>=0), CHECK(payment_terms_days>0), FOREIGN KEY(customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE credit_transactions (
credit_txn_id BIGINT AUTO_INCREMENT PRIMARY KEY, credit_account_id INT NOT NULL, order_id INT NULL, txn_type ENUM('CHARGE','PAYMENT','ADJUSTMENT') NOT NULL, amount DECIMAL(14,2) NOT NULL, due_date DATE NULL, notes VARCHAR(255), created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CHECK(amount>0), FOREIGN KEY(credit_account_id) REFERENCES credit_accounts(credit_account_id), FOREIGN KEY(order_id) REFERENCES sales_orders(order_id), INDEX idx_credit_txn_account(credit_account_id,created_at)
) ENGINE=InnoDB;

-- Warranty: policies are attached to products; claims point at the exact sold order line.
CREATE TABLE warranty_policies (
policy_id INT AUTO_INCREMENT PRIMARY KEY, policy_name VARCHAR(80) NOT NULL UNIQUE, duration_months SMALLINT NOT NULL, terms VARCHAR(255), CHECK(duration_months>0)
) ENGINE=InnoDB;

CREATE TABLE product_warranties (
product_id INT NOT NULL PRIMARY KEY, policy_id INT NOT NULL, FOREIGN KEY(product_id) REFERENCES products(product_id), FOREIGN KEY(policy_id) REFERENCES warranty_policies(policy_id)
) ENGINE=InnoDB;

CREATE TABLE warranty_claims (
claim_id INT AUTO_INCREMENT PRIMARY KEY, order_id INT NOT NULL, product_id INT NOT NULL, claimed_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, issue_description VARCHAR(500) NOT NULL, status ENUM('OPEN','APPROVED','REJECTED','RESOLVED') NOT NULL DEFAULT 'OPEN', resolution VARCHAR(255), resolved_on DATETIME NULL, CHECK(resolved_on IS NULL OR resolved_on>=claimed_on), FOREIGN KEY(order_id,product_id) REFERENCES sales_order_items(order_id,product_id), INDEX idx_claims_status(status,claimed_on)
) ENGINE=InnoDB;

-- Deterministic synthetic seed data; INR amounts, sample tax rates only.
INSERT INTO customers (customer_code,first_name,last_name,email,phone,customer_type) VALUES
('PA-C001','Aarav','Patil','customer001@example.com','DEMO-0001','FARMER'),
('PA-C002','Aditi','Patil','customer002@example.com','DEMO-0002','RETAILER'),
('PA-C003','Ishaan','Patil','customer003@example.com','DEMO-0003','WHOLESALER'),
('PA-C004','Ananya','Patil','customer004@example.com','DEMO-0004','FARMER'),
('PA-C005','Vihaan','Patil','customer005@example.com','DEMO-0005','RETAILER'),
('PA-C006','Diya','Patil','customer006@example.com','DEMO-0006','WHOLESALER'),
('PA-C007','Arjun','Patil','customer007@example.com','DEMO-0007','FARMER'),
('PA-C008','Saanvi','Patil','customer008@example.com','DEMO-0008','RETAILER'),
('PA-C009','Kabir','Patil','customer009@example.com','DEMO-0009','WHOLESALER'),
('PA-C010','Meera','Patil','customer010@example.com','DEMO-0010','FARMER'),
('PA-C011','Aarav','Shinde','customer011@example.com','DEMO-0011','RETAILER'),
('PA-C012','Aditi','Shinde','customer012@example.com','DEMO-0012','WHOLESALER'),
('PA-C013','Ishaan','Shinde','customer013@example.com','DEMO-0013','FARMER'),
('PA-C014','Ananya','Shinde','customer014@example.com','DEMO-0014','RETAILER'),
('PA-C015','Vihaan','Shinde','customer015@example.com','DEMO-0015','WHOLESALER'),
('PA-C016','Diya','Shinde','customer016@example.com','DEMO-0016','FARMER'),
('PA-C017','Arjun','Shinde','customer017@example.com','DEMO-0017','RETAILER'),
('PA-C018','Saanvi','Shinde','customer018@example.com','DEMO-0018','WHOLESALER'),
('PA-C019','Kabir','Shinde','customer019@example.com','DEMO-0019','FARMER'),
('PA-C020','Meera','Shinde','customer020@example.com','DEMO-0020','RETAILER'),
('PA-C021','Aarav','Pawar','customer021@example.com','DEMO-0021','WHOLESALER'),
('PA-C022','Aditi','Pawar','customer022@example.com','DEMO-0022','FARMER'),
('PA-C023','Ishaan','Pawar','customer023@example.com','DEMO-0023','RETAILER'),
('PA-C024','Ananya','Pawar','customer024@example.com','DEMO-0024','WHOLESALER'),
('PA-C025','Vihaan','Pawar','customer025@example.com','DEMO-0025','FARMER'),
('PA-C026','Diya','Pawar','customer026@example.com','DEMO-0026','RETAILER'),
('PA-C027','Arjun','Pawar','customer027@example.com','DEMO-0027','WHOLESALER'),
('PA-C028','Saanvi','Pawar','customer028@example.com','DEMO-0028','FARMER'),
('PA-C029','Kabir','Pawar','customer029@example.com','DEMO-0029','RETAILER'),
('PA-C030','Meera','Pawar','customer030@example.com','DEMO-0030','WHOLESALER'),
('PA-C031','Aarav','Jadhav','customer031@example.com','DEMO-0031','FARMER'),
('PA-C032','Aditi','Jadhav','customer032@example.com','DEMO-0032','RETAILER'),
('PA-C033','Ishaan','Jadhav','customer033@example.com','DEMO-0033','WHOLESALER'),
('PA-C034','Ananya','Jadhav','customer034@example.com','DEMO-0034','FARMER'),
('PA-C035','Vihaan','Jadhav','customer035@example.com','DEMO-0035','RETAILER'),
('PA-C036','Diya','Jadhav','customer036@example.com','DEMO-0036','WHOLESALER'),
('PA-C037','Arjun','Jadhav','customer037@example.com','DEMO-0037','FARMER'),
('PA-C038','Saanvi','Jadhav','customer038@example.com','DEMO-0038','RETAILER'),
('PA-C039','Kabir','Jadhav','customer039@example.com','DEMO-0039','WHOLESALER'),
('PA-C040','Meera','Jadhav','customer040@example.com','DEMO-0040','FARMER'),
('PA-C041','Aarav','Deshmukh','customer041@example.com','DEMO-0041','RETAILER'),
('PA-C042','Aditi','Deshmukh','customer042@example.com','DEMO-0042','WHOLESALER'),
('PA-C043','Ishaan','Deshmukh','customer043@example.com','DEMO-0043','FARMER'),
('PA-C044','Ananya','Deshmukh','customer044@example.com','DEMO-0044','RETAILER'),
('PA-C045','Vihaan','Deshmukh','customer045@example.com','DEMO-0045','WHOLESALER'),
('PA-C046','Diya','Deshmukh','customer046@example.com','DEMO-0046','FARMER'),
('PA-C047','Arjun','Deshmukh','customer047@example.com','DEMO-0047','RETAILER'),
('PA-C048','Saanvi','Deshmukh','customer048@example.com','DEMO-0048','WHOLESALER'),
('PA-C049','Kabir','Deshmukh','customer049@example.com','DEMO-0049','FARMER'),
('PA-C050','Meera','Deshmukh','customer050@example.com','DEMO-0050','RETAILER'),
('PA-C051','Aarav','Kulkarni','customer051@example.com','DEMO-0051','WHOLESALER'),
('PA-C052','Aditi','Kulkarni','customer052@example.com','DEMO-0052','FARMER'),
('PA-C053','Ishaan','Kulkarni','customer053@example.com','DEMO-0053','RETAILER'),
('PA-C054','Ananya','Kulkarni','customer054@example.com','DEMO-0054','WHOLESALER'),
('PA-C055','Vihaan','Kulkarni','customer055@example.com','DEMO-0055','FARMER'),
('PA-C056','Diya','Kulkarni','customer056@example.com','DEMO-0056','RETAILER'),
('PA-C057','Arjun','Kulkarni','customer057@example.com','DEMO-0057','WHOLESALER'),
('PA-C058','Saanvi','Kulkarni','customer058@example.com','DEMO-0058','FARMER'),
('PA-C059','Kabir','Kulkarni','customer059@example.com','DEMO-0059','RETAILER'),
('PA-C060','Meera','Kulkarni','customer060@example.com','DEMO-0060','WHOLESALER'),
('PA-C061','Aarav','More','customer061@example.com','DEMO-0061','FARMER'),
('PA-C062','Aditi','More','customer062@example.com','DEMO-0062','RETAILER'),
('PA-C063','Ishaan','More','customer063@example.com','DEMO-0063','WHOLESALER'),
('PA-C064','Ananya','More','customer064@example.com','DEMO-0064','FARMER'),
('PA-C065','Vihaan','More','customer065@example.com','DEMO-0065','RETAILER'),
('PA-C066','Diya','More','customer066@example.com','DEMO-0066','WHOLESALER'),
('PA-C067','Arjun','More','customer067@example.com','DEMO-0067','FARMER'),
('PA-C068','Saanvi','More','customer068@example.com','DEMO-0068','RETAILER'),
('PA-C069','Kabir','More','customer069@example.com','DEMO-0069','WHOLESALER'),
('PA-C070','Meera','More','customer070@example.com','DEMO-0070','FARMER'),
('PA-C071','Aarav','Joshi','customer071@example.com','DEMO-0071','RETAILER'),
('PA-C072','Aditi','Joshi','customer072@example.com','DEMO-0072','WHOLESALER'),
('PA-C073','Ishaan','Joshi','customer073@example.com','DEMO-0073','FARMER'),
('PA-C074','Ananya','Joshi','customer074@example.com','DEMO-0074','RETAILER'),
('PA-C075','Vihaan','Joshi','customer075@example.com','DEMO-0075','WHOLESALER'),
('PA-C076','Diya','Joshi','customer076@example.com','DEMO-0076','FARMER'),
('PA-C077','Arjun','Joshi','customer077@example.com','DEMO-0077','RETAILER'),
('PA-C078','Saanvi','Joshi','customer078@example.com','DEMO-0078','WHOLESALER'),
('PA-C079','Kabir','Joshi','customer079@example.com','DEMO-0079','FARMER'),
('PA-C080','Meera','Joshi','customer080@example.com','DEMO-0080','RETAILER'),
('PA-C081','Aarav','Kadam','customer081@example.com','DEMO-0081','WHOLESALER'),
('PA-C082','Aditi','Kadam','customer082@example.com','DEMO-0082','FARMER'),
('PA-C083','Ishaan','Kadam','customer083@example.com','DEMO-0083','RETAILER'),
('PA-C084','Ananya','Kadam','customer084@example.com','DEMO-0084','WHOLESALER'),
('PA-C085','Vihaan','Kadam','customer085@example.com','DEMO-0085','FARMER'),
('PA-C086','Diya','Kadam','customer086@example.com','DEMO-0086','RETAILER'),
('PA-C087','Arjun','Kadam','customer087@example.com','DEMO-0087','WHOLESALER'),
('PA-C088','Saanvi','Kadam','customer088@example.com','DEMO-0088','FARMER'),
('PA-C089','Kabir','Kadam','customer089@example.com','DEMO-0089','RETAILER'),
('PA-C090','Meera','Kadam','customer090@example.com','DEMO-0090','WHOLESALER'),
('PA-C091','Aarav','Gaikwad','customer091@example.com','DEMO-0091','FARMER'),
('PA-C092','Aditi','Gaikwad','customer092@example.com','DEMO-0092','RETAILER'),
('PA-C093','Ishaan','Gaikwad','customer093@example.com','DEMO-0093','WHOLESALER'),
('PA-C094','Ananya','Gaikwad','customer094@example.com','DEMO-0094','FARMER'),
('PA-C095','Vihaan','Gaikwad','customer095@example.com','DEMO-0095','RETAILER'),
('PA-C096','Diya','Gaikwad','customer096@example.com','DEMO-0096','WHOLESALER'),
('PA-C097','Arjun','Gaikwad','customer097@example.com','DEMO-0097','FARMER'),
('PA-C098','Saanvi','Gaikwad','customer098@example.com','DEMO-0098','RETAILER'),
('PA-C099','Kabir','Gaikwad','customer099@example.com','DEMO-0099','WHOLESALER'),
('PA-C100','Meera','Gaikwad','customer100@example.com','DEMO-0100','FARMER');
INSERT INTO customer_addresses (customer_id,address_type,address_line,city,state_name,postal_code) VALUES
(1,'BILLING','Demo Farm Road 1','Pune','Maharashtra','411001'),
(1,'SHIPPING','Demo Farm Road 1','Pune','Maharashtra','411001'),
(2,'BILLING','Demo Farm Road 2','Nashik','Maharashtra','411002'),
(2,'SHIPPING','Demo Farm Road 2','Nashik','Maharashtra','411002'),
(3,'BILLING','Demo Farm Road 3','Satara','Maharashtra','411003'),
(3,'SHIPPING','Demo Farm Road 3','Satara','Maharashtra','411003'),
(4,'BILLING','Demo Farm Road 4','Sangli','Maharashtra','411004'),
(4,'SHIPPING','Demo Farm Road 4','Sangli','Maharashtra','411004'),
(5,'BILLING','Demo Farm Road 5','Kolhapur','Maharashtra','411005'),
(5,'SHIPPING','Demo Farm Road 5','Kolhapur','Maharashtra','411005'),
(6,'BILLING','Demo Farm Road 6','Pune','Maharashtra','411006'),
(6,'SHIPPING','Demo Farm Road 6','Pune','Maharashtra','411006'),
(7,'BILLING','Demo Farm Road 7','Nashik','Maharashtra','411007'),
(7,'SHIPPING','Demo Farm Road 7','Nashik','Maharashtra','411007'),
(8,'BILLING','Demo Farm Road 8','Satara','Maharashtra','411008'),
(8,'SHIPPING','Demo Farm Road 8','Satara','Maharashtra','411008'),
(9,'BILLING','Demo Farm Road 9','Sangli','Maharashtra','411009'),
(9,'SHIPPING','Demo Farm Road 9','Sangli','Maharashtra','411009'),
(10,'BILLING','Demo Farm Road 10','Kolhapur','Maharashtra','411010'),
(10,'SHIPPING','Demo Farm Road 10','Kolhapur','Maharashtra','411010'),
(11,'BILLING','Demo Farm Road 11','Pune','Maharashtra','411011'),
(11,'SHIPPING','Demo Farm Road 11','Pune','Maharashtra','411011'),
(12,'BILLING','Demo Farm Road 12','Nashik','Maharashtra','411012'),
(12,'SHIPPING','Demo Farm Road 12','Nashik','Maharashtra','411012'),
(13,'BILLING','Demo Farm Road 13','Satara','Maharashtra','411013'),
(13,'SHIPPING','Demo Farm Road 13','Satara','Maharashtra','411013'),
(14,'BILLING','Demo Farm Road 14','Sangli','Maharashtra','411014'),
(14,'SHIPPING','Demo Farm Road 14','Sangli','Maharashtra','411014'),
(15,'BILLING','Demo Farm Road 15','Kolhapur','Maharashtra','411015'),
(15,'SHIPPING','Demo Farm Road 15','Kolhapur','Maharashtra','411015'),
(16,'BILLING','Demo Farm Road 16','Pune','Maharashtra','411016'),
(16,'SHIPPING','Demo Farm Road 16','Pune','Maharashtra','411016'),
(17,'BILLING','Demo Farm Road 17','Nashik','Maharashtra','411017'),
(17,'SHIPPING','Demo Farm Road 17','Nashik','Maharashtra','411017'),
(18,'BILLING','Demo Farm Road 18','Satara','Maharashtra','411018'),
(18,'SHIPPING','Demo Farm Road 18','Satara','Maharashtra','411018'),
(19,'BILLING','Demo Farm Road 19','Sangli','Maharashtra','411019'),
(19,'SHIPPING','Demo Farm Road 19','Sangli','Maharashtra','411019'),
(20,'BILLING','Demo Farm Road 20','Kolhapur','Maharashtra','411020'),
(20,'SHIPPING','Demo Farm Road 20','Kolhapur','Maharashtra','411020'),
(21,'BILLING','Demo Farm Road 21','Pune','Maharashtra','411021'),
(21,'SHIPPING','Demo Farm Road 21','Pune','Maharashtra','411021'),
(22,'BILLING','Demo Farm Road 22','Nashik','Maharashtra','411022'),
(22,'SHIPPING','Demo Farm Road 22','Nashik','Maharashtra','411022'),
(23,'BILLING','Demo Farm Road 23','Satara','Maharashtra','411023'),
(23,'SHIPPING','Demo Farm Road 23','Satara','Maharashtra','411023'),
(24,'BILLING','Demo Farm Road 24','Sangli','Maharashtra','411024'),
(24,'SHIPPING','Demo Farm Road 24','Sangli','Maharashtra','411024'),
(25,'BILLING','Demo Farm Road 25','Kolhapur','Maharashtra','411025'),
(25,'SHIPPING','Demo Farm Road 25','Kolhapur','Maharashtra','411025'),
(26,'BILLING','Demo Farm Road 26','Pune','Maharashtra','411026'),
(26,'SHIPPING','Demo Farm Road 26','Pune','Maharashtra','411026'),
(27,'BILLING','Demo Farm Road 27','Nashik','Maharashtra','411027'),
(27,'SHIPPING','Demo Farm Road 27','Nashik','Maharashtra','411027'),
(28,'BILLING','Demo Farm Road 28','Satara','Maharashtra','411028'),
(28,'SHIPPING','Demo Farm Road 28','Satara','Maharashtra','411028'),
(29,'BILLING','Demo Farm Road 29','Sangli','Maharashtra','411029'),
(29,'SHIPPING','Demo Farm Road 29','Sangli','Maharashtra','411029'),
(30,'BILLING','Demo Farm Road 30','Kolhapur','Maharashtra','411030'),
(30,'SHIPPING','Demo Farm Road 30','Kolhapur','Maharashtra','411030'),
(31,'BILLING','Demo Farm Road 31','Pune','Maharashtra','411031'),
(31,'SHIPPING','Demo Farm Road 31','Pune','Maharashtra','411031'),
(32,'BILLING','Demo Farm Road 32','Nashik','Maharashtra','411032'),
(32,'SHIPPING','Demo Farm Road 32','Nashik','Maharashtra','411032'),
(33,'BILLING','Demo Farm Road 33','Satara','Maharashtra','411033'),
(33,'SHIPPING','Demo Farm Road 33','Satara','Maharashtra','411033'),
(34,'BILLING','Demo Farm Road 34','Sangli','Maharashtra','411034'),
(34,'SHIPPING','Demo Farm Road 34','Sangli','Maharashtra','411034'),
(35,'BILLING','Demo Farm Road 35','Kolhapur','Maharashtra','411035'),
(35,'SHIPPING','Demo Farm Road 35','Kolhapur','Maharashtra','411035'),
(36,'BILLING','Demo Farm Road 36','Pune','Maharashtra','411036'),
(36,'SHIPPING','Demo Farm Road 36','Pune','Maharashtra','411036'),
(37,'BILLING','Demo Farm Road 37','Nashik','Maharashtra','411037'),
(37,'SHIPPING','Demo Farm Road 37','Nashik','Maharashtra','411037'),
(38,'BILLING','Demo Farm Road 38','Satara','Maharashtra','411038'),
(38,'SHIPPING','Demo Farm Road 38','Satara','Maharashtra','411038'),
(39,'BILLING','Demo Farm Road 39','Sangli','Maharashtra','411039'),
(39,'SHIPPING','Demo Farm Road 39','Sangli','Maharashtra','411039'),
(40,'BILLING','Demo Farm Road 40','Kolhapur','Maharashtra','411040'),
(40,'SHIPPING','Demo Farm Road 40','Kolhapur','Maharashtra','411040'),
(41,'BILLING','Demo Farm Road 41','Pune','Maharashtra','411041'),
(41,'SHIPPING','Demo Farm Road 41','Pune','Maharashtra','411041'),
(42,'BILLING','Demo Farm Road 42','Nashik','Maharashtra','411042'),
(42,'SHIPPING','Demo Farm Road 42','Nashik','Maharashtra','411042'),
(43,'BILLING','Demo Farm Road 43','Satara','Maharashtra','411043'),
(43,'SHIPPING','Demo Farm Road 43','Satara','Maharashtra','411043'),
(44,'BILLING','Demo Farm Road 44','Sangli','Maharashtra','411044'),
(44,'SHIPPING','Demo Farm Road 44','Sangli','Maharashtra','411044'),
(45,'BILLING','Demo Farm Road 45','Kolhapur','Maharashtra','411045'),
(45,'SHIPPING','Demo Farm Road 45','Kolhapur','Maharashtra','411045'),
(46,'BILLING','Demo Farm Road 46','Pune','Maharashtra','411046'),
(46,'SHIPPING','Demo Farm Road 46','Pune','Maharashtra','411046'),
(47,'BILLING','Demo Farm Road 47','Nashik','Maharashtra','411047'),
(47,'SHIPPING','Demo Farm Road 47','Nashik','Maharashtra','411047'),
(48,'BILLING','Demo Farm Road 48','Satara','Maharashtra','411048'),
(48,'SHIPPING','Demo Farm Road 48','Satara','Maharashtra','411048'),
(49,'BILLING','Demo Farm Road 49','Sangli','Maharashtra','411049'),
(49,'SHIPPING','Demo Farm Road 49','Sangli','Maharashtra','411049'),
(50,'BILLING','Demo Farm Road 50','Kolhapur','Maharashtra','411000'),
(50,'SHIPPING','Demo Farm Road 50','Kolhapur','Maharashtra','411000'),
(51,'BILLING','Demo Farm Road 51','Pune','Maharashtra','411001'),
(51,'SHIPPING','Demo Farm Road 51','Pune','Maharashtra','411001'),
(52,'BILLING','Demo Farm Road 52','Nashik','Maharashtra','411002'),
(52,'SHIPPING','Demo Farm Road 52','Nashik','Maharashtra','411002'),
(53,'BILLING','Demo Farm Road 53','Satara','Maharashtra','411003'),
(53,'SHIPPING','Demo Farm Road 53','Satara','Maharashtra','411003'),
(54,'BILLING','Demo Farm Road 54','Sangli','Maharashtra','411004'),
(54,'SHIPPING','Demo Farm Road 54','Sangli','Maharashtra','411004'),
(55,'BILLING','Demo Farm Road 55','Kolhapur','Maharashtra','411005'),
(55,'SHIPPING','Demo Farm Road 55','Kolhapur','Maharashtra','411005'),
(56,'BILLING','Demo Farm Road 56','Pune','Maharashtra','411006'),
(56,'SHIPPING','Demo Farm Road 56','Pune','Maharashtra','411006'),
(57,'BILLING','Demo Farm Road 57','Nashik','Maharashtra','411007'),
(57,'SHIPPING','Demo Farm Road 57','Nashik','Maharashtra','411007'),
(58,'BILLING','Demo Farm Road 58','Satara','Maharashtra','411008'),
(58,'SHIPPING','Demo Farm Road 58','Satara','Maharashtra','411008'),
(59,'BILLING','Demo Farm Road 59','Sangli','Maharashtra','411009'),
(59,'SHIPPING','Demo Farm Road 59','Sangli','Maharashtra','411009'),
(60,'BILLING','Demo Farm Road 60','Kolhapur','Maharashtra','411010'),
(60,'SHIPPING','Demo Farm Road 60','Kolhapur','Maharashtra','411010'),
(61,'BILLING','Demo Farm Road 61','Pune','Maharashtra','411011'),
(61,'SHIPPING','Demo Farm Road 61','Pune','Maharashtra','411011'),
(62,'BILLING','Demo Farm Road 62','Nashik','Maharashtra','411012'),
(62,'SHIPPING','Demo Farm Road 62','Nashik','Maharashtra','411012'),
(63,'BILLING','Demo Farm Road 63','Satara','Maharashtra','411013'),
(63,'SHIPPING','Demo Farm Road 63','Satara','Maharashtra','411013'),
(64,'BILLING','Demo Farm Road 64','Sangli','Maharashtra','411014'),
(64,'SHIPPING','Demo Farm Road 64','Sangli','Maharashtra','411014'),
(65,'BILLING','Demo Farm Road 65','Kolhapur','Maharashtra','411015'),
(65,'SHIPPING','Demo Farm Road 65','Kolhapur','Maharashtra','411015'),
(66,'BILLING','Demo Farm Road 66','Pune','Maharashtra','411016'),
(66,'SHIPPING','Demo Farm Road 66','Pune','Maharashtra','411016'),
(67,'BILLING','Demo Farm Road 67','Nashik','Maharashtra','411017'),
(67,'SHIPPING','Demo Farm Road 67','Nashik','Maharashtra','411017'),
(68,'BILLING','Demo Farm Road 68','Satara','Maharashtra','411018'),
(68,'SHIPPING','Demo Farm Road 68','Satara','Maharashtra','411018'),
(69,'BILLING','Demo Farm Road 69','Sangli','Maharashtra','411019'),
(69,'SHIPPING','Demo Farm Road 69','Sangli','Maharashtra','411019'),
(70,'BILLING','Demo Farm Road 70','Kolhapur','Maharashtra','411020'),
(70,'SHIPPING','Demo Farm Road 70','Kolhapur','Maharashtra','411020'),
(71,'BILLING','Demo Farm Road 71','Pune','Maharashtra','411021'),
(71,'SHIPPING','Demo Farm Road 71','Pune','Maharashtra','411021'),
(72,'BILLING','Demo Farm Road 72','Nashik','Maharashtra','411022'),
(72,'SHIPPING','Demo Farm Road 72','Nashik','Maharashtra','411022'),
(73,'BILLING','Demo Farm Road 73','Satara','Maharashtra','411023'),
(73,'SHIPPING','Demo Farm Road 73','Satara','Maharashtra','411023'),
(74,'BILLING','Demo Farm Road 74','Sangli','Maharashtra','411024'),
(74,'SHIPPING','Demo Farm Road 74','Sangli','Maharashtra','411024'),
(75,'BILLING','Demo Farm Road 75','Kolhapur','Maharashtra','411025'),
(75,'SHIPPING','Demo Farm Road 75','Kolhapur','Maharashtra','411025'),
(76,'BILLING','Demo Farm Road 76','Pune','Maharashtra','411026'),
(76,'SHIPPING','Demo Farm Road 76','Pune','Maharashtra','411026'),
(77,'BILLING','Demo Farm Road 77','Nashik','Maharashtra','411027'),
(77,'SHIPPING','Demo Farm Road 77','Nashik','Maharashtra','411027'),
(78,'BILLING','Demo Farm Road 78','Satara','Maharashtra','411028'),
(78,'SHIPPING','Demo Farm Road 78','Satara','Maharashtra','411028'),
(79,'BILLING','Demo Farm Road 79','Sangli','Maharashtra','411029'),
(79,'SHIPPING','Demo Farm Road 79','Sangli','Maharashtra','411029'),
(80,'BILLING','Demo Farm Road 80','Kolhapur','Maharashtra','411030'),
(80,'SHIPPING','Demo Farm Road 80','Kolhapur','Maharashtra','411030'),
(81,'BILLING','Demo Farm Road 81','Pune','Maharashtra','411031'),
(81,'SHIPPING','Demo Farm Road 81','Pune','Maharashtra','411031'),
(82,'BILLING','Demo Farm Road 82','Nashik','Maharashtra','411032'),
(82,'SHIPPING','Demo Farm Road 82','Nashik','Maharashtra','411032'),
(83,'BILLING','Demo Farm Road 83','Satara','Maharashtra','411033'),
(83,'SHIPPING','Demo Farm Road 83','Satara','Maharashtra','411033'),
(84,'BILLING','Demo Farm Road 84','Sangli','Maharashtra','411034'),
(84,'SHIPPING','Demo Farm Road 84','Sangli','Maharashtra','411034'),
(85,'BILLING','Demo Farm Road 85','Kolhapur','Maharashtra','411035'),
(85,'SHIPPING','Demo Farm Road 85','Kolhapur','Maharashtra','411035'),
(86,'BILLING','Demo Farm Road 86','Pune','Maharashtra','411036'),
(86,'SHIPPING','Demo Farm Road 86','Pune','Maharashtra','411036'),
(87,'BILLING','Demo Farm Road 87','Nashik','Maharashtra','411037'),
(87,'SHIPPING','Demo Farm Road 87','Nashik','Maharashtra','411037'),
(88,'BILLING','Demo Farm Road 88','Satara','Maharashtra','411038'),
(88,'SHIPPING','Demo Farm Road 88','Satara','Maharashtra','411038'),
(89,'BILLING','Demo Farm Road 89','Sangli','Maharashtra','411039'),
(89,'SHIPPING','Demo Farm Road 89','Sangli','Maharashtra','411039'),
(90,'BILLING','Demo Farm Road 90','Kolhapur','Maharashtra','411040'),
(90,'SHIPPING','Demo Farm Road 90','Kolhapur','Maharashtra','411040'),
(91,'BILLING','Demo Farm Road 91','Pune','Maharashtra','411041'),
(91,'SHIPPING','Demo Farm Road 91','Pune','Maharashtra','411041'),
(92,'BILLING','Demo Farm Road 92','Nashik','Maharashtra','411042'),
(92,'SHIPPING','Demo Farm Road 92','Nashik','Maharashtra','411042'),
(93,'BILLING','Demo Farm Road 93','Satara','Maharashtra','411043'),
(93,'SHIPPING','Demo Farm Road 93','Satara','Maharashtra','411043'),
(94,'BILLING','Demo Farm Road 94','Sangli','Maharashtra','411044'),
(94,'SHIPPING','Demo Farm Road 94','Sangli','Maharashtra','411044'),
(95,'BILLING','Demo Farm Road 95','Kolhapur','Maharashtra','411045'),
(95,'SHIPPING','Demo Farm Road 95','Kolhapur','Maharashtra','411045'),
(96,'BILLING','Demo Farm Road 96','Pune','Maharashtra','411046'),
(96,'SHIPPING','Demo Farm Road 96','Pune','Maharashtra','411046'),
(97,'BILLING','Demo Farm Road 97','Nashik','Maharashtra','411047'),
(97,'SHIPPING','Demo Farm Road 97','Nashik','Maharashtra','411047'),
(98,'BILLING','Demo Farm Road 98','Satara','Maharashtra','411048'),
(98,'SHIPPING','Demo Farm Road 98','Satara','Maharashtra','411048'),
(99,'BILLING','Demo Farm Road 99','Sangli','Maharashtra','411049'),
(99,'SHIPPING','Demo Farm Road 99','Sangli','Maharashtra','411049'),
(100,'BILLING','Demo Farm Road 100','Kolhapur','Maharashtra','411000'),
(100,'SHIPPING','Demo Farm Road 100','Kolhapur','Maharashtra','411000');
INSERT INTO employees (full_name,job_title,email,hired_on) VALUES
('Demo Administrator','Manager','admin@example.com','2025-01-01'),
('Demo Staff','Sales Executive','staff@example.com','2025-02-01');
INSERT INTO categories (category_name,description) VALUES
('Seeds','Seeds products'),
('Fertilizers','Fertilizers products'),
('Crop Care','Crop Care products'),
('Tools','Tools products'),
('Irrigation','Irrigation products');
INSERT INTO units (unit_code,unit_name) VALUES
('BAG','Bag'),
('KG','Kilogram'),
('L','Litre'),
('PCS','Piece');
INSERT INTO products (sku,product_name,category_id,unit_id,sale_price,reorder_level) VALUES
('PA-P001','Wheat Seed Bag',1,1,135,20),
('PA-P002','Soybean Seed Bag',1,1,170,20),
('PA-P003','Maize Seed Bag',1,1,205,20),
('PA-P004','Onion Seed Pack',1,1,240,20),
('PA-P005','Tomato Seed Pack',1,1,275,20),
('PA-P006','Compost Bag',2,1,310,20),
('PA-P007','NPK Fertilizer Bag',2,1,345,20),
('PA-P008','Vermicompost Bag',2,1,380,20),
('PA-P009','Soil Conditioner',2,1,415,20),
('PA-P010','Micronutrient Mix',2,1,450,20),
('PA-P011','Neem Oil',3,3,485,20),
('PA-P012','Bio Crop Protectant',3,3,520,20),
('PA-P013','Sticky Trap',3,4,555,20),
('PA-P014','Spray Adjuvant',3,3,590,20),
('PA-P015','Bio Fungicide',3,3,625,20),
('PA-P016','Hand Hoe',4,4,660,20),
('PA-P017','Pruning Shears',4,4,695,20),
('PA-P018','Garden Spade',4,4,730,20),
('PA-P019','Manual Sprayer',4,4,765,20),
('PA-P020','Harvest Sickle',4,4,800,20),
('PA-P021','Drip Pipe Roll',5,4,835,20),
('PA-P022','Drip Emitter Pack',5,4,870,20),
('PA-P023','Hose Connector',5,4,905,20),
('PA-P024','Watering Can',5,4,940,20),
('PA-P025','Irrigation Filter',5,4,975,20);
INSERT INTO suppliers (supplier_name,email,phone,city) VALUES
('Demo Agro Supplier 1','supplier1@example.com','DEMO-S1','Pune'),
('Demo Agro Supplier 2','supplier2@example.com','DEMO-S2','Nashik'),
('Demo Agro Supplier 3','supplier3@example.com','DEMO-S3','Satara'),
('Demo Agro Supplier 4','supplier4@example.com','DEMO-S4','Sangli'),
('Demo Agro Supplier 5','supplier5@example.com','DEMO-S5','Kolhapur'),
('Demo Agro Supplier 6','supplier6@example.com','DEMO-S6','Pune'),
('Demo Agro Supplier 7','supplier7@example.com','DEMO-S7','Nashik'),
('Demo Agro Supplier 8','supplier8@example.com','DEMO-S8','Satara');
INSERT INTO product_suppliers (product_id,supplier_id,quoted_cost) VALUES
(1,1,94.5),
(2,2,119.0),
(3,3,143.5),
(4,4,168.0),
(5,5,192.5),
(6,6,217.0),
(7,7,241.5),
(8,8,266.0),
(9,1,290.5),
(10,2,315.0),
(11,3,339.5),
(12,4,364.0),
(13,5,388.5),
(14,6,413.0),
(15,7,437.5),
(16,8,462.0),
(17,1,486.5),
(18,2,511.0),
(19,3,535.5),
(20,4,560.0),
(21,5,584.5),
(22,6,609.0),
(23,7,633.5),
(24,8,658.0),
(25,1,682.5);
INSERT INTO warehouses (warehouse_name,city) VALUES
('Main Warehouse','Pune'),
('Regional Warehouse','Nashik');
INSERT INTO inventory (warehouse_id,product_id,quantity) VALUES
(1,1,1000),
(1,2,1000),
(1,3,1000),
(1,4,1000),
(1,5,1000),
(1,6,1000),
(1,7,1000),
(1,8,1000),
(1,9,1000),
(1,10,1000),
(1,11,1000),
(1,12,1000),
(1,13,1000),
(1,14,1000),
(1,15,1000),
(1,16,1000),
(1,17,1000),
(1,18,1000),
(1,19,1000),
(1,20,1000),
(1,21,1000),
(1,22,1000),
(1,23,1000),
(1,24,1000),
(1,25,1000),
(2,1,1000),
(2,2,1000),
(2,3,1000),
(2,4,1000),
(2,5,1000),
(2,6,1000),
(2,7,1000),
(2,8,1000),
(2,9,1000),
(2,10,1000),
(2,11,1000),
(2,12,1000),
(2,13,1000),
(2,14,1000),
(2,15,1000),
(2,16,1000),
(2,17,1000),
(2,18,1000),
(2,19,1000),
(2,20,1000),
(2,21,1000),
(2,22,1000),
(2,23,1000),
(2,24,1000),
(2,25,1000);
INSERT INTO inventory_movements(warehouse_id,product_id,quantity_delta,reason) SELECT warehouse_id,product_id,quantity,'OPENING' FROM inventory;
INSERT INTO purchase_orders (supplier_id,warehouse_id,ordered_on) VALUES
(1,1,'2026-09-01'),
(2,1,'2026-09-01'),
(3,1,'2026-09-01'),
(4,1,'2026-09-01'),
(5,1,'2026-09-01'),
(6,1,'2026-09-01'),
(7,1,'2026-09-01'),
(8,1,'2026-09-01');
INSERT INTO purchase_order_items (purchase_order_id,product_id,quantity,unit_cost) VALUES
(1,1,100,94.5),
(2,2,100,119.0),
(3,3,100,143.5),
(4,4,100,168.0),
(5,5,100,192.5),
(6,6,100,217.0),
(7,7,100,241.5),
(8,8,100,266.0),
(1,9,100,290.5),
(2,10,100,315.0),
(3,11,100,339.5),
(4,12,100,364.0),
(5,13,100,388.5),
(6,14,100,413.0),
(7,15,100,437.5),
(8,16,100,462.0),
(1,17,100,486.5),
(2,18,100,511.0),
(3,19,100,535.5),
(4,20,100,560.0),
(5,21,100,584.5),
(6,22,100,609.0),
(7,23,100,633.5),
(8,24,100,658.0),
(1,25,100,682.5);
INSERT INTO sales_orders (customer_id,warehouse_id,order_date,shipping_address_snapshot) VALUES
(1,1,'2026-07-01 10:00:00','{"address_line": "Demo Farm Road 1", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(2,2,'2026-07-02 10:00:00','{"address_line": "Demo Farm Road 2", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(3,1,'2026-07-03 10:00:00','{"address_line": "Demo Farm Road 3", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(4,2,'2026-07-04 10:00:00','{"address_line": "Demo Farm Road 4", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(5,1,'2026-07-05 10:00:00','{"address_line": "Demo Farm Road 5", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(6,2,'2026-07-06 10:00:00','{"address_line": "Demo Farm Road 6", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(7,1,'2026-07-07 10:00:00','{"address_line": "Demo Farm Road 7", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(8,2,'2026-07-08 10:00:00','{"address_line": "Demo Farm Road 8", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(9,1,'2026-07-09 10:00:00','{"address_line": "Demo Farm Road 9", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(10,2,'2026-07-10 10:00:00','{"address_line": "Demo Farm Road 10", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(11,1,'2026-07-11 10:00:00','{"address_line": "Demo Farm Road 11", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(12,2,'2026-07-12 10:00:00','{"address_line": "Demo Farm Road 12", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(13,1,'2026-07-13 10:00:00','{"address_line": "Demo Farm Road 13", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(14,2,'2026-07-14 10:00:00','{"address_line": "Demo Farm Road 14", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(15,1,'2026-07-15 10:00:00','{"address_line": "Demo Farm Road 15", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(16,2,'2026-07-16 10:00:00','{"address_line": "Demo Farm Road 16", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(17,1,'2026-07-17 10:00:00','{"address_line": "Demo Farm Road 17", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(18,2,'2026-07-18 10:00:00','{"address_line": "Demo Farm Road 18", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(19,1,'2026-07-19 10:00:00','{"address_line": "Demo Farm Road 19", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(20,2,'2026-07-20 10:00:00','{"address_line": "Demo Farm Road 20", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(21,1,'2026-07-21 10:00:00','{"address_line": "Demo Farm Road 21", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(22,2,'2026-07-22 10:00:00','{"address_line": "Demo Farm Road 22", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(23,1,'2026-07-23 10:00:00','{"address_line": "Demo Farm Road 23", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(24,2,'2026-07-24 10:00:00','{"address_line": "Demo Farm Road 24", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(25,1,'2026-07-25 10:00:00','{"address_line": "Demo Farm Road 25", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(26,2,'2026-07-26 10:00:00','{"address_line": "Demo Farm Road 26", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(27,1,'2026-07-27 10:00:00','{"address_line": "Demo Farm Road 27", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(28,2,'2026-07-28 10:00:00','{"address_line": "Demo Farm Road 28", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(29,1,'2026-07-29 10:00:00','{"address_line": "Demo Farm Road 29", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(30,2,'2026-07-30 10:00:00','{"address_line": "Demo Farm Road 30", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(31,1,'2026-07-31 10:00:00','{"address_line": "Demo Farm Road 31", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(32,2,'2026-08-01 10:00:00','{"address_line": "Demo Farm Road 32", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(33,1,'2026-08-02 10:00:00','{"address_line": "Demo Farm Road 33", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(34,2,'2026-08-03 10:00:00','{"address_line": "Demo Farm Road 34", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(35,1,'2026-08-04 10:00:00','{"address_line": "Demo Farm Road 35", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(36,2,'2026-08-05 10:00:00','{"address_line": "Demo Farm Road 36", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(37,1,'2026-08-06 10:00:00','{"address_line": "Demo Farm Road 37", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(38,2,'2026-08-07 10:00:00','{"address_line": "Demo Farm Road 38", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(39,1,'2026-08-08 10:00:00','{"address_line": "Demo Farm Road 39", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(40,2,'2026-08-09 10:00:00','{"address_line": "Demo Farm Road 40", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(41,1,'2026-08-10 10:00:00','{"address_line": "Demo Farm Road 41", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(42,2,'2026-08-11 10:00:00','{"address_line": "Demo Farm Road 42", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(43,1,'2026-08-12 10:00:00','{"address_line": "Demo Farm Road 43", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(44,2,'2026-08-13 10:00:00','{"address_line": "Demo Farm Road 44", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(45,1,'2026-08-14 10:00:00','{"address_line": "Demo Farm Road 45", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(46,2,'2026-08-15 10:00:00','{"address_line": "Demo Farm Road 46", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(47,1,'2026-08-16 10:00:00','{"address_line": "Demo Farm Road 47", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(48,2,'2026-08-17 10:00:00','{"address_line": "Demo Farm Road 48", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(49,1,'2026-08-18 10:00:00','{"address_line": "Demo Farm Road 49", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(50,2,'2026-08-19 10:00:00','{"address_line": "Demo Farm Road 50", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(51,1,'2026-08-20 10:00:00','{"address_line": "Demo Farm Road 51", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(52,2,'2026-08-21 10:00:00','{"address_line": "Demo Farm Road 52", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(53,1,'2026-08-22 10:00:00','{"address_line": "Demo Farm Road 53", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(54,2,'2026-08-23 10:00:00','{"address_line": "Demo Farm Road 54", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(55,1,'2026-08-24 10:00:00','{"address_line": "Demo Farm Road 55", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(56,2,'2026-08-25 10:00:00','{"address_line": "Demo Farm Road 56", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(57,1,'2026-08-26 10:00:00','{"address_line": "Demo Farm Road 57", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(58,2,'2026-08-27 10:00:00','{"address_line": "Demo Farm Road 58", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(59,1,'2026-08-28 10:00:00','{"address_line": "Demo Farm Road 59", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(60,2,'2026-08-29 10:00:00','{"address_line": "Demo Farm Road 60", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(61,1,'2026-08-30 10:00:00','{"address_line": "Demo Farm Road 61", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(62,2,'2026-08-31 10:00:00','{"address_line": "Demo Farm Road 62", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(63,1,'2026-09-01 10:00:00','{"address_line": "Demo Farm Road 63", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(64,2,'2026-09-02 10:00:00','{"address_line": "Demo Farm Road 64", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(65,1,'2026-09-03 10:00:00','{"address_line": "Demo Farm Road 65", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(66,2,'2026-09-04 10:00:00','{"address_line": "Demo Farm Road 66", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(67,1,'2026-09-05 10:00:00','{"address_line": "Demo Farm Road 67", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(68,2,'2026-09-06 10:00:00','{"address_line": "Demo Farm Road 68", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(69,1,'2026-09-07 10:00:00','{"address_line": "Demo Farm Road 69", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(70,2,'2026-09-08 10:00:00','{"address_line": "Demo Farm Road 70", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(71,1,'2026-09-09 10:00:00','{"address_line": "Demo Farm Road 71", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(72,2,'2026-09-10 10:00:00','{"address_line": "Demo Farm Road 72", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(73,1,'2026-09-11 10:00:00','{"address_line": "Demo Farm Road 73", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(74,2,'2026-09-12 10:00:00','{"address_line": "Demo Farm Road 74", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(75,1,'2026-09-13 10:00:00','{"address_line": "Demo Farm Road 75", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(76,2,'2026-09-14 10:00:00','{"address_line": "Demo Farm Road 76", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(77,1,'2026-09-15 10:00:00','{"address_line": "Demo Farm Road 77", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(78,2,'2026-09-16 10:00:00','{"address_line": "Demo Farm Road 78", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(79,1,'2026-09-17 10:00:00','{"address_line": "Demo Farm Road 79", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(80,2,'2026-09-18 10:00:00','{"address_line": "Demo Farm Road 80", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(81,1,'2026-09-19 10:00:00','{"address_line": "Demo Farm Road 81", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(82,2,'2026-09-20 10:00:00','{"address_line": "Demo Farm Road 82", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(83,1,'2026-09-21 10:00:00','{"address_line": "Demo Farm Road 83", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(84,2,'2026-09-22 10:00:00','{"address_line": "Demo Farm Road 84", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(85,1,'2026-09-23 10:00:00','{"address_line": "Demo Farm Road 85", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(86,2,'2026-09-24 10:00:00','{"address_line": "Demo Farm Road 86", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(87,1,'2026-09-25 10:00:00','{"address_line": "Demo Farm Road 87", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(88,2,'2026-09-26 10:00:00','{"address_line": "Demo Farm Road 88", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(89,1,'2026-09-27 10:00:00','{"address_line": "Demo Farm Road 89", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(90,2,'2026-09-28 10:00:00','{"address_line": "Demo Farm Road 90", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(91,1,'2026-07-01 10:00:00','{"address_line": "Demo Farm Road 91", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(92,2,'2026-07-02 10:00:00','{"address_line": "Demo Farm Road 92", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(93,1,'2026-07-03 10:00:00','{"address_line": "Demo Farm Road 93", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(94,2,'2026-07-04 10:00:00','{"address_line": "Demo Farm Road 94", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(95,1,'2026-07-05 10:00:00','{"address_line": "Demo Farm Road 95", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(96,2,'2026-07-06 10:00:00','{"address_line": "Demo Farm Road 96", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(97,1,'2026-07-07 10:00:00','{"address_line": "Demo Farm Road 97", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(98,2,'2026-07-08 10:00:00','{"address_line": "Demo Farm Road 98", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(99,1,'2026-07-09 10:00:00','{"address_line": "Demo Farm Road 99", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(100,2,'2026-07-10 10:00:00','{"address_line": "Demo Farm Road 100", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(1,1,'2026-07-11 10:00:00','{"address_line": "Demo Farm Road 1", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(2,2,'2026-07-12 10:00:00','{"address_line": "Demo Farm Road 2", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(3,1,'2026-07-13 10:00:00','{"address_line": "Demo Farm Road 3", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(4,2,'2026-07-14 10:00:00','{"address_line": "Demo Farm Road 4", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(5,1,'2026-07-15 10:00:00','{"address_line": "Demo Farm Road 5", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(6,2,'2026-07-16 10:00:00','{"address_line": "Demo Farm Road 6", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(7,1,'2026-07-17 10:00:00','{"address_line": "Demo Farm Road 7", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(8,2,'2026-07-18 10:00:00','{"address_line": "Demo Farm Road 8", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(9,1,'2026-07-19 10:00:00','{"address_line": "Demo Farm Road 9", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(10,2,'2026-07-20 10:00:00','{"address_line": "Demo Farm Road 10", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(11,1,'2026-07-21 10:00:00','{"address_line": "Demo Farm Road 11", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(12,2,'2026-07-22 10:00:00','{"address_line": "Demo Farm Road 12", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(13,1,'2026-07-23 10:00:00','{"address_line": "Demo Farm Road 13", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(14,2,'2026-07-24 10:00:00','{"address_line": "Demo Farm Road 14", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(15,1,'2026-07-25 10:00:00','{"address_line": "Demo Farm Road 15", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(16,2,'2026-07-26 10:00:00','{"address_line": "Demo Farm Road 16", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(17,1,'2026-07-27 10:00:00','{"address_line": "Demo Farm Road 17", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(18,2,'2026-07-28 10:00:00','{"address_line": "Demo Farm Road 18", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(19,1,'2026-07-29 10:00:00','{"address_line": "Demo Farm Road 19", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(20,2,'2026-07-30 10:00:00','{"address_line": "Demo Farm Road 20", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(21,1,'2026-07-31 10:00:00','{"address_line": "Demo Farm Road 21", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(22,2,'2026-08-01 10:00:00','{"address_line": "Demo Farm Road 22", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(23,1,'2026-08-02 10:00:00','{"address_line": "Demo Farm Road 23", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(24,2,'2026-08-03 10:00:00','{"address_line": "Demo Farm Road 24", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(25,1,'2026-08-04 10:00:00','{"address_line": "Demo Farm Road 25", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(26,2,'2026-08-05 10:00:00','{"address_line": "Demo Farm Road 26", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(27,1,'2026-08-06 10:00:00','{"address_line": "Demo Farm Road 27", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(28,2,'2026-08-07 10:00:00','{"address_line": "Demo Farm Road 28", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(29,1,'2026-08-08 10:00:00','{"address_line": "Demo Farm Road 29", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(30,2,'2026-08-09 10:00:00','{"address_line": "Demo Farm Road 30", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(31,1,'2026-08-10 10:00:00','{"address_line": "Demo Farm Road 31", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(32,2,'2026-08-11 10:00:00','{"address_line": "Demo Farm Road 32", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(33,1,'2026-08-12 10:00:00','{"address_line": "Demo Farm Road 33", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(34,2,'2026-08-13 10:00:00','{"address_line": "Demo Farm Road 34", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(35,1,'2026-08-14 10:00:00','{"address_line": "Demo Farm Road 35", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(36,2,'2026-08-15 10:00:00','{"address_line": "Demo Farm Road 36", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(37,1,'2026-08-16 10:00:00','{"address_line": "Demo Farm Road 37", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(38,2,'2026-08-17 10:00:00','{"address_line": "Demo Farm Road 38", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(39,1,'2026-08-18 10:00:00','{"address_line": "Demo Farm Road 39", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(40,2,'2026-08-19 10:00:00','{"address_line": "Demo Farm Road 40", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(41,1,'2026-08-20 10:00:00','{"address_line": "Demo Farm Road 41", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(42,2,'2026-08-21 10:00:00','{"address_line": "Demo Farm Road 42", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(43,1,'2026-08-22 10:00:00','{"address_line": "Demo Farm Road 43", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(44,2,'2026-08-23 10:00:00','{"address_line": "Demo Farm Road 44", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(45,1,'2026-08-24 10:00:00','{"address_line": "Demo Farm Road 45", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}'),
(46,2,'2026-08-25 10:00:00','{"address_line": "Demo Farm Road 46", "city": "Pune", "state": "Maharashtra", "country": "IN"}'),
(47,1,'2026-08-26 10:00:00','{"address_line": "Demo Farm Road 47", "city": "Nashik", "state": "Maharashtra", "country": "IN"}'),
(48,2,'2026-08-27 10:00:00','{"address_line": "Demo Farm Road 48", "city": "Satara", "state": "Maharashtra", "country": "IN"}'),
(49,1,'2026-08-28 10:00:00','{"address_line": "Demo Farm Road 49", "city": "Sangli", "state": "Maharashtra", "country": "IN"}'),
(50,2,'2026-08-29 10:00:00','{"address_line": "Demo Farm Road 50", "city": "Kolhapur", "state": "Maharashtra", "country": "IN"}');
INSERT INTO sales_order_items (order_id,product_id,quantity,unit_price,discount_percent,tax_percent) VALUES
(1,1,2,135,0,0),
(1,2,2,170,0,0),
(2,3,3,205,0,0),
(2,4,3,240,0,0),
(3,5,4,275,0,0),
(3,6,4,310,0,0),
(4,7,1,345,0,0),
(4,8,1,380,0,0),
(5,9,2,415,5,0),
(5,10,2,450,5,0),
(6,11,3,485,0,0),
(6,12,3,520,0,0),
(7,13,4,555,0,0),
(7,14,4,590,0,0),
(8,15,1,625,0,0),
(8,16,1,660,0,0),
(9,17,2,695,0,0),
(9,18,2,730,0,0),
(10,19,3,765,5,0),
(10,20,3,800,5,0),
(11,21,4,835,0,0),
(11,22,4,870,0,0),
(12,23,1,905,0,0),
(12,24,1,940,0,0),
(13,25,2,975,0,0),
(13,1,2,135,0,0),
(14,2,3,170,0,0),
(14,3,3,205,0,0),
(15,4,4,240,5,0),
(15,5,4,275,5,0),
(16,6,1,310,0,0),
(16,7,1,345,0,0),
(17,8,2,380,0,0),
(17,9,2,415,0,0),
(18,10,3,450,0,0),
(18,11,3,485,0,0),
(19,12,4,520,0,0),
(19,13,4,555,0,0),
(20,14,1,590,5,0),
(20,15,1,625,5,0),
(21,16,2,660,0,0),
(21,17,2,695,0,0),
(22,18,3,730,0,0),
(22,19,3,765,0,0),
(23,20,4,800,0,0),
(23,21,4,835,0,0),
(24,22,1,870,0,0),
(24,23,1,905,0,0),
(25,24,2,940,5,0),
(25,25,2,975,5,0),
(26,1,3,135,0,0),
(26,2,3,170,0,0),
(27,3,4,205,0,0),
(27,4,4,240,0,0),
(28,5,1,275,0,0),
(28,6,1,310,0,0),
(29,7,2,345,0,0),
(29,8,2,380,0,0),
(30,9,3,415,5,0),
(30,10,3,450,5,0),
(31,11,4,485,0,0),
(31,12,4,520,0,0),
(32,13,1,555,0,0),
(32,14,1,590,0,0),
(33,15,2,625,0,0),
(33,16,2,660,0,0),
(34,17,3,695,0,0),
(34,18,3,730,0,0),
(35,19,4,765,5,0),
(35,20,4,800,5,0),
(36,21,1,835,0,0),
(36,22,1,870,0,0),
(37,23,2,905,0,0),
(37,24,2,940,0,0),
(38,25,3,975,0,0),
(38,1,3,135,0,0),
(39,2,4,170,0,0),
(39,3,4,205,0,0),
(40,4,1,240,5,0),
(40,5,1,275,5,0),
(41,6,2,310,0,0),
(41,7,2,345,0,0),
(42,8,3,380,0,0),
(42,9,3,415,0,0),
(43,10,4,450,0,0),
(43,11,4,485,0,0),
(44,12,1,520,0,0),
(44,13,1,555,0,0),
(45,14,2,590,5,0),
(45,15,2,625,5,0),
(46,16,3,660,0,0),
(46,17,3,695,0,0),
(47,18,4,730,0,0),
(47,19,4,765,0,0),
(48,20,1,800,0,0),
(48,21,1,835,0,0),
(49,22,2,870,0,0),
(49,23,2,905,0,0),
(50,24,3,940,5,0),
(50,25,3,975,5,0),
(51,1,4,135,0,0),
(51,2,4,170,0,0),
(52,3,1,205,0,0),
(52,4,1,240,0,0),
(53,5,2,275,0,0),
(53,6,2,310,0,0),
(54,7,3,345,0,0),
(54,8,3,380,0,0),
(55,9,4,415,5,0),
(55,10,4,450,5,0),
(56,11,1,485,0,0),
(56,12,1,520,0,0),
(57,13,2,555,0,0),
(57,14,2,590,0,0),
(58,15,3,625,0,0),
(58,16,3,660,0,0),
(59,17,4,695,0,0),
(59,18,4,730,0,0),
(60,19,1,765,5,0),
(60,20,1,800,5,0),
(61,21,2,835,0,0),
(61,22,2,870,0,0),
(62,23,3,905,0,0),
(62,24,3,940,0,0),
(63,25,4,975,0,0),
(63,1,4,135,0,0),
(64,2,1,170,0,0),
(64,3,1,205,0,0),
(65,4,2,240,5,0),
(65,5,2,275,5,0),
(66,6,3,310,0,0),
(66,7,3,345,0,0),
(67,8,4,380,0,0),
(67,9,4,415,0,0),
(68,10,1,450,0,0),
(68,11,1,485,0,0),
(69,12,2,520,0,0),
(69,13,2,555,0,0),
(70,14,3,590,5,0),
(70,15,3,625,5,0),
(71,16,4,660,0,0),
(71,17,4,695,0,0),
(72,18,1,730,0,0),
(72,19,1,765,0,0),
(73,20,2,800,0,0),
(73,21,2,835,0,0),
(74,22,3,870,0,0),
(74,23,3,905,0,0),
(75,24,4,940,5,0),
(75,25,4,975,5,0),
(76,1,1,135,0,0),
(76,2,1,170,0,0),
(77,3,2,205,0,0),
(77,4,2,240,0,0),
(78,5,3,275,0,0),
(78,6,3,310,0,0),
(79,7,4,345,0,0),
(79,8,4,380,0,0),
(80,9,1,415,5,0),
(80,10,1,450,5,0),
(81,11,2,485,0,0),
(81,12,2,520,0,0),
(82,13,3,555,0,0),
(82,14,3,590,0,0),
(83,15,4,625,0,0),
(83,16,4,660,0,0),
(84,17,1,695,0,0),
(84,18,1,730,0,0),
(85,19,2,765,5,0),
(85,20,2,800,5,0),
(86,21,3,835,0,0),
(86,22,3,870,0,0),
(87,23,4,905,0,0),
(87,24,4,940,0,0),
(88,25,1,975,0,0),
(88,1,1,135,0,0),
(89,2,2,170,0,0),
(89,3,2,205,0,0),
(90,4,3,240,5,0),
(90,5,3,275,5,0),
(91,6,4,310,0,0),
(91,7,4,345,0,0),
(92,8,1,380,0,0),
(92,9,1,415,0,0),
(93,10,2,450,0,0),
(93,11,2,485,0,0),
(94,12,3,520,0,0),
(94,13,3,555,0,0),
(95,14,4,590,5,0),
(95,15,4,625,5,0),
(96,16,1,660,0,0),
(96,17,1,695,0,0),
(97,18,2,730,0,0),
(97,19,2,765,0,0),
(98,20,3,800,0,0),
(98,21,3,835,0,0),
(99,22,4,870,0,0),
(99,23,4,905,0,0),
(100,24,1,940,5,0),
(100,25,1,975,5,0),
(101,1,2,135,0,0),
(101,2,2,170,0,0),
(102,3,3,205,0,0),
(102,4,3,240,0,0),
(103,5,4,275,0,0),
(103,6,4,310,0,0),
(104,7,1,345,0,0),
(104,8,1,380,0,0),
(105,9,2,415,5,0),
(105,10,2,450,5,0),
(106,11,3,485,0,0),
(106,12,3,520,0,0),
(107,13,4,555,0,0),
(107,14,4,590,0,0),
(108,15,1,625,0,0),
(108,16,1,660,0,0),
(109,17,2,695,0,0),
(109,18,2,730,0,0),
(110,19,3,765,5,0),
(110,20,3,800,5,0),
(111,21,4,835,0,0),
(111,22,4,870,0,0),
(112,23,1,905,0,0),
(112,24,1,940,0,0),
(113,25,2,975,0,0),
(113,1,2,135,0,0),
(114,2,3,170,0,0),
(114,3,3,205,0,0),
(115,4,4,240,5,0),
(115,5,4,275,5,0),
(116,6,1,310,0,0),
(116,7,1,345,0,0),
(117,8,2,380,0,0),
(117,9,2,415,0,0),
(118,10,3,450,0,0),
(118,11,3,485,0,0),
(119,12,4,520,0,0),
(119,13,4,555,0,0),
(120,14,1,590,5,0),
(120,15,1,625,5,0),
(121,16,2,660,0,0),
(121,17,2,695,0,0),
(122,18,3,730,0,0),
(122,19,3,765,0,0),
(123,20,4,800,0,0),
(123,21,4,835,0,0),
(124,22,1,870,0,0),
(124,23,1,905,0,0),
(125,24,2,940,5,0),
(125,25,2,975,5,0),
(126,1,3,135,0,0),
(126,2,3,170,0,0),
(127,3,4,205,0,0),
(127,4,4,240,0,0),
(128,5,1,275,0,0),
(128,6,1,310,0,0),
(129,7,2,345,0,0),
(129,8,2,380,0,0),
(130,9,3,415,5,0),
(130,10,3,450,5,0),
(131,11,4,485,0,0),
(131,12,4,520,0,0),
(132,13,1,555,0,0),
(132,14,1,590,0,0),
(133,15,2,625,0,0),
(133,16,2,660,0,0),
(134,17,3,695,0,0),
(134,18,3,730,0,0),
(135,19,4,765,5,0),
(135,20,4,800,5,0),
(136,21,1,835,0,0),
(136,22,1,870,0,0),
(137,23,2,905,0,0),
(137,24,2,940,0,0),
(138,25,3,975,0,0),
(138,1,3,135,0,0),
(139,2,4,170,0,0),
(139,3,4,205,0,0),
(140,4,1,240,5,0),
(140,5,1,275,5,0),
(141,6,2,310,0,0),
(141,7,2,345,0,0),
(142,8,3,380,0,0),
(142,9,3,415,0,0),
(143,10,4,450,0,0),
(143,11,4,485,0,0),
(144,12,1,520,0,0),
(144,13,1,555,0,0),
(145,14,2,590,5,0),
(145,15,2,625,5,0),
(146,16,3,660,0,0),
(146,17,3,695,0,0),
(147,18,4,730,0,0),
(147,19,4,765,0,0),
(148,20,1,800,0,0),
(148,21,1,835,0,0),
(149,22,2,870,0,0),
(149,23,2,905,0,0),
(150,24,3,940,5,0),
(150,25,3,975,5,0);

-- Views are invoker-security: callers also need the underlying table privileges.
CREATE SQL SECURITY INVOKER VIEW v_order_totals AS
SELECT o.order_id,o.customer_id,o.warehouse_id,o.order_date,o.status,
 COALESCE(SUM(i.line_total),0) AS order_total
FROM sales_orders o LEFT JOIN sales_order_items i ON i.order_id=o.order_id
GROUP BY o.order_id,o.customer_id,o.warehouse_id,o.order_date,o.status;
CREATE SQL SECURITY INVOKER VIEW v_payment_totals AS
SELECT order_id,SUM(CASE WHEN status='SUCCESS' THEN amount ELSE 0 END) AS paid_amount
FROM payments GROUP BY order_id;
CREATE SQL SECURITY INVOKER VIEW v_order_balances AS
SELECT t.*,COALESCE(p.paid_amount,0) AS paid_amount,t.order_total-COALESCE(p.paid_amount,0) AS balance_due
FROM v_order_totals t LEFT JOIN v_payment_totals p ON p.order_id=t.order_id;
CREATE SQL SECURITY INVOKER VIEW v_customer_summary AS
SELECT c.customer_id,c.customer_code,CONCAT(c.first_name,' ',c.last_name) AS customer_name,
COUNT(t.order_id) AS order_count,COALESCE(SUM(t.order_total),0) AS ordered_value
FROM customers c LEFT JOIN v_order_totals t ON c.customer_id=t.customer_id AND t.status IN ('CONFIRMED','SHIPPED','DELIVERED')
GROUP BY c.customer_id,c.customer_code,c.first_name,c.last_name;
CREATE SQL SECURITY INVOKER VIEW v_low_stock AS
SELECT i.warehouse_id,w.warehouse_name,p.product_id,p.sku,p.product_name,i.quantity,p.reorder_level
FROM inventory i JOIN products p ON p.product_id=i.product_id JOIN warehouses w ON w.warehouse_id=i.warehouse_id
WHERE i.quantity<=p.reorder_level;
CREATE SQL SECURITY INVOKER VIEW v_product_catalog AS
SELECT p.product_id,p.sku,p.product_name,c.category_name,u.unit_code,p.sale_price,
COALESCE(SUM(i.quantity),0) AS available_quantity
FROM products p JOIN categories c ON p.category_id=c.category_id JOIN units u ON p.unit_id=u.unit_id
LEFT JOIN inventory i ON i.product_id=p.product_id WHERE p.is_active=TRUE
GROUP BY p.product_id,p.sku,p.product_name,c.category_name,u.unit_code,p.sale_price;

CREATE SQL SECURITY INVOKER VIEW v_credit_balances AS
SELECT a.credit_account_id,a.customer_id,a.credit_limit,
COALESCE(SUM(CASE WHEN t.txn_type='CHARGE' THEN t.amount WHEN t.txn_type='PAYMENT' THEN -t.amount ELSE 0 END),0) AS outstanding,
a.credit_limit-COALESCE(SUM(CASE WHEN t.txn_type='CHARGE' THEN t.amount WHEN t.txn_type='PAYMENT' THEN -t.amount ELSE 0 END),0) AS available_credit
FROM credit_accounts a LEFT JOIN credit_transactions t ON t.credit_account_id=a.credit_account_id
GROUP BY a.credit_account_id,a.customer_id,a.credit_limit;

DELIMITER $$
CREATE FUNCTION fn_customer_name(p_customer_id INT) RETURNS VARCHAR(121)
READS SQL DATA SQL SECURITY INVOKER
BEGIN
 DECLARE v_name VARCHAR(121);
 SELECT CONCAT(first_name,' ',last_name) INTO v_name FROM customers WHERE customer_id=p_customer_id;
 RETURN v_name;
END$$
CREATE FUNCTION fn_order_total(p_order_id INT) RETURNS DECIMAL(14,2)
READS SQL DATA SQL SECURITY INVOKER
BEGIN
 DECLARE v_total DECIMAL(14,2);
 SELECT SUM(line_total) INTO v_total FROM sales_order_items WHERE order_id=p_order_id;
 RETURN COALESCE(v_total,0);
END$$
CREATE PROCEDURE sp_customer_orders(IN p_customer_id INT)
SQL SECURITY INVOKER
BEGIN
 SELECT * FROM v_order_balances WHERE customer_id=p_customer_id ORDER BY order_date DESC,order_id DESC;
END$$
-- These two posting procedures deliberately NEVER commit. The caller owns the transaction.
-- Use START TRANSACTION; CALL ...; COMMIT; and ROLLBACK on ANY error.
-- Each locks its header and inventory rows; duplicate posting is rejected.
CREATE PROCEDURE sp_confirm_order(IN p_order_id INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(20) DEFAULT NULL;
 DECLARE v_wh INT;
 DECLARE v_bad INT DEFAULT 0;
 DECLARE v_count INT DEFAULT 0;
 SELECT status,warehouse_id INTO v_status,v_wh FROM sales_orders WHERE order_id=p_order_id FOR UPDATE;
 IF v_status IS NULL OR v_status<>'DRAFT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Order must exist and be DRAFT'; END IF;
 SELECT COUNT(*) INTO v_count FROM sales_order_items WHERE order_id=p_order_id;
 IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot confirm an empty order'; END IF;
 UPDATE inventory i JOIN sales_order_items s ON s.product_id=i.product_id AND s.order_id=p_order_id
 SET i.quantity=i.quantity WHERE i.warehouse_id=v_wh;
 SELECT COUNT(*) INTO v_bad FROM sales_order_items s LEFT JOIN inventory i ON i.product_id=s.product_id AND i.warehouse_id=v_wh
 JOIN products p ON p.product_id=s.product_id
 WHERE s.order_id=p_order_id AND (i.product_id IS NULL OR i.quantity<s.quantity OR p.is_active=FALSE);
 IF v_bad>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insufficient stock, missing inventory or inactive product'; END IF;
 UPDATE inventory i JOIN sales_order_items s ON s.product_id=i.product_id AND s.order_id=p_order_id
 SET i.quantity=i.quantity-s.quantity WHERE i.warehouse_id=v_wh;
 INSERT INTO inventory_movements(warehouse_id,product_id,quantity_delta,reason,order_id)
 SELECT v_wh,product_id,-quantity,'SALE',p_order_id FROM sales_order_items WHERE order_id=p_order_id;
 UPDATE sales_orders SET status='CONFIRMED' WHERE order_id=p_order_id;
END$$
CREATE PROCEDURE sp_receive_purchase(IN p_purchase_id INT)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(20) DEFAULT NULL;
 DECLARE v_wh INT;
 DECLARE v_count INT;
 SELECT status,warehouse_id INTO v_status,v_wh FROM purchase_orders WHERE purchase_order_id=p_purchase_id FOR UPDATE;
 IF v_status IS NULL OR v_status<>'DRAFT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase must exist and be DRAFT'; END IF;
 SELECT COUNT(*) INTO v_count FROM purchase_order_items WHERE purchase_order_id=p_purchase_id;
 IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot receive an empty purchase'; END IF;
 INSERT INTO inventory(warehouse_id,product_id,quantity)
 SELECT v_wh,product_id,0 FROM purchase_order_items WHERE purchase_order_id=p_purchase_id
 ON DUPLICATE KEY UPDATE quantity=inventory.quantity;
 UPDATE inventory i JOIN purchase_order_items p ON p.product_id=i.product_id AND p.purchase_order_id=p_purchase_id
 SET i.quantity=i.quantity+p.quantity WHERE i.warehouse_id=v_wh;
 INSERT INTO inventory_movements(warehouse_id,product_id,quantity_delta,reason,purchase_order_id)
 SELECT v_wh,product_id,quantity,'PURCHASE',p_purchase_id FROM purchase_order_items WHERE purchase_order_id=p_purchase_id;
 UPDATE purchase_orders SET status='RECEIVED' WHERE purchase_order_id=p_purchase_id;
END$$
CREATE TRIGGER trg_items_insert BEFORE INSERT ON sales_order_items FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(20);
 SELECT status INTO v_status FROM sales_orders WHERE order_id=NEW.order_id FOR UPDATE;
 IF v_status<>'DRAFT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only DRAFT order items can be changed'; END IF;
END$$
CREATE TRIGGER trg_items_update BEFORE UPDATE ON sales_order_items FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(20);
 SELECT status INTO v_status FROM sales_orders WHERE order_id=OLD.order_id FOR UPDATE;
 IF v_status<>'DRAFT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only DRAFT order items can be changed'; END IF;
 IF NEW.order_id<>OLD.order_id OR NEW.product_id<>OLD.product_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Item keys are immutable; delete and insert instead'; END IF;
END$$
CREATE TRIGGER trg_items_delete BEFORE DELETE ON sales_order_items FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(20);
 SELECT status INTO v_status FROM sales_orders WHERE order_id=OLD.order_id FOR UPDATE;
 IF v_status<>'DRAFT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only DRAFT order items can be changed'; END IF;
END$$
CREATE TRIGGER trg_payment_validate BEFORE INSERT ON payments FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(20);
 SELECT status INTO v_status FROM sales_orders WHERE order_id=NEW.order_id FOR UPDATE;
 IF v_status NOT IN ('CONFIRMED','SHIPPED','DELIVERED') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payments require a confirmed order'; END IF;
END$$
DELIMITER ;
-- Seed posted orders through the same stock workflow used by the application.
START TRANSACTION;
CALL sp_confirm_order(1);
CALL sp_confirm_order(2);
CALL sp_confirm_order(3);
CALL sp_confirm_order(4);
CALL sp_confirm_order(5);
CALL sp_confirm_order(6);
CALL sp_confirm_order(7);
CALL sp_confirm_order(8);
CALL sp_confirm_order(9);
CALL sp_confirm_order(10);
CALL sp_confirm_order(11);
CALL sp_confirm_order(12);
CALL sp_confirm_order(13);
CALL sp_confirm_order(14);
CALL sp_confirm_order(15);
CALL sp_confirm_order(16);
CALL sp_confirm_order(17);
CALL sp_confirm_order(18);
CALL sp_confirm_order(19);
CALL sp_confirm_order(20);
CALL sp_confirm_order(21);
CALL sp_confirm_order(22);
CALL sp_confirm_order(23);
CALL sp_confirm_order(24);
CALL sp_confirm_order(25);
CALL sp_confirm_order(26);
CALL sp_confirm_order(27);
CALL sp_confirm_order(28);
CALL sp_confirm_order(29);
CALL sp_confirm_order(30);
CALL sp_confirm_order(31);
CALL sp_confirm_order(32);
CALL sp_confirm_order(33);
CALL sp_confirm_order(34);
CALL sp_confirm_order(35);
CALL sp_confirm_order(36);
CALL sp_confirm_order(37);
CALL sp_confirm_order(38);
CALL sp_confirm_order(39);
CALL sp_confirm_order(40);
CALL sp_confirm_order(41);
CALL sp_confirm_order(42);
CALL sp_confirm_order(43);
CALL sp_confirm_order(44);
CALL sp_confirm_order(45);
CALL sp_confirm_order(46);
CALL sp_confirm_order(47);
CALL sp_confirm_order(48);
CALL sp_confirm_order(49);
CALL sp_confirm_order(50);
CALL sp_confirm_order(51);
CALL sp_confirm_order(52);
CALL sp_confirm_order(53);
CALL sp_confirm_order(54);
CALL sp_confirm_order(55);
CALL sp_confirm_order(56);
CALL sp_confirm_order(57);
CALL sp_confirm_order(58);
CALL sp_confirm_order(59);
CALL sp_confirm_order(60);
CALL sp_confirm_order(61);
CALL sp_confirm_order(62);
CALL sp_confirm_order(63);
CALL sp_confirm_order(64);
CALL sp_confirm_order(65);
CALL sp_confirm_order(66);
CALL sp_confirm_order(67);
CALL sp_confirm_order(68);
CALL sp_confirm_order(69);
CALL sp_confirm_order(70);
CALL sp_confirm_order(71);
CALL sp_confirm_order(72);
CALL sp_confirm_order(73);
CALL sp_confirm_order(74);
CALL sp_confirm_order(75);
CALL sp_confirm_order(76);
CALL sp_confirm_order(77);
CALL sp_confirm_order(78);
CALL sp_confirm_order(79);
CALL sp_confirm_order(80);
CALL sp_confirm_order(81);
CALL sp_confirm_order(82);
CALL sp_confirm_order(83);
CALL sp_confirm_order(84);
CALL sp_confirm_order(85);
CALL sp_confirm_order(86);
CALL sp_confirm_order(87);
CALL sp_confirm_order(88);
CALL sp_confirm_order(89);
CALL sp_confirm_order(90);
CALL sp_confirm_order(91);
CALL sp_confirm_order(92);
CALL sp_confirm_order(93);
CALL sp_confirm_order(94);
CALL sp_confirm_order(95);
CALL sp_confirm_order(96);
CALL sp_confirm_order(97);
CALL sp_confirm_order(98);
CALL sp_confirm_order(99);
CALL sp_confirm_order(100);
CALL sp_confirm_order(101);
CALL sp_confirm_order(102);
CALL sp_confirm_order(103);
CALL sp_confirm_order(104);
CALL sp_confirm_order(105);
CALL sp_confirm_order(106);
CALL sp_confirm_order(107);
CALL sp_confirm_order(108);
CALL sp_confirm_order(109);
CALL sp_confirm_order(110);
CALL sp_confirm_order(111);
CALL sp_confirm_order(112);
CALL sp_confirm_order(113);
CALL sp_confirm_order(114);
CALL sp_confirm_order(115);
CALL sp_confirm_order(116);
CALL sp_confirm_order(117);
CALL sp_confirm_order(118);
CALL sp_confirm_order(119);
CALL sp_confirm_order(120);
CALL sp_confirm_order(121);
CALL sp_confirm_order(122);
CALL sp_confirm_order(123);
CALL sp_confirm_order(124);
CALL sp_confirm_order(125);
CALL sp_confirm_order(126);
CALL sp_confirm_order(127);
CALL sp_confirm_order(128);
CALL sp_confirm_order(129);
CALL sp_confirm_order(130);
CALL sp_receive_purchase(1);
CALL sp_receive_purchase(2);
CALL sp_receive_purchase(3);
CALL sp_receive_purchase(4);
CALL sp_receive_purchase(5);
CALL sp_receive_purchase(6);

INSERT INTO payments(order_id,reference_code,amount,method,status,paid_at)
SELECT order_id,CONCAT('DEMO-PAY-',order_id),order_total,ELT(1+MOD(order_id,4),'CASH','UPI','CARD','BANK'),'SUCCESS',DATE_ADD(order_date,INTERVAL 1 DAY)
FROM v_order_totals WHERE order_id<=100;
INSERT INTO shipments(order_id,carrier,tracking_number,shipped_at,delivered_at)
SELECT order_id,'Demo Agro Logistics',CONCAT('DEMO-TRACK-',order_id),DATE_ADD(order_date,INTERVAL 2 DAY),
CASE WHEN order_id<=60 THEN DATE_ADD(order_date,INTERVAL 4 DAY) ELSE NULL END
FROM sales_orders WHERE order_id<=90;
UPDATE sales_orders SET status=CASE WHEN order_id<=60 THEN 'DELIVERED' ELSE 'SHIPPED' END WHERE order_id<=90;
COMMIT;

-- Credit and warranty seed data (synthetic).
INSERT INTO credit_accounts (customer_id,credit_limit,payment_terms_days,opened_on)
SELECT customer_id,CASE customer_type WHEN 'WHOLESALER' THEN 100000 ELSE 40000 END,CASE customer_type WHEN 'WHOLESALER' THEN 45 ELSE 30 END,'2026-06-01'
FROM customers WHERE customer_type IN ('RETAILER','WHOLESALER');
-- Orders 101-130 were confirmed without payment: record them as credit sales for credit customers.
INSERT INTO credit_transactions (credit_account_id,order_id,txn_type,amount,due_date,notes,created_at)
SELECT a.credit_account_id,t.order_id,'CHARGE',t.order_total,DATE_ADD(DATE(t.order_date),INTERVAL a.payment_terms_days DAY),'Sale on credit',t.order_date
FROM v_order_totals t JOIN credit_accounts a ON a.customer_id=t.customer_id
WHERE t.order_id BETWEEN 101 AND 130 AND t.order_total>0;
-- A few of those credit orders have been settled.
INSERT INTO credit_transactions (credit_account_id,order_id,txn_type,amount,notes,created_at)
SELECT credit_account_id,order_id,'PAYMENT',amount,'Part of credit settlement',DATE_ADD(created_at,INTERVAL 20 DAY)
FROM credit_transactions WHERE txn_type='CHARGE' AND MOD(order_id,3)=0;
INSERT INTO warranty_policies (policy_name,duration_months,terms) VALUES
('Hand Tool Warranty',12,'Covers manufacturing defects; excludes misuse and wear.'),
('Irrigation Equipment Warranty',24,'Covers leaks and component failure under normal use.');
INSERT INTO product_warranties (product_id,policy_id)
SELECT product_id,CASE category_id WHEN 4 THEN 1 ELSE 2 END FROM products WHERE category_id IN (4,5);
INSERT INTO warranty_claims (order_id,product_id,claimed_on,issue_description,status,resolution,resolved_on) VALUES
(8,16,'2026-08-01 11:00:00','Handle cracked after first use.','RESOLVED','Replacement issued.','2026-08-05 15:00:00'),
(9,18,'2026-08-10 09:30:00','Blade bent under normal digging.','APPROVED','Replacement approved; pending dispatch.',NULL),
(11,21,'2026-09-02 14:00:00','Pipe roll leaking at joints.','OPEN',NULL,NULL),
(10,19,'2026-09-15 10:15:00','Sprayer damaged by chemical misuse.','REJECTED','Outside warranty terms.','2026-09-16 12:00:00');
-- Final result 1: every base table and view.
SELECT table_name,table_type FROM information_schema.tables WHERE table_schema=DATABASE() ORDER BY table_type,table_name;
-- Final result 2: exact base-table row counts (not approximate metadata estimates).
SELECT 'customers' AS table_name,COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'customer_addresses' AS table_name,COUNT(*) AS row_count FROM customer_addresses
UNION ALL
SELECT 'employees' AS table_name,COUNT(*) AS row_count FROM employees
UNION ALL
SELECT 'categories' AS table_name,COUNT(*) AS row_count FROM categories
UNION ALL
SELECT 'units' AS table_name,COUNT(*) AS row_count FROM units
UNION ALL
SELECT 'products' AS table_name,COUNT(*) AS row_count FROM products
UNION ALL
SELECT 'suppliers' AS table_name,COUNT(*) AS row_count FROM suppliers
UNION ALL
SELECT 'product_suppliers' AS table_name,COUNT(*) AS row_count FROM product_suppliers
UNION ALL
SELECT 'warehouses' AS table_name,COUNT(*) AS row_count FROM warehouses
UNION ALL
SELECT 'inventory' AS table_name,COUNT(*) AS row_count FROM inventory
UNION ALL
SELECT 'purchase_orders' AS table_name,COUNT(*) AS row_count FROM purchase_orders
UNION ALL
SELECT 'purchase_order_items' AS table_name,COUNT(*) AS row_count FROM purchase_order_items
UNION ALL
SELECT 'sales_orders' AS table_name,COUNT(*) AS row_count FROM sales_orders
UNION ALL
SELECT 'sales_order_items' AS table_name,COUNT(*) AS row_count FROM sales_order_items
UNION ALL
SELECT 'payments' AS table_name,COUNT(*) AS row_count FROM payments
UNION ALL
SELECT 'shipments' AS table_name,COUNT(*) AS row_count FROM shipments
UNION ALL
SELECT 'inventory_movements' AS table_name,COUNT(*) AS row_count FROM inventory_movements
UNION ALL
SELECT 'credit_accounts' AS table_name,COUNT(*) AS row_count FROM credit_accounts
UNION ALL
SELECT 'credit_transactions' AS table_name,COUNT(*) AS row_count FROM credit_transactions
UNION ALL
SELECT 'warranty_policies' AS table_name,COUNT(*) AS row_count FROM warranty_policies
UNION ALL
SELECT 'product_warranties' AS table_name,COUNT(*) AS row_count FROM product_warranties
UNION ALL
SELECT 'warranty_claims' AS table_name,COUNT(*) AS row_count FROM warranty_claims
ORDER BY table_name;
