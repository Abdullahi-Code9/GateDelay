This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

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
