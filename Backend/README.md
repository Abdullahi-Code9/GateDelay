<p align="center">
  <a href="http://nestjs.com/" target="blank"><img src="https://nestjs.com/img/logo-small.svg" width="120" alt="Nest Logo" /></a>
</p>

[circleci-image]: https://img.shields.io/circleci/build/github/nestjs/nest/master?token=abc123def456
[circleci-url]: https://circleci.com/gh/nestjs/nest

  <p align="center">A progressive <a href="http://nodejs.org" target="_blank">Node.js</a> framework for building efficient and scalable server-side applications.</p>
    <p align="center">
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/v/@nestjs/core.svg" alt="NPM Version" /></a>
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/l/@nestjs/core.svg" alt="Package License" /></a>
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/dm/@nestjs/common.svg" alt="NPM Downloads" /></a>
<a href="https://circleci.com/gh/nestjs/nest" target="_blank"><img src="https://img.shields.io/circleci/build/github/nestjs/nest/master" alt="CircleCI" /></a>
<a href="https://discord.gg/G7Qnnhy" target="_blank"><img src="https://img.shields.io/badge/discord-online-brightgreen.svg" alt="Discord"/></a>
<a href="https://opencollective.com/nest#backer" target="_blank"><img src="https://opencollective.com/nest/backers/badge.svg" alt="Backers on Open Collective" /></a>
<a href="https://opencollective.com/nest#sponsor" target="_blank"><img src="https://opencollective.com/nest/sponsors/badge.svg" alt="Sponsors on Open Collective" /></a>
  <a href="https://paypal.me/kamilmysliwiec" target="_blank"><img src="https://img.shields.io/badge/Donate-PayPal-ff3f59.svg" alt="Donate us"/></a>
    <a href="https://opencollective.com/nest#sponsor"  target="_blank"><img src="https://img.shields.io/badge/Support%20us-Open%20Collective-41B883.svg" alt="Support us"></a>
  <a href="https://twitter.com/nestframework" target="_blank"><img src="https://img.shields.io/twitter/follow/nestframework.svg?style=social&label=Follow" alt="Follow us on Twitter"></a>
</p>
  <!--[![Backers on Open Collective](https://opencollective.com/nest/backers/badge.svg)](https://opencollective.com/nest#backer)
  [![Sponsors on Open Collective](https://opencollective.com/nest/sponsors/badge.svg)](https://opencollective.com/nest#sponsor)-->

## Description

[Nest](https://github.com/nestjs/nest) framework TypeScript starter repository.

## GateDelay Backend Setup

**For complete setup instructions, prerequisites, and troubleshooting, see [SETUP.md](./SETUP.md)**

### Quick Start

**Prerequisites**: Node.js >= 20.11, MongoDB, Redis

```bash
# 1. Install dependencies
$ npm install

# 2. Configure environment
$ cp .env.example .env
# Edit .env with your configuration

# 3. Start external services (MongoDB, Redis)

# 4. Build (⚠️ currently has build errors - see SETUP.md)
$ npm run build
```

## Project setup

```bash
$ npm install
```

## AML Compliance Endpoint

The backend includes an AML (Anti-Money Laundering) compliance route handler at `Backend/routes/aml.js`.

**Routes:**
- `POST /screen` — Screen a user against AML watchlists (requires auth)
- `POST /flag` — Record suspicious-activity flags (requires auth)
- `GET /report/:userId` — Generate a screening report for a date range (requires auth)
- `POST /file-report` — Submit regulatory filings (requires auth)

**Quick smoke test:**
```bash
npm run test:aml
```

See `Backend/routes/aml.js` and `Backend/services/amlService.js` for full inline documentation including the threat model and security assumptions.

## Approval Workflows

The backend includes a multi-step trade approval workflow handler at `Backend/routes/approvals.js`.

**Environment variable:**
- `APPROVAL_CRON_ENABLED` — Set to `"true"` to enable the background cron job that expires stale workflows every minute. Defaults to `false` (cron disabled), suitable for local development.

**Routes (9 endpoints, mount at `/approvals`):**
- `GET /approvals/stages` — List all approval stages with configuration
- `GET /approvals/history` — Get approval workflow history (optional filters)
- `GET /approvals/notifications` — Get pending notification queue
- `GET /approvals/trade/:tradeId` — Get workflows associated with a trade
- `GET /approvals/:workflowId` — Get full status of a specific workflow
- `POST /approvals` — Create a new approval workflow (requires `x-user-id` header)
- `POST /approvals/:workflowId/approve` — Submit an approval decision (requires `x-approver-id`, `x-approver-role` headers)
- `POST /approvals/delegate` — Delegate approval authority
- `DELETE /approvals/delegate` — Revoke a delegation

**Quick smoke test:**
```bash
npm run test:approvals
```

See `Backend/routes/approvals.js` and `Backend/services/approvalService.js` for full inline documentation.

## Beta Access

The backend includes a beta access management route handler at `Backend/routes/beta.js`.

**Routes (8 endpoints):**
- `GET /beta/features` — List available beta features
- `GET /beta/users` — List beta users (optional `?status=`, `?limit=`)
- `POST /beta/users` — Add a user to the beta list
- `DELETE /beta/users/:walletAddress` — Remove a user from the beta list
- `POST /beta/invite/accept` — Accept a beta invitation
- `GET /beta/access/:walletAddress` — Check beta access for a wallet
- `POST /beta/activity` — Track a beta activity event
- `GET /beta/activity/:walletAddress` — Get activity log for a wallet

**Quick smoke test:**
```bash
npm run test:beta
```

See `Backend/routes/beta.js` and `backend/services/betaAccess.js` for full inline documentation.

## Blacklist Management

The backend includes a blacklist management route handler at `Backend/routes/blacklist.js`.

**Routes (7 endpoints):**
- `POST /blacklist/add` — Add an identifier to the blacklist
- `POST /blacklist/remove` — Remove an identifier from the blacklist
- `GET /blacklist/check/:identifier` — Check if an identifier is blacklisted (no auth)
- `POST /blacklist/batch-add` — Batch add identifiers
- `POST /blacklist/batch-remove` — Batch remove identifiers
- `GET /blacklist/count` — Get total blacklisted entries
- `GET /blacklist/report` — Generate a report for a date range

**Quick smoke test:**
```bash
npm run test:blacklist
```

See `Backend/routes/blacklist.js` and `Backend/services/blacklistService.js` for full inline documentation.

## Health endpoints

The backend exposes health check endpoints for monitoring and CI/CD probes:

**Express server (port 4000):**
- `GET /health` - Basic health check with status and timestamp
- `GET /health/details` - Comprehensive health report including database, blockchain, Redis, and system components

**NestJS (port 3000):**
- `GET /api/health` - Basic health check with service info
- `GET /api/health/details` - Detailed health with uptime, memory, and environment info

## Compile and run the project

```bash
# Express server
$ npm run start:express

# Express server with watch mode
$ npm run start:express:dev

# NestJS development
$ npm run start:nest

# NestJS watch mode
$ npm run start:nest:dev

# NestJS debug mode
$ npm run start:nest:debug

# NestJS production
$ npm run start:nest:prod
```

## Build the project

```bash
$ npm run build
```

## Run tests

```bash
# unit tests
$ npm run test

# watch mode
$ npm run test:watch

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov

# debug tests
$ npm run test:debug
```

## Deployment

When you're ready to deploy your NestJS application to production, there are some key steps you can take to ensure it runs as efficiently as possible. Check out the [deployment documentation](https://docs.nestjs.com/deployment) for more information.

If you are looking for a cloud-based platform to deploy your NestJS application, check out [Mau](https://mau.nestjs.com), our official platform for deploying NestJS applications on AWS. Mau makes deployment straightforward and fast, requiring just a few simple steps:

```bash
$ npm install -g @nestjs/mau
$ mau deploy
```

With Mau, you can deploy your application in just a few clicks, allowing you to focus on building features rather than managing infrastructure.

## Resources

Check out a few resources that may come in handy when working with NestJS:

- Visit the [NestJS Documentation](https://docs.nestjs.com) to learn more about the framework.
- For questions and support, please visit our [Discord channel](https://discord.gg/G7Qnnhy).
- To dive deeper and get more hands-on experience, check out our official video [courses](https://courses.nestjs.com/).
- Deploy your application to AWS with the help of [NestJS Mau](https://mau.nestjs.com) in just a few clicks.
- Visualize your application graph and interact with the NestJS application in real-time using [NestJS Devtools](https://devtools.nestjs.com).
- Need help with your project (part-time to full-time)? Check out our official [enterprise support](https://enterprise.nestjs.com).
- To stay in the loop and get updates, follow us on [X](https://x.com/nestframework) and [LinkedIn](https://linkedin.com/company/nestjs).
- Looking for a job, or have a job to offer? Check out our official [Jobs board](https://jobs.nestjs.com).

## Support

Nest is an MIT-licensed open source project. It can grow thanks to the sponsors and support by the amazing backers. If you'd like to join them, please [read more here](https://docs.nestjs.com/support).

## Stay in touch

- Author - [Kamil Myśliwiec](https://twitter.com/kammysliwiec)
- Website - [https://nestjs.com](https://nestjs.com/)
- Twitter - [@nestframework](https://twitter.com/nestframework)

## License

Nest is [MIT licensed](https://github.com/nestjs/nest/blob/master/LICENSE).
