import { Module } from '@nestjs/common';
import { AppCacheModule } from '../cache/cache.module';
import { AuthModule } from '../auth/auth.module';
import { ClipStore } from './clip.store';
import { IpfsUploadService } from './ipfs-upload.service';
import { NftController } from './nft.controller';
import { NftMintService } from './nft-mint.service';
import { NftService } from './nft.service';
import { SorobanNftClient } from './soroban/soroban-nft.client';

@Module({
  imports: [AppCacheModule, AuthModule],
  controllers: [NftController],
  providers: [
    NftService,
    NftMintService,
    IpfsUploadService,
    SorobanNftClient,
    ClipStore,
  ],
  exports: [
    NftService,
    NftMintService,
    IpfsUploadService,
    SorobanNftClient,
    ClipStore,
  ],
})
export class NftModule {}
