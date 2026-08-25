import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emits `.next/standalone` with a self-contained `server.js` and only the
  // node_modules actually traced from the build. The Dockerfile's runtime stage
  // copies that instead of the full dependency tree, which is what keeps the
  // image from carrying the whole devDependency set.
  // Harmless outside Docker: `next dev` and `next start` are unaffected.
  output: "standalone",

  // Pin the Turbopack root to this package so the monorepo's parent
  // package-lock.json is not treated as the workspace root.
  turbopack: {
    root: __dirname,
    // Particle ConnectKit → AWS credential providers reference Node built-ins.
    // Stub them for the browser so Turbopack can chunk the wallet graph.
    resolveAlias: {
      fs: "./lib/empty-module.js",
      "node:fs": "./lib/empty-module.js",
      child_process: "./lib/empty-module.js",
      "node:child_process": "./lib/empty-module.js",
      net: "./lib/empty-module.js",
      "node:net": "./lib/empty-module.js",
      tls: "./lib/empty-module.js",
      "node:tls": "./lib/empty-module.js",
    },
  },

  webpack: (config, { isServer, webpack }) => {
    // Rewrite `node:fs` → `fs` so resolve.fallback can stub them for the browser.
    config.plugins.push(
      new webpack.NormalModuleReplacementPlugin(/^node:/, (resource: { request: string }) => {
        resource.request = resource.request.replace(/^node:/, "");
      }),
    );

    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        child_process: false,
        net: false,
        tls: false,
      };
    }
    return config;
  },
};

export default nextConfig;
