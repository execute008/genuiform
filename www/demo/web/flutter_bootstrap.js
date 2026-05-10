{{flutter_js}}
{{flutter_build_config}}

// Force the canvaskit (dart2js) renderer instead of skwasm (dart2wasm).
// Skwasm runs in a Web Worker with OffscreenCanvas; on the deployed
// build it stalls after first paint and only repaints when a real
// window-size change re-publishes metrics from the main thread to the
// worker — setState / StreamBuilder rebuilds queue but never render
// until the user resizes the window. `flutter run -d chrome` uses
// dart2js + canvaskit and does not exhibit this stall, so pinning the
// renderer to canvaskit aligns prod with the dev path.
_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
