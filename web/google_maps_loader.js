(function loadGoogleMaps() {
  const key = window.__GOOGLE_MAPS_API_KEY__ || "";
  if (!key) {
    console.warn("Google Maps API key is not configured.");
    return;
  }

  const script = document.createElement("script");
  script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}`;
  script.async = true;
  script.defer = true;
  document.head.appendChild(script);
})();
