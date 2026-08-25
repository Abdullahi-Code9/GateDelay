This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server from **`Frontend/`**:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) (Next.js default). If that port is taken, `next dev` prints the next free port.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## App shell and WebSocket quickstart

`app/layout.tsx` is the application shell. On every route it mounts:

1. `PageErrorBoundary` — render failures show the error message (and stack in development), not a blank page
2. `ParticleClientWrapper` — client-only wallet provider; **children (navbar + page) render immediately** while ConnectKit loads
3. `WebSocketProvider` — Socket.IO client to Backend `/prices` (`NEXT_PUBLIC_BACKEND_URL`)
4. `Navbar` (`components/layout/Navigation.tsx`) — markets, wallet, Connect Wallet
5. `WalletRuntimeFeatures` — gates `BackupReminder` / `PendingTransactions` until ConnectKit is mounted so those hooks cannot blank the shell
6. The matched `app/**/page.tsx` route

[WEBSOCKET_QUICKSTART.md](WEBSOCKET_QUICKSTART.md) is the contributor guide for that WebSocket layer: TypeScript `@/*` aliases, env/ports, `/test-websocket`, and JWT requirements. Follow it from `Frontend/`; you do not add another `WebSocketProvider` unless you are writing an isolated test.

TypeScript aliases (`tsconfig.json`): `@/*` → `./*` (this package root). Example: `@/hooks/usePriceUpdates` → `Frontend/hooks/usePriceUpdates.ts`.

Wallet env vars and Backend port details: [CONTRIBUTING.md](../CONTRIBUTING.md), [`Backend/.env.example`](../Backend/.env.example) (`PORT=4000`).

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

## SSR Notes

- `Frontend/components/wallet/QRDisplay.tsx` is a client-only wallet QR component.
- The QR rendering library (`qrcode`) is dynamically imported at runtime to avoid SSR bundling or server-side DOM access issues.
- Clipboard access is guarded as a browser-only API.
- QR session timers are cleaned up on unmount to keep client transition paths stable during hydration.
- Phase 2+: if server-rendered QR previews are required, add a lightweight server-safe placeholder before hydration.
