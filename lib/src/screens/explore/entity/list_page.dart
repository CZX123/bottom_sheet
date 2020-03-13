import 'package:hc_garden/src/library.dart';

class EntityListPage extends StatelessWidget {
  final bool isFlora;
  final ScrollController scrollController;

  const EntityListPage({
    Key key,
    @required this.isFlora,
    @required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Only update when entities change
    final firebaseData = context.provide<FirebaseData>();
    if (firebaseData == null) return const SizedBox.shrink();

    final entities = firebaseData.entities;

    List<String> categories = ['flora'];
    if (!isFlora) {
      categories = entities.keys.where((category) {
        return category != 'flora';
      }).toList()
        ..sort();
    }

    final filterNotifier = context.provide<FilterNotifier>();
    final searchTerm = filterNotifier.searchTerm;
    var selectedTrailKeys = filterNotifier.selectedTrailKeys;
    final newEntityMap = EntityMap();

    for (final category in categories) {
      // Sort by distance and does filtering based on trails and search inside as well
      if (filterNotifier.isSortedByDistance) {
        newEntityMap[category] = [];
        for (final entityDistance in filterNotifier.entitiesByDist[category]) {
          final entity = firebaseData.entities[category][entityDistance.key.id];
          if (!selectedTrailKeys.every((trailKey) {
                return entity.locations.every((location) {
                  return location.trailLocationKey.trailKey != trailKey;
                });
              }) &&
              entity.satisfies(searchTerm)) newEntityMap[category].add(entity);
        }
      }

      // Filter by trail, no sorting by distance
      else {
        if (selectedTrailKeys.length == 3) {
          newEntityMap[category] =
              firebaseData.entities[category].where((entity) {
            return entity.satisfies(searchTerm);
          }).toList();
        } else {
          newEntityMap[category] =
              firebaseData.entities[category].where((entity) {
            return !selectedTrailKeys.every((trailKey) {
                  return entity.locations.every((location) {
                    return location.trailLocationKey.trailKey != trailKey;
                  });
                }) &&
                entity.satisfies(searchTerm);
          }).toList();
        }
        newEntityMap[category].sort();
      }
    }

    final categoriesEntityCount = newEntityMap.map((category, entities) {
      return MapEntry(category, max(entities.length, 1));
    });
    final key = searchTerm + categoriesEntityCount.values.join();

    return CustomAnimatedSwitcher(
      child: Stack(
        key: ValueKey(key),
        children: <Widget>[
          CustomScrollView(
            controller: scrollController,
            physics: NeverScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 16,
                ),
              ),
              for (final category in categories) ...[
                if (!isFlora) SliverEntityHeaderSpace(),
                SliverEntityList(
                  categoriesEntityCount: categoriesEntityCount,
                  entities: newEntityMap[category],
                  category: category,
                  scrollController: scrollController,
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: Sizes.kBottomBarHeight + 8),
              ),
              SliverToBoxAdapter(child: BottomPadding()),
            ],
          ),
          if (!isFlora)
            FaunaListCategories(
              scrollController: scrollController,
              categoriesEntityCount: categoriesEntityCount,
            ),
        ],
      ),
    );
  }
}

class FaunaListCategories extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, int> categoriesEntityCount;
  const FaunaListCategories({
    Key key,
    @required this.scrollController,
    @required this.categoriesEntityCount,
  }) : super(key: key);

  @override
  _FaunaListCategoriesState createState() => _FaunaListCategoriesState();
}

class _FaunaListCategoriesState extends State<FaunaListCategories>
    with TickerProviderStateMixin {
  // Needed when scroll scontroller throws an error, so this offset can be used instead
  List<double> _breakPoints = [0];
  List<Widget> _categoryButtons;

  @override
  void initState() {
    super.initState();
    final searchTerm = Provider.of<FilterNotifier>(
      context,
      listen: false,
    ).searchTerm;
    widget.categoriesEntityCount.forEach((category, count) {
      _breakPoints.add(
          48.0 + count * (searchTerm.isEmpty ? 104 : 84) + _breakPoints.last);
    });
    _breakPoints.removeLast();
    _categoryButtons = [
      for (int i = 0; i < widget.categoriesEntityCount.length; i++)
        EntityCategoryButton(
          title: widget.categoriesEntityCount.keys.elementAt(i),
          onTap: () {
            widget.scrollController.animateTo(
              _breakPoints[i],
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
            );
          },
        ),
    ];
  }

  @override
  void didUpdateWidget(FaunaListCategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    final searchTerm =
        context.provide<FilterNotifier>(listen: false).searchTerm;
    _breakPoints = [0];
    widget.categoriesEntityCount.forEach((category, count) {
      _breakPoints.add(
          48.0 + count * (searchTerm.isEmpty ? 104 : 84) + _breakPoints.last);
    });
    _breakPoints.removeLast();
    _categoryButtons = [
      for (int i = 0; i < widget.categoriesEntityCount.length; i++)
        EntityCategoryButton(
          title: widget.categoriesEntityCount.keys.elementAt(i),
          onTap: () {
            widget.scrollController.animateTo(
              _breakPoints[i] + 16,
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).canvasColor;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = MediaQuery.of(context).size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding + Sizes.kBottomBarHeight - 1,
          child: AnimatedBuilder(
            animation: widget.scrollController,
            builder: (context, child) {
              double current = 0;
              try {
                current = widget.scrollController.offset;
              } catch (e) {}
              final end = _breakPoints.last + 16;
              final start = end -
                  height +
                  topPadding +
                  Sizes.hEntityButtonHeightCollapsed +
                  16 +
                  bottomPadding +
                  Sizes.kBottomBarHeight +
                  40;
              return Material(
                shape: Border(
                  top: BorderSide(
                    color: current > start
                        ? Colors.transparent
                        : Theme.of(context).dividerColor,
                  ),
                ),
                color: current > start ? Colors.transparent : bgColor,
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9, top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < _categoryButtons.length; i++)
                    AnimatedBuilder(
                      animation: widget.scrollController,
                      builder: (context, child) {
                        double current = 0;
                        double speed = 0;
                        try {
                          current = widget.scrollController.offset;
                          speed = widget
                              .scrollController.position.activity.velocity
                              .abs();
                        } catch (e) {}
                        final duration =
                            speed == 0 ? 100 : min(100, 100000 ~/ speed);
                        final end = _breakPoints[i] + 16;
                        final start = end -
                            height +
                            topPadding +
                            Sizes.hEntityButtonHeightCollapsed +
                            16 +
                            bottomPadding +
                            Sizes.kBottomBarHeight +
                            40;
                        final widthFactor = current > start + 48 ? 0.0 : 1.0;
                        return TweenAnimationBuilder(
                          tween: Tween(
                            begin: widthFactor,
                            end: widthFactor,
                          ),
                          duration: Duration(milliseconds: duration),
                          curve: Curves.easeOutQuad,
                          builder: (context, value, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: Visibility(
                                visible: current < start,
                                maintainState: true,
                                maintainAnimation: true,
                                maintainSize: true,
                                child: child,
                              ),
                            );
                          },
                          child: child,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _categoryButtons[i],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        for (int i = 0; i < _categoryButtons.length; i++)
          AnimatedBuilder(
            animation: widget.scrollController,
            builder: (context, child) {
              double current = 0;
              try {
                current = widget.scrollController.offset;
              } catch (e) {}
              final end = _breakPoints[i] + 16;
              final start = end -
                  height +
                  topPadding +
                  Sizes.hEntityButtonHeightCollapsed +
                  16 +
                  bottomPadding +
                  Sizes.kBottomBarHeight +
                  40;
              final nextEnd = i + 1 == _categoryButtons.length
                  ? double.infinity
                  : _breakPoints[i + 1] + 16;
              double y = 0;
              if (current < start || current > nextEnd) {
                return const SizedBox();
              } else if (current >= start && current < end) {
                y = end - current;
              } else if (current > nextEnd - 48) {
                y = nextEnd - 48 - current;
              }
              return Positioned(
                top: y,
                left: 0,
                right: 0,
                child: Material(
                  shape: Border(
                    bottom: BorderSide(
                      color: current < end
                          ? Colors.transparent
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  color: current < end ? Colors.transparent : null,
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: _categoryButtons[i],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SliverEntityHeaderSpace extends StatelessWidget {
  const SliverEntityHeaderSpace({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: SizedBox(
        height: 48,
      ),
    );
  }
}

class EntityCategoryButton extends StatelessWidget {
  static const height = 32.0;

  final String title;
  final VoidCallback onTap;

  const EntityCategoryButton({
    Key key,
    @required this.title,
    @required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(69),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            title[0].toUpperCase() + title.substring(1),
            style: Theme.of(context).textTheme.subtitle,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class SliverEntityList extends StatelessWidget {
  final Map<String, int> categoriesEntityCount;
  final List<Entity> entities;
  final String category;
  final ScrollController scrollController;
  const SliverEntityList({
    Key key,
    @required this.categoriesEntityCount,
    @required this.entities,
    @required this.category,
    @required this.scrollController,
  }) : super(key: key);

  static const notFoundIcons = [
    Icons.nature_people,
    Icons.filter_vintage,
    Icons.spa,
    Icons.bug_report,
    Icons.pets,
  ];

  @override
  Widget build(BuildContext context) {
    final searchTerm =
        context.provide<FilterNotifier>(listen: false).searchTerm;
    if (entities.length == 0) {
      return SliverToBoxAdapter(
        child: Container(
          height: searchTerm.isEmpty ? 104 : 84,
          alignment: Alignment.centerLeft,
          child: Row(
            children: <Widget>[
              Container(
                width: 94,
                alignment: Alignment.center,
                child: Icon(
                  Icons.nature_people,
                  size: 36,
                  color: Theme.of(context).disabledColor,
                ),
              ),
              Text(
                'No matching $category',
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverFixedExtentList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return EntityListRow(
            categoriesEntityCount: categoriesEntityCount,
            entity: entities[index],
            index: index,
            scrollController: scrollController,
          );
        },
        childCount: entities.length,
      ),
      itemExtent: searchTerm.isEmpty ? 104 : 84,
    );
  }
}

class EntityListRow extends StatefulWidget {
  final Map<String, int> categoriesEntityCount;
  final Entity entity;
  final int index;
  final ScrollController scrollController; // For getting scroll position
  const EntityListRow({
    Key key,
    @required this.categoriesEntityCount,
    @required this.entity,
    @required this.index,
    @required this.scrollController,
  }) : super(key: key);

  @override
  _EntityListRowState createState() => _EntityListRowState();
}

class _EntityListRowState extends State<EntityListRow> {
  double _rowHeight;
  Animation<double> _bottomSheetAnimation;
  Tween<double> _topSpaceTween;
  Tween<double> _contentOffsetTween;

  /// Needed for fauna, where the space for previous categories also\
  /// needs to be correctly calculated
  double _previousCategoriesHeight = 0;

  double _getSourceTop() {
    if (!widget.scrollController.hasClients) return null;
    return _topSpaceTween.evaluate(_bottomSheetAnimation) +
        _rowHeight * widget.index +
        _previousCategoriesHeight -
        widget.scrollController.offset;
  }

  double _getContentOffset() {
    return _contentOffsetTween.evaluate(_bottomSheetAnimation);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final height = MediaQuery.of(context).size.height;

    final searchTerm =
        context.provide<FilterNotifier>(listen: false).searchTerm;
    _rowHeight = searchTerm.isEmpty ? 104 : 84;

    if (widget.entity.key.category != 'flora') {
      _previousCategoriesHeight += 48;
      for (final entry in widget.categoriesEntityCount.entries) {
        if (entry.key == widget.entity.key.category) break;
        _previousCategoriesHeight += 48 + _rowHeight * entry.value;
      }
    }

    _bottomSheetAnimation = Tween<double>(
      begin: 0,
      end: 1 / (height - Sizes.kBottomHeight),
    ).animate(
      Provider.of<BottomSheetNotifier>(context, listen: false).animation,
    );
    _topSpaceTween = Tween(
      begin: Sizes.hEntityButtonHeightCollapsed + 24 + topPadding,
      end: Sizes.kBottomHeight - Sizes.hBottomBarHeight + 8,
    );
    _contentOffsetTween = Tween(
      begin: topPadding + 16 - (_rowHeight - 64) / 2,
      end: 16 - (_rowHeight - 64) / 2,
    );

    final heroTag = widget.entity.key;
    return InkWell(
      child: InfoRow(
        height: _rowHeight,
        heroTag: heroTag,
        image: widget.entity.smallImage,
        title: widget.entity.name,
        titleStyle: searchTerm.isEmpty
            ? Theme.of(context).textTheme.subhead.copyWith(
                  fontSize: 16,
                )
            : null,
        subtitle: searchTerm.isEmpty
            ? widget.entity.description
            : widget.entity.sciName,
        subtitleStyle:
            searchTerm.isEmpty ? null : Theme.of(context).textTheme.overline,
        tapToAnimate: false,
        isThreeLine: searchTerm.isEmpty,
      ),
      onTap: () {
        context.provide<AppNotifier>(listen: false).push(
              context: context,
              routeInfo: RouteInfo(
                name: widget.entity.name,
                dataKey: widget.entity.key,
                route: SlidingUpPageRoute(
                  getSourceTop: _getSourceTop,
                  sourceHeight: _rowHeight,
                  getContentOffset: _getContentOffset,
                  builder: (context) => EntityDetailsPage(
                    entityKey: widget.entity.key,
                  ),
                ),
              ),
            );
      },
    );
  }
}
