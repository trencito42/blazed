-- 47: Admin sanction system (ADMIN_SYSTEM_SPEC.md §3)
-- Owned by sunset_admin (domain rule: only this resource writes it).

CREATE TABLE IF NOT EXISTS admin_sanctions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    action ENUM('warn','kick','tempban','ban','unban','jail','unjail','freeze','slap','clearwarns') NOT NULL,
    target_account_id INT NULL,
    target_character_id INT NULL,
    target_name VARCHAR(64) NOT NULL,
    target_license VARCHAR(64) NULL,
    admin_account_id INT NULL,
    admin_name VARCHAR(64) NOT NULL,
    reason VARCHAR(255) NOT NULL DEFAULT '',
    duration_min INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_target_acc (target_account_id),
    INDEX idx_license (target_license),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Temp-ban support: bans.expires_at already exists in schema (verified);
-- ensure the connecting-player deferral uses it (server code change, no DDL).
-- Ban hardening: store hardware tokens per ban (phase 2 of spec).
CREATE TABLE IF NOT EXISTS ban_tokens (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ban_id INT UNSIGNED NOT NULL,
    token VARCHAR(128) NOT NULL,
    INDEX idx_token (token),
    INDEX idx_ban (ban_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
