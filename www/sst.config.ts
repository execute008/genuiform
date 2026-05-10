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
        // --dart2js-optimization=O1 is a workaround for release-only Flutter
        // web bugs that don't repro in `flutter run` (default optimization is
        // O4, which has produced rendering / repaint regressions in past
        // releases — see flutter#130961, flutter#160327). Larger bundle, but
        // dodges the optimizer.
        command: "flutter build web --release --dart2js-optimization=O1",
        output: "build/web",
      },
      domain: "workbench.genuiform.draht.dev",
    });

    return {
      landing: landing.url,
      demo: demo.url,
    };
  },
});
