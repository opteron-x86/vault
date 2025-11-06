-- Customer database schema and data
-- This file is for documentation; RDS initialization happens via Lambda or manual execution

CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    credit_card_last4 VARCHAR(4),
    total_spent DECIMAL(10, 2),
    secret_data TEXT
);

INSERT INTO customers (email, full_name, account_type, credit_card_last4, total_spent, secret_data) VALUES
('alice@example.com', 'Alice Johnson', 'premium', '4532', 15847.23, 'Account ID: ACC-2847'),
('bob@example.com', 'Bob Martinez', 'standard', '8765', 3421.89, 'Account ID: ACC-2848'),
('charlie@example.com', 'Charlie Davis', 'enterprise', '1234', 98234.56, 'Account ID: ACC-2849'),
('david@example.com', 'David Wilson', 'premium', '5678', 23456.78, 'Account ID: ACC-2850'),
('eve@example.com', 'Eve Anderson', 'standard', '9012', 8934.12, 'FLAG{rds_database_accessed_via_stolen_credentials}'),
('frank@example.com', 'Frank Thomas', 'enterprise', '3456', 145678.90, 'Account ID: ACC-2852'),
('grace@example.com', 'Grace Lee', 'premium', '7890', 34567.89, 'Account ID: ACC-2853'),
('henry@example.com', 'Henry Clark', 'standard', '2345', 12345.67, 'Account ID: ACC-2854'),
('iris@example.com', 'Iris Rodriguez', 'enterprise', '6789', 234567.89, 'Account ID: ACC-2855'),
('jack@example.com', 'Jack White', 'premium', '0123', 45678.90, 'Account ID: ACC-2856');

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    amount DECIMAL(10, 2) NOT NULL,
    transaction_type VARCHAR(50),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50)
);

INSERT INTO transactions (customer_id, amount, transaction_type, status) VALUES
(1, 1234.56, 'purchase', 'completed'),
(2, 234.89, 'purchase', 'completed'),
(3, 9876.54, 'purchase', 'completed'),
(1, 500.00, 'refund', 'completed'),
(4, 1500.00, 'purchase', 'pending'),
(5, 750.00, 'purchase', 'completed'),
(3, 15000.00, 'purchase', 'completed'),
(6, 2345.67, 'purchase', 'failed'),
(7, 890.12, 'purchase', 'completed'),
(8, 456.78, 'purchase', 'completed');

CREATE TABLE IF NOT EXISTS api_keys (
    key_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    api_key VARCHAR(255) NOT NULL,
    key_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO api_keys (customer_id, api_key, key_type, is_active) VALUES
(1, 'sk_live_abc123def456ghi789', 'production', true),
(2, 'sk_test_xyz987wvu654tsr321', 'test', true),
(3, 'sk_live_mno456pqr789stu012', 'production', true),
(4, 'sk_live_jkl345mno678pqr901', 'production', false),
(5, 'sk_test_def234ghi567jkl890', 'test', true);