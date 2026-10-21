import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Observable, tap } from 'rxjs';
import type { Request, Response } from 'express';

const EMAIL_RE = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;

function redact(s: string) {
  return s.replace(EMAIL_RE, '[redacted-email]');
}

@Injectable()
export class RequestIdInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest<Request & { requestId?: string }>();
    const res = http.getResponse<Response>();
    const id = (req.headers['x-request-id'] as string) || randomUUID();
    req.requestId = id;
    res.setHeader('x-request-id', id);
    const started = Date.now();
    return next.handle().pipe(
      tap({
        next: () => {
          const line = JSON.stringify({
            level: 'info',
            msg: 'http',
            requestId: id,
            method: req.method,
            path: redact(req.originalUrl || req.url),
            status: res.statusCode,
            ms: Date.now() - started,
          });
          // Structured JSON for CloudWatch
          console.log(line);
        },
        error: () => {
          console.log(
            JSON.stringify({
              level: 'error',
              msg: 'http',
              requestId: id,
              method: req.method,
              path: redact(req.originalUrl || req.url),
              ms: Date.now() - started,
            }),
          );
        },
      }),
    );
  }
}
