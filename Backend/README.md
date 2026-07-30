# Backend

The backend mixes a lightweight Express API (`server.js`), background services, and a newer Nest-based `src/` app. Start by copying `.env.example` to `.env` and filling in the placeholders for the services you plan to run.

## Required environment variables

These values should always be reviewed before local development or deployment:

- `JWT_SECRET` and `JWT_REFRESH_SECRET`: authentication secrets
- `MONGODB_URI`: primary application database
- `AVIATION_STACK_API_KEY`: live flight data provider
- `RPC_URL` or `BLOCKCHAIN_RPC_URL`: chain access for rollback and oracle flows
- `PRIVATE_KEY`: signer used by contract-facing backend jobs

Redis-backed workers also require either `REDIS_URL` or `REDIS_HOST`/`REDIS_PORT`.

## Setup

```bash
npm install
```

## Run

```bash
npm run dev
```

The default Express entrypoint listens on `PORT` and serves:

- `/health`
- `/api/migrations`
- `/api/rollback`
- `/api/beta`
- `/api/oncall`
- `/api/upgrades`

## Notes

- `.env.example` intentionally contains placeholders only; do not commit real secrets.
- Several advanced integrations such as PagerDuty, Twilio, IPFS, Polygon/Mainnet/Testnet addresses, and Firebase are optional unless you enable those workflows.
