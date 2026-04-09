# Wi-Fi 안에서 내 폰과 PC가 알아서 동기화되는 메모 앱. 
클라우드 서비스를 사용하지 않고 사설 WIFI환경에서 정해진 기기들간의 동기화.**
동기화시 우선순위 확인


## Windows Build Method 

 - git pull

 - flutter pub get

 - flutter build windows --release



## 현재까지 진행사항

- [x] 자동 동기화 (신뢰 기기 발견 시 자동 실행)
- [x] 비승인 기기 접근 차단 및 알림
- [x] Windows 지원
- [x] iOS 실기기 테스트
- [x] 차단 기기 목록 관리 UI (차단 해제 기능)
- [x] 맥 Save As 다이얼로그 (내보내기 위치 직접 선택)
- [ ] iOS App Store / 맥 App Store 배포 (애플 개발자 계정 필요)


### SimNote 개선이 필요한 주요 사항 및 구체적 방안

1. **테스트 자동화 및 커버리지 강화**
   - 동기화, 암호화, 충돌 관리 등 핵심 로직에 대해 단위 테스트와 통합 테스트를 작성
   - Flutter의 `flutter_test`와 `mockito` 등 테스트 프레임워크 적극 활용
   - CI(지속적 통합) 환경에서 자동 테스트 실행 및 커버리지 리포트 확인

2. **에러 및 예외 처리 고도화**
   - 네트워크, 암호화, 데이터 파싱 등에서 발생할 수 있는 예외를 try-catch로 세분화 처리
   - 사용자에게 명확한 에러 메시지와 복구 방법 안내
   - 에러 발생 시 로그 기록 및, 필요시 Sentry 등 외부 에러 트래킹 도구 연동

3. **UI/UX 개선**
   - 동기화 상태, 에러, 진행 상황에 대한 실시간 시각적 피드백 강화 (예: 스낵바, 로딩 인디케이터)
   - 충돌 다이얼로그 등 주요 UI의 사용성 테스트 및 피드백 반영
   - 접근성(폰트 크기, 색상 대비 등) 점검 및 개선

4. **보안 강화**
   - 암호화 키와 PIN 등 민감 정보는 메모리 내 임시 저장, 영구 저장 금지
   - .env 등 민감 정보 파일 접근 권한 재점검 및 gitignore 관리
   - 외부 침입/리버스 엔지니어링 방지 위한 코드 난독화, 보안 점검 도구 활용

5. **코드 구조 및 문서화**
   - 각 서비스/모듈별 책임 분리(예: 동기화/암호화/DB/뷰)
   - 주요 함수, 클래스에 DartDoc 주석 추가 및 README/개발 가이드 보강
   - 불필요한 의존성/중복 코드 제거, 리팩토링 주기적 시행

6. **멀티플랫폼 호환성 테스트**
   - Android/iOS/macOS/Windows에서의 파일 경로, 권한, 네트워크 차이점에 대한 테스트 케이스 작성
   - 실제 기기/에뮬레이터에서의 동작 일관성 검증
   - 플랫폼별 버그/이슈 발생 시 별도 대응 로직 마련

7. **성능 최적화**
   - 대용량 데이터/동기화 시 UI 프리징, 느려짐 현상 점검 및 비동기 처리 강화
   - DB 쿼리, 암호화 연산 등 병목 구간 프로파일링 및 최적화
   - 필요시 데이터 페이징, 캐싱 등 적용

---

1-1. 보안 — 세션 키 저장 방식 교체
* pubspec.yaml: flutter_secure_storage: ^9.2.4 추가
* trusted_devices.dart: 세션 키 저장을 평문 JSON 파일 → iOS Keychain/Android Keystore/macOS Keychain으로 교체. 앱 최초 실행 시 기존 파일이 있으면 자동 마이그레이션 후 삭제
* DebugProfile.entitlements, Release.entitlements: macOS Keychain 접근 권한 추가
1-2. 에러 처리 — 침묵하는 실패 제거
* lib/core/errors.dart 신규 생성: SimNoteError, SyncError, CryptoError, StorageError 타입 정의
* sync_client.dart: 문자열 throw '...' → throw SyncError('...') 교체
* home_screen.dart: 동기화 에러 발생 시 빨간 SnackBar 표시 추가
1-3. 테스트
* test/widget_test.dart: 깨진 MyApp 참조 수정
* test/sync/sync_crypto_test.dart: 암호화 단위 테스트 11개
* test/sync/sync_conflict_test.dart: 충돌 데이터 클래스 테스트 8개
보너스 버그 수정: 테스트 도중 발견한 SyncConflict.title getter가 빈 문자열을 '(제목 없음)'으로 처리 못하는 버그도 함께 수정했습니다.

2-1. UI/UX 피드백 강화
* home_screen.dart: 동기화 중(connecting/syncing) 화면 상단에 LinearProgressIndicator (2px 높이) 표시
* sync_panel.dart:
    * 동기화 아이콘에 에러 상태 시 빨간 점 배지 추가
    * 패널 헤더에 "3분 전 동기화됨" 형태의 상대 시각 표시
* sync_provider.dart: lastSyncAt 상태 추가, 앱 시작 및 동기화 완료 시 업데이트
2-2. 보안 강화
* sync_server.dart:
    * PIN 생성 후 5분 만료 타이머 추가 — 만료 시 연결 자동 종료
    * 잘못된 PIN 3회 입력 시 연결 차단
2-3. 멀티플랫폼 테스트
* discovery_service.dart: IP 판별 순수 함수 3개 @visibleForTesting static 메서드로 노출. Docker br-<hash> 인터페이스 패턴도 함께 추가 수정
* test/platform/discovery_service_test.dart: IP 변환·가상 인터페이스·사설 IP 판별 테스트 20개

3-1. 코드 문서화 (DartDoc)
* sync_crypto.dart: 클래스에 알고리즘 명세 (SHA-256 키 파생, AES-256-CBC, IV 포맷), 메서드 4개에 파라미터·반환값 설명
* sync_protocol.dart: 메시지 타입 상수 12개에 방향·페이로드 구조 설명, JSON-Lines 방식 설명, noteToMap 필드 목록
* db_service.dart: 클래스에 소프트 딜리트·태그 정책 설명, _pruneOrphanTags·getAllNotesForSync·mergeRemoteNotes 병합 규칙 문서화
3-2. 성능
* note_list.dart는 ListView.separated (lazy builder) 이미 사용 중 — 추가 최적화 불필요
* app_provider.dart: isLoading 상태 추가, load() 시작/완료 시 토글
* note_list.dart: 로딩 중 펄스 애니메이션 스켈레톤 UI 표시 (6개 행, 밝기 0.3↔0.7 반복)

