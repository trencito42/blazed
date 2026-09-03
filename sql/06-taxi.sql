CREATE TABLE IF NOT EXISTS taxi_rides (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    passenger_character_id INT UNSIGNED NOT NULL,
    driver_character_id INT UNSIGNED NULL,
    pickup JSON NOT NULL,
    destination JSON NOT NULL,
    fare INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('pending', 'accepted', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    INDEX idx_passenger (passenger_character_id),
    INDEX idx_driver (driver_character_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
