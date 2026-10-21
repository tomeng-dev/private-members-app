import { Injectable, Logger } from '@nestjs/common';
import { hostname } from 'os';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

/**
 * Single-instance-safe job lock. For multi-instance, all nodes share MySQL
 * and only the lock holder runs the job. See docs/scheduled-jobs.md.
 */
@Injectable()
export class JobLockService {
  private readonly logger = new Logger(JobLockService.name);
  private readonly owner = `${hostname()}:${process.pid}`;

  constructor(private readonly prisma: PrismaService) {}

  async withLock<T>(
    name: string,
    ttlMs: number,
    fn: () => Promise<T>,
  ): Promise<T | null> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ttlMs);
    try {
      const existing = await this.prisma.jobLock.findUnique({
        where: { name },
      });
      if (existing && existing.expiresAt > now) {
        this.logger.debug(`lock busy: ${name}`);
        return null;
      }
      await this.prisma.jobLock.upsert({
        where: { name },
        create: { name, lockedAt: now, lockedBy: this.owner, expiresAt },
        update: { lockedAt: now, lockedBy: this.owner, expiresAt },
      });
      return await fn();
    } catch (e) {
      this.logger.warn(`job ${name} failed: ${String(e)}`);
      return null;
    }
  }
}
