ALTER TABLE accounts MODIFY password_hash VARCHAR(255) NOT NULL;

CREATE TABLE IF NOT EXISTS auth_quick_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id INT UNSIGNED NOT NULL,
    token_hash CHAR(64) NOT NULL,
    device_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    last_used_at DATETIME NULL,
    revoked_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_auth_quick_token_hash (token_hash),
    KEY idx_auth_quick_account_device (account_id, device_hash),
    KEY idx_auth_quick_expiry (expires_at),
    CONSTRAINT fk_auth_quick_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
