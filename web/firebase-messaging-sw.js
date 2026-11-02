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

self.addEventListener("install", function () {
  self.skipWaiting();
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (key) {
        return caches.delete(key);
      }));
    }).then(function () {
      return self.clients.claim();
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
