(function () {
  var deferredPrompt = null;

  window.nketaCanInstall = function () {
    return !!deferredPrompt;
  };

  window.nketaIsStandalone = function () {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
    );
  };

  window.nketaIsIos = function () {
    var ua = window.navigator.userAgent || "";
    var iOS = /iPad|iPhone|iPod/.test(ua);
    var iPadOs = window.navigator.platform === "MacIntel" && window.navigator.maxTouchPoints > 1;
    var isSafari = /^((?!chrome|android).)*safari/i.test(ua) || iOS;
    return (iOS || iPadOs) && isSafari;
  };

  window.nketaInstall = function () {
    if (!deferredPrompt) {
      return Promise.resolve(false);
    }
    var promptEvent = deferredPrompt;
    deferredPrompt = null;
    return promptEvent.prompt().then(function () {
      return promptEvent.userChoice;
    }).then(function (choice) {
      return choice && choice.outcome === "accepted";
    }).catch(function () {
      return false;
    });
  };

  window.addEventListener("beforeinstallprompt", function (event) {
    event.preventDefault();
    deferredPrompt = event;
  });

  window.addEventListener("appinstalled", function () {
    deferredPrompt = null;
  });
})();
