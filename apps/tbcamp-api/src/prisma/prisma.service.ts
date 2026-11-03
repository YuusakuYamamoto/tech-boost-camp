import { Injectable } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';

// 起動時に $connect() しない。DB が落ちていても api を起動し、/health に応答できるようにするため。
// Prisma Client は最初のクエリで遅延接続する
@Injectable()
export class PrismaService extends PrismaClient {
  constructor() {
    super({
      adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
    });
  }
}
