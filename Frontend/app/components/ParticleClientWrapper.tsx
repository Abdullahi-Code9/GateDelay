"use client";
import dynamic from "next/dynamic";

const ParticleProviderInner = dynamic(
  () => import("./ParticleProvider").then((m) => m.ParticleProvider),
  {
    ssr: false,
    loading: () => (
      <div className="flex min-h-screen items-center justify-center" role="status" aria-live="polite">
        <span className="text-sm" style={{ color: "var(--muted)" }}>
          Resolving wallet connection…
        </span>
      </div>
    ),
  },
);

export function ParticleClientWrapper({ children }: { children: React.ReactNode }) {
  return <ParticleProviderInner>{children}</ParticleProviderInner>;
}
