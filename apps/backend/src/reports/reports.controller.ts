import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ReportsService } from './reports.service';
import { JwtPayload } from '@simtc/shared-types';

@ApiTags('reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reports')
export class ReportsController {
  constructor(private readonly service: ReportsService) {}

  @Get('training-sessions')
  getAll(@CurrentUser() user: JwtPayload) {
    return this.service.getTrainingSessions(user);
  }

  @Get('training-sessions/:id')
  getSession(@Param('id') id: string, @CurrentUser() user: JwtPayload) {
    return this.service.getSessionReport(id, user);
  }

  @Get('companies/:id/history')
  getCompanyHistory(@Param('id') companyId: string, @CurrentUser() user: JwtPayload) {
    return this.service.getCompanyHistory(companyId, user);
  }
}
