import '../library.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({Key key}) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  bool _init = false;
  GoogleMapController _mapController;
  CameraPosition _initialCameraPosition;
  static const _initialZoom = 16.4;

  /// When map is first built, it does not have the top padding, so the initial camera position will also have to account for [topPaddingAdjustment]
  double get topPaddingAdjustment {
    final topPadding = MediaQuery.of(context).padding.top;
    const circumference = 2 * pi * 6378137;
    final metresPerPixel =
        156543.03392 * cos(center.latitude * pi / 180) / pow(2, _initialZoom);
    final _height = topPadding / 2 * metresPerPixel;
    return _height / circumference * 360;
  }

  // LatLngBounds _getBounds(LatLng center, double zoom) {
  //   const circumference = 2 * pi * 6378137;
  //   final metresPerPixel =
  //       156543.03392 * cos(center.latitude * pi / 180) / pow(2, zoom);
  //   final width = MediaQuery.of(context).size.width / 2 * metresPerPixel;
  //   final height = (MediaQuery.of(context).size.height -
  //           MediaQuery.of(context).padding.top -
  //           62) /
  //       2 *
  //       metresPerPixel;
  //   var latAngle = height / circumference * 360;
  //   var lngAngle = width / circumference * 360;
  //   return LatLngBounds(
  //     northeast: LatLng(
  //       center.latitude + latAngle,
  //       center.longitude + lngAngle,
  //     ),
  //     southwest: LatLng(
  //       center.latitude - latAngle,
  //       center.longitude - lngAngle,
  //     ),
  //   );
  // }

  void rebuild() {
    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    final mapNotifier = Provider.of<MapNotifier>(context, listen: false);
    _mapController = controller;
    mapNotifier.mapController = _mapController;
    _mapController.setMapStyle(
        mapNotifier.mapType == CustomMapType.dark ? darkMapStyle : mapStyle);
    // Needed to correctly apply padding
    rebuild();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Needed because of a bug with Google Maps not showing, after going back from recents
      // Don't know if this works consistently, 1s randomly chosen
      Future.delayed(const Duration(seconds: 1), rebuild);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final mapNotifier = Provider.of<MapNotifier>(context);
      final adjustAmount = mapNotifier._getAdjustAmount(_initialZoom);
      _initialCameraPosition = CameraPosition(
        target: LatLng(
          center.latitude - adjustAmount + topPaddingAdjustment,
          center.longitude,
        ),
        zoom: _initialZoom,
      );
      mapNotifier.cameraPosition = CameraPosition(
        target: LatLng(
          center.latitude - adjustAmount,
          center.longitude,
        ),
        zoom: _initialZoom,
      );
      _init = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapNotifier = Provider.of<MapNotifier>(context);
    return CustomAnimatedSwitcher(
      crossShrink: false,
      child: mapNotifier.markers?.isEmpty ?? true
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
              ),
            )
          : GoogleMap(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
              ),
              myLocationEnabled: true,
              mapType: mapNotifier.mapType == CustomMapType.satellite
                  ? MapType.hybrid
                  : MapType.normal,
              rotateGesturesEnabled: false,
              onMapCreated: _onMapCreated,
              onCameraMove: (position) {
                mapNotifier.cameraPosition = position;
              },
              initialCameraPosition: _initialCameraPosition,
              markers: mapNotifier.markers.values.toSet(),
            ),
    );
  }
}

Marker generateMarker({
  BuildContext context,
  Trail trail,
  TrailLocation location,
}) {
  final mapNotifier = Provider.of<MapNotifier>(context, listen: false);
  return Marker(
    onTap: mapNotifier.stopAnimating,
    markerId: MarkerId('${trail.id} ${location.id}'),
    position: location.coordinates,
    infoWindow: InfoWindow(
      title: location.name,
      onTap: () {
        final appNotifier = Provider.of<AppNotifier>(
          context,
          listen: false,
        );
        if (appNotifier.routes.isNotEmpty &&
            appNotifier.routes.last.data is TrailLocation &&
            appNotifier.routes.last.data == location) {
          Provider.of<BottomSheetNotifier>(
            context,
            listen: false,
          ).animateTo(0);
        } else {
          appNotifier.push(
            context: context,
            routeInfo: RouteInfo(
              name: location.name,
              data: location,
              route: CrossFadePageRoute(
                builder: (context) {
                  return Material(
                    color: Theme.of(context).bottomAppBarColor,
                    child: TrailLocationOverviewPage(
                      trailLocation: location,
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
    ),
    icon: mapNotifier.mapType == CustomMapType.dark
        ? mapNotifier.darkThemeMarkerIcons[trail.id - 1]
        : mapNotifier.lightThemeMarkerIcons[trail.id - 1],
  );
}

enum CustomMapType {
  normal,
  satellite,
  dark,
}

class MapNotifier extends ChangeNotifier {
  // todo: Do something with these information
  bool permissionEnabled;
  bool gpsOn;
  GoogleMapController mapController;
  final lightThemeMarkerIcons = [
    BitmapDescriptor.defaultMarkerWithHue(38),
    BitmapDescriptor.defaultMarkerWithHue(340),
    BitmapDescriptor.defaultMarkerWithHue(199),
    BitmapDescriptor.defaultMarkerWithHue(90),
  ];
  List<BitmapDescriptor> _darkThemeMarkerIcons;
  List<BitmapDescriptor> get darkThemeMarkerIcons {
    if (_darkThemeMarkerIcons == null) {
      // If something goes wrong, return the light theme icons instead so no fatal errors occur
      return lightThemeMarkerIcons;
    }
    return _darkThemeMarkerIcons;
  }

  set darkThemeMarkerIcons(List<BitmapDescriptor> darkThemeMarkerIcons) {
    _darkThemeMarkerIcons = darkThemeMarkerIcons;
  }

  CameraPosition cameraPosition;

  double bottomSheetHeight = Sizes.kBottomHeight - Sizes.hBottomBarHeight;

  /// Translation needed to move the map up if bottom sheet is half expanded. (+ve values)
  double _getAdjustAmount(double zoom) {
    const circumference = 2 * pi * 6378137;
    final metresPerPixel =
        156543.03392 * cos(center.latitude * pi / 180) / pow(2, zoom);
    // height of bottom sheet in metres, based on the map
    final height = bottomSheetHeight / 2 * metresPerPixel;
    final angle = height / circumference * 360;
    return angle;
  }

  CustomMapType _mapType = CustomMapType.normal;
  CustomMapType get mapType => _mapType;
  set mapType(CustomMapType mapType) {
    if (mapType != _mapType) {
      if (mapType == CustomMapType.dark) {
        mapController?.setMapStyle(darkMapStyle);
        for (var id in defaultMarkers?.keys ?? []) {
          defaultMarkers[id] = defaultMarkers[id].copyWith(
            iconParam:
                darkThemeMarkerIcons[int.parse(id.value.split(' ').first) - 1],
          );
        }
        for (var id in markers?.keys ?? []) {
          markers[id] = markers[id].copyWith(
            iconParam: greenMarkers.contains(id)
                ? darkThemeMarkerIcons.last
                : darkThemeMarkerIcons[
                    int.parse(id.value.split(' ').first) - 1],
          );
        }
      } else {
        if (mapType == CustomMapType.normal) {
          mapController?.setMapStyle(mapStyle);
        }
        if (_mapType == CustomMapType.dark) {
          for (var id in defaultMarkers?.keys ?? []) {
            defaultMarkers[id] = defaultMarkers[id].copyWith(
              iconParam: lightThemeMarkerIcons[
                  int.parse(id.value.split(' ').first) - 1],
            );
          }
          for (var id in markers?.keys ?? []) {
            markers[id] = markers[id].copyWith(
              iconParam: greenMarkers.contains(id)
                  ? lightThemeMarkerIcons.last
                  : lightThemeMarkerIcons[
                      int.parse(id.value.split(' ').first) - 1],
            );
          }
        }
      }
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('mapType', CustomMapType.values.indexOf(mapType));
      });
      _mapType = mapType;
      notifyListeners();
    }
  }

  List<MarkerId> greenMarkers = [];
  bool isDefaultMarkers = false;

  Map<MarkerId, Marker> _defaultMarkers;
  Map<MarkerId, Marker> get defaultMarkers => _defaultMarkers;
  set defaultMarkers(Map<MarkerId, Marker> defaultMarkers) {
    _defaultMarkers = defaultMarkers;
    if (_markers == null || isDefaultMarkers) {
      markers = _defaultMarkers;
      isDefaultMarkers = true;
    }
  }

  Map<MarkerId, Marker> _markers;
  Map<MarkerId, Marker> get markers => _markers;

  /// This will also call [notifyListeners]
  set markers(Map<MarkerId, Marker> markers) {
    if (mapEquals(_markers, markers)) return;
    _markers = markers;
    notifyListeners();
  }

  void setMarkers(Map<MarkerId, Marker> markers, {bool notify = true}) {
    _markers = markers;
    if (notify) notifyListeners();
  }

  void _replaceWithGreenMarker(
    Map<MarkerId, Marker> markers,
    MarkerId markerId,
  ) {
    isDefaultMarkers = false;
    greenMarkers.add(markerId);
    markers[markerId] = markers[markerId].copyWith(
      iconParam: mapType == CustomMapType.dark
          ? darkThemeMarkerIcons.last
          : lightThemeMarkerIcons.last,
    );
  }

  void rebuildMap() {
    notifyListeners();
  }

  /// Animate to a specific point
  void _animateToPoint(LatLng point, double zoom, [bool adjusted = false]) {
    mapController.animateCamera(CameraUpdate.newLatLngZoom(
      adjusted
          ? LatLng(
              point.latitude - _getAdjustAmount(zoom),
              point.longitude,
            )
          : point,
      zoom,
    ));
  }

  /// Get the correct zoom level of the map from the bounds, and mapSize in pts
  double _getZoomFromBounds(LatLngBounds bounds, Size mapSize) {
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    const circumference = 2 * pi * 6378137;
    final latAngle = (bounds.northeast.latitude - bounds.southwest.latitude);
    final lngAngle = (bounds.northeast.longitude - bounds.southwest.longitude);
    final height = latAngle * circumference / 360;
    final width = lngAngle * circumference / 360;
    final metresPerPixel = max(width / mapSize.width, height / mapSize.height);
    final zoom =
        log(156543.03392 * cos(centerLat * pi / 180) / metresPerPixel) / log(2);
    return zoom;
  }

  /// Animate to the bounds of a list of points
  void _animateToPoints(
    List<LatLng> points, [
    bool adjusted = false,
    Size mapSize,
  ]) {
    if (points?.isEmpty ?? true)
      return;
    else if (points.length == 1) {
      return _animateToPoint(points.first, 18.5, adjusted);
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final point in points.sublist(1)) {
      if (point.latitude < minLat) {
        minLat = point.latitude;
      } else if (point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (point.longitude < minLng) {
        minLng = point.longitude;
      } else if (point.longitude > maxLng) {
        maxLng = point.longitude;
      }
    }
    final bounds = LatLngBounds(
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );
    final center = LatLng(
      (minLat + maxLat) / 2 + 0.00008,
      (minLng + maxLng) / 2,
    );
    final zoom = min(_getZoomFromBounds(bounds, mapSize) * .98, 19.0);
    _animateToPoint(center, zoom, adjusted);
  }

  /// Animate back to default map of HC Garden
  void animateBackToCenter({bool adjusted = false}) {
    if (!isDefaultMarkers) {
      greenMarkers = [];
      markers = defaultMarkers;
      isDefaultMarkers = true;
    }
    _animateToPoint(center, 16.4, adjusted);
  }

  /// Moves the map to a specific location on a trail
  void animateToLocation({
    TrailLocation location,
    double zoom = 18.5,
    bool adjusted = false,
    bool changeMarkerColor = false,
  }) {
    if (changeMarkerColor) {
      final newMarkers = Map<MarkerId, Marker>.from(defaultMarkers);
      greenMarkers = [];
      final markerId = MarkerId('${location.trail.id} ${location.id}');
      _replaceWithGreenMarker(newMarkers, markerId);
      markers = newMarkers;
    }
    // TODO: Focus on the specific marker as well
    // (need to wait for upcoming update for google maps plugin)
    // https://github.com/flutter/flutter/issues/33481
    _animateToPoint(location.coordinates, zoom ?? 18.5, adjusted);
  }

  /// Moves the map to the bounding box of all locations of the entity
  void animateToEntity({
    @required Entity entity,
    @required Map<Trail, List<TrailLocation>> trails,
    @required Size mapSize,
    bool adjusted = false,
  }) {
    greenMarkers = [];
    final newMarkers = Map<MarkerId, Marker>.from(defaultMarkers);
    final points = entity.locations.map((tuple) {
      final int trailId = tuple[0];
      final int locationId = tuple[1];
      final markerId = MarkerId('$trailId $locationId');
      _replaceWithGreenMarker(newMarkers, markerId);
      final trail = trails.keys.firstWhere((trail) {
        return trail.id == trailId;
      });
      final location = trails[trail].firstWhere((loc) {
        return loc.id == locationId;
      });
      return location.coordinates;
    }).toList();
    markers = newMarkers;
    _animateToPoints(points, adjusted, mapSize);
  }

  /// Moves the map to the bounding box of a trail
  void animateToTrail({
    List<TrailLocation> locations,
    bool adjusted = false,
    Size mapSize,
  }) {
    if (!isDefaultMarkers) {
      greenMarkers = [];
      markers = defaultMarkers;
      isDefaultMarkers = true;
    }
    final points = locations.map((location) => location.coordinates).toList();
    _animateToPoints(points, adjusted, mapSize);
  }

  /// Stop any map movement. This is used when markers are tapped to prevent map from moving to the marker.
  void stopAnimating() {
    mapController.moveCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }
}
