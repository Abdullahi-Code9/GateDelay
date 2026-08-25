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

## The `/archive` route

`app/archive/page.tsx` lists resolved and cancelled markets.
`components/archive/ArchiveView.tsx` owns filtering, search and the summary
stats; the page owns data loading and the four terminal states.

**Data flow.** The page calls `/api/archive?limit=500`. That route handler
(`app/api/archive/route.ts`) proxies to `${NEXT_PUBLIC_API_URL}/markets/archive`,
forwarding the `category`, `outcome`, `from`, `to` and `limit` filters. The
browser never learns the backend origin. Both a bare array and a
`{ data: [...] }` envelope are accepted; rows that fail `isArchivedMarket` are
dropped rather than being allowed to crash the list mid-render.

**Environment.** `NEXT_PUBLIC_API_URL` — e.g. `http://localhost:4000/api`.
Resolved through `lib/apiBase.ts`, which keeps the localhost default for local
development but **throws in production builds** if the variable is unset. The
previous inline `?? "http://localhost:3000/api"` meant a deployment that forgot
the variable failed silently, pointing live traffic at a loopback address and
rendering an empty page instead of an error.

**Hydration.** Data is fetched in an effect, never during render, so the first
paint is identical on server and client and there is nothing to reconcile. When
adding to this page, do not seed state from `Date.now()`, `window`, or
`Math.random()` — each produces a server/client mismatch and the "text content
did not match" warning.

**No blank screens.** `loading`, `error`, `empty` and `ready` are all rendered
explicitly. The error state shows the reason the proxy reported and offers a
retry. The page previously held a static mock array with `isLoading` pinned to
`false`, so no failure could surface at all.

**Tests.** `app/archive/page.test.tsx` — 10 cases covering the heading, the
loading state, the proxy URL, rendering, the envelope form, malformed-row
filtering, the empty state, both error paths, and retry.

```bash
npm test                        # whole suite
npx vitest run app/archive      # this route only
```

> Known unrelated issue: `npm run lint` currently dies with
> `ERR_PACKAGE_PATH_NOT_EXPORTED` from `zod-validation-error` inside
> `eslint-config-next`'s dependency tree. It reproduces on untouched files and
> is a dependency version mismatch, not a code problem.
## Docker

```bash
npm run docker:build     # docker build -t gatedelay-frontend:local .
npm run docker:smoke     # boots the image, checks /api/ping, / and /audit
```

Multi-stage build on `node:22-alpine` using Next.js `output: "standalone"`, run
as a non-root user with a `/api/ping` healthcheck.

`NEXT_PUBLIC_*` values are **build args, not runtime env** — Next.js inlines them
into the client bundle, so an image is environment-specific and no secret may be
passed in. Required keys: `.env.example` (the only tracked `.env*` here). Full
build, retry, rollback and deploy-sequencing notes, including how a release
orders itself against `backend/services/upgradeCoordinator.js`:
[`docs/DEPLOY_FRONTEND_DOCKER.md`](../docs/DEPLOY_FRONTEND_DOCKER.md).

## App shell

`app/layout.tsx` is the only place chrome is defined. Every route renders inside
it, so a page component starts at its own `<main>` and never repeats the navbar,
theme or providers.

Provider order, outermost first:

| Provider | Supplies |
|---|---|
| `PageErrorBoundary` | Catches a render throw so one broken route does not blank the app |
| `ThemeProvider` | `--background` / `--foreground` / `--card` / `--border` / `--muted` tokens |
| `ToastProvider` | App-wide toasts |
| `QueryProvider` | The TanStack `QueryClient` every `useQuery` caller needs |
| `ParticleClientWrapper` | Wallet connect (Particle ConnectKit), client-only |
| `WebSocketProvider` / `ConnectivityProvider` | Live updates and offline detection |
| `Navbar` | `components/layout/Navigation.tsx`, re-exported by `app/components/Navbar.tsx` |

`QueryProvider` sits **outside** `ParticleClientWrapper` on purpose.
`ParticleProvider` returns its children unwrapped when the wallet env vars are
absent (`isParticleConnectKitConfigured()`), which is the normal state for a
fresh checkout — a query client nested inside it would vanish exactly when a new
collaborator first runs the app, and every `useQuery` page would throw
"No QueryClient set" on first load.

Adding a route to the navbar means adding it to `NAV_LINKS` in
`components/layout/Navigation.tsx`; the desktop row and the mobile drawer both
render from that one array.

## The `/audit` route

`app/audit/page.tsx` is the market audit log. It owns the page container, header
and `<Suspense>` fallback; all the data work lives in
`components/audit/AuditLogViewer.tsx`.

**Data flow.** The viewer calls `/api/market-audit?limit=2000`. That route
handler (`app/api/market-audit/route.ts`) proxies to the NestJS backend at
`${NEXT_PUBLIC_API_URL}/market-audit/logs`, forwarding the `marketId`,
`operation`, `actor`, `from`, `to` and `limit` filters. When the backend returns
rows they are rendered; when it returns nothing the viewer falls back to a
generated `MOCK_LOGS` set so the table, pagination and CSV export stay usable
offline. Live rows always win over the fallback.

**Responsive rules.** The page and the viewer share three:

- the container gutter steps `px-4` -> `sm:px-6` -> `lg:px-8` instead of sitting
  at a fixed `px-4`;
- stat cards step 1 -> 2 -> 4 columns (`grid-cols-1 sm:grid-cols-2
  lg:grid-cols-4`); going straight from 1 to 4 at `md` squeezed four cards into
  roughly 180px each on a tablet;
- the log table declares `min-w-[880px]` inside a `overflow-x-auto` wrapper, and
  the section around it is `min-w-0`. Together these keep the nine-column table
  scrolling **inside its own box** rather than widening the page — without the
  `min-w-0`, a wide grid child forces the whole document to scroll sideways.

**Tests.** `app/audit/page.test.tsx` covers the happy path: the header renders,
the page mounts under a `QueryClient`, `/api/market-audit` is called on first
load, live rows replace the mock fallback, and the table stays inside its scroll
container.

```bash
npm test                      # whole suite
npx vitest run app/audit       # this route only
```

## SSR Notes

- `Frontend/components/wallet/QRDisplay.tsx` is a client-only wallet QR component.
- The QR rendering library (`qrcode`) is dynamically imported at runtime to avoid SSR bundling or server-side DOM access issues.
- Clipboard access is guarded as a browser-only API.
- QR session timers are cleaned up on unmount to keep client transition paths stable during hydration.
- Phase 2+: if server-rendered QR previews are required, add a lightweight server-safe placeholder before hydration.
