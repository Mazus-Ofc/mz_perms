-- mz_perms SQL
CREATE TABLE IF NOT EXISTS `player_groups` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `type` ENUM('staff','vip','group') NOT NULL,
  `group_name` VARCHAR(64) NOT NULL,
  `added_by` VARCHAR(64) DEFAULT NULL,
  `added_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_identifier` (`identifier`),
  KEY `idx_type_name` (`type`, `group_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
