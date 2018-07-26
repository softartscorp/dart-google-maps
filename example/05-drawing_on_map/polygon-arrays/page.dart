import 'dart:html' hide MouseEvent;
import 'package:google_maps/google_maps.dart';

GMap map;
InfoWindow infoWindow;
Polygon bermudaTriangle;

void main() {
  final mapOptions = MapOptions()
    ..zoom = 5
    ..center = LatLng(24.886436490787712, -70.2685546875)
    ..mapTypeId = MapTypeId.TERRAIN;
  map = GMap(document.getElementById('map-canvas'), mapOptions);

  final triangleCoords = <LatLng>[
    LatLng(25.774252, -80.190262),
    LatLng(18.466465, -66.118292),
    LatLng(32.321384, -64.75737)
  ];

  bermudaTriangle = Polygon(PolygonOptions()
    ..paths = triangleCoords
    ..strokeColor = '#FF0000'
    ..strokeOpacity = 0.8
    ..strokeWeight = 3
    ..fillColor = '#FF0000'
    ..fillOpacity = 0.35);

  bermudaTriangle.map = map;

  // Add a listener for the click event
  bermudaTriangle.onClick.listen(showArrays);

  infoWindow = InfoWindow();
}

void showArrays(MouseEvent e) {
  // Since this Polygon only has one path, we can call getPath()
  // to return the MVCArray of LatLngs
  final vertices = bermudaTriangle.path;

  String contentString = '<b>Bermuda Triangle Polygon</b><br>'
      'Clicked Location: <br>${e.latLng.lat},${e.latLng.lng}<br>';

  // Iterate over the vertices.
  for (var i = 0; i < vertices.length; i++) {
    var xy = vertices.getAt(i);
    contentString += '<br>Coordinate: ${i}<br>${xy.lat},${xy.lng}';
  }

  // Replace our Info Window's content and position
  infoWindow
    ..content = contentString.toString()
    ..position = e.latLng
    ..open(map);
}
