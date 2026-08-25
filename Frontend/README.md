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

## SSR Notes

- `Frontend/components/wallet/QRDisplay.tsx` is a client-only wallet QR component.
- The QR rendering library (`qrcode`) is dynamically imported at runtime to avoid SSR bundling or server-side DOM access issues.
- Clipboard access is guarded as a browser-only API.
- QR session timers are cleaned up on unmount to keep client transition paths stable during hydration.
- Phase 2+: if server-rendered QR previews are required, add a lightweight server-safe placeholder before hydration.
