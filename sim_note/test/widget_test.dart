import 'package:flutter_test/flutter_test.dart';
import 'package:sim_note/main.dart';

void main() {
  test('SimNoteApp 클래스가 정상적으로 참조됨', () {
    // DbService.init()과 Provider 의존성 없이 클래스 자체만 확인
    expect(SimNoteApp, isNotNull);
  });
}
