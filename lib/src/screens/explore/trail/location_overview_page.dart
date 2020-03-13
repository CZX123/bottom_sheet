import 'package:hc_garden/src/library.dart';

class TrailLocationOverviewPage extends StatefulWidget {
  final TrailLocationKey trailLocationKey;
  const TrailLocationOverviewPage({
    Key key,
    @required this.trailLocationKey,
  }) : super(key: key);

  @override
  _TrailLocationOverviewPageState createState() =>
      _TrailLocationOverviewPageState();
}

class _TrailLocationOverviewPageState extends State<TrailLocationOverviewPage> {
  bool _init = false;
  BottomSheetNotifier _bottomSheetNotifier;
  final _scrollController = ScrollController();
  double _aspectRatio;
  final _rotate = ValueNotifier(false);
  final _showRotateIcon = ValueNotifier(false);
  Timer _hideRotateIconTimer;

  void _listener() {
    if (_bottomSheetNotifier.animation.value > 10) {
      if (_showRotateIcon.value) _toggleRotateIcon();
      _rotate.value = false;
    } else if (!_showRotateIcon.value) _toggleRotateIcon();
  }

  void _toggleRotateIcon() {
    _hideRotateIconTimer?.cancel();
    if (!_showRotateIcon.value) {
      if (_bottomSheetNotifier.animation.value > 10 ||
          _aspectRatio != null && _aspectRatio <= 1) return;
      _hideRotateIconTimer = Timer(Duration(seconds: 3), () {
        if (_showRotateIcon.value) _showRotateIcon.value = false;
      });
    }
    _showRotateIcon.value = !_showRotateIcon.value;
  }

  @override
  void initState() {
    super.initState();
    _bottomSheetNotifier = context.provide(listen: false);
    _bottomSheetNotifier.animation.addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      context.provide<AppNotifier>(listen: false).updateScrollController(
            context: context,
            dataKey: widget.trailLocationKey,
            scrollController: _scrollController,
          );
      _init = true;
    }
  }

  @override
  void dispose() {
    _hideRotateIconTimer?.cancel();
    _bottomSheetNotifier.animation.removeListener(_listener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trailLocation = FirebaseData.getTrailLocation(
      context: context,
      key: widget.trailLocationKey,
    );

    return GestureDetector(
      onTap: _toggleRotateIcon,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder(
                valueListenable: _bottomSheetNotifier.animation,
                builder: (context, value, child) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight - value,
                    ),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const TopPaddingSpace(),
                    Hero(
                      tag: widget.trailLocationKey,
                      child: InfoRow(
                        image: trailLocation.smallImage,
                        title: trailLocation.name,
                        subtitle: trailLocation.entityPositions
                            .map((position) {
                              return FirebaseData.getEntity(
                                context: context,
                                key: position.entityKey,
                              )?.name;
                            })
                            .where((name) => name != null)
                            .join(', '),
                        subtitleStyle:
                            Theme.of(context).textTheme.caption.copyWith(
                                  fontSize: 13.5,
                                ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Stack(
                          children: <Widget>[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return OverflowBox(
                                  minHeight: 0,
                                  maxHeight: double.infinity,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: 0,
                                      maxHeight: 5000,
                                    ),
                                    child: Center(
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: _rotate,
                                        builder: (context, value, child) {
                                          return CustomAnimatedSwitcher(
                                            child: RotatedBox(
                                              key: ValueKey(value),
                                              quarterTurns: value ? 1 : 0,
                                              child: TrailLocationImageWidget(
                                                trailLocation: trailLocation,
                                                aspectRatio: _aspectRatio,
                                                onLoad: (double aspectRatio) {
                                                  setState(() {
                                                    _aspectRatio = aspectRatio;
                                                  });
                                                  _toggleRotateIcon();
                                                },
                                                rotated: value,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _showRotateIcon,
                                builder: (context, value, child) {
                                  return IgnorePointer(
                                    ignoring: !value,
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.ease,
                                      opacity: value ? 1 : 0,
                                      child: child,
                                    ),
                                  );
                                },
                                child: FloatingActionButton(
                                  child: Icon(
                                    Icons.sync,
                                    color: Theme.of(context).hintColor,
                                  ),
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  elevation: 0,
                                  highlightElevation: 0,
                                  mini: true,
                                  backgroundColor:
                                      Theme.of(context).bottomAppBarColor,
                                  onPressed: () {
                                    _rotate.value = !_rotate.value;
                                    _toggleRotateIcon();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Sizes.kBottomBarHeight),
                    const BottomPadding(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TrailLocationImageWidget extends StatelessWidget {
  final TrailLocation trailLocation;
  final double aspectRatio;
  final bool rotated;
  final void Function(double) onLoad;

  const TrailLocationImageWidget({
    Key key,
    @required this.trailLocation,
    @required this.aspectRatio,
    this.rotated = false,
    @required this.onLoad,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        CustomImage(
          lowerRes(trailLocation.image),
          height: rotated ? double.infinity : null,
          width: rotated ? null : double.infinity,
          onLoad: onLoad,
        ),
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: aspectRatio != null ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
            child: Stack(
              children: <Widget>[
                if (aspectRatio != null)
                  for (var entityPosition in trailLocation.entityPositions)
                    EntityPositionWidget(
                      entityPosition: entityPosition,
                      size: aspectRatio > 1 && !rotated
                          ? entityPosition.size / aspectRatio
                          : entityPosition.size.toDouble(),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EntityPositionWidget extends StatelessWidget {
  final EntityPosition entityPosition;
  final double size;

  const EntityPositionWidget({
    Key key,
    @required this.entityPosition,
    @required this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final entity = FirebaseData.getEntity(
      context: context,
      key: entityPosition.entityKey,
    );
    return Align(
      alignment: Alignment(
        entityPosition.left * 2 - 1,
        entityPosition.top * 2 - 1,
      ),
      child: Transform.translate(
        offset: Offset(
          (entityPosition.left - 0.5) * size,
          (entityPosition.top - 0.5) * size,
        ),
        child: SizedBox(
          height: size,
          width: size,
          child: AnimatedEntityPulseCircle(
            entity: entity,
            size: size,
          ),
        ),
      ),
    );
    // return Positioned(
    //   left: entityPosition.left * imageWidth - size / 2,
    //   top: entityPosition.top * imageHeight - size / 2,
    //   width: size,
    //   height: size,
    //   child: AnimatedEntityPulseCircle(
    //     entity: entity,
    //     size: size,
    //   ),
    // );
  }
}

class AnimatedEntityPulseCircle extends StatefulWidget {
  final Entity entity;
  final double size;
  AnimatedEntityPulseCircle({
    Key key,
    @required this.entity,
    @required this.size,
  }) : super(key: key);

  @override
  _AnimatedEntityPulseCircleState createState() =>
      _AnimatedEntityPulseCircleState();
}

class _AnimatedEntityPulseCircleState extends State<AnimatedEntityPulseCircle>
    with SingleTickerProviderStateMixin {
  final _isPressed = ValueNotifier(false);
  Animation<double> scale;
  Animation<Color> color;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    scale = Tween<double>(begin: 1, end: 1.8).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    ));
    color = ColorTween(
      begin: Colors.white54,
      end: null,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    ));
    controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurveTween(curve: Curves.fastOutSlowIn);
    return GestureDetector(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: <Widget>[
            ScaleTransition(
              scale: scale,
              child: ValueListenableBuilder<double>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color.value,
                        width: widget.size *
                            .4 *
                            curve.transform(value) /
                            scale.value,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: _isPressed,
                builder: (context, value, child) {
                  return AnimatedOpacity(
                    opacity: value ? .38 : 1,
                    duration: Duration(milliseconds: value ? 100 : 300),
                    curve: Curves.ease,
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: Colors.white,
                      width: min(widget.size * .05, 3),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  elevation: widget.entity.key.category == 'flora' ? 0 : 4,
                  child: widget.entity.key.category == 'flora'
                      ? null
                      : CustomImage(
                          widget.entity.smallImage,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      onTapDown: (_) {
        _isPressed.value = true;
      },
      onTapUp: (_) {
        _isPressed.value = false;
      },
      onTap: () {
        final appNotifier = context.provide<AppNotifier>(listen: false);
        appNotifier.push(
          context: context,
          routeInfo: RouteInfo(
            name: widget.entity.name,
            dataKey: widget.entity.key,
            route: CrossFadePageRoute(
              builder: (context) => Material(
                color: Theme.of(context).bottomAppBarColor,
                child: EntityDetailsPage(
                  entityKey: widget.entity.key,
                ),
              ),
            ),
          ),
        );
      },
      onTapCancel: () {
        _isPressed.value = false;
      },
    );
  }
}
