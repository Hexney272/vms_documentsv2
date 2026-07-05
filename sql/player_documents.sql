CREATE TABLE IF NOT EXISTS `player_documents` (
    `serial_number` varchar(64) NOT NULL,
    `owner` varchar(128) NOT NULL,
    `type` varchar(64) NOT NULL,
    `photo` longtext NULL,
    `valid` tinyint(1) NOT NULL DEFAULT 1,
    `for_pickup` tinyint(1) NOT NULL DEFAULT 0,
    `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`serial_number`),
    KEY `idx_owner_valid` (`owner`, `valid`),
    KEY `idx_owner_type_valid` (`owner`, `type`, `valid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `photo` LONGTEXT NULL;
ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `valid` TINYINT(1) NOT NULL DEFAULT 1;
ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `for_pickup` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
