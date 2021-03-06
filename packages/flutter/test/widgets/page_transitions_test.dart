// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

class TestOverlayRoute extends OverlayRoute<void> {
  TestOverlayRoute({ RouteSettings settings }) : super(settings: settings);
  @override
  Iterable<OverlayEntry> createOverlayEntries() sync* {
    yield new OverlayEntry(builder: _build);
  }
  Widget _build(BuildContext context) => const Text('Overlay');
}

class PersistentBottomSheetTest extends StatefulWidget {
  const PersistentBottomSheetTest({ Key key }) : super(key: key);

  @override
  PersistentBottomSheetTestState createState() => new PersistentBottomSheetTestState();
}

class PersistentBottomSheetTestState extends State<PersistentBottomSheetTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  bool setStateCalled = false;

  void showBottomSheet() {
    _scaffoldKey.currentState.showBottomSheet<Null>((BuildContext context) {
      return const Text('bottomSheet');
    })
    .closed.whenComplete(() {
      setState(() {
        setStateCalled = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _scaffoldKey,
      body: const Text('Sheet')
    );
  }
}

void main() {
  testWidgets('Check onstage/offstage handling around transitions', (WidgetTester tester) async {
    final GlobalKey containerKey1 = new GlobalKey();
    final GlobalKey containerKey2 = new GlobalKey();
    final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
      '/': (_) => new Container(key: containerKey1, child: const Text('Home')),
      '/settings': (_) => new Container(key: containerKey2, child: const Text('Settings')),
    };

    await tester.pumpWidget(new MaterialApp(routes: routes));

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Overlay'), findsNothing);

    expect(Navigator.canPop(containerKey1.currentContext), isFalse);
    Navigator.pushNamed(containerKey1.currentContext, '/settings');
    expect(Navigator.canPop(containerKey1.currentContext), isTrue);

    await tester.pump();

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings', skipOffstage: false), isOffstage);
    expect(find.text('Overlay'), findsNothing);

    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), findsNothing);

    Navigator.push(containerKey2.currentContext, new TestOverlayRoute());

    await tester.pump();

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), isOnstage);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), isOnstage);

    expect(Navigator.canPop(containerKey2.currentContext), isTrue);
    Navigator.pop(containerKey2.currentContext);
    await tester.pump();

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), findsNothing);

    expect(Navigator.canPop(containerKey2.currentContext), isTrue);
    Navigator.pop(containerKey2.currentContext);
    await tester.pump();
    await tester.pump();

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), isOnstage);
    expect(find.text('Overlay'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Overlay'), findsNothing);

    expect(Navigator.canPop(containerKey1.currentContext), isFalse);
  });

  testWidgets('Check back gesture disables Heroes', (WidgetTester tester) async {
    final GlobalKey containerKey1 = new GlobalKey();
    final GlobalKey containerKey2 = new GlobalKey();
    const String kHeroTag = 'hero';
    final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
      '/': (_) => new Scaffold(
        key: containerKey1,
        body: new Container(
          color: const Color(0xff00ffff),
          child: const Hero(
            tag: kHeroTag,
            child: Text('Home')
          )
        )
      ),
      '/settings': (_) => new Scaffold(
        key: containerKey2,
        body: new Container(
          padding: const EdgeInsets.all(100.0),
          color: const Color(0xffff00ff),
          child: const Hero(
            tag: kHeroTag,
            child: Text('Settings')
          )
        )
      ),
    };

    await tester.pumpWidget(new MaterialApp(
      routes: routes,
      theme: new ThemeData(platform: TargetPlatform.iOS),
    ));

    Navigator.pushNamed(containerKey1.currentContext, '/settings');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Settings'), isOnstage);

    // Settings text is heroing to its new location
    Offset settingsOffset = tester.getTopLeft(find.text('Settings'));
    expect(settingsOffset.dx, greaterThan(0.0));
    expect(settingsOffset.dx, lessThan(100.0));
    expect(settingsOffset.dy, greaterThan(0.0));
    expect(settingsOffset.dy, lessThan(100.0));

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);

    // Drag from left edge to invoke the gesture.
    final TestGesture gesture = await tester.startGesture(const Offset(5.0, 100.0));
    await gesture.moveBy(const Offset(50.0, 0.0));
    await tester.pump();

    // Home is now visible.
    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), isOnstage);

    // Home page is sliding in from the left, no heroes.
    final Offset homeOffset = tester.getTopLeft(find.text('Home'));
    expect(homeOffset.dx, lessThan(0.0));
    expect(homeOffset.dy, 0.0);

    // Settings page is sliding off to the right, no heroes.
    settingsOffset = tester.getTopLeft(find.text('Settings'));
    expect(settingsOffset.dx, greaterThan(100.0));
    expect(settingsOffset.dy, 100.0);
  });

  testWidgets('Check back gesture doesn\'t start during transitions', (WidgetTester tester) async {
    final GlobalKey containerKey1 = new GlobalKey();
    final GlobalKey containerKey2 = new GlobalKey();
    final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
      '/': (_) => new Scaffold(key: containerKey1, body: const Text('Home')),
      '/settings': (_) => new Scaffold(key: containerKey2, body: const Text('Settings')),
    };

    await tester.pumpWidget(new MaterialApp(
      routes: routes,
      theme: new ThemeData(platform: TargetPlatform.iOS),
    ));

    Navigator.pushNamed(containerKey1.currentContext, '/settings');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // We are mid-transition, both pages are on stage.
    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), isOnstage);

    // Drag from left edge to invoke the gesture. (near bottom so we grab
    // the Settings page as it comes up).
    TestGesture gesture = await tester.startGesture(const Offset(5.0, 550.0));
    await gesture.moveBy(const Offset(500.0, 0.0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // The original forward navigation should have completed, instead of the
    // back gesture, since we were mid transition.
    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), isOnstage);

    // Try again now that we're settled.
    gesture = await tester.startGesture(const Offset(5.0, 550.0));
    await gesture.moveBy(const Offset(500.0, 0.0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Home'), isOnstage);
    expect(find.text('Settings'), findsNothing);
  });

  // Tests bug https://github.com/flutter/flutter/issues/6451
  testWidgets('Check back gesture with a persistent bottom sheet showing', (WidgetTester tester) async {
    final GlobalKey containerKey1 = new GlobalKey();
    final GlobalKey containerKey2 = new GlobalKey();
    final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
      '/': (_) => new Scaffold(key: containerKey1, body: const Text('Home')),
      '/sheet': (_) => new PersistentBottomSheetTest(key: containerKey2),
    };

    await tester.pumpWidget(new MaterialApp(
      routes: routes,
      theme: new ThemeData(platform: TargetPlatform.iOS),
    ));

    Navigator.pushNamed(containerKey1.currentContext, '/sheet');

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Sheet'), isOnstage);

    // Drag from left edge to invoke the gesture. We should go back.
    TestGesture gesture = await tester.startGesture(const Offset(5.0, 100.0));
    await gesture.moveBy(const Offset(500.0, 0.0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    Navigator.pushNamed(containerKey1.currentContext, '/sheet');

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Sheet'), isOnstage);

    // Show the bottom sheet.
    final PersistentBottomSheetTestState sheet = containerKey2.currentState;
    sheet.showBottomSheet();

    await tester.pump(const Duration(seconds: 1));

    // Drag from left edge to invoke the gesture. Nothing should happen.
    gesture = await tester.startGesture(const Offset(5.0, 100.0));
    await gesture.moveBy(const Offset(500.0, 0.0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Sheet'), isOnstage);

    // Sheet did not call setState (since the gesture did nothing).
    expect(sheet.setStateCalled, isFalse);
  });

  testWidgets('Test completed future', (WidgetTester tester) async {
    final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
      '/': (_) => const Center(child: Text('home')),
      '/next': (_) => const Center(child: Text('next')),
    };

    await tester.pumpWidget(new MaterialApp(routes: routes));

    final PageRoute<void> route = new MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/page'),
      builder: (BuildContext context) => const Center(child: Text('page')),
    );

    int popCount = 0;
    route.popped.whenComplete(() {
      popCount += 1;
    });

    int completeCount = 0;
    route.completed.whenComplete(() {
      completeCount += 1;
    });

    expect(popCount, 0);
    expect(completeCount, 0);

    Navigator.push(tester.element(find.text('home')), route);

    expect(popCount, 0);
    expect(completeCount, 0);

    await tester.pump();

    expect(popCount, 0);
    expect(completeCount, 0);

    await tester.pump(const Duration(milliseconds: 100));

    expect(popCount, 0);
    expect(completeCount, 0);

    await tester.pump(const Duration(milliseconds: 100));

    expect(popCount, 0);
    expect(completeCount, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(popCount, 0);
    expect(completeCount, 0);

    Navigator.pop(tester.element(find.text('page')));

    expect(popCount, 0);
    expect(completeCount, 0);

    await tester.pump();

    expect(popCount, 1);
    expect(completeCount, 0);

    await tester.pump(const Duration(milliseconds: 100));

    expect(popCount, 1);
    expect(completeCount, 0);

    await tester.pump(const Duration(milliseconds: 100));

    expect(popCount, 1);
    expect(completeCount, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(popCount, 1);
    expect(completeCount, 1);
  });
}
