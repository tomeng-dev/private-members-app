ALTER TABLE `users` ADD COLUMN `totp_secret` VARCHAR(255) NULL;
ALTER TABLE `users` ADD COLUMN `totp_enabled_at` DATETIME(3) NULL;
ALTER TABLE `users` ADD COLUMN `totp_recovery_hashes` TEXT NULL;

CREATE TABLE `notification_preferences` (
    `user_id` CHAR(36) NOT NULL,
    `push_messages` BOOLEAN NOT NULL DEFAULT true,
    `push_events` BOOLEAN NOT NULL DEFAULT true,
    `push_threads` BOOLEAN NOT NULL DEFAULT true,
    `push_dues` BOOLEAN NOT NULL DEFAULT true,
    `push_applications` BOOLEAN NOT NULL DEFAULT true,
    `email_events` BOOLEAN NOT NULL DEFAULT true,
    `email_dues` BOOLEAN NOT NULL DEFAULT true,
    `email_applications` BOOLEAN NOT NULL DEFAULT true,
    `updated_at` DATETIME(3) NOT NULL,

    PRIMARY KEY (`user_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `notification_preferences` ADD CONSTRAINT `notification_preferences_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE `job_locks` (
    `name` VARCHAR(100) NOT NULL,
    `locked_at` DATETIME(3) NOT NULL,
    `locked_by` VARCHAR(100) NOT NULL,
    `expires_at` DATETIME(3) NOT NULL,

    PRIMARY KEY (`name`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
