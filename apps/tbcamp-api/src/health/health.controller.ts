import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** プロセスの生存のみを返す。DB が落ちていても 200 を返すため、依存は見ない */
  @Get('health')
  health() {
    return { status: 'ok' };
  }

  /** DB に到達できるかを返す。到達できなければ 503 */
  @Get('ready')
  async ready() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      throw new ServiceUnavailableException({ status: 'not-ready' });
    }
    return { status: 'ready' };
  }
}
