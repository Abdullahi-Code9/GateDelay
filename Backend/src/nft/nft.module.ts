import { Module } from '@nestjs/common';
import { AppCacheModule } from '../cache/cache.module';
import { AuthModule } from '../auth/auth.module';
import { ClipStore } from './clip.store';
import { NftController } from './nft.controller';
import { NftMintService } from './nft-mint.service';
import { NftController } from './nft.controller';
import { NftService } from './nft.service';
import { SorobanNftClient } from './soroban/soroban-nft.client';

@Module({
  imports: [AppCacheModule, AuthModule],
  controllers: [NftController],
  providers: [NftService, NftMintService, SorobanNftClient, ClipStore],
  exports: [NftService, NftMintService, SorobanNftClient, ClipStore],
  providers: [NftService, SorobanNftClient],
  exports: [NftService, SorobanNftClient],
})
export class NftModule {}
