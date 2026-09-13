-- 46: Faction management overhaul
-- FP (faction punish), resignation requests, membership join tracking.

-- FP: characters blocked from joining any faction while fp > 0.
-- Decays 1 FP per payday (handled in sunset_factions, NOT in economy -
-- economy emits sunset:payday:processed and factions owns this table).
CREATE TABLE IF NOT EXISTS faction_punish (
    character_id INT NOT NULL PRIMARY KEY,
    fp INT NOT NULL DEFAULT 0,
    reason VARCHAR(255) NULL,
    set_by_character_id INT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Resignation requests: member submits, leader accepts (with or without FP)
-- or declines. Expires after 7 days.
CREATE TABLE IF NOT EXISTS faction_resignations (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    faction_id VARCHAR(48) NOT NULL,
    character_id INT NOT NULL,
    reason VARCHAR(255) NULL,
    status ENUM('pending','accepted','accepted_fp','declined','expired') NOT NULL DEFAULT 'pending',
    handled_by_character_id INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    handled_at TIMESTAMP NULL,
    -- NULL unless pending; UNIQUE ignores NULLs -> max ONE pending row per char.
    pending_key INT AS (CASE WHEN status = 'pending' THEN character_id ELSE NULL END) STORED,
    UNIQUE KEY uq_pending_resignation (pending_key),
    INDEX idx_faction_pending (faction_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Membership join tracking: when a character joined their CURRENT faction.
-- Roster shows "< 14 days" badge so leaders spot recent joins (who should be
-- kicked WITH FP manually if they leave early).
CREATE TABLE IF NOT EXISTS faction_membership (
    character_id INT NOT NULL PRIMARY KEY,
    faction_id VARCHAR(48) NOT NULL,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_faction (faction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
