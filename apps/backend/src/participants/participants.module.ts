import { Module } from '@nestjs/common';
import { ParticipantsController } from './participants.controller';
import { ParticipantsService } from './participants.service';
import { PublicRegisterController } from './public-register.controller';

@Module({
  controllers: [ParticipantsController, PublicRegisterController],
  providers: [ParticipantsService],
  exports: [ParticipantsService],
})
export class ParticipantsModule {}
