-- AlterTable
ALTER TABLE `business_pages` ADD COLUMN `hidden_at` DATETIME(3) NULL,
    ADD COLUMN `show_contact_email` BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN `show_contact_phone` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `media` ADD COLUMN `exif_stripped` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `hidden_at` DATETIME(3) NULL,
    ADD COLUMN `scan_status` VARCHAR(32) NOT NULL DEFAULT 'pending',
    ADD COLUMN `thumbnail_key` VARCHAR(500) NULL;

-- AlterTable
ALTER TABLE `users` ADD COLUMN `hidden_at` DATETIME(3) NULL,
    ADD COLUMN `show_email` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `show_events_attended` BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN `show_phone` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `vehicles` ADD COLUMN `blur_plate` BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN `color` VARCHAR(64) NULL,
    ADD COLUMN `hidden_at` DATETIME(3) NULL,
    ADD COLUMN `plate_number` VARCHAR(32) NULL;
