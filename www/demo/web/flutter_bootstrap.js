{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const splash = document.getElementById('flutter-splash');
    // Remove the fixed/inset splash overlay BEFORE measuring the viewport.
    // Initializing the engine while #flutter-splash still covers the viewport
    // causes the platform dispatcher to latch onto stale metrics, leaving the
    // first frame frozen until a window resize re-publishes the size.
    if (splash) {
      splash.classList.add('fade-out');
      await new Promise(r => setTimeout(r, 700));
      splash.remove();
    }

    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
