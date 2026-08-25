"use client";

import { createContext, useContext, useMemo, type ReactNode } from "react";
import { useAccount, useModal, useDisconnect } from "@particle-network/connectkit";

export type ConnectKitBridgeValue = {
  /** ConnectKit provider is mounted and hooks are available */
  isAvailable: boolean;
  /** Stable connection resolution state for shell and wallet UI. */
  resolutionStatus: "unavailable" | "disconnected" | "resolving" | "connected";
  /** Human-readable setup/runtime failure, when the wallet path is unavailable. */
  error: string | undefined;
  isConnected: boolean;
  isConnecting: boolean;
  address: string | undefined;
  /** Opens Particle ConnectKit modal; no-op when unavailable */
  openConnectKit: () => void;
  disconnect: () => void;
};

const defaultBridge: ConnectKitBridgeValue = {
  isAvailable: false,
  resolutionStatus: "unavailable",
  error: "Wallet connection is not configured. Add the NEXT_PUBLIC_PROJECT_ID, NEXT_PUBLIC_CLIENT_KEY, and NEXT_PUBLIC_APP_ID variables to Frontend/.env.local.",
  isConnected: false,
  isConnecting: false,
  address: undefined,
  openConnectKit: () => {},
  disconnect: () => {},
};

const ConnectKitBridgeContext = createContext<ConnectKitBridgeValue>(defaultBridge);

/**
 * Must render inside ConnectKitProvider. Exposes connection actions to
 * components that must not call ConnectKit hooks directly (e.g. ConnectModal
 * when providers may be absent).
 */
export function ConnectKitBridge({ children }: { children: ReactNode }) {
  const { isConnected, address, isConnecting } = useAccount();
  const { setOpen } = useModal();
  const { disconnect } = useDisconnect();

  const value = useMemo<ConnectKitBridgeValue>(
    () => ({
      isAvailable: true,
      resolutionStatus: isConnecting ? "resolving" : isConnected ? "connected" : "disconnected",
      error: undefined,
      isConnected,
      isConnecting,
      address,
      openConnectKit: () => setOpen(true),
      disconnect: () => disconnect(),
    }),
    [isConnected, isConnecting, address, setOpen, disconnect],
  );

  return (
    <ConnectKitBridgeContext.Provider value={value}>{children}</ConnectKitBridgeContext.Provider>
  );
}

export function useConnectKitBridge(): ConnectKitBridgeValue {
  return useContext(ConnectKitBridgeContext);
}
