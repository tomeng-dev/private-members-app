import { Module } from '@nestjs/common';
import { ApplicationsModule } from '../applications/applications.module';
import { MembersModule } from '../members/members.module';
import { AdminConsoleController } from './admin-console.controller';
import { AdminConsoleService } from './admin-console.service';

@Module({
  imports: [ApplicationsModule, MembersModule],
  controllers: [AdminConsoleController],
  providers: [AdminConsoleService],
})
export class AdminConsoleModule {}
