// Google Maps dark-mode style สำหรับหน้าจอลูกค้า
// โทนสีตรงกับ token mapBg (#17302A), mapGrid (#1E3B34), mapRoad (#25453D), route (#E0A53F)
// ใช้ใน GoogleMap(style: ...) เมื่อ Theme.of(context).brightness == Brightness.dark

const String kMapDarkStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#17302a"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9cb1a9"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#0e1f1b"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#24403a"}]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9ab6ae"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#e8f1ed"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9cb1a9"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#1e3b34"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6fc3ba"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#25453d"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1e3b34"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9cb1a9"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#2e5a50"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1e3b34"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#e8f1ed"}]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{"color": "#1e3b34"}]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9cb1a9"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#0b1a17"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#66736d"}]
  }
]
''';
