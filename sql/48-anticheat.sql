-- 48-anticheat.sql — Blaze Shield anticheat (docs/ANTICHEAT_SPEC.md §7)
-- Owned domain: sunset_anticheat (writes ONLY these two tables).

CREATE TABLE IF NOT EXISTS anticheat_strikes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id INT NULL,
  account_id INT NULL,
  player_name VARCHAR(64) NOT NULL,
  license VARCHAR(64) NULL,
  detector VARCHAR(48) NOT NULL,
  severity TINYINT UNSIGNED NOT NULL,
  measured VARCHAR(255) NOT NULL,      -- e.g. "68.2 m/s vs limit 45 (sedan)"
  context JSON NULL,                   -- {in_war:false, bucket:0, admin_action:"/tp 4s ago", session:null, ping:82}
  resolved ENUM('pending','dismissed','warned','kicked','banned') DEFAULT 'pending',
  resolved_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NULL,           -- decay (30 min default)
  INDEX idx_acc_created (account_id, created_at),
  INDEX idx_detector (detector, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS anticheat_flags (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  account_id INT NULL,
  player_name VARCHAR(64) NOT NULL,
  flag_type VARCHAR(48) NOT NULL,      -- 'economy_injection','admin_event_abuse','aim_stats'
  evidence JSON NOT NULL,
  action_taken VARCHAR(32) DEFAULT 'none',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_acc (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
