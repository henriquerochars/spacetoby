import { Global, Module } from '@nestjs/common';
import { DataRepositoryService } from './data-repository.service';

@Global()
@Module({
  providers: [DataRepositoryService],
  exports: [DataRepositoryService],
})
export class DataRepositoryModule {}
