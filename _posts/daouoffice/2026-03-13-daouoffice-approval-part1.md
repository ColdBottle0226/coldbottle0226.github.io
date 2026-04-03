---
title: 다우오피스 전자결재 분석 정리 - Part 1. 개요 & 전자결재 홈
date: 2026-03-13 10:00:00 +0900
categories: [업무, 결재, 다우오피스]
tags: [다우오피스, 전자결재, 전자결재홈, 결재, 그룹웨어]
---

## 📗 1. 전자결재란

---

전자결재는 종이 문서 없이 온라인으로 결재 문서를 작성하고 승인받는 시스템이다. 다우오피스 전자결재 App은 단순한 승인/반려를 넘어, 합의·확인·감사·선결·대결·전결 등 조직의 다양한 결재 문화를 반영한 복잡한 결재 흐름을 지원한다.

결재가 완료된 문서는 자동으로 문서함에 보관되고, 최종 결재 시점에 문서번호가 자동으로 채번된다.

### 📌 전자결재에서 할 수 있는 일

| 기능 | 설명 |
| --- | --- |
| 결재 문서 작성 및 상신 | 양식을 선택하고 문서를 작성하여 결재를 요청한다 |
| 다양한 결재 프로세스 | 결재·반려·합의·확인·감사·선결·후결·전결·대결·후열 |
| 결재선 커스터마이징 | 결재자·합의자·수신자·참조자·열람자를 자유롭게 지정 |
| 자주 쓰는 결재선 저장 | 개인 결재선으로 저장하여 반복 작업 단축 |
| 문서 자동 보관 | 결재 완료 시 개인/부서 문서함에 자동 저장 |
| 문서 이력 관리 | 결재 처리 이력·댓글·첨부파일 통합 관리 |
| 외부 공문 발송 | 결재 완료 문서를 공문·메일·게시판으로 발송/공유 |
| 모바일 결재 | PC와 동일한 환경에서 모바일 결재 처리 가능 |

---

## 📗 2. 전자결재 처리 흐름

---

전자결재의 전체 흐름을 한눈에 보면 아래와 같다.

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 900 580" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:900px;font-family:sans-serif;">
  <defs>
    <marker id="arr" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#4361ee"/>
    </marker>
    <marker id="arrerr" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#ef233c"/>
    </marker>
    <marker id="arrwarn" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#f77f00"/>
    </marker>
  </defs>
  <rect width="900" height="580" fill="#f8f9fa" rx="12"/>
  <text x="450" y="34" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">다우오피스 전자결재 전체 흐름</text>

  <!-- 1단계: 기안자 -->
  <rect x="30" y="60" width="155" height="80" rx="8" fill="#4361ee"/>
  <text x="107" y="90" text-anchor="middle" font-size="13" fill="white" font-weight="bold">① 기안자</text>
  <text x="107" y="108" text-anchor="middle" font-size="10" fill="#cfd8ff">양식 선택</text>
  <text x="107" y="122" text-anchor="middle" font-size="10" fill="#cfd8ff">문서 작성 · 결재선 설정</text>
  <text x="107" y="136" text-anchor="middle" font-size="10" fill="#cfd8ff">상신(결재요청)</text>

  <line x1="185" y1="100" x2="215" y2="100" stroke="#4361ee" stroke-width="2" marker-end="url(#arr)"/>

  <!-- 2단계: 결재 진행 -->
  <rect x="215" y="60" width="210" height="80" rx="8" fill="#3a86ff" opacity="0.9"/>
  <text x="320" y="90" text-anchor="middle" font-size="13" fill="white" font-weight="bold">② 결재 진행 (순차 처리)</text>
  <text x="320" y="108" text-anchor="middle" font-size="10" fill="#cfe0ff">결재자 · 합의자 순서대로 처리</text>
  <text x="320" y="122" text-anchor="middle" font-size="10" fill="#cfe0ff">알림 발송 → 결재 처리</text>
  <text x="320" y="136" text-anchor="middle" font-size="10" fill="#cfe0ff">전결 · 선결 · 대결 옵션 가능</text>

  <line x1="425" y1="100" x2="455" y2="100" stroke="#4361ee" stroke-width="2" marker-end="url(#arr)"/>

  <!-- 3단계: 최종 결재 -->
  <rect x="455" y="60" width="180" height="80" rx="8" fill="#7209b7" opacity="0.9"/>
  <text x="545" y="90" text-anchor="middle" font-size="13" fill="white" font-weight="bold">③ 최종 결재</text>
  <text x="545" y="108" text-anchor="middle" font-size="10" fill="#e5c7ff">마지막 결재자 승인</text>
  <text x="545" y="122" text-anchor="middle" font-size="10" fill="#e5c7ff">문서번호 자동 채번</text>
  <text x="545" y="136" text-anchor="middle" font-size="10" fill="#e5c7ff">결재 완료 처리</text>

  <line x1="635" y1="100" x2="665" y2="100" stroke="#4361ee" stroke-width="2" marker-end="url(#arr)"/>

  <!-- 4단계: 완료 -->
  <rect x="665" y="60" width="210" height="80" rx="8" fill="#06d6a0" opacity="0.9"/>
  <text x="770" y="90" text-anchor="middle" font-size="13" fill="white" font-weight="bold">④ 결재 완료</text>
  <text x="770" y="108" text-anchor="middle" font-size="10" fill="#c0fff2">개인 · 부서 문서함 보관</text>
  <text x="770" y="122" text-anchor="middle" font-size="10" fill="#c0fff2">수신 부서 전달</text>
  <text x="770" y="136" text-anchor="middle" font-size="10" fill="#c0fff2">공문 · 메일 발송 가능</text>

  <!-- 반려 화살표 -->
  <path d="M 320,140 Q 320,185 107,185 Q 60,185 60,140" stroke="#ef233c" stroke-width="2" fill="none" stroke-dasharray="6,3" marker-end="url(#arrerr)"/>
  <text x="193" y="198" text-anchor="middle" font-size="11" fill="#ef233c">반려 → 기안자 반환 (재기안 가능)</text>

  <!-- 구분선 -->
  <line x1="30" y1="225" x2="870" y2="225" stroke="#dee2e6" stroke-width="1.5" stroke-dasharray="4,3"/>
  <text x="450" y="246" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">📌 처리 단계별 상태 변화</text>

  <!-- 상태 머신 -->
  <rect x="40" y="258" width="100" height="36" rx="6" fill="#dee2e6"/>
  <text x="90" y="281" text-anchor="middle" font-size="11" fill="#333" font-weight="bold">임시저장</text>

  <line x1="140" y1="276" x2="168" y2="276" stroke="#4361ee" stroke-width="1.5" marker-end="url(#arr)"/>
  <text x="154" y="268" text-anchor="middle" font-size="8" fill="#4361ee">상신</text>

  <rect x="168" y="258" width="110" height="36" rx="6" fill="#ffd166"/>
  <text x="223" y="281" text-anchor="middle" font-size="11" fill="#333" font-weight="bold">결재 진행 중</text>

  <line x1="278" y1="276" x2="306" y2="276" stroke="#4361ee" stroke-width="1.5" marker-end="url(#arr)"/>
  <text x="292" y="268" text-anchor="middle" font-size="8" fill="#4361ee">최종승인</text>

  <rect x="306" y="258" width="100" height="36" rx="6" fill="#06d6a0"/>
  <text x="356" y="281" text-anchor="middle" font-size="11" fill="white" font-weight="bold">결재 완료</text>

  <!-- 반려 경로 -->
  <path d="M 223,294 Q 223,318 90,318 Q 40,318 40,294" stroke="#ef233c" stroke-width="1.5" fill="none" stroke-dasharray="4,3" marker-end="url(#arrerr)"/>
  <text x="136" y="332" text-anchor="middle" font-size="9" fill="#ef233c">반려</text>

  <rect x="40" y="294" width="100" height="28" rx="6" fill="#ef233c" opacity="0.8"/>
  <text x="90" y="312" text-anchor="middle" font-size="10" fill="white" font-weight="bold">반려됨</text>

  <!-- 취소/회수 -->
  <path d="M 168,290 L 168,340 L 90,340 L 90,322" stroke="#adb5bd" stroke-width="1.5" fill="none" stroke-dasharray="3,2" marker-end="url(#arr)"/>
  <text x="120" y="353" text-anchor="middle" font-size="9" fill="#6c757d">상신취소 / 회수</text>

  <!-- 강제반려 -->
  <path d="M 356,294 Q 356,360 280,360 Q 223,360 223,328" stroke="#f77f00" stroke-width="1.5" fill="none" stroke-dasharray="4,3" marker-end="url(#arrwarn)"/>
  <text x="400" y="358" text-anchor="middle" font-size="9" fill="#f77f00">강제반려 (관리자 전용)</text>

  <!-- 구분선 2 -->
  <line x1="30" y1="385" x2="870" y2="385" stroke="#dee2e6" stroke-width="1.5" stroke-dasharray="4,3"/>
  <text x="450" y="406" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">📌 결재선 구성 요소</text>

  <!-- 결재선 구성 -->
  <rect x="30" y="418" width="155" height="78" rx="8" fill="#4361ee" opacity="0.12"/>
  <rect x="30" y="418" width="155" height="8" rx="4" fill="#4361ee"/>
  <text x="107" y="438" text-anchor="middle" font-size="11" fill="#4361ee" font-weight="bold">결재자</text>
  <text x="107" y="454" text-anchor="middle" font-size="9" fill="#333">승인 또는 반려 권한</text>
  <text x="107" y="468" text-anchor="middle" font-size="9" fill="#333">전결 · 선결 · 보류 옵션</text>
  <text x="107" y="482" text-anchor="middle" font-size="9" fill="#333">순서대로 차례로 처리</text>
  <text x="107" y="492" text-anchor="middle" font-size="9" fill="#555">⚡ 핵심 결재 주체</text>

  <rect x="200" y="418" width="155" height="78" rx="8" fill="#3a86ff" opacity="0.12"/>
  <rect x="200" y="418" width="155" height="8" rx="4" fill="#3a86ff"/>
  <text x="277" y="438" text-anchor="middle" font-size="11" fill="#3a86ff" font-weight="bold">합의자</text>
  <text x="277" y="454" text-anchor="middle" font-size="9" fill="#333">타 부서 협조 의사 표시</text>
  <text x="277" y="468" text-anchor="middle" font-size="9" fill="#333">합의 / 반대 선택</text>
  <text x="277" y="482" text-anchor="middle" font-size="9" fill="#333">반대해도 결재 진행(기본)</text>
  <text x="277" y="492" text-anchor="middle" font-size="9" fill="#555">🤝 협조 요청 역할</text>

  <rect x="370" y="418" width="155" height="78" rx="8" fill="#7209b7" opacity="0.12"/>
  <rect x="370" y="418" width="155" height="8" rx="4" fill="#7209b7"/>
  <text x="447" y="438" text-anchor="middle" font-size="11" fill="#7209b7" font-weight="bold">수신자</text>
  <text x="447" y="454" text-anchor="middle" font-size="9" fill="#333">결재 완료 후 문서 수신</text>
  <text x="447" y="468" text-anchor="middle" font-size="9" fill="#333">접수 / 반송 처리</text>
  <text x="447" y="482" text-anchor="middle" font-size="9" fill="#333">후속 결재 진행 가능</text>
  <text x="447" y="492" text-anchor="middle" font-size="9" fill="#555">📬 후속 업무 처리</text>

  <rect x="540" y="418" width="155" height="78" rx="8" fill="#06d6a0" opacity="0.12"/>
  <rect x="540" y="418" width="155" height="8" rx="4" fill="#06d6a0"/>
  <text x="617" y="438" text-anchor="middle" font-size="11" fill="#16825e" font-weight="bold">참조자</text>
  <text x="617" y="454" text-anchor="middle" font-size="9" fill="#333">진행 중 + 완료 후 열람</text>
  <text x="617" y="468" text-anchor="middle" font-size="9" fill="#333">사용자 / 부서 단위 지정</text>
  <text x="617" y="482" text-anchor="middle" font-size="9" fill="#333">진행 상황 실시간 확인</text>
  <text x="617" y="492" text-anchor="middle" font-size="9" fill="#555">👁 진행 중 공유</text>

  <rect x="710" y="418" width="160" height="78" rx="8" fill="#f77f00" opacity="0.12"/>
  <rect x="710" y="418" width="160" height="8" rx="4" fill="#f77f00"/>
  <text x="790" y="438" text-anchor="middle" font-size="11" fill="#b35700" font-weight="bold">열람자</text>
  <text x="790" y="454" text-anchor="middle" font-size="9" fill="#333">결재 완료 후에만 열람</text>
  <text x="790" y="468" text-anchor="middle" font-size="9" fill="#333">사용자 단위만 지정 가능</text>
  <text x="790" y="482" text-anchor="middle" font-size="9" fill="#333">완료 후 추가 지정 가능</text>
  <text x="790" y="492" text-anchor="middle" font-size="9" fill="#555">📄 완료 후 공유</text>
</svg>
</div>

---

## 📗 3. 전자결재 홈 화면 구성

---

전자결재 App에 접속하면 처음 표시되는 홈 화면에서 현재 처리해야 할 문서 현황을 한눈에 확인할 수 있다.

### 📌 홈 상단 - 처리 대기 목록

홈 상단에는 내가 처리해야 할 문서 목록이 표시된다.

| 항목 | 설명 |
| --- | --- |
| 결재 대기 문서 | 내가 결재해야 할 문서. 클릭하면 목록으로 이동 |
| 결재 수신 문서 | 수신자 또는 수신 부서로 지정된 문서 |
| 공문 대기 문서 | 공문 발송 전 승인이 필요한 문서 (공문 발송 관리자만 노출) |
| 참조 / 열람 대기 | 참조자 또는 열람자로 지정되었으나 아직 확인하지 않은 문서 |
| 결재 예정 문서 | 내가 결재자로 지정되었으나 아직 내 차례가 되지 않은 문서 |

> 💡 `결재 예정 문서`에서 선결재(선결) 처리가 가능하다. 내 차례가 아니더라도 미리 결재할 수 있다.

### 📌 홈 중단 - 최근 결재 현황

최근 내가 기안하거나 처리한 결재 문서의 현황을 요약해서 보여준다.

- 진행 중인 기안 문서 / 완료된 기안 문서 / 반려된 문서 건수 확인 가능
- 각 항목 클릭 시 해당 문서 목록으로 이동

### 📌 홈 하단 - 바로가기

자주 사용하는 결재 양식이나 기능에 빠르게 접근할 수 있다.

- `[새 결재 진행]`: 결재 문서 작성 시작
- `[자주 쓰는 양식]`: 저장한 양식 목록
- `[나의 결재선]`: 저장한 개인 결재선 목록

---

## 📗 4. 멤버 타입별 권한

---

부서장과 부부서장의 전자결재 사용 권한은 동일하다. 부서원은 일부 기능이 제한된다.

| 구분 | 부서장(M) | 부부서장(S) | 부서원 |
| --- | --- | --- | --- |
| 부서 문서함 추가 / 삭제 | O | O | X |
| 문서함 이관 | O | O | X |
| 부서 수신함 조회 | O | O | X |
| 문서함 내 문서 이동 / 삭제 | O | O | O (기본 문서함 제외) |
| 부서원 '문서함 담당자' 지정 | O | O | X |

> 💡 부서장·부부서장이 부서원 중 '문서함 담당자'를 지정하면, 그 부서원은 부서장과 동일한 권한으로 문서함을 관리할 수 있다.

**결재 수신자가 '부서'로 지정된 경우 결재 권한 순서:**

1. 부서장 결재
2. 부서장 부재 시 → 부부서장 결재
3. 부서장, 부부서장 모두 부재 시 → 부서원 결재

---

## 📗 5. 정리

---

- 전자결재는 양식 선택 → 문서 작성 → 결재선 설정 → 상신 → 결재 진행 → 완료 순서로 흐른다.
- 결재선은 결재자·합의자·수신자·참조자·열람자로 구성되며, 각 역할의 열람 시점과 권한이 다르다.
- 홈 화면에서 결재 대기·수신·참조·예정 문서를 한눈에 확인할 수 있다.
- 부서장·부부서장은 동일한 권한을 가지며, 부서원은 일부 기능이 제한된다.

> 📎 다음 글: [Part 2. 결재 유형 완전 정복](/posts/daouoffice-approval-part2)에서 결재·합의·확인·감사·선결·전결·대결 각 유형의 개념과 차이를 정리한다.

---

## 참고 자료

- 다우오피스 헬프데스크 - 전자결재 소개: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/42424955855385>
- 다우오피스 헬프데스크 - 전자결재 홈: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45227541747481>
