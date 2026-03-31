# Wi-Fi 안에서 내 폰과 PC가 알아서 동기화되는 메모 앱. 
데이터는 내 기기 밖으로 절대 안 나간다.**


업데이트 내용:

현재 상태: 5단계 → 8단계 완료로 갱신
완료 항목: iOS 지원(6), 마크다운 렌더링(7), 노트 내보내기(8) 추가
트러블슈팅: 오버플로우 2건, 암호화 페어링 버그, 맥 프로세스 미교체, PDF 한글 처리 추가
파일 구조: export/note_exporter.dart 반영
향후 계획: 완료된 항목 제거, 남은 것만 정리

Markdown view 가능
pdf 및 txt 변환 가능 update

# Windows Build Method 

 - git pull

 - flutter pub get

 - flutter build windows --release


# 에디터에 Apple Notes 스타일의 서식 입력 툴바를 추가

 - 마크다운 문법을 직접 타이핑하지 않아도 버튼 클릭으로 서식을 적용할 수 있게 한다.
