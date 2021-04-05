mapboxgl.accessToken =
  "pk.eyJ1Ijoia2ltbGFpIiwiYSI6ImNpdHg4b3psMDAwMnAzd29hZ2VrbzVmeTcifQ.JEzjYNojtEPRBove3beibA";

document.querySelectorAll(".map").forEach(element => {
  var map = new mapboxgl.Map({
    container: element.id, // container ID
    style: "mapbox://styles/kim-lai/ckn4ywrgd027z17mqw9ds8fsg", // style URL
    center: [1.59, 47.22],
    zoom: 3 // starting zoom
  });
  var marker = new mapboxgl.Marker()
    .setLngLat([element.dataset.lon, element.dataset.lat])
    .addTo(map);
});
