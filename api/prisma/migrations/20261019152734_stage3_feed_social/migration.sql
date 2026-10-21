/*
  Warnings:

  - You are about to drop the column `link_preview` on the `posts` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE `comments` ADD COLUMN `hidden_at` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `media` ADD COLUMN `poster_key` VARCHAR(500) NULL;

-- AlterTable
ALTER TABLE `posts` DROP COLUMN `link_preview`,
    ADD COLUMN `hidden_at` DATETIME(3) NULL,
    ADD COLUMN `link_description` VARCHAR(1000) NULL,
    ADD COLUMN `link_image_url` VARCHAR(1000) NULL,
    ADD COLUMN `link_title` VARCHAR(500) NULL,
    ADD COLUMN `shared_from_post_id` CHAR(36) NULL;

-- CreateIndex
CREATE INDEX `posts_hidden_at_idx` ON `posts`(`hidden_at`);

-- AddForeignKey
ALTER TABLE `posts` ADD CONSTRAINT `posts_shared_from_post_id_fkey` FOREIGN KEY (`shared_from_post_id`) REFERENCES `posts`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
