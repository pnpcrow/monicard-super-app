{{flutter_js}}
{{flutter_build_config}}

(function bootMoniCard() {
  if (window.__monicardFlutterBooted) return;
  window.__monicardFlutterBooted = true;

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) {
        reg.unregister();
      });
    }).catch(function () {});
  }

  var host = document.getElementById("flutter-host");
  var config = {
    renderer: "canvaskit",
    useLocalCanvasKit: true,
    canvasKitBaseUrl: "/app/canvaskit/",
    assetBase: "/app/",
    entrypointBaseUrl: "/app/",
    hostElement: host || undefined,
  };

  function fail(err) {
    console.error("[MoniCard] Flutter failed to start", err);
    window.__monicardFlutterBooted = false;
    var splash = document.getElementById("flutter-splash");
    if (splash) {
      splash.innerHTML =
        '<div class="brand"><img class="icon" src="splash/icon.png" alt="MoniCard"><img class="product" src="splash/product.png" alt=""><h1>MoniCard Super App</h1><p>미리보기를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.</p></div>';
    }
  }

  if (!_flutter || !_flutter.loader) {
    fail(new Error("Flutter loader missing"));
    return;
  }

  _flutter.loader
    .load({
      config: config,
      onEntrypointLoaded: function (engineInitializer) {
        return engineInitializer
          .initializeEngine(config)
          .then(function (appRunner) {
            return appRunner.runApp();
          });
      },
    })
    .catch(fail);
})();
