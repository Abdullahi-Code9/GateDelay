import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emits `.next/standalone` with a self-contained `server.js` and only the
  // node_modules actually traced from the build. The Dockerfile's runtime stage
  // copies that instead of the full dependency tree, which is what keeps the
  // image from carrying the whole devDependency set.
  // Harmless outside Docker: `next dev` and `next start` are unaffected.
  output: "standalone",
};

export default nextConfig;
