import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/main.dart';
import 'package:childmbti/store.dart';

void main() {
  testWidgets('샘플 리포트가 열리고 탭이 바뀐다', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      await loadContent();
      await store.load();
    });
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(const App());
    await t.pump();
    tab.value = 1;
    await t.pump();
    expect(find.text('샘플로 보기'), findsOneWidget);
    await t.tap(find.text('샘플로 보기'));
    await t.pump();
    expect(find.text('정밀검사 결과 보고서'), findsOneWidget);
    for (final x in ['성격(자라는 힘)', '양육자 비교', '달라진 점', '기질']) {
      final f = find.text(x).first;
      await t.scrollUntilVisible(f, -200, scrollable: find.byType(Scrollable).first);
      await t.tap(f);
      await t.pump();
    }
    tab.value = 2;
    await t.pump();
    expect(find.text('함께 보면 더 잘 보여요'), findsWidgets);
  });
}
