CREATE TABLE IF NOT EXISTS jc_jobs (
    id VARCHAR(48) NOT NULL PRIMARY KEY,
    label VARCHAR(96) NOT NULL,
    description TEXT,
    category VARCHAR(48) NOT NULL DEFAULT 'civilian',
    icon VARCHAR(64) NOT NULL DEFAULT 'briefcase',
    status ENUM('draft', 'published', 'disabled') NOT NULL DEFAULT 'draft',
    definition JSON NOT NULL,
    version INT NOT NULL DEFAULT 1,
    created_by VARCHAR(64) DEFAULT NULL,
    updated_by VARCHAR(64) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_jc_jobs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS jc_job_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    job_id VARCHAR(48) NOT NULL,
    character_id INT UNSIGNED DEFAULT NULL,
    action VARCHAR(48) NOT NULL,
    detail VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_jc_logs_job (job_id),
    INDEX idx_jc_logs_char (character_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
