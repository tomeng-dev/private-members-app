import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { MembersModule } from '../members/members.module';
import { JobLockService } from './job-lock.service';
import { JobsService } from './jobs.service';

@Module({
  imports: [ScheduleModule.forRoot(), MembersModule],
  providers: [JobLockService, JobsService],
  exports: [JobsService, JobLockService],
})
export class JobsModule {}
