-- RSVP status enum widen
ALTER TABLE `event_rsvps` MODIFY `status` ENUM('going', 'maybe', 'not_going', 'waitlisted') NOT NULL DEFAULT 'going';

-- Events: status + fields; drop published
ALTER TABLE `events` ADD COLUMN `status` ENUM('draft', 'published', 'cancelled', 'completed') NOT NULL DEFAULT 'draft';
ALTER TABLE `events` ADD COLUMN `cover_image_key` VARCHAR(500) NULL;
ALTER TABLE `events` ADD COLUMN `capacity` INT NULL;
ALTER TABLE `events` ADD COLUMN `rsvp_cutoff_at` DATETIME(3) NULL;
ALTER TABLE `events` ADD COLUMN `fee_usd_cents` INT NOT NULL DEFAULT 100000;
ALTER TABLE `events` ADD COLUMN `payment_link_url` VARCHAR(1000) NULL;
UPDATE `events` SET `status` = 'published' WHERE `published` = true;
ALTER TABLE `events` DROP INDEX `events_published_idx`;
ALTER TABLE `events` DROP COLUMN `published`;
CREATE INDEX `events_status_idx` ON `events`(`status`);

ALTER TABLE `event_speakers` ADD COLUMN `topic` VARCHAR(500) NULL;
ALTER TABLE `event_speakers` ADD COLUMN `host_name` VARCHAR(200) NULL;
ALTER TABLE `event_speakers` ADD COLUMN `menu_notes` TEXT NULL;

ALTER TABLE `event_rsvps` ADD COLUMN `payment_status` ENUM('unpaid', 'paid', 'waived') NOT NULL DEFAULT 'unpaid';
ALTER TABLE `event_rsvps` CHANGE `qr_token` `qr_nonce` VARCHAR(128) NOT NULL;
CREATE INDEX `event_rsvps_event_id_status_idx` ON `event_rsvps`(`event_id`, `status`);

ALTER TABLE `event_checkins` ADD COLUMN `walk_in` BOOLEAN NOT NULL DEFAULT false;
