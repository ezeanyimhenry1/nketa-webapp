importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDt8sSeT6UgEFNHqVOYER-JGjX1ZQ3WWS0",
  appId: "1:994305615388:web:2349ae15de9a7e875a21d9",
  messagingSenderId: "994305615388",
  projectId: "the-igbo-bible",
  authDomain: "the-igbo-bible.firebaseapp.com",
  storageBucket: "the-igbo-bible.firebasestorage.app",
});

const messaging = firebase.messaging();
const CACHE = "nketa-shell-v1";
const PRECACHE = [
  "/",
  "/index.html",
  "/main.dart.js",
  "/flutter.js",
  "/manifest.json",
  "/pwa.js",
  "/favicon.png",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  "/icons/apple-touch-icon.png",
];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      return cache.addAll(PRECACHE);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", function (event) {
  var request = event.request;
  if (request.method !== "GET") return;
  var url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  event.respondWith(
    caches.match(request).then(function (cached) {
      var fetched = fetch(request)
        .then(function (response) {
          if (response && response.status === 200) {
            var copy = response.clone();
            caches.open(CACHE).then(function (cache) {
              cache.put(request, copy);
            });
          }
          return response;
        })
        .catch(function () {
          return cached;
        });
      return cached || fetched;
    })
  );
});

messaging.onBackgroundMessage(function (payload) {
  var title =
    (payload.notification && payload.notification.title) || "Nketa";
  var options = {
    body: (payload.notification && payload.notification.body) || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: Object.assign({ url: "/" }, payload.data || {}),
  };
  return self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (clients) {
      for (var i = 0; i < clients.length; i++) {
        if ("focus" in clients[i]) {
          return clients[i].focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(target);
      }
    })
  );
});
