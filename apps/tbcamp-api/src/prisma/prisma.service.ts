import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

// 起動時に $connect() しない。DB が落ちていても api を起動し、/health に応答できるようにするため。
// Prisma Client は最初のクエリで遅延接続する
@Injectable()
export class PrismaService extends PrismaClient {}
