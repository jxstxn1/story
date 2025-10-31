import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:story/story_image.dart';

typedef _StoryItemBuilder = Widget Function(
  BuildContext context,
  int pageIndex,
  int storyIndex,
);

typedef _StoryConfigFunction = int Function(int pageIndex);

/// Actions for controlling story indicator animation
enum _StoryIndicatorAction { restart, start, pause }

/// Controller for managing story indicator animation states
class StoryIndicatorAnimationController {
  final List<void Function(_StoryIndicatorAction)> _listeners = [];

  void addListener(void Function(_StoryIndicatorAction) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(_StoryIndicatorAction) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(_StoryIndicatorAction action) {
    for (final listener in _listeners) {
      listener(action);
    }
  }

  /// Restart the current story animation from the beginning
  void restart() {
    _notifyListeners(_StoryIndicatorAction.restart);
  }

  /// Start/resume the story animation
  void start() {
    _notifyListeners(_StoryIndicatorAction.start);
  }

  /// Pause the story animation
  void pause() {
    _notifyListeners(_StoryIndicatorAction.pause);
  }

  void dispose() {
    _listeners.clear();
  }
}

/// PageView to implement story like UI
///
/// [itemBuilder], [storyLength], [pageLength] are required.
class StoryPageView extends StatefulWidget {
  StoryPageView({
    Key? key,
    required this.itemBuilder,
    required this.storyLength,
    required this.pageLength,
    this.gestureItemBuilder,
    this.initialStoryIndex,
    this.initialPage = 0,
    this.onPageLimitReached,
    this.indicatorDuration = const Duration(seconds: 5),
    this.indicatorPadding =
        const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
    this.backgroundColor = Colors.black,
    this.indicatorAnimationController,
    this.onPageChanged,
    this.onPageOverscroll,
    this.indicatorVisitedColor = Colors.white,
    this.indicatorUnvisitedColor = Colors.grey,
    this.indicatorHeight = 2,
    this.indicatorRadius = 10,
    this.showShadow = false,
  }) : super(key: key);

  ///  visited color of [_Indicators]
  final Color indicatorVisitedColor;

  ///  unvisited color of [_Indicators]
  final Color indicatorUnvisitedColor;

  /// Function to build story content
  final _StoryItemBuilder itemBuilder;

  /// Function to build story content
  /// Components with gesture actions are expected
  /// Placed above the story gestures.
  final _StoryItemBuilder? gestureItemBuilder;

  /// decides length of story for each page
  final _StoryConfigFunction storyLength;

  /// length of [StoryPageView]
  final int pageLength;

  /// Initial index of story for each page
  final _StoryConfigFunction? initialStoryIndex;

  /// padding of [_Indicators]
  final EdgeInsetsGeometry indicatorPadding;

  /// duration of [_Indicators]
  final Duration indicatorDuration;

  /// Called when the very last story is finished.
  ///
  /// Functions like "Navigator.pop(context)" is expected.
  final VoidCallback? onPageLimitReached;

  /// Called when the user tries to overscroll the first or last page.
  ///
  /// Functions like "Navigator.pop(context)" is expected.
  final VoidCallback? onPageOverscroll;

  /// Called whenever the page in the center of the viewport changes.
  final void Function(int)? onPageChanged;

  /// initial index for [StoryPageView]
  final int initialPage;

  /// Color under the Stories which is visible when the cube transition is in progress
  final Color backgroundColor;

  /// Width of indicator
  final double indicatorHeight;

  /// radius of indicator
  final double indicatorRadius;

  /// Whether to show shadow near indicator
  final bool showShadow;

  /// Controller to pause, start, or restart indicator animation
  /// Useful when you need to show any popup over the story
  final StoryIndicatorAnimationController? indicatorAnimationController;

  @override
  _StoryPageViewState createState() => _StoryPageViewState();
}

class _StoryPageViewState extends State<StoryPageView> {
  late PageController pageController;

  var currentPageValue;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialPage);

    currentPageValue = widget.initialPage.toDouble();

    pageController.addListener(pageControllerListener);
  }

  void pageControllerListener() {
    final currentPage = pageController.page;
    final itemCount = widget.pageLength;

    final minScrollExtent = pageController.position.minScrollExtent;
    final maxScrollExtent = pageController.position.maxScrollExtent;

    if (currentPage == 0 && pageController.position.pixels < minScrollExtent) {
      widget.onPageOverscroll?.call();
    } else if (currentPage == itemCount - 1 &&
        pageController.position.pixels > maxScrollExtent) {
      widget.onPageOverscroll?.call();
    }

    setState(() => currentPageValue = pageController.page);
  }

  @override
  void dispose() {
    pageController.removeListener(pageControllerListener);
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: PageView.builder(
        controller: pageController,
        itemCount: widget.pageLength,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          final isLeaving = (index - currentPageValue) <= 0;
          final t = (index - currentPageValue);
          final rotationY = lerpDouble(0, 30, t as double)!;
          final maxOpacity = 0.8;
          final num opacity =
              lerpDouble(0, maxOpacity, t.abs())!.clamp(0.0, maxOpacity);
          final isPaging = opacity != maxOpacity;
          final transform = Matrix4.identity();
          transform.setEntry(3, 2, 0.003);
          transform.rotateY(-rotationY * (pi / 180.0));
          return Transform(
            alignment: isLeaving ? Alignment.centerRight : Alignment.centerLeft,
            transform: transform,
            child: Stack(
              children: [
                _StoryPageBuilder.wrapped(
                  showShadow: widget.showShadow,
                  indicatorHeight: widget.indicatorHeight,
                  indicatorRadius: widget.indicatorRadius,
                  pageLength: widget.pageLength,
                  storyLength: widget.storyLength(index),
                  initialStoryIndex: widget.initialStoryIndex?.call(index) ?? 0,
                  pageIndex: index,
                  animateToPage: (index) {
                    pageController.animateToPage(index,
                        duration: Duration(milliseconds: 500),
                        curve: Curves.ease);
                  },
                  isCurrentPage: currentPageValue == index,
                  isPaging: isPaging,
                  onPageLimitReached: widget.onPageLimitReached,
                  itemBuilder: widget.itemBuilder,
                  gestureItemBuilder: widget.gestureItemBuilder,
                  indicatorDuration: widget.indicatorDuration,
                  indicatorPadding: widget.indicatorPadding,
                  indicatorAnimationController:
                      widget.indicatorAnimationController,
                  indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
                  indicatorVisitedColor: widget.indicatorVisitedColor,
                ),
                if (isPaging && !isLeaving)
                  Positioned.fill(
                    child: Opacity(
                      opacity: opacity as double,
                      child: ColoredBox(
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper widget that creates and provides controllers via InheritedWidgets
class _StoryPageBuilderWrapper extends StatefulWidget {
  const _StoryPageBuilderWrapper({
    Key? key,
    required this.pageIndex,
    required this.pageLength,
    required this.storyLength,
    required this.initialStoryIndex,
    required this.animateToPage,
    required this.onPageLimitReached,
    required this.child,
  }) : super(key: key);

  final int pageIndex;
  final int pageLength;
  final int storyLength;
  final int initialStoryIndex;
  final ValueChanged<int> animateToPage;
  final VoidCallback? onPageLimitReached;
  final Widget child;

  @override
  _StoryPageBuilderWrapperState createState() =>
      _StoryPageBuilderWrapperState();
}

class _StoryPageBuilderWrapperState extends State<_StoryPageBuilderWrapper> {
  late _StoryLimitController _limitController;
  late _StoryStackController _stackController;

  @override
  void initState() {
    super.initState();
    _limitController = _StoryLimitController();
    _stackController = _StoryStackController(
      storyLength: widget.storyLength,
      onPageBack: () {
        if (widget.pageIndex != 0) {
          widget.animateToPage(widget.pageIndex - 1);
        }
      },
      onPageForward: () {
        if (widget.pageIndex == widget.pageLength - 1) {
          _limitController.onPageLimitReached(widget.onPageLimitReached);
        } else {
          widget.animateToPage(widget.pageIndex + 1);
        }
      },
      initialStoryIndex: widget.initialStoryIndex,
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StoryLimitInheritedWidget(
      controller: _limitController,
      child: _StoryStackInheritedWidget(
        controller: _stackController,
        child: widget.child,
      ),
    );
  }
}

class _StoryPageBuilder extends StatefulWidget {
  const _StoryPageBuilder._({
    Key? key,
    required this.storyLength,
    required this.initialStoryIndex,
    required this.pageIndex,
    required this.isCurrentPage,
    required this.isPaging,
    required this.itemBuilder,
    required this.gestureItemBuilder,
    required this.indicatorDuration,
    required this.indicatorPadding,
    required this.indicatorAnimationController,
    required this.indicatorUnvisitedColor,
    required this.indicatorVisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
    required this.showShadow,
  }) : super(key: key);
  final int storyLength;
  final int initialStoryIndex;
  final int pageIndex;
  final bool isCurrentPage;
  final bool isPaging;
  final _StoryItemBuilder itemBuilder;
  final _StoryItemBuilder? gestureItemBuilder;
  final Duration indicatorDuration;
  final EdgeInsetsGeometry indicatorPadding;
  final StoryIndicatorAnimationController? indicatorAnimationController;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;
  final bool showShadow;

  static Widget wrapped({
    required int pageIndex,
    required int pageLength,
    required ValueChanged<int> animateToPage,
    required int storyLength,
    required int initialStoryIndex,
    required bool isCurrentPage,
    required bool isPaging,
    required VoidCallback? onPageLimitReached,
    required _StoryItemBuilder itemBuilder,
    _StoryItemBuilder? gestureItemBuilder,
    required Duration indicatorDuration,
    required EdgeInsetsGeometry indicatorPadding,
    required StoryIndicatorAnimationController? indicatorAnimationController,
    required Color indicatorVisitedColor,
    required Color indicatorUnvisitedColor,
    required double indicatorHeight,
    required double indicatorRadius,
    required bool showShadow,
  }) {
    return _StoryPageBuilderWrapper(
      pageIndex: pageIndex,
      pageLength: pageLength,
      storyLength: storyLength,
      initialStoryIndex: initialStoryIndex,
      animateToPage: animateToPage,
      onPageLimitReached: onPageLimitReached,
      child: _StoryPageBuilder._(
        showShadow: showShadow,
        storyLength: storyLength,
        initialStoryIndex: initialStoryIndex,
        pageIndex: pageIndex,
        isCurrentPage: isCurrentPage,
        isPaging: isPaging,
        itemBuilder: itemBuilder,
        gestureItemBuilder: gestureItemBuilder,
        indicatorDuration: indicatorDuration,
        indicatorPadding: indicatorPadding,
        indicatorAnimationController: indicatorAnimationController,
        indicatorVisitedColor: indicatorVisitedColor,
        indicatorUnvisitedColor: indicatorUnvisitedColor,
        indicatorHeight: indicatorHeight,
        indicatorRadius: indicatorRadius,
      ),
    );
  }

  @override
  _StoryPageBuilderState createState() => _StoryPageBuilderState();
}

class _StoryPageBuilderState extends State<_StoryPageBuilder>
    with
        AutomaticKeepAliveClientMixin<_StoryPageBuilder>,
        SingleTickerProviderStateMixin {
  late AnimationController animationController;

  late void Function(_StoryIndicatorAction) indicatorListener;
  late VoidCallback imageLoadingListener;

  @override
  void initState() {
    super.initState();

    indicatorListener = (_StoryIndicatorAction action) {
      if (widget.isCurrentPage) {
        switch (action) {
          case _StoryIndicatorAction.pause:
            animationController.stop();
            break;
          case _StoryIndicatorAction.start:
            if (storyImageLoadingController.value ==
                StoryImageLoadingState.loading) {
              return;
            }
            animationController.forward();
            break;
          case _StoryIndicatorAction.restart:
            if (storyImageLoadingController.value ==
                StoryImageLoadingState.loading) {
              return;
            }
            animationController.forward(from: 0);
            break;
        }
      }
    };
    imageLoadingListener = () {
      if (widget.isCurrentPage) {
        switch (storyImageLoadingController.value) {
          case StoryImageLoadingState.loading:
            animationController.stop();
            break;
          case StoryImageLoadingState.available:
            animationController.forward();
            break;
        }
      }
    };
    animationController = AnimationController(
      vsync: this,
      duration: widget.indicatorDuration,
    )..addStatusListener(
        (status) {
          if (status == AnimationStatus.completed) {
            _StoryStackInheritedWidget.of(context).increment(
                restartAnimation: () => animationController.forward(from: 0));
          }
        },
      );
    widget.indicatorAnimationController?.addListener(indicatorListener);
    storyImageLoadingController.addListener(imageLoadingListener);
  }

  @override
  void dispose() {
    widget.indicatorAnimationController?.removeListener(indicatorListener);
    storyImageLoadingController.removeListener(imageLoadingListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.topLeft,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        Positioned.fill(
          child: widget.itemBuilder(
            context,
            widget.pageIndex,
            _StoryStackInheritedWidget.of(context).value,
          ),
        ),
        Container(
          height: 50,
          decoration: widget.showShadow
              ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      spreadRadius: 10,
                      blurRadius: 20,
                    ),
                  ],
                )
              : null,
        ),
        _Indicators(
          indicatorHeight: widget.indicatorHeight,
          indicatorRadius: widget.indicatorRadius,
          storyLength: widget.storyLength,
          animationController: animationController,
          isCurrentPage: widget.isCurrentPage,
          isPaging: widget.isPaging,
          padding: widget.indicatorPadding,
          indicatorVisitedColor: widget.indicatorVisitedColor,
          indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
          indicatorAnimationController: widget.indicatorAnimationController,
        ),
        _Gestures(
          animationController: animationController,
        ),
        Positioned.fill(
          child: widget.gestureItemBuilder?.call(
                context,
                widget.pageIndex,
                _StoryStackInheritedWidget.of(context).value,
              ) ??
              const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _Gestures extends StatelessWidget {
  const _Gestures({
    Key? key,
    required this.animationController,
  }) : super(key: key);

  final AnimationController? animationController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                animationController!.forward(from: 0);
                _StoryStackInheritedWidget.of(context).decrement();
              },
              onTapDown: (_) {
                animationController!.stop();
              },
              onTapUp: (_) {
                if (storyImageLoadingController.value !=
                    StoryImageLoadingState.loading) {
                  animationController!.forward();
                }
              },
              onLongPress: () {
                animationController!.stop();
              },
              onLongPressUp: () {
                if (storyImageLoadingController.value !=
                    StoryImageLoadingState.loading) {
                  animationController!.forward();
                }
              },
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _StoryStackInheritedWidget.of(context).increment(
                  restartAnimation: () => animationController!.forward(from: 0),
                  completeAnimation: () => animationController!.value = 1,
                );
              },
              onTapDown: (_) {
                animationController!.stop();
              },
              onTapUp: (_) {
                if (storyImageLoadingController.value !=
                    StoryImageLoadingState.loading) {
                  animationController!.forward();
                }
              },
              onLongPress: () {
                animationController!.stop();
              },
              onLongPressUp: () {
                if (storyImageLoadingController.value !=
                    StoryImageLoadingState.loading) {
                  animationController!.forward();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Indicators extends StatefulWidget {
  const _Indicators({
    Key? key,
    required this.animationController,
    required this.storyLength,
    required this.isCurrentPage,
    required this.isPaging,
    required this.padding,
    required this.indicatorUnvisitedColor,
    required this.indicatorVisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
    required this.indicatorAnimationController,
  }) : super(key: key);
  final int storyLength;
  final AnimationController? animationController;
  final EdgeInsetsGeometry padding;
  final bool isCurrentPage;
  final bool isPaging;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;
  final StoryIndicatorAnimationController? indicatorAnimationController;

  @override
  _IndicatorsState createState() => _IndicatorsState();
}

class _IndicatorsState extends State<_Indicators> {
  late Animation<double> indicatorAnimation;

  @override
  void initState() {
    super.initState();
    if (storyImageLoadingController.value != StoryImageLoadingState.loading) {
      widget.animationController!.forward();
    }
    indicatorAnimation =
        Tween(begin: 0.0, end: 1.0).animate(widget.animationController!)
          ..addListener(() {
            setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final int currentStoryIndex = _StoryStackInheritedWidget.of(context).value;
    final bool isStoryEnded = _StoryLimitInheritedWidget.of(context).value;
    if (!widget.isCurrentPage && widget.isPaging) {
      widget.animationController!.stop();
    }
    if (!widget.isCurrentPage &&
        !widget.isPaging &&
        widget.animationController!.value != 0) {
      widget.animationController!.value = 0;
    }
    if (widget.isCurrentPage &&
        !widget.animationController!.isAnimating &&
        !isStoryEnded &&
        storyImageLoadingController.value != StoryImageLoadingState.loading) {
      widget.animationController!.forward(from: 0);
    }
    return Padding(
      padding: widget.padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          widget.storyLength,
          (index) => _Indicator(
            index: index,
            indicatorHeight: widget.indicatorHeight,
            indicatorRadius: widget.indicatorRadius,
            value: (index == currentStoryIndex)
                ? indicatorAnimation.value
                : (index > currentStoryIndex)
                    ? 0
                    : 1,
            indicatorVisitedColor: widget.indicatorVisitedColor,
            indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.animationController!.dispose();
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    Key? key,
    required this.index,
    required this.value,
    required this.indicatorVisitedColor,
    required this.indicatorUnvisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
  }) : super(key: key);
  final int index;
  final double value;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: (index == 0) ? 0 : 4),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(indicatorRadius)),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: indicatorUnvisitedColor,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorVisitedColor),
            minHeight: indicatorHeight,
          ),
        ),
      ),
    );
  }
}

/// InheritedWidget for _StoryStackController
class _StoryStackInheritedWidget
    extends InheritedNotifier<_StoryStackController> {
  const _StoryStackInheritedWidget({
    Key? key,
    required _StoryStackController controller,
    required Widget child,
  }) : super(key: key, notifier: controller, child: child);

  static _StoryStackController of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<_StoryStackInheritedWidget>();
    assert(widget != null, '_StoryStackInheritedWidget not found in context');
    return widget!.notifier!;
  }
}

/// InheritedWidget for _StoryLimitController
class _StoryLimitInheritedWidget
    extends InheritedNotifier<_StoryLimitController> {
  const _StoryLimitInheritedWidget({
    Key? key,
    required _StoryLimitController controller,
    required Widget child,
  }) : super(key: key, notifier: controller, child: child);

  static _StoryLimitController of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<_StoryLimitInheritedWidget>();
    assert(widget != null, '_StoryLimitInheritedWidget not found in context');
    return widget!.notifier!;
  }
}

/// Notify current stack index
class _StoryStackController extends ValueNotifier<int> {
  _StoryStackController({
    required this.storyLength,
    required this.onPageForward,
    required this.onPageBack,
    initialStoryIndex = 0,
  }) : super(initialStoryIndex);
  final int storyLength;
  final VoidCallback onPageForward;
  final VoidCallback onPageBack;

  int get limitIndex => storyLength - 1;

  void increment(
      {VoidCallback? restartAnimation, VoidCallback? completeAnimation}) {
    if (value == limitIndex) {
      completeAnimation?.call();
      onPageForward();
    } else {
      value++;
      restartAnimation?.call();
    }
  }

  void decrement() {
    if (value == 0) {
      onPageBack();
    } else {
      value--;
    }
  }
}

class _StoryLimitController extends ValueNotifier<bool> {
  _StoryLimitController() : super(false);

  void onPageLimitReached(VoidCallback? callback) {
    if (!value) {
      callback?.call();
      value = true;
    }
  }
}
