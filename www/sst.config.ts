/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "genuiform",
      removal: input?.stage === "production" ? "retain" : "remove",
      protect: ["production"].includes(input?.stage),
      home: "aws",
    };
  },
  async run() {
    const landing = new sst.aws.StaticSite("Landing", {
      path: "landing",
      build: {
        command: "npm install && npm run build",
        output: "dist",
      },
      domain: "genuiform.draht.dev",
    });

    const demo = new sst.aws.StaticSite("Demo", {
      path: "demo",
      build: {
        command: "flutter build web --release --wasm",
        output: "build/web",
      },
      domain: "workbench.genuiform.draht.dev",
      // Disable CloudFront's automatic compression. Diagnosed live:
      // byte-identical Flutter web bundle renders correctly with no
      // compression (local HTTP serve) AND with gzip (cloudflared
      // tunnel of the same local serve), but freezes when CloudFront
      // (or Netlify) serves it with `content-encoding: br`. The
      // dialog still opens (early setState works), but later
      // StreamBuilder rebuilds driven by the LLM streaming response
      // never paint until the user resizes the window. Compression
      // off makes CloudFront serve the bundle uncompressed; the
      // browser still gets correct bytes (md5 verified) and rebuilds
      // pump fine.
      transform: {
        cdn: (args) => {
          // Mutate-in-place so we keep SST's defaults (allowedMethods,
          // cachedMethods, cachePolicyId, functionAssociations, etc.) and
          // only flip compress -> false.
          if ((args as any).defaultCacheBehavior) {
            (args as any).defaultCacheBehavior.compress = false;
          }
        },
      },
    });

    return {
      landing: landing.url,
      demo: demo.url,
    };
  },
});
