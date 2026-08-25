import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { POST } from "./route";

describe("POST /api/ipfs/upload-json", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    process.env.NODE_ENV = "development";
    delete process.env.NEXT_PUBLIC_IPFS_GATEWAY;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("uploads JSON and returns a public gateway URL (happy path)", async () => {
    const res = await POST(
      new Request("http://localhost/api/ipfs/upload-json", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          data: { title: "GateDelay market", outcome: "delayed" },
          metadata: { name: "test-market" },
        }),
      }),
    );

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.success).toBe(true);
    expect(body.data.hash).toMatch(/^Qm/);
    expect(body.data.url).toMatch(/^https:\/\/gateway\.pinata\.cloud\/ipfs\/Qm/);
    expect(body.data.url).not.toMatch(/localhost/);
  });

  it("rejects missing data with VALIDATION_ERROR", async () => {
    const res = await POST(
      new Request("http://localhost/api/ipfs/upload-json", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ metadata: { name: "x" } }),
      }),
    );
    expect(res.status).toBe(400);
    await expect(res.json()).resolves.toMatchObject({
      success: false,
      code: "VALIDATION_ERROR",
    });
  });

  it("rejects malformed JSON without crashing the route", async () => {
    const res = await POST(
      new Request("http://localhost/api/ipfs/upload-json", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      }),
    );
    expect(res.status).toBe(400);
    await expect(res.json()).resolves.toMatchObject({
      code: "VALIDATION_ERROR",
    });
  });

  it("refuses a localhost gateway in the production path", async () => {
    process.env.NODE_ENV = "production";
    process.env.NEXT_PUBLIC_IPFS_GATEWAY = "http://localhost:8080/ipfs/";

    const res = await POST(
      new Request("http://localhost/api/ipfs/upload-json", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ data: { ok: true } }),
      }),
    );

    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.success).toBe(false);
    expect(body.code).toBe("CONFIG_ERROR");
    expect(body.error).toMatch(/localhost/i);
  });
});
