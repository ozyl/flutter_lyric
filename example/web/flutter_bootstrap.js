{{flutter_js}}
{{flutter_build_config}}

// Version both scripts: a fresh bootstrap must not load a cached main.dart.js.
// Local runs without BUILD_ID keep Flutter's default entrypoint paths.
(() => {
  const buildId = new URL(document.currentScript.src).searchParams.get('v');
  if (buildId && !buildId.includes('{{')) {
    for (const build of _flutter.buildConfig.builds) {
      if (build.mainJsPath) {
        build.mainJsPath += `?v=${encodeURIComponent(buildId)}`;
      }
    }
  }

  const serviceWorkerVersion = {{flutter_service_worker_version}};
  _flutter.loader.load(serviceWorkerVersion === null ? {} : {
    serviceWorkerSettings: { serviceWorkerVersion },
  });
})();
