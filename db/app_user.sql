-- ---------------------------------------------------------------------------
-- app_user: the ONLY new table for Practical 5.
-- It stores the people who can log in to the web application.
-- The seven business tables are NOT changed.
-- Passwords are stored as bcrypt hashes (never plain text).
-- Run this file in MySQL Workbench, or let `npm run seed:users` run it for you.
-- ---------------------------------------------------------------------------
USE PanchshilAgro;

CREATE TABLE IF NOT EXISTS app_user (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role           ENUM('admin','staff','accountant') NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
