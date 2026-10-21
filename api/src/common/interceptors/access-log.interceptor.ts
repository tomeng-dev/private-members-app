import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';

@Injectable()
export class AccessLogInterceptor implements NestInterceptor {
  private readonly logger = new Logger('AccessLog');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest();
    const { method, originalUrl } = req;
    const start = Date.now();
    const userId = req.user?.userId ?? '-';
    return next.handle().pipe(
      tap({
        next: () => {
          const res = context.switchToHttp().getResponse();
          this.logger.log(
            `${method} ${originalUrl} ${res.statusCode} ${Date.now() - start}ms user=${userId}`,
          );
        },
        error: (err) => {
          this.logger.warn(
            `${method} ${originalUrl} ERR ${Date.now() - start}ms user=${userId} ${err?.message}`,
          );
        },
      }),
    );
  }
}
