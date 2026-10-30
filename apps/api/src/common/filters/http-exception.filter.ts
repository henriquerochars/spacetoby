import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const exceptionResponse =
      exception instanceof HttpException
        ? exception.getResponse()
        : { message: 'Internal server error' };

    const message =
      typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as any).message || 'Unexpected error';

    const errorCode =
      typeof exceptionResponse === 'object' && (exceptionResponse as any).error
        ? (exceptionResponse as any).error
        : HttpStatus[status] || 'ERROR';

    response.status(status).json({
      success: false,
      error: {
        code: errorCode,
        message,
        statusCode: status,
        path: request.url,
      },
      timestamp: new Date().toISOString(),
    });
  }
}
