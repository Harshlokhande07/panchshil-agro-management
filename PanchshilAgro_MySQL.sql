-- =====================================================================
-- Panchshil Agro Agencies - DBMS ER model (MySQL 8.0 / MySQL Workbench)
-- Creates the database and all 7 tables.
-- Safe to re-run: existing tables are dropped first.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS PanchshilAgro
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE PanchshilAgro;

-- ---------------------------------------------------------------------
-- Drop existing tables (children first)
-- ---------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Warranty;
DROP TABLE IF EXISTS Payment;
DROP TABLE IF EXISTS Credit;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS Product;
DROP TABLE IF EXISTS Supplier;
DROP TABLE IF EXISTS Customer;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Customer
CREATE TABLE Customer (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    phone         VARCHAR(15),
    address       VARCHAR(255)
) ENGINE=InnoDB;

-- 2. Supplier
CREATE TABLE Supplier (
    supplier_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    phone         VARCHAR(15),
    email         VARCHAR(100)
) ENGINE=InnoDB;

-- 3. Product  (Supplier 1:N Product)
CREATE TABLE Product (
    product_id      INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id     INT NOT NULL,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50),          -- Fertilizer, Pesticide, Seed, Equipment
    brand           VARCHAR(50),
    purchase_price  DECIMAL(10,2) NOT NULL,
    selling_price   DECIMAL(10,2) NOT NULL,
    min_stock       INT NOT NULL DEFAULT 0,
    CONSTRAINT CK_Product_Purchase CHECK (purchase_price >= 0),
    CONSTRAINT CK_Product_Selling  CHECK (selling_price >= 0),
    CONSTRAINT CK_Product_MinStock CHECK (min_stock >= 0),
    CONSTRAINT FK_Product_Supplier FOREIGN KEY (supplier_id)
        REFERENCES Supplier(supplier_id)
) ENGINE=InnoDB;

-- 4. Inventory  (Product 1:N Inventory)
CREATE TABLE Inventory (
    inventory_id  INT AUTO_INCREMENT PRIMARY KEY,
    product_id    INT NOT NULL,
    batch_no      VARCHAR(50) NOT NULL,
    expiry_date   DATE,
    shelf_qty     INT NOT NULL DEFAULT 0,
    godown_qty    INT NOT NULL DEFAULT 0,
    CONSTRAINT CK_Inventory_Shelf  CHECK (shelf_qty >= 0),
    CONSTRAINT CK_Inventory_Godown CHECK (godown_qty >= 0),
    CONSTRAINT FK_Inventory_Product FOREIGN KEY (product_id)
        REFERENCES Product(product_id),
    CONSTRAINT UQ_Inventory_Product_Batch UNIQUE (product_id, batch_no)
) ENGINE=InnoDB;

-- 5. Credit  (Customer 1:N Credit)
CREATE TABLE Credit (
    credit_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT NOT NULL,
    total_due    DECIMAL(10,2) NOT NULL,
    amount_paid  DECIMAL(10,2) NOT NULL DEFAULT 0,
    due_date     DATE,
    status       ENUM('Pending','Partial','Paid','Overdue') NOT NULL DEFAULT 'Pending',
    CONSTRAINT CK_Credit_Due  CHECK (total_due >= 0),
    CONSTRAINT CK_Credit_Paid CHECK (amount_paid >= 0),
    CONSTRAINT FK_Credit_Customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
) ENGINE=InnoDB;

-- 6. Payment  (Customer 1:N Payment, Credit 1:N Payment; credit_id nullable for cash sales)
CREATE TABLE Payment (
    payment_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT NOT NULL,
    credit_id     INT NULL,
    amount        DECIMAL(10,2) NOT NULL,
    payment_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
    mode          ENUM('Cash','UPI','Card') NOT NULL,
    CONSTRAINT CK_Payment_Amount CHECK (amount > 0),
    CONSTRAINT FK_Payment_Customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id),
    CONSTRAINT FK_Payment_Credit FOREIGN KEY (credit_id)
        REFERENCES Credit(credit_id)
) ENGINE=InnoDB;

-- 7. Warranty  (Customer 1:N Warranty; Product 1:N Warranty)
CREATE TABLE Warranty (
    warranty_id      INT AUTO_INCREMENT PRIMARY KEY,
    product_id       INT NOT NULL,
    customer_id      INT NOT NULL,
    batch_no         VARCHAR(50) NOT NULL,
    start_date       DATE NOT NULL,
    end_date         DATE NOT NULL,
    return_reason    VARCHAR(255),
    supplier_status  ENUM('Sent','Replaced','Rejected') NOT NULL DEFAULT 'Sent',
    CONSTRAINT CK_Warranty_Dates CHECK (end_date >= start_date),
    CONSTRAINT FK_Warranty_Product FOREIGN KEY (product_id)
        REFERENCES Product(product_id),
    CONSTRAINT FK_Warranty_Customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Verify: should list all 7 tables
-- ---------------------------------------------------------------------
SHOW TABLES;
