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
        command: "flutter build web --release",
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
