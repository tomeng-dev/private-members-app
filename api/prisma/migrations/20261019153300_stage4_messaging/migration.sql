-- AlterTable
ALTER TABLE `messages` ADD COLUMN `link_url` VARCHAR(2000) NULL,
    ADD COLUMN `shared_post_id` CHAR(36) NULL;

-- CreateTable
CREATE TABLE `user_blocks` (
    `blocker_id` CHAR(36) NOT NULL,
    `blocked_id` CHAR(36) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `user_blocks_blocked_id_idx`(`blocked_id`),
    PRIMARY KEY (`blocker_id`, `blocked_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `thread_mutes` (
    `thread_id` CHAR(36) NOT NULL,
    `user_id` CHAR(36) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `thread_mutes_user_id_idx`(`user_id`),
    PRIMARY KEY (`thread_id`, `user_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `messages_shared_post_id_idx` ON `messages`(`shared_post_id`);

-- AddForeignKey
ALTER TABLE `messages` ADD CONSTRAINT `messages_shared_post_id_fkey` FOREIGN KEY (`shared_post_id`) REFERENCES `posts`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_blocks` ADD CONSTRAINT `user_blocks_blocker_id_fkey` FOREIGN KEY (`blocker_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_blocks` ADD CONSTRAINT `user_blocks_blocked_id_fkey` FOREIGN KEY (`blocked_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `thread_mutes` ADD CONSTRAINT `thread_mutes_thread_id_fkey` FOREIGN KEY (`thread_id`) REFERENCES `event_threads`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `thread_mutes` ADD CONSTRAINT `thread_mutes_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
