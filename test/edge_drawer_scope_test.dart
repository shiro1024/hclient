import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/edge_drawer_scope.dart';

const channel = MethodChannel('shiro.hclient.edge_drawer');

Widget drawerPage(GlobalKey<ScaffoldState> scaffoldKey, {bool left = true, bool right = true, Widget? body}) {
  return EdgeDrawerScope(
    scaffoldKey: scaffoldKey,
    leftEnabled: left,
    rightEnabled: right,
    builder: (context, drawersChanged) => Scaffold(
      key: scaffoldKey,
      drawer: left ? const Drawer(child: Text('left drawer')) : null,
      endDrawer: right ? const Drawer(child: Text('right drawer')) : null,
      onDrawerChanged: (_) => drawersChanged(),
      onEndDrawerChanged: (_) => drawersChanged(),
      body: body ?? const SizedBox.expand(),
    ),
  );
}

Future<void> openDrawerFromAndroid(WidgetTester tester, Object? id, String side) async {
  final response = Completer<void>();
  tester.binding.channelBuffers.push(channel.name, const StandardMethodCodec().encodeMethodCall(MethodCall('open', {'id': id, 'side': side})), (_) => response.complete());
  await response.future;
  await tester.pumpAndSettle();
}

void main() {
  final updates = <Map<Object?, Object?>>[];

  setUp(() {
    updates.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      updates.add(call.arguments as Map<Object?, Object?>);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('opens the committed drawer and leaves an open drawer to normal back', (tester) async {
    final scaffold = GlobalKey<ScaffoldState>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: drawerPage(scaffold)));
    final owner = updates.last['id'];

    await openDrawerFromAndroid(tester, owner, 'left');
    expect(scaffold.currentState!.isDrawerOpen, isTrue);
    expect(updates.last['left'], isFalse);
    expect(updates.last['right'], isFalse);

    await openDrawerFromAndroid(tester, owner, 'right');
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isDrawerOpen, isFalse);
    expect(updates.last['left'], isTrue);
    expect(updates.last['right'], isTrue);

    await openDrawerFromAndroid(tester, owner, 'right');
    expect(scaffold.currentState!.isEndDrawerOpen, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a dialog and a reader route suspend the mounted home drawers', (tester) async {
    final scaffold = GlobalKey<ScaffoldState>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: drawerPage(scaffold)));
    final owner = updates.last['id'];

    unawaited(
      showDialog<void>(
        context: scaffold.currentContext!,
        builder: (_) => const AlertDialog(title: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    expect(updates.last['id'], isNull);
    await openDrawerFromAndroid(tester, owner, 'left');
    expect(scaffold.currentState!.isDrawerOpen, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(updates.last['id'], owner);

    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('reader')))));
    await tester.pumpAndSettle();
    expect(updates.last['id'], isNull);
    await openDrawerFromAndroid(tester, owner, 'right');
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(updates.last['id'], owner);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('search owns only its right drawer and stale route commits cannot open it', (tester) async {
    final home = GlobalKey<ScaffoldState>();
    final search = GlobalKey<ScaffoldState>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: drawerPage(home)));
    final homeOwner = updates.last['id'];
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => drawerPage(search, left: false))));
    await tester.pumpAndSettle();
    final searchOwner = updates.last['id'];
    expect(searchOwner, isNot(homeOwner));
    expect(updates.last['left'], isFalse);
    expect(updates.last['right'], isTrue);

    await openDrawerFromAndroid(tester, homeOwner, 'right');
    expect(search.currentState!.isEndDrawerOpen, isFalse);
    await openDrawerFromAndroid(tester, searchOwner, 'left');
    expect(search.currentState!.isDrawerOpen, isFalse);
    await openDrawerFromAndroid(tester, searchOwner, 'right');
    expect(search.currentState!.isEndDrawerOpen, isTrue);
    search.currentState!.closeEndDrawer();
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(updates.last['id'], homeOwner);
    await openDrawerFromAndroid(tester, searchOwner, 'right');
    expect(home.currentState!.isEndDrawerOpen, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('changing gesture settings updates the visible owner', (tester) async {
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(MaterialApp(home: drawerPage(scaffold)));
    final owner = updates.last['id'];
    await tester.pumpWidget(MaterialApp(home: drawerPage(scaffold, left: false, right: false)));
    await tester.pumpAndSettle();
    expect(updates.last['left'], isFalse);
    expect(updates.last['right'], isFalse);
    await openDrawerFromAndroid(tester, owner, 'right');
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('middle swipes reach tabs while the standard narrow edge still opens the drawer', (tester) async {
    final scaffold = GlobalKey<ScaffoldState>();
    final pages = PageController();
    addTearDown(pages.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: drawerPage(
          scaffold,
          body: PageView(controller: pages, children: const [Text('first'), Text('second')]),
        ),
      ),
    );

    await tester.dragFrom(const Offset(650, 300), const Offset(-550, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    expect(scaffold.currentState!.isDrawerOpen, isFalse);
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);

    await tester.dragFrom(const Offset(5, 300), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isDrawerOpen, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
