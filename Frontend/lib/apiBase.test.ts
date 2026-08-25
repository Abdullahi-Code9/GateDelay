import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  MissingApiBaseError,
  MissingBackendUrlError,
  resolveApiBase,
  resolveBackendUrl,
} from "./apiBase";

describe("resolveApiBase", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.NEXT_PUBLIC_API_URL;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("returns the configured URL without a trailing slash", () => {
    process.env.NEXT_PUBLIC_API_URL = "https://api.example.com/api/";
    expect(resolveApiBase()).toBe("https://api.example.com/api");
  });

  it("falls back to localhost:4000/api in development", () => {
    process.env.NODE_ENV = "development";
    expect(resolveApiBase()).toBe("http://localhost:4000/api");
  });

  it("throws in production when unset", () => {
    process.env.NODE_ENV = "production";
    expect(() => resolveApiBase()).toThrow(MissingApiBaseError);
  });
});

describe("resolveBackendUrl", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.NEXT_PUBLIC_BACKEND_URL;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("returns the configured origin without a trailing slash", () => {
    process.env.NEXT_PUBLIC_BACKEND_URL = "https://api.example.com/";
    expect(resolveBackendUrl()).toBe("https://api.example.com");
  });

  it("falls back to localhost:4000 in development", () => {
    process.env.NODE_ENV = "development";
    expect(resolveBackendUrl()).toBe("http://localhost:4000");
  });

  it("throws in production when unset", () => {
    process.env.NODE_ENV = "production";
    expect(() => resolveBackendUrl()).toThrow(MissingBackendUrlError);
  });
});
