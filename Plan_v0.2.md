# SimNote 개선 계획 v0.2

> 작성일: 2026-04-09  
> 작성자: Claude (코드베이스 직접 분석 기반)  
> 기준: README.md 개선 사항 7개 항목을 실제 코드 상태에 맞게 재검토

---

## 분석 요약: 현재 실제 상태

계획을 세우기 전에, 실제 코드를 보고 나서 파악한 진짜 현황이다.

| 항목 | 현재 상태 | 심각도 |
|------|-----------|--------|
| 테스트 | 테스트 파일 1개, 내용 전부 깨져 있음 (존재하지 않는 `MyApp` 참조) | 🔴 심각 |
| 에러 처리 | 10개 파일 try-catch 사용 중, SnackBar 알림은 4곳뿐 | 🔴 심각 |
| 보안 | 세션 키가 평문 hex로 파일에 저장됨 (`trusted_devices.dart`) | 🔴 심각 |
| UI/UX | 동기화 오류 발생해도 사용자에게 안 보이는 경우 다수 | 🟡 중간 |
| 코드 구조 | 8개 서비스로 잘 분리되어 있음, 문서화만 부족 | 🟢 양호 |
| 멀티플랫폼 | 플랫폼별 분기 코드 있음, 테스트 없음 | 🟡 중간 |
| 성능 | 큰 문제 없음, 대용량 처리 미검증 | 🟢 양호 |

**핵심 판단:** README의 7개 항목 중 지금 당장 실제로 위험한 건 3가지다.  
테스트 없음 → 무엇이 깨져도 모름. 에러 숨김 → 사용자가 문제를 모름. 키 평문 저장 → 보안 구멍.

---

## 우선순위 기준

아래 계획은 **위험도 × 작업량** 기준으로 순서를 정했다.  
빠르게 효과가 나는 것 먼저, 리팩토링은 나중이다.

---

## Phase 1 — 즉시 해야 할 것 (1~2주) ✅ 완료 (2026-04-09)

### ✅ 1-1. 보안: 세션 키 저장 방식 교체

**문제:**  
`lib/sync/trusted_devices.dart`에서 기기 신뢰 정보와 세션 키를 JSON 파일로 평문 저장한다.  
세션 키가 유출되면 저장된 모든 동기화 데이터를 복호화할 수 있다.

**해결 방안:**
- `flutter_secure_storage` 패키지 도입 (iOS Keychain / Android Keystore / macOS Keychain 연동)
- 기기 ID + 세션 키 → `flutter_secure_storage`에 저장
- 블록리스트(차단 기기 목록)는 민감 정보 없으므로 기존 파일 저장 유지
- 마이그레이션: 앱 시작 시 기존 파일 존재하면 읽어서 secure storage로 이전 후 원본 파일 삭제

**작업 파일:**
- `lib/sync/trusted_devices.dart` — 저장/조회 로직 교체
- `pubspec.yaml` — `flutter_secure_storage` 추가

---

### ✅ 1-2. 에러 처리: 침묵하는 실패 제거

**문제:**  
동기화 실패, 암호화 오류, 파일 I/O 실패가 `debugPrint`로만 기록되고 사용자에게 전달되지 않는다.  
특히 `sync_client.dart`에서 소켓 연결 실패 시 문자열을 `throw`하는데, 이게 UI까지 안 올라오는 경우가 있다.

**해결 방안:**

1. **에러 타입 통일** — `lib/core/errors.dart` 파일 신규 생성:
   ```dart
   // 예시 구조
   class SimNoteError {
     final String userMessage;  // 사용자에게 보여줄 메시지
     final String? technical;   // 로그용
   }
   class SyncError extends SimNoteError { ... }
   class CryptoError extends SimNoteError { ... }
   class StorageError extends SimNoteError { ... }
   ```

2. **SyncProvider에 에러 상태 추가** (`lib/providers/sync_provider.dart`):
   - `String? lastError` 필드 추가
   - 에러 발생 시 상태 업데이트 → UI가 리슨

3. **HomeScreen에서 에러 표시** (`lib/screens/home_screen.dart`):
   - `SyncProvider.lastError` 변화 감지 → SnackBar 표시
   - 현재 4곳뿐인 SnackBar를 동기화/암호화/DB 에러 전체로 확장

**작업 파일:**
- `lib/core/errors.dart` — 신규 생성
- `lib/sync/sync_client.dart` — throw 문자열 → SyncError 객체로 교체
- `lib/sync/sync_server.dart` — 콜백 에러 타입 정리
- `lib/providers/sync_provider.dart` — lastError 상태 추가
- `lib/screens/home_screen.dart` — 에러 SnackBar 연결

---

### ✅ 1-3. 테스트: 핵심 로직 단위 테스트 작성

**문제:**  
테스트가 사실상 없다. 암호화 로직이 바뀌어도, DB 쿼리가 틀려도, 충돌 판정 로직이 깨져도 알 방법이 없다.

**해결 방안 — 우선순위 높은 순:**

**① 암호화 테스트** (`test/sync/sync_crypto_test.dart`):
- 암호화 후 복호화 → 원문 일치 확인
- 잘못된 키로 복호화 시 예외 발생 확인
- 빈 문자열, 긴 문자열, 한국어 포함 문자열 엣지 케이스

**② DB 서비스 테스트** (`test/database/db_service_test.dart`):
- Isar 인메모리 인스턴스 사용 (실제 파일 불필요)
- 노트 생성/수정/삭제/복구 확인
- 소프트 딜리트 후 trash 조회 확인
- 고아 태그 정리 로직 확인

**③ 충돌 감지 테스트** (`test/sync/sync_conflict_test.dart`):
- 로컬 최신 vs 원격 최신 → 충돌 발생 여부
- 동일 타임스탬프 → 처리 방식
- 삭제된 노트 vs 수정된 노트 충돌

**④ 기존 테스트 수정** (`test/widget_test.dart`):
- `MyApp` → `SimNoteApp`으로 수정해서 최소한 빌드는 되게

**추가 패키지:**
- `mockito` + `build_runner` (이미 build_runner 있음)
- `isar_test` (Isar 인메모리 테스트용)

---

## Phase 2 — 중요하지만 급하지 않은 것 (3~4주) ✅ 완료 (2026-04-09)

### ✅ 2-1. UI/UX: 동기화 상태 피드백 강화

**현재 상태:**  
`sync_panel.dart`에 동기화 UI가 있지만, 백그라운드 자동 동기화 중 상태 변화가 눈에 잘 안 띈다.

**구체적 개선:**

1. **홈 화면 상단 동기화 배너** — 동기화 중일 때 얇은 진행 바 표시 (LinearProgressIndicator)
2. **마지막 동기화 시각 표시** — "3분 전 동기화됨" 형태로 사이드바 하단에 표시
3. **충돌 다이얼로그 개선** (`lib/widgets/conflict_dialog.dart`):
   - 현재: 로컬/원격/둘 다 버튼만 있음
   - 개선: 두 버전의 수정 시각과 첫 줄 미리보기 나란히 표시
4. **자동 동기화 실패 시 배지** — 사이드바 동기화 아이콘에 빨간 점 표시

**작업 파일:**
- `lib/widgets/sync_panel.dart`
- `lib/widgets/conflict_dialog.dart`
- `lib/screens/home_screen.dart`
- `lib/providers/sync_provider.dart` (마지막 동기화 시각 상태 추가)

---

### ✅ 2-2. 보안: PIN 처리 방식 점검

**현재 상태:**  
`sync_server.dart`에서 PIN을 생성하고 `sync_client.dart`에서 입력받아 PBKDF2로 키를 파생한다.  
PIN 자체는 메모리에만 있고 파일에 저장되지 않는다 — 이 부분은 올바르다.

**추가 점검 및 개선:**

1. **PIN 유효 시간 제한** — 현재 PIN이 만료되지 않음. 5분 후 자동 만료 로직 추가
2. **연결 시도 횟수 제한** — 잘못된 PIN 3회 입력 시 연결 차단 (브루트포스 방어)
3. **세션 키 교체 주기** — 현재 세션 키가 한번 만들어지면 영구 사용. 매 동기화 세션마다 새 키 파생 검토

**작업 파일:**
- `lib/sync/sync_server.dart` — PIN 만료 타이머
- `lib/sync/sync_client.dart` — 재시도 제한 카운터
- `lib/sync/trusted_devices.dart` — 키 교체 로직

---

### ✅ 2-3. 멀티플랫폼: 핵심 차이점 테스트 케이스

**현재 상태:**  
`discovery_service.dart`에 `wlan0` (Android) 처리와 Windows `ReusePort` 플래그 분기가 있다.  
실제 기기에서 검증된 흔적이 없다.

**구체적 테스트 시나리오 문서화** (`test/platform/platform_compat_test.md`):

| 테스트 | Android | iOS | macOS | Windows |
|--------|---------|-----|-------|---------|
| LAN 기기 발견 | wlan0 IP 탐지 | — | — | ReusePort 플래그 |
| 파일 저장 경로 | `/data/data/` | 샌드박스 | `~/Library/` | `AppData` |
| 파일 내보내기 | Share Sheet | Share Sheet | 네이티브 저장 다이얼로그 | 파일 선택기 |
| 소켓 포트 권한 | 8765/8766 | 8765/8766 | 방화벽 확인 필요 | 방화벽 확인 필요 |

**우선 자동화할 것:**
- 경로 처리 단위 테스트 (실제 파일시스템 불필요, 경로 문자열 검증만)
- IP 주소 우선순위 로직 단위 테스트 (`discovery_service.dart`의 `_getBestLocalIp`)

---

## Phase 3 — 장기 개선 (한달 이후)

### 3-1. 코드 문서화

**현재:** 한국어 주석 일부 존재, DartDoc 없음  
**목표:** 각 서비스 클래스에 DartDoc 주석 추가

우선순위:
1. `sync_crypto.dart` — 암호화 알고리즘 파라미터 문서화 (키 길이, IV 방식)
2. `sync_protocol.dart` — 메시지 타입별 페이로드 형식 문서화
3. `db_service.dart` — 소프트 딜리트 / 복구 / 고아 태그 정리 로직

---

### 3-2. 성능: 대용량 검증

**현재 미검증 시나리오:**
- 노트 1,000개 이상 보유 시 홈 화면 로딩
- 큰 노트(10,000자 이상) 동기화 시 패킷 처리
- 자동 동기화 중 노트 편집 동시 발생

**접근 방법:**
- 테스트 데이터 생성기 스크립트 작성 → 대량 노트 삽입 후 프로파일링
- Flutter DevTools의 Performance 탭으로 실측 후 병목 확인 후 대응

**지금 바로 적용할 수 있는 것:**
- `note_list.dart`에 `ListView.builder` 사용 여부 확인 (이미 되어 있으면 패스)
- 노트 목록 로딩을 `FutureBuilder`로 래핑해서 초기 로딩 중 스켈레톤 UI 표시

---

## 작업 순서 요약

```
Week 1-2 (Phase 1)
├── 1-1. flutter_secure_storage로 키 저장 방식 교체
├── 1-2. 에러 타입 정의 + SnackBar 전파 연결
└── 1-3. 암호화/DB/충돌 단위 테스트 작성

Week 3-4 (Phase 2)
├── 2-1. 동기화 상태 UI 피드백 강화
├── 2-2. PIN 만료 + 재시도 제한 추가
└── 2-3. 플랫폼별 테스트 시나리오 문서 + IP 로직 단위 테스트

Month 2+ (Phase 3)
├── 3-1. DartDoc 주석 추가
└── 3-2. 대용량 성능 검증
```

---

## 하지 않기로 한 것 (이유 포함)

| 항목 | 판단 |
|------|------|
| Sentry 연동 | 현재 규모에서 과잉. 에러 상태를 UI에 노출하는 것으로 충분 |
| 코드 난독화 | 오픈소스 구조 아니면 큰 의미 없음. 보안 핵심은 키 관리 |
| CI/CD 자동화 | 테스트가 제대로 갖춰진 이후 논의. 지금은 테스트 작성이 먼저 |
| 전체 아키텍처 리팩토링 | 현재 구조(8개 서비스 분리)는 충분히 잘 되어 있음. 건드리지 않는다 |

---

## 다음 단계

사장님 확인 후 Phase 1부터 순서대로 진행.  
각 작업은 독립적이므로 순서 조정 가능.  
Phase 1-1 (보안 키 저장)은 다른 작업과 무관하게 가장 먼저 시작하는 것을 권장.
