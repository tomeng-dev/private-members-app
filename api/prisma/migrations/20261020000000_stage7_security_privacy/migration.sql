-- Stage 7: lockout + deletion grace period
ALTER TABLE `users`
  ADD COLUMN `failed_login_count` INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN `locked_until` DATETIME(3) NULL,
  ADD COLUMN `deletion_requested_at` DATETIME(3) NULL,
  ADD COLUMN `deletion_scheduled_at` DATETIME(3) NULL;
