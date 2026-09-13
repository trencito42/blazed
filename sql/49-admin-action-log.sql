-- 49: Full admin action log (every staff command invocation with args).
-- Owned by sunset_admin (domain rule: only this resource writes it).

CREATE TABLE IF NOT EXISTS admin_action_log (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    admin_source INT NULL,
    admin_name VARCHAR(64) NOT NULL,
    admin_account_id INT NULL,
    command VARCHAR(32) NOT NULL,
    args VARCHAR(255) NOT NULL DEFAULT '',
    allowed TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin_acc (admin_account_id),
    INDEX idx_cmd (command),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
