import '../library.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key key}) : super(key: key);

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            32, 64 + MediaQuery.of(context).padding.top, 32, 64),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemBuilder: (context, index) {
                    if (index == 0)
                      return OnboardingPageOne(
                        pageController: _pageController,
                      );
                    return Center(
                      child: Text(index.toString()),
                    );
                  },
                  itemCount: 3,
                ),
              ),
              Divider(
                height: 1,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Theme(
                      data: ThemeData(
                        fontFamily: 'Manrope',
                        accentColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFFF5730F)
                                : Color(0xFF7A3735),
                        buttonTheme: ButtonThemeData(
                          minWidth: 0,
                          textTheme: ButtonTextTheme.accent,
                        ),
                      ),
                      child: FlatButton(
                        child: const Text('Cancel'),
                        onPressed: Navigator.of(context).pop,
                      ),
                    ),
                    ButtonTheme(
                      minWidth: 0,
                      child: FlatButton(
                        textTheme: ButtonTextTheme.accent,
                        child: const Text('Next'),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.fastOutSlowIn,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPageOne extends StatelessWidget {
  final PageController pageController;
  const OnboardingPageOne({
    Key key,
    @required this.pageController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Image.asset(
            'assets/images/app_logo/default.png',
            height: 108,
          ),
          Text(
            'Welcome to\nHC Garden!',
            style: Theme.of(context).textTheme.display2.copyWith(
              color: Theme.of(context).accentColor,
            ),
          ),
          Text('HC Garden is an amazing app!'),
        ],
      ),
    );
  }
}
