{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    // Workaround for a Flutter web release-build issue: after the first
    // paint the engine can stop pumping frames in response to setState /
    // StreamBuilder rebuilds, so async results (LLM stream tokens, mascot
    // SVG fetches) sit in the controller but never paint until a platform
    // metrics event fires. Confirmed live: dispatching a synthetic resize
    // with no actual size change instantly painted the deferred form.
    // SchedulerBinding.scheduleFrame() does NOT take the same engine code
    // path; only `window.dispatchEvent(new Event('resize'))` reliably wakes
    // the renderer. Lives in JS rather than Dart because the dart2wasm
    // build chokes on the package:web interop binding for dispatchEvent.
    //
    // Pump for 15s to cover cold-load async work, then stop — once the
    // user starts interacting, the engine stays warm on its own.
    let ticks = 0;
    const heartbeat = setInterval(() => {
      ticks++;
      if (ticks > 75) {
        clearInterval(heartbeat);
        return;
      }
      window.dispatchEvent(new Event('resize'));
    }, 200);
  }
});
