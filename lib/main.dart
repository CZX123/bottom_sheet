import 'library.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(HcGardenApp());
}

class HcGardenApp extends StatefulWidget {
  @override
  _HcGardenAppState createState() => _HcGardenAppState();
}

class _HcGardenAppState extends State<HcGardenApp> {
  final _location = Location();
  final _themeNotifier = ThemeNotifier(false);
  final _mapNotifier = MapNotifier();

  void checkPermission() async {
    var granted = await _location.hasPermission();
    if (!granted) {
      granted = await _location.requestPermission();
    }
    _mapNotifier.permissionEnabled = granted;
    if (granted) {
      checkGPS();
    }
  }

  void checkGPS() async {
    var isOn = await _location.serviceEnabled();
    if (!isOn) {
      isOn = await _location.requestService();
    }
    _mapNotifier.gpsOn = isOn;
    if (isOn) _mapNotifier.rebuildMap();
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      _themeNotifier.value = prefs.getBool('isDark') ?? false;
      _mapNotifier.mapType = CustomMapType.values[prefs.getInt('mapType') ?? 0];
    });
    BitmapDescriptor.fromAssetImage(
      ImageConfiguration(),
      'assets/images/google_maps/yellow_marker.png',
    ).then((descriptor) {
      _mapNotifier.darkThemeMarkerIcons.insert(0, descriptor);
    });
    BitmapDescriptor.fromAssetImage(
      ImageConfiguration(),
      'assets/images/google_maps/pink_marker.png',
    ).then((descriptor) {
      _mapNotifier.darkThemeMarkerIcons.insert(
        _mapNotifier.darkThemeMarkerIcons.isEmpty ? 0 : 1,
        descriptor,
      );
    });
    BitmapDescriptor.fromAssetImage(
      ImageConfiguration(),
      'assets/images/google_maps/blue_marker.png',
    ).then((descriptor) {
      _mapNotifier.darkThemeMarkerIcons.add(descriptor);
    });
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Custom cache for all images in the app
        Provider<Map<String, Uint8List>>.value(
          value: {},
        ),
        FutureProvider.value(
          value: getApplicationDocumentsDirectory(),
        ),
        ChangeNotifierProvider.value(
          value: _themeNotifier,
        ),
        ChangeNotifierProvider.value(
          value: _mapNotifier,
        ),
        ChangeNotifierProvider(
          builder: (context) => DebugNotifier(),
        ),
        ChangeNotifierProvider(
          builder: (context) => AppNotifier(),
        ),
        ChangeNotifierProvider(
          builder: (context) => BottomSheetNotifier(),
        ),
        ChangeNotifierProvider(
          builder: (context) => SearchNotifier(),
        ),
        ChangeNotifierProvider(
          builder: (context) => SortNotifier(),
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return Consumer<DebugNotifier>(
            builder: (context, debugInfo, child) {
              return MaterialApp(
                title: 'HC Garden',
                theme:
                    (themeNotifier.value ? darkThemeData : themeData).copyWith(
                  platform: debugInfo.isIOS
                      ? TargetPlatform.iOS
                      : TargetPlatform.android,
                ),
                onGenerateRoute: (settings) {
                  if (settings.isInitialRoute)
                    return PageRouteBuilder(
                      pageBuilder: (context, _, __) =>
                          const MyHomePage(title: 'HC Garden'),
                    );
                  return null;
                },
                debugShowMaterialGrid: debugInfo.debugShowMaterialGrid,
                showPerformanceOverlay: debugInfo.showPerformanceOverlay,
                checkerboardRasterCacheImages:
                    debugInfo.checkerboardRasterCacheImages,
                checkerboardOffscreenLayers:
                    debugInfo.checkerboardOffscreenLayers,
                showSemanticsDebugger: debugInfo.showSemanticsDebugger,
                debugShowCheckedModeBanner:
                    debugInfo.debugShowCheckedModeBanner,
              );
            },
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final _location = Location();
  final _pageIndex = ValueNotifier(1);
  TabController _tabController;
  final _scrollControllers = [
    ScrollController(),
    ScrollController(),
  ];
  Stream<FirebaseData> _stream;
  double topPadding;
  double height;

  // TODO: offline indicator if user opens app when offline, and old contents show instead
  // Maybe can reduce code duplication
  /* rootBundle.loadString('assets/data/data.json').then((contents) {
    List<Flora> floraList = [];
    List<Fauna> faunaList = [];
    final parsedJson = jsonDecode(contents);
    parsedJson['flora&fauna'].forEach((key, value) {
      if (key.contains('flora')) {
        floraList.add(Flora.fromJson(key, value));
      } else if (key.contains('fauna')) {
        faunaList.add(Fauna.fromJson(key, value));
      }
    });
    floraList.sort((a, b) => a.name.compareTo(b.name));
    faunaList.sort((a, b) => a.name.compareTo(b.name));
    Map<Trail, List<TrailLocation>> trails = {};
    parsedJson['map'].forEach((key, value) {
      final trail = Trail.fromJson(key, value);
      trails[trail] = [];
      value['route'].forEach((key, value) {
        trails[trail].add(TrailLocation.fromJson(
          key,
          value,
          floraList: floraList,
          faunaList: faunaList,
        ));
      });
    });
    Provider.of<AppNotifier>(context, listen: false)
        .updateBackupLists(floraList, faunaList);
    Provider.of<AppNotifier>(context, listen: false).trails = trails;
  }); */

  Future<bool> onBack(BuildContext context) async {
    final appNotifier = Provider.of<AppNotifier>(context, listen: false);
    final bottomSheetNotifier = Provider.of<BottomSheetNotifier>(
      context,
      listen: false,
    );
    final searchNotifier = Provider.of<SearchNotifier>(context, listen: false);
    final animation = bottomSheetNotifier.animation;
    final state = appNotifier.state;
    if (state == 0) {
      if (appNotifier.routes.isNotEmpty) {
        appNotifier.pop(context);
        bottomSheetNotifier
          ..activeScrollController = _scrollControllers[_tabController.index]
          ..animateTo(height - bottomHeight);
        return false;
      }
      // If something wrong happens, navigator somehow still can be popped
      if (appNotifier.navigatorKey.currentState.canPop()) {
        appNotifier.navigatorKey.currentState.pop();
        return false;
      }
      if (searchNotifier.isSearching) {
        searchNotifier
          ..isSearching = false
          ..searchTerm = '';
        return false;
      } else if (animation.value < height - bottomHeight) {
        bottomSheetNotifier.animateTo(height - bottomHeight);
        return false;
      }
      if (_pageIndex.value != 1) {
        _pageIndex.value = 1;
        bottomSheetNotifier
          ..draggingDisabled = false
          ..animateTo(height - bottomHeight);
        return false;
      }
      return true;
    } else {
      appNotifier.pop(context);
      if (appNotifier.routes.isEmpty) {
        bottomSheetNotifier.activeScrollController =
            _scrollControllers[_tabController.index];
        if (state == 1 && animation.value > height - bottomHeight) {
          bottomSheetNotifier.animateTo(height - bottomHeight);
        }
        if (searchNotifier.searchTerm.isNotEmpty)
          searchNotifier.isSearching = true;
      }
      return false;
    }
  }

  void checkPermission() async {
    var granted = await _location.hasPermission();
    if (!granted) {
      granted = await _location.requestPermission();
    }
    Provider.of<MapNotifier>(context, listen: false).permissionEnabled =
        granted;
    if (granted) {
      checkGPS();
    }
  }

  void checkGPS() async {
    var isOn = await _location.serviceEnabled();
    if (!isOn) {
      isOn = await _location.requestService();
    }
    if (isOn) setState(() {});
    Provider.of<MapNotifier>(context, listen: false).gpsOn = isOn;
  }

  void tabListener() {
    if (Provider.of<AppNotifier>(context, listen: false).state == 0)
      Provider.of<BottomSheetNotifier>(context, listen: false)
          .activeScrollController = _scrollControllers[_tabController.index];
  }

  @override
  void initState() {
    super.initState();
    checkPermission();
    _tabController = TabController(
      length: 2,
      vsync: this,
    )..addListener(tabListener);
    _stream = FirebaseDatabase.instance.reference().onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('Value is empty!');
      }

      // Add list of entities
      final parsedJson = Map<String, dynamic>.from(event.snapshot.value);
      List<Flora> floraList = [];
      List<Fauna> faunaList = [];
      parsedJson['flora&fauna'].forEach((key, value) {
        if (key.contains('flora')) {
          floraList.add(Flora.fromJson(key, value));
        } else {
          faunaList.add(Fauna.fromJson(key, value));
        }
      });
      floraList.sort((a, b) => a.name.compareTo(b.name));
      faunaList.sort((a, b) => a.name.compareTo(b.name));

      Set<Marker> mapMarkers = {};
      final mapNotifier = Provider.of<MapNotifier>(context, listen: false);
      final hues = [38.0, 340.0, 199.0];

      // Add trails and locations
      Map<Trail, List<TrailLocation>> trails = {};
      parsedJson['map'].forEach((key, value) {
        final trail = Trail.fromJson(key, value);
        trails[trail] = [];
        value['route'].forEach((key, value) {
          final location = TrailLocation.fromJson(
            key,
            value,
            trail: trail,
            floraList: floraList,
            faunaList: faunaList,
          );
          trails[trail].add(location);
          mapMarkers.add(
            Marker(
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
                      routeInfo: RouteInfo(
                        name: location.name,
                        data: location,
                      ),
                    );
                  }
                },
              ),
              icon: mapNotifier.mapType == CustomMapType.dark
                  ? mapNotifier.darkThemeMarkerIcons[trail.id - 1]
                  : BitmapDescriptor.defaultMarkerWithHue(hues[trail.id - 1]),
            ),
          );
        });
      });
      mapNotifier.setMarkers(mapMarkers, notify: false);

      List<HistoricalData> historicalDataList = [];
      parsedJson['historical'].forEach((key, value) {
        historicalDataList.add(HistoricalData.fromJson(key, value));
      });
      historicalDataList.sort((a, b) => a.id.compareTo(b.id));

      List<AboutPageData> aboutPageDataList = [];
      parsedJson['about'].forEach((key, value) {
        aboutPageDataList.add(AboutPageData.fromJson(key, value));
      });
      aboutPageDataList.sort((a, b) => a.id.compareTo(b.id));

      // TODO: handle cases of invalid data
      // i.e. filter those whose data fields are null out

      return FirebaseData(
        floraList: floraList,
        faunaList: faunaList,
        trails: trails,
        historicalDataList: historicalDataList,
        aboutPageDataList: aboutPageDataList,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    topPadding = MediaQuery.of(context).padding.top;
    height = MediaQuery.of(context).size.height;
    if (height == 0) return;
    if (Provider.of<AppNotifier>(context, listen: false).state == 0)
      Provider.of<BottomSheetNotifier>(context, listen: false)
        ..snappingPositions.value = [
          0,
          height - bottomHeight,
          height - bottomBarHeight,
        ]
        ..endCorrection = topPadding - offsetTranslation
        ..activeScrollController ??= _scrollControllers[_tabController.index];
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(tabListener)
      ..dispose();
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider.value(
      initialData: FirebaseData(
        floraList: [],
        faunaList: [],
        trails: {},
        historicalDataList: [],
        aboutPageDataList: [],
      ),
      value: _stream,
      child: Scaffold(
        drawer: DebugDrawer(),
        endDrawer: SortingDrawer(),
        body: Builder(builder: (context) {
          return WillPopScope(
            onWillPop: () {
              return onBack(context);
            },
            child: CustomAnimatedSwitcher(
              crossShrink: false,
              child: height != 0
                  ? NestedBottomSheet(
                      initialPosition: height - bottomHeight,
                      background: Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: bottomBarHeight,
                        child: ValueListenableBuilder(
                          valueListenable: _pageIndex,
                          builder: (context, pageIndex, child) {
                            return CustomAnimatedSwitcher(
                              child: pageIndex == 0
                                  ? HistoryPage()
                                  : pageIndex == 2 ? AboutPage() : child,
                            );
                          },
                          child: MapWidget(),
                        ),
                      ),
                      body: ExploreBody(
                        tabController: _tabController,
                        scrollControllers: _scrollControllers,
                      ),
                      footer: BottomSheetFooter(
                        pageIndex: _pageIndex,
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          );
        }),
      ),
    );
  }
}
