# SimNote 개발 리포트 v0.1

> 클라우드 없이, 같은 Wi-Fi 안의 내 기기끼리만 동기화되는 메모 앱

작성일: 2026-03-28

---

## 현재 상태

**3단계 완료.** 맥과 안드로이드 간 양방향 노트 동기화 작동 확인.

---

## 완료된 것

### 1단계 — 로컬 메모 앱 ✅

| 기능 | 상태 |
|------|------|
| Flutter 프로젝트 (Android + macOS) | 완료 |
| Isar DB 연동 (Notebook, Note, Tag) | 완료 |
| 메모 작성 / 수정 / 삭제 | 완료 |
| 폴더(Notebook) 생성 및 메모 분류 | 완료 |
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

---

## 핵심 기술 구조

```
기기 탐색:  UDP 브로드캐스트 (포트 8766, 3초마다)
인증:       TCP 소켓 + 6자리 PIN → 신뢰 기기 파일 저장
데이터:     JSON-Lines 프로토콜 over TCP (포트 8765)
병합:       updatedAt 타임스탬프 비교 (최신 우선)
로컬 DB:    Isar (NoSQL, 오프라인 우선)
상태관리:   Provider (AppProvider + SyncProvider)
```

### 동기화 흐름

```
[클라이언트] 동기화 버튼 클릭
    → TCP 연결 (8765)
    → Hello 전송 (deviceId 포함)
    → 신뢰 기기면 즉시 / 아니면 PIN 교환
    → 내 노트 전체 전송
    → 서버가 병합 후 자신의 노트 전체 응답
    → 클라이언트도 병합
    → 양쪽 UI 갱신
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

---

## 파일 구조

```
sim_note/lib/
├── models/
│   ├── note.dart          # syncId(UUID) 포함 노트 모델
│   ├── notebook.dart
│   └── tag.dart
├── database/
│   └── db_service.dart    # getAllNotesForSync(), mergeRemoteNotes()
├── sync/
│   ├── discovery_service.dart  # UDP 브로드캐스트 탐색
│   ├── sync_server.dart        # TCP 서버 (포트 8765)
│   ├── sync_client.dart        # TCP 클라이언트
│   ├── sync_protocol.dart      # JSON-Lines 프로토콜
│   ├── device_identity.dart    # 기기 고유 UUID
│   └── trusted_devices.dart   # 신뢰 기기 목록
├── providers/
│   ├── app_provider.dart       # 노트 상태 관리
│   └── sync_provider.dart      # 동기화 상태 관리
├── screens/
│   └── home_screen.dart        # PIN 다이얼로그, 동기화 완료 후 갱신
└── widgets/
    ├── sync_panel.dart         # 안테나 버튼, 기기 목록 바텀시트
    ├── sidebar.dart
    ├── note_list.dart
    ├── note_editor.dart
    └── mobile_layout.dart
```

---

## 향후 진행 사항

### 4단계 — 충돌 해결 (다음)

현재는 updatedAt 기준으로 더 최신인 쪽이 이깁니다.
아래 케이스는 아직 미처리:

- [ ] 양쪽에서 같은 노트를 동시에 수정했을 때 사용자에게 선택권 제공
- [ ] 한쪽에서 삭제 + 다른 쪽에서 수정한 경우 처리
- [ ] 동기화 로그 (무엇이 어떻게 바뀌었는지)

### 5단계 — 보안 강화

- [ ] 전송 데이터 AES-256 암호화
- [ ] 비승인 기기 접근 차단 및 알림

### 추가 개선 아이디어

- [ ] 자동 동기화 (같은 네트워크 감지 시 백그라운드 자동 실행)
- [ ] iOS / Windows 지원
- [ ] 마크다운 렌더링
- [ ] 노트 내보내기 (PDF, 텍스트)

---

## 테스트 환경

| 항목 | 내용 |
|------|------|
| 맥 | macOS (Apple Silicon), IP 192.168.0.169 |
| 안드로이드 | Samsung Galaxy, IP 192.168.0.209 |
| 공유기 | TP-Link AX1500 |
| 테스트 내용 | 양방향 노트 동기화 성공 확인 |
