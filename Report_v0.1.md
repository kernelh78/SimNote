# SimNote 개발 리포트 v0.1

> 클라우드 없이, 같은 Wi-Fi 안의 내 기기끼리만 동기화되는 메모 앱

작성일: 2026-03-29 | 최종 업데이트: 2026-03-29

---

## 현재 상태

**8단계 완료.** 맥 ↔ 안드로이드 암호화 동기화 + iOS 지원 + 마크다운 렌더링 + 노트 내보내기(PDF/텍스트) 완료.

---

## 완료된 것

### 1단계 — 로컬 메모 앱 ✅

| 기능 | 상태 |
|------|------|
| Flutter 프로젝트 (Android + macOS) | 완료 |
| Isar DB 연동 (Notebook, Note, Tag) | 완료 |
| 메모 작성 / 수정 / 삭제 (소프트 삭제) | 완료 |
| 폴더(Notebook) 생성 / 이름 변경 / 삭제 | 완료 |
| 해시태그 추가 및 태그별 필터링 | 완료 |
| 즐겨찾기 기능 | 완료 |
| 실시간 검색 (제목 + 본문) | 완료 |
| 반응형 UI (데스크탑 3컬럼 / 모바일 드로어) | 완료 |

### 2단계 — 기기 탐색 ✅

| 기능 | 상태 |
|------|------|
| UDP 브로드캐스트로 같은 Wi-Fi 기기 자동 발견 | 완료 |
| 기기 이름 / IP / 플랫폼 표시 | 완료 |
| 탐색 결과 실시간 업데이트 (배지 포함) | 완료 |
| 10초 이상 응답 없는 기기 자동 제거 | 완료 |

> **기술 선택 변경**: 계획서의 mDNS(bonsoir) → UDP 브로드캐스트로 변경.
> 이유: 공유기 멀티캐스트 차단 문제. UDP 브로드캐스트가 더 범용적으로 작동.

### 3단계 — 기기 간 동기화 ✅

| 기능 | 상태 |
|------|------|
| TCP 소켓 연결 (포트 8765 고정) | 완료 |
| 최초 연결 시 6자리 PIN 인증 | 완료 |
| 인증된 기기 저장 (재연결 시 PIN 생략) | 완료 |
| 노트 JSON 직렬화 및 양방향 전송 | 완료 |
| Last-write-wins 병합 (updatedAt 기준) | 완료 |
| 동기화 완료 후 UI 자동 갱신 | 완료 |
| 동기화 상태 표시 (연결중 / PIN / 동기화중 / 완료 / 오류) | 완료 |

### 4단계 — 스마트 동기화 ✅

| 기능 | 상태 |
|------|------|
| 소프트 삭제 전파 (isDeleted + deletedAt) | 완료 |
| 충돌 감지 (양쪽 모두 마지막 동기화 이후 수정) | 완료 |
| 충돌 해결 UI (내 버전 / 상대 버전 / 둘 다 유지) | 완료 |
| 태그 동기화 (추가 / 삭제 / 변경 감지) | 완료 |
| 폴더 이름 변경 동기화 | 완료 |
| 즐겨찾기 변경 동기화 | 완료 |
| 동기화 로그 (추가 / 수정 / 삭제 / 태그변경 / 충돌해결) | 완료 |
| 마지막 동기화 시각 저장 (SyncStateStore) | 완료 |

### 5단계 — 보안 강화 ✅

| 기능 | 상태 |
|------|------|
| AES-256-CBC 전송 암호화 | 완료 |
| PIN + salt → SHA-256 세션 키 파생 | 완료 |
| 기기별 세션 키 영구 저장 (TrustedDevices) | 완료 |
| 신뢰 기기 재연결 시 저장 키로 자동 암호화 | 완료 |
| 전송 패킷 구조: IV.ciphertext (base64) | 완료 |
| 세션 키 없는 구버전 페어링 → 자동 PIN 재인증 유도 | 완료 |

### 6단계 — iOS 지원 ✅

| 기능 | 상태 |
|------|------|
| iOS 빌드 설정 (Podfile, 최소 버전 14.0) | 완료 |
| 로컬 네트워크 권한 (NSLocalNetworkUsageDescription) | 완료 |
| Bonjour 서비스 등록 (NSBonjourServices) | 완료 |
| iPhone 시뮬레이터 동작 확인 | 완료 |

### 7단계 — 마크다운 렌더링 ✅

| 기능 | 상태 |
|------|------|
| 편집 ↔ 미리보기 토글 버튼 (연필 / 눈 아이콘) | 완료 |
| 미리보기: h1·h2·h3, 굵기, 기울임, 코드, 인용 | 완료 |
| 미리보기 전환 시 자동 저장 | 완료 |
| 데스크탑(NoteEditor) + 모바일(MobileEditorScreen) 동일 적용 | 완료 |
| 힌트 텍스트에 마크다운 문법 안내 | 완료 |

### 8단계 — 노트 내보내기 ✅

| 기능 | 상태 |
|------|------|
| PDF 내보내기 (마크다운 → HTML → PDF, 한글 폰트 지원) | 완료 |
| 텍스트(.md) 내보내기 (제목·날짜·폴더·태그 메타 포함) | 완료 |
| 데스크탑: 툴바 공유 아이콘 팝업 | 완료 |
| 모바일: ⋮ 팝업 메뉴에 내보내기 항목 추가 | 완료 |
| 플랫폼 공유 시트 연동 (share_plus) | 완료 |

---

## 핵심 기술 구조

```
기기 탐색:  UDP 브로드캐스트 (포트 8766, 3초마다)
인증:       TCP 소켓 + 6자리 PIN → SHA-256(PIN:salt) → 세션 키
암호화:     AES-256-CBC, IV 앞부분 포함 (base64 인코딩)
데이터:     JSON-Lines 프로토콜 over TCP (포트 8765)
병합:       updatedAt 타임스탬프 비교 + 충돌 감지
로컬 DB:    Isar (NoSQL, 오프라인 우선)
상태관리:   Provider (AppProvider + SyncProvider)
```

### 동기화 흐름 (5단계 기준)

```
[클라이언트]
    → TCP 연결 (8765)
    → Hello 전송 (deviceId 포함)
    → 신뢰 기기: TrustedDevices에서 세션 키 로드
      첫 연결: 서버가 salt 전달 → PIN 교환 → SHA-256(PIN:salt) 세션 키 파생 → 저장
    → 내 노트 전체를 AES-256 암호화해서 전송
    → 서버도 암호화해서 응답
    → 양쪽 복호화 후 병합
    → 충돌 있으면 UI에서 선택
    → 양쪽 UI 갱신
```

---

## 파일 구조

```
sim_note/lib/
├── models/
│   ├── note.dart            # syncId(UUID), isDeleted, deletedAt 포함
│   ├── notebook.dart
│   └── tag.dart
├── database/
│   └── db_service.dart      # mergeRemoteNotes(), resolveConflict(), _setTags()
├── export/
│   └── note_exporter.dart   # PDF / 텍스트 내보내기 (share_plus + printing)
├── sync/
│   ├── discovery_service.dart   # UDP 브로드캐스트 탐색
│   ├── sync_server.dart         # TCP 서버, salt 생성, 암호화 응답
│   ├── sync_client.dart         # TCP 클라이언트, salt 수신, 암호화 전송
│   ├── sync_protocol.dart       # JSON-Lines + sendEncrypted/decryptMsg
│   ├── sync_crypto.dart         # AES-256-CBC, SHA-256 키 파생
│   ├── sync_state_store.dart    # 마지막 동기화 시각 저장
│   ├── sync_conflict.dart       # 충돌 데이터 모델
│   ├── sync_log.dart            # 동기화 로그 (최대 200건)
│   ├── trusted_devices.dart     # 기기별 세션 키 저장
│   └── device_identity.dart     # 기기 고유 UUID
├── providers/
│   ├── app_provider.dart        # 노트/폴더/태그 상태 관리
│   └── sync_provider.dart       # 동기화 상태, PIN Completer
├── screens/
│   ├── home_screen.dart         # PIN 다이얼로그, 충돌 처리, 갱신
│   └── mobile_editor_screen.dart
└── widgets/
    ├── sync_panel.dart          # 안테나 버튼, 기기 목록, 동기화 로그 탭
    ├── note_tag_row.dart        # 태그 입력/표시 (Mac + Android 공용)
    ├── conflict_dialog.dart     # 충돌 해결 UI
    ├── sidebar.dart
    ├── note_list.dart
    ├── note_editor.dart         # 마크다운 미리보기 + 내보내기 버튼
    └── mobile_layout.dart
```

---

## 트러블슈팅 기록

| 문제 | 원인 | 해결 |
|------|------|------|
| mDNS 기기 미발견 | 공유기 멀티캐스트 차단 | UDP 브로드캐스트로 교체 |
| 안드로이드 IP 오인식 (192.0.0.4) | 가상 네트워크 인터페이스 선택 | wlan0 우선, 192.168.x.x 필터링 |
| 포트 41476 연결 오류 | bonsoir 패키지 잔류, 랜덤 포트 등록 | bonsoir 완전 제거, 포트 8765 하드코딩 |
| 맥 PIN 다이얼로그 미표시 | addPostFrameCallback 타이밍 불안정 | HomeScreen StatefulWidget + addListener |
| 안드로이드 PIN 입력창 미표시 | 바텀시트 닫힌 후 상태 변경 | PIN 입력을 AlertDialog로 이동 |
| 동기화 후 노트 미갱신 | AppProvider 갱신 트리거 없음 | SyncState.done 시 AppProvider.load() 호출 |
| 태그 저장 안 됨 (Mac) | _TagRow가 StatelessWidget → 컨트롤러 매 빌드마다 재생성 | StatefulWidget으로 변경 |
| 태그 저장 안 됨 (Android) | MobileEditorScreen에 별도의 구식 _TagRow 존재 | 공용 NoteTagRow 위젯으로 통합 |
| 태그 동기화 안 됨 | 태그 추가/삭제 시 note.updatedAt 미갱신 | addTagToNote / removeTagFromNote에서 updatedAt 갱신 |
| Isar 트랜잭션 오류 | writeTxn 안에서 async read (_setTags, 노트북 조회) | 모든 read를 트랜잭션 밖으로 이동 |
| 사이드바 오버플로우 | Column에 Expanded 없음 | Expanded(ListView) 로 감쌈 |
| 즐겨찾기 변경 미동기화 | toggleFavorite에서 updatedAt 미갱신 | updatedAt = DateTime.now() 추가 |
| 폴더 이름 변경 미동기화 | renameNotebook이 소속 노트 updatedAt 미갱신 | 소속 노트 전체 updatedAt 갱신 |
| 병합 시 노트북 소속 미변경 | mergeRemoteNotes가 내용만 업데이트, 노트북 재배정 없음 | _moveNoteToNotebook 헬퍼 추가 |
| resolveConflictKeepBoth 크래시 | writeTxn 안에서 _setTags 호출 (중첩 트랜잭션) | _setTags를 txn 밖으로 분리 |
| PIN 확인 버튼 항상 비활성화 | TextField onChanged에서 setState 미호출 | onChanged: (_) => setState(() {}) 추가 |
| 그래픽 오버플로우 (드로어 52px) | Column 안에 Expanded ListView 구조 오류 | SafeArea(child: ListView(...)) 최상위 구조로 교체 |
| 그래픽 오버플로우 (에디터 키보드 122px) | TextField expands:true + SingleChildScrollView 충돌 | maxLines:null + viewInsets.bottom 패딩으로 교체 |
| 암호화 후 기존 페어링 동기화 불가 | 구버전 페어링의 세션 키가 빈 문자열로 저장됨 → 서버가 kTrusted 전송 시 복호화 불가 | 서버에서 키 유효성 검사 후 빈 키면 PIN 재인증 강제 |
| 맥 업데이트 후 동기화 여전히 실패 | 신버전 앱 설치 후 구버전 프로세스가 계속 실행 중 | 구 프로세스 종료 후 신버전 실행 |
| PDF 한글 폰트 깨짐 방지 | pdf 패키지의 내장 폰트는 한글 미지원 | Printing.convertHtml() 사용 → WebKit 렌더러가 시스템 폰트로 처리 |

---

## 향후 진행 사항

- [ ] 자동 동기화 (같은 네트워크 감지 시 백그라운드 자동 실행)
- [ ] iOS 실기기 배포 (애플 개발자 계정 필요)
- [ ] Windows 지원
- [ ] 비승인 기기 접근 차단 및 알림
- [ ] 맥 Save As 다이얼로그 (내보내기 위치 직접 선택)

---

## 테스트 환경

| 항목 | 내용 |
|------|------|
| 맥 | macOS (Apple Silicon) |
| 안드로이드 | Samsung Galaxy |
| 공유기 | TP-Link AX1500 |
| iOS | iPhone 17 Pro 시뮬레이터 |
| 테스트 내용 | 양방향 동기화, 마크다운 미리보기, PDF/텍스트 내보내기 |
