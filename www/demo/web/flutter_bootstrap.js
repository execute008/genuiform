{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const splash = document.getElementById('flutter-splash');
    if (splash) splash.classList.add('fade-out');

    // Initialize engine during the fade transition (0.65s)
    const appRunner = await engineInitializer.initializeEngine();

    await new Promise(r => setTimeout(r, 700));
    if (splash) splash.remove();

    await appRunner.runApp();
  }
});
