"use client";

import dynamic from "next/dynamic";
import { isParticleConnectKitConfigured } from "../../lib/walletDetection";
import { ConnectKitBridgePassthrough } from "./ConnectKitBridgeContext";
import { WagmiShell } from "./WagmiShell";

const ParticleProviderInner = dynamic(
  () => import("./ParticleProvider").then((m) => m.ParticleProvider),
  { ssr: false, loading: () => null },
);

/**
 * Wallet provider gate for the app shell.
 *
 * - No Particle credentials: mount a minimal `WagmiShell` + no-op ConnectKit
 *   bridge so layout/nav/home widgets that call wagmi hooks do not crash.
 * - With credentials: mount Particle ConnectKit (which supplies Wagmi + bridge).
 */
export function ParticleClientWrapper({ children }: { children: React.ReactNode }) {
  if (!isParticleConnectKitConfigured()) {
    return (
      <WagmiShell>
        <ConnectKitBridgePassthrough>{children}</ConnectKitBridgePassthrough>
      </WagmiShell>
    );
  }

  return <ParticleProviderInner>{children}</ParticleProviderInner>;
}
