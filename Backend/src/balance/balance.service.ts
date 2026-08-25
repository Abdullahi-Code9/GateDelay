import { Injectable } from '@nestjs/common';

// The legacy model remains the persistence contract for both API stacks.
const balanceService = require('../../services/balanceService') as {
  getBalances(userId: string, asset?: string): Promise<unknown[]>;
  getBalance(userId: string, asset: string): Promise<unknown | null>;
};

@Injectable()
export class BalanceService {
  getBalances(userId: string, asset?: string) {
    return balanceService.getBalances(userId, asset);
  }

  getBalance(userId: string, asset: string) {
    return balanceService.getBalance(userId, asset);
  }
}
