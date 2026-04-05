-- ============================================================
-- REVOLUT BANKING DATABASE
-- Fichier 1 : Création des tables (DDL)
-- Compatible MySQL 8.0+ — Moteur InnoDB
-- ============================================================

CREATE DATABASE IF NOT EXISTS Revolut;
USE Revolut;

CREATE TABLE IF NOT EXISTS Country (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)   NOT NULL,
    currency        VARCHAR(10)    NOT NULL,
    withdrawal_rate DECIMAL(10, 4) NOT NULL
);

CREATE TABLE IF NOT EXISTS Bank (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    name             VARCHAR(100)   NOT NULL,
    country_id       INT            NOT NULL,
    currency         VARCHAR(10)    NOT NULL,
    withdrawal_limit DECIMAL(15, 2) NOT NULL,
    CONSTRAINT fk_bank_country FOREIGN KEY (country_id) REFERENCES Country(id)
);

CREATE TABLE IF NOT EXISTS Users (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    sex         CHAR(1)      CHECK (sex IN ('M', 'F', 'O')),
    age         INT,
    email       VARCHAR(255) NOT NULL UNIQUE,
    phoneNumber VARCHAR(20),
    address     VARCHAR(255),
    startDate   DATE         NOT NULL DEFAULT '2024-01-01'
);

CREATE TABLE IF NOT EXISTS TransactionType (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS Account (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    owner           INT            NOT NULL,
    bank_id         INT            NOT NULL,
    status          VARCHAR(20)    NOT NULL DEFAULT 'active',
    startDate       DATE           NOT NULL DEFAULT '2024-01-01',
    IBAN            VARCHAR(34)    NOT NULL UNIQUE,
    transferLimit   DECIMAL(15, 2) NOT NULL DEFAULT 0,
    withdrawalLimit DECIMAL(15, 2) NOT NULL DEFAULT 0,
    overdrawnLimit  DECIMAL(15, 2) NOT NULL DEFAULT 0,
    balance         DECIMAL(15, 2) NOT NULL DEFAULT 0,
    stockValue      DECIMAL(15, 2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_account_user FOREIGN KEY (owner)   REFERENCES Users(id),
    CONSTRAINT fk_account_bank FOREIGN KEY (bank_id) REFERENCES Bank(id)
);

CREATE TABLE IF NOT EXISTS BankCard (
    id                       INT AUTO_INCREMENT PRIMARY KEY,
    number                   VARCHAR(20)    NOT NULL UNIQUE,
    account_id               INT            NOT NULL,
    type                     VARCHAR(30)    NOT NULL,
    deposit_limit            DECIMAL(15, 2) NOT NULL DEFAULT 0,
    withdrawal_limit         DECIMAL(15, 2) NOT NULL DEFAULT 0,
    payment_limit            DECIMAL(15, 2) NOT NULL DEFAULT 0,
    transaction_date         DATE,
    transaction_country_rate DECIMAL(10, 4) NOT NULL DEFAULT 1,
    country_id               INT            NULL,
    CONSTRAINT fk_bankcard_account  FOREIGN KEY (account_id) REFERENCES Account(id),
    CONSTRAINT fk_bankcard_country  FOREIGN KEY (country_id) REFERENCES Country(id)
);

CREATE TABLE IF NOT EXISTS StockMarket (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    stock_name      VARCHAR(100)   NOT NULL,
    unit_value      DECIMAL(15, 4) NOT NULL,
    evolution_daily DECIMAL(10, 4) NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS Portfolio (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    account_id        INT            NOT NULL,
    stock_market_id   INT            NOT NULL,
    stock_name        VARCHAR(100)   NOT NULL,
    unit_value        DECIMAL(15, 4) NOT NULL,
    nb_shares         INT            NOT NULL DEFAULT 0,
    total_stock_value DECIMAL(15, 2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_portfolio_account     FOREIGN KEY (account_id)     REFERENCES Account(id),
    CONSTRAINT fk_portfolio_stockmarket FOREIGN KEY (stock_market_id) REFERENCES StockMarket(id)
);

CREATE TABLE IF NOT EXISTS Transactions (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    account_id       INT            NOT NULL,
    type_id          INT            NOT NULL,
    amount           DECIMAL(15, 2) NOT NULL,
    transaction_date DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_transaction_account FOREIGN KEY (account_id) REFERENCES Account(id),
    CONSTRAINT fk_transaction_type    FOREIGN KEY (type_id)    REFERENCES TransactionType(id)
);

CREATE TABLE IF NOT EXISTS Withdrawal (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id   INT            NOT NULL UNIQUE,
    amount           DECIMAL(15, 2) NOT NULL,
    rate             DECIMAL(10, 4) NOT NULL DEFAULT 1,
    transaction_date DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_withdrawal_transaction FOREIGN KEY (transaction_id) REFERENCES Transactions(id)
);

CREATE TABLE IF NOT EXISTS Deposit (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id   INT            NOT NULL UNIQUE,
    amount           DECIMAL(15, 2) NOT NULL,
    transaction_date DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_deposit_transaction FOREIGN KEY (transaction_id) REFERENCES Transactions(id)
);

CREATE TABLE IF NOT EXISTS Transfer (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id      INT            NOT NULL UNIQUE,
    amount              DECIMAL(15, 2) NOT NULL,
    reference           VARCHAR(100)   NOT NULL UNIQUE,
    user_destination_id INT            NOT NULL,
    transaction_date    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_transfer_transaction FOREIGN KEY (transaction_id)     REFERENCES Transactions(id),
    CONSTRAINT fk_transfer_dest_user   FOREIGN KEY (user_destination_id) REFERENCES Users(id)
);

CREATE TABLE IF NOT EXISTS AuditLogs (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT            NOT NULL,
    type             VARCHAR(50)    NOT NULL,
    amount           DECIMAL(15, 2),
    transaction_date DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_auditlogs_user FOREIGN KEY (user_id) REFERENCES Users(id)
);
