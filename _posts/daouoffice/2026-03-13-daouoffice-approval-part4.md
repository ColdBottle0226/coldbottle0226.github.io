---
title: 다우오피스 전자결재 분석 정리 - Part 4. 결재 처리 & 취소/회수/강제반려
date: 2026-03-13 10:30:00 +0900
categories: [업무, 결재, 다우오피스]
tags: [다우오피스, 전자결재, 결재처리, 결재취소, 회수, 강제반려, 선결, 후결, 전결, 대결]
---

## 📗 1. 개요

---

결재 요청을 받은 결재자 입장에서 해야 할 일은 생각보다 많다. 단순 승인/반려 외에도 선결·전결·보류 옵션이 있고, 상황에 따라 이미 한 결재를 취소해야 할 수도 있다.

이번 글에서는 결재자가 처리할 수 있는 모든 액션과 취소/회수/강제반려를 정리한다.

### 📌 결재 처리 흐름

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 880 310" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:880px;font-family:sans-serif;">
  <defs>
    <marker id="pa" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#4361ee"/>
    </marker>
    <marker id="perr" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#ef233c"/>
    </marker>
    <marker id="pwarn" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#f77f00"/>
    </marker>
  </defs>
  <rect width="880" height="310" fill="#f8f9fa" rx="12"/>
  <text x="440" y="28" text-anchor="middle" font-size="14" font-weight="bold" fill="#1a1a2e">결재자 처리 가능 액션</text>

  <!-- 중앙: 결재 대기 문서 -->
  <rect x="340" y="50" width="200" height="50" rx="8" fill="#ffd166"/>
  <text x="440" y="78" text-anchor="middle" font-size="12" fill="#333" font-weight="bold">결재 대기 문서 도착</text>

  <!-- 승인 -->
  <line x1="440" y1="100" x2="200" y2="148" stroke="#06d6a0" stroke-width="2" marker-end="url(#pa)"/>
  <rect x="80" y="148" width="240" height="60" rx="8" fill="#06d6a0" opacity="0.85"/>
  <text x="200" y="171" text-anchor="middle" font-size="11" fill="white" font-weight="bold">✅ 승인</text>
  <text x="200" y="187" text-anchor="middle" font-size="9" fill="white">다음 결재자에게 전달</text>
  <text x="200" y="200" text-anchor="middle" font-size="9" fill="white">최종 결재자라면 완료 처리</text>

  <!-- 전결 -->
  <line x1="440" y1="100" x2="440" y2="148" stroke="#4361ee" stroke-width="2" marker-end="url(#pa)"/>
  <rect x="340" y="148" width="200" height="60" rx="8" fill="#4361ee" opacity="0.85"/>
  <text x="440" y="171" text-anchor="middle" font-size="11" fill="white" font-weight="bold">⚡ 전결</text>
  <text x="440" y="187" text-anchor="middle" font-size="9" fill="white">이후 결재자 건너뜀</text>
  <text x="440" y="200" text-anchor="middle" font-size="9" fill="white">결재 즉시 완료 처리</text>

  <!-- 반려 -->
  <line x1="440" y1="100" x2="680" y2="148" stroke="#ef233c" stroke-width="2" marker-end="url(#perr)"/>
  <rect x="560" y="148" width="240" height="60" rx="8" fill="#ef233c" opacity="0.8"/>
  <text x="680" y="171" text-anchor="middle" font-size="11" fill="white" font-weight="bold">X 반려</text>
  <text x="680" y="187" text-anchor="middle" font-size="9" fill="white">기안자에게 반환</text>
  <text x="680" y="200" text-anchor="middle" font-size="9" fill="white">사유 입력 필수</text>

  <!-- 보류 -->
  <line x1="200" y1="208" x2="200" y2="235" stroke="#adb5bd" stroke-width="1.5" marker-end="url(#pa)"/>
  <rect x="80" y="235" width="240" height="45" rx="6" fill="#adb5bd" opacity="0.8"/>
  <text x="200" y="257" text-anchor="middle" font-size="10" fill="white" font-weight="bold">🕐 보류</text>
  <text x="200" y="272" text-anchor="middle" font-size="9" fill="white">나중에 처리 (결재 대기 잔류)</text>

  <!-- 결재 취소 -->
  <line x1="200" y1="208" x2="440" y2="235" stroke="#f77f00" stroke-width="1.5" stroke-dasharray="4,3" marker-end="url(#pwarn)"/>
  <rect x="350" y="235" width="200" height="45" rx="6" fill="#f77f00" opacity="0.7"/>
  <text x="450" y="257" text-anchor="middle" font-size="10" fill="white" font-weight="bold">↩ 결재 취소</text>
  <text x="450" y="272" text-anchor="middle" font-size="9" fill="white">다음 결재자 미처리 시만 가능</text>

  <!-- 합의 -->
  <line x1="680" y1="208" x2="680" y2="235" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#pa)"/>
  <rect x="560" y="235" width="240" height="45" rx="6" fill="#3a86ff" opacity="0.8"/>
  <text x="680" y="257" text-anchor="middle" font-size="10" fill="white" font-weight="bold">🤝 합의자인 경우</text>
  <text x="680" y="272" text-anchor="middle" font-size="9" fill="white">합의 / 반대 선택 (반대해도 진행)</text>
</svg>
</div>

---

## 📗 2. 결재 (승인) 처리

---

결재를 요청받으면 전자결재 홈 상단 또는 결재 대기 문서 목록에서 확인할 수 있다.

🧭 전자결재 홈 > `[결재하기]` 또는 `[결재 대기 문서]` > 문서 클릭

```
1. 문서 내용 검토
2. 상단 [결재] 버튼 클릭
3. 결재 팝업에서 옵션 설정
   - 결재 의견 작성 (선택)
   - 전결 옵션 체크 여부 결정
4. [승인] 클릭
```

**결재 처리 후 결과:**
- 다음 결재자가 있다면 → 다음 결재자에게 알림 발송
- 마지막 결재자라면 → 문서 결재 완료, 문서번호 채번, 기안자에게 완료 알림

### 📌 전결 옵션

결재 팝업에서 `[전결]` 체크박스를 선택하면, 내 뒤에 결재자가 있어도 결재를 즉시 완료 처리한다.

- 이후 결재자들은 문서를 확인할 수 없다.
- 양식 설정에서 전결 허용이 되어 있어야 옵션이 표시된다.

### 📌 다음 문서로 이동 옵션

결재 처리 후 바로 다음 결재 대기 문서로 자동 이동하는 옵션이다. 여러 문서를 연속으로 처리할 때 유용하다.

---

## 📗 3. 반려 처리

---

결재 내용에 문제가 있거나 수정이 필요한 경우 반려를 선택한다.

```
문서 상세 화면 상단 [반려] 버튼 클릭
→ 반려 팝업 > 반려 사유 입력 (필수)
→ [반려] 클릭
```

- 반려된 문서는 최초 기안자에게 반환된다.
- 기안자는 내용 수정 후 재기안 상신이 가능하다.

**전단계 반려 (옵션):** 관리자 설정에 따라 기안자가 아닌 직전 결재자에게 반려할 수 있다.

> 💡 반려 사유는 반드시 입력해야 하며, 기안자에게 전달된다.

---

## 📗 4. 합의 처리

---

합의자로 지정된 경우 결재 대기 문서 목록에 해당 문서가 표시된다.

```
결재 대기 문서 > 합의할 문서 클릭
→ [합의] 또는 [반대] 클릭
→ 합의/반대 의견 작성 (선택) > [확인]
```

- 합의자 정보는 결재방과 별도 위치(합의 영역)에 표시된다.
- 반대를 해도 기본적으로 결재는 계속 진행된다.
- 반대 시 결재를 중단하려면 관리자 설정이 필요하다.

---

## 📗 5. 선결 처리

---

선결은 내 차례가 되기 전에 미리 결재하는 기능이다. '결재 예정 문서함'에서 처리한다.

```
전자결재 홈 > [결재 예정 문서] 클릭
→ 선결할 문서 선택
→ 문서 상세 상단 [선결재] 버튼 클릭
→ 결재 의견 작성 (선택)
→ [승인] 클릭
```

**선결 처리 후:**
- 앞 순서 결재자들에게 **후결 요청** 알림이 발송된다.
- 내가 최종 결재자였다면 결재가 즉시 완료된다.

> ⚠️ 합의·확인 타입으로 지정된 결재자는 선결 불가.

---

## 📗 6. 후결 처리

---

선결에 의해 완료된 문서에서 원래 순서의 결재자가 나중에 서명하는 기능이다.

```
전자결재 홈 > [결재 대기 문서] (후결 문서 표시됨)
→ 후결할 문서 선택
→ [후결] 버튼 클릭
→ 결재 의견 작성 (선택) > [확인]
```

> ⚠️ 후결은 이미 완료된 문서의 서명이므로 반려가 불가능하다.

---

## 📗 7. 대결 처리

---

대결을 처리하려면 먼저 원 결재자가 **부재/위임 설정**을 해두어야 한다.

**사전 설정 (원 결재자):**
```
임직원 포털 > 내 정보 > [부재/위임 설정]
→ 부재 기간 설정
→ 대결자 지정
→ [저장]
```

**대결 처리 (대결자):**
```
전자결재 홈 > [결재 대기 문서] (대결 문서로 표시됨)
→ 해당 문서 클릭
→ 일반 결재와 동일하게 [결재] 또는 [반려] 처리
```

- 결재선에는 대결자 이름과 "(대결)" 표시가 기록된다.
- 대결 처리 완료 후 원 결재자에게 **후열 요청** 알림 발송.

---

## 📗 8. 후열 처리

---

대결이 완료된 문서를 원 결재자가 복귀 후 열람하는 기능이다.

```
전자결재 홈 > [결재 대기 문서] (후열 문서로 표시됨)
→ 후열할 문서 선택
→ [후열] 버튼 클릭 → 열람 확인
```

> ⚠️ 후열은 열람 확인만 하는 것이며 반려가 불가능하다.

---

## 📗 9. 결재 취소 / 회수 / 강제반려

---

이미 처리한 결재나 상신한 문서를 되돌려야 할 때 사용하는 세 가지 방법이다. 상황에 따라 사용하는 기능이 다르다.

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 860 290" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:860px;font-family:sans-serif;">
  <rect width="860" height="290" fill="#f8f9fa" rx="10"/>
  <text x="430" y="28" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">결재 되돌리기 방법 비교</text>

  <!-- 상신취소 -->
  <rect x="20" y="44" width="255" height="228" rx="8" fill="#4361ee" opacity="0.08" stroke="#4361ee" stroke-width="1.5"/>
  <rect x="20" y="44" width="255" height="32" rx="6" fill="#4361ee" opacity="0.8"/>
  <text x="147" y="65" text-anchor="middle" font-size="12" fill="white" font-weight="bold">① 상신취소</text>

  <text x="147" y="95" text-anchor="middle" font-size="11" fill="#4361ee" font-weight="bold">주체: 기안자</text>
  <text x="147" y="113" text-anchor="middle" font-size="10" fill="#333">사용 시점: 첫 결재자가 결재하기 전</text>
  <text x="147" y="131" text-anchor="middle" font-size="10" fill="#555">→ 아무도 결재하지 않은 상태</text>
  <text x="147" y="157" text-anchor="middle" font-size="10" fill="#333" font-weight="bold">결과:</text>
  <text x="147" y="173" text-anchor="middle" font-size="10" fill="#555">임시 저장함으로 이동</text>
  <text x="147" y="189" text-anchor="middle" font-size="10" fill="#555">수정 후 재상신 가능</text>
  <text x="147" y="213" text-anchor="middle" font-size="10" fill="#4361ee">📍 경로:</text>
  <text x="147" y="229" text-anchor="middle" font-size="9" fill="#555">기안 문서함 > 문서 클릭</text>
  <text x="147" y="245" text-anchor="middle" font-size="9" fill="#555">> [상신취소] 클릭</text>
  <text x="147" y="261" text-anchor="middle" font-size="9" fill="#555"> </text>

  <!-- 결재문서 회수 -->
  <rect x="302" y="44" width="255" height="228" rx="8" fill="#f77f00" opacity="0.08" stroke="#f77f00" stroke-width="1.5"/>
  <rect x="302" y="44" width="255" height="32" rx="6" fill="#f77f00" opacity="0.8"/>
  <text x="429" y="65" text-anchor="middle" font-size="12" fill="white" font-weight="bold">② 결재 문서 회수</text>

  <text x="429" y="95" text-anchor="middle" font-size="11" fill="#b35700" font-weight="bold">주체: 기안자</text>
  <text x="429" y="113" text-anchor="middle" font-size="10" fill="#333">사용 시점: 결재 진행 중</text>
  <text x="429" y="131" text-anchor="middle" font-size="10" fill="#555">→ 한 명 이상 결재한 상태</text>
  <text x="429" y="149" text-anchor="middle" font-size="9" fill="#ef233c">⚠ 관리자 설정이 필요한 옵션</text>
  <text x="429" y="167" text-anchor="middle" font-size="10" fill="#333" font-weight="bold">결과:</text>
  <text x="429" y="183" text-anchor="middle" font-size="10" fill="#555">임시 저장함으로 이동</text>
  <text x="429" y="199" text-anchor="middle" font-size="10" fill="#555">수정 후 재상신 가능</text>
  <text x="429" y="215" text-anchor="middle" font-size="9" fill="#ef233c">회수 불가: 완료 문서, 시스템 연동 문서</text>
  <text x="429" y="231" text-anchor="middle" font-size="10" fill="#f77f00">📍 경로:</text>
  <text x="429" y="247" text-anchor="middle" font-size="9" fill="#555">기안 문서함 > 문서 클릭</text>
  <text x="429" y="261" text-anchor="middle" font-size="9" fill="#555">> [결재 문서 회수] 클릭</text>

  <!-- 강제반려 -->
  <rect x="584" y="44" width="255" height="228" rx="8" fill="#ef233c" opacity="0.08" stroke="#ef233c" stroke-width="1.5"/>
  <rect x="584" y="44" width="255" height="32" rx="6" fill="#ef233c" opacity="0.8"/>
  <text x="711" y="65" text-anchor="middle" font-size="12" fill="white" font-weight="bold">③ 강제반려</text>

  <text x="711" y="95" text-anchor="middle" font-size="11" fill="#b71c1c" font-weight="bold">주체: 결재 관리자 / 양식 운영자</text>
  <text x="711" y="113" text-anchor="middle" font-size="10" fill="#333">사용 시점: 결재 완료 후에도 가능</text>
  <text x="711" y="131" text-anchor="middle" font-size="10" fill="#555">→ 결재 완료 문서도 강제 되돌리기</text>
  <text x="711" y="149" text-anchor="middle" font-size="9" fill="#ef233c">⚠ 사유 입력 필수</text>
  <text x="711" y="167" text-anchor="middle" font-size="10" fill="#333" font-weight="bold">결과:</text>
  <text x="711" y="183" text-anchor="middle" font-size="10" fill="#555">기안자 기안 문서함으로 이동</text>
  <text x="711" y="199" text-anchor="middle" font-size="10" fill="#555">기안자가 [재기안]으로 재상신</text>
  <text x="711" y="215" text-anchor="middle" font-size="10" fill="#333">📍 경로:</text>
  <text x="711" y="231" text-anchor="middle" font-size="9" fill="#555">전자결재 > 전자결재 문서관리</text>
  <text x="711" y="247" text-anchor="middle" font-size="9" fill="#555">> 양식별 문서 조회 > 문서 클릭</text>
  <text x="711" y="261" text-anchor="middle" font-size="9" fill="#555">> [강제반려] > 사유 입력 > [반려]</text>
</svg>
</div>

### 📌 결재 취소 (결재자 본인)

내가 처리한 결재를 취소하는 기능이다. 취소는 다음 결재자가 아직 결재하지 않은 경우에만 가능하다.

```
전자결재 > 개인문서함 > [결재 문서함] > [진행] 탭
→ 취소할 문서 클릭
→ [결재취소] 클릭
```

> ⚠️ 최종 결재자는 결재 취소 처리를 할 수 없다.

### 📌 재기안

강제반려 또는 반려된 문서를 수정하여 다시 상신하는 방법이다.

```
기안 문서함 > 반려된 문서 클릭
→ [재기안] 버튼 클릭
→ 내용 수정 > [결재 요청]
```

---

## 📗 10. 결재 완료 후 추가 기능

---

결재가 완료된 문서에서 사용할 수 있는 추가 기능이 있다.

| 기능 | 설명 | 실행 위치 |
| --- | --- | --- |
| 공문서 발송 | 외부 기관으로 공문 발송 | 문서 상세 > [공문 발송] |
| 메일 발송 | 결재 문서를 메일로 발송 | 문서 상세 > [메일 발송] |
| 게시판 게시 | 그룹웨어 게시판에 게시 | 문서 상세 > [게시판 게시] |
| HTML 다운로드 | 결재 문서 HTML 파일로 저장 | 문서 상세 > [다운로드] |
| PDF 저장 | 결재 문서 PDF로 저장 | 문서 상세 > [인쇄] > PDF로 저장 |
| 댓글 | 문서에 댓글 작성 | 문서 상세 하단 댓글 영역 |
| 열람자 추가 | 결재 완료 후에도 열람자 추가 가능 | 문서 상세 > [결재선 지정] |

> 💡 댓글을 작성하면 해당 문서를 열람할 수 있는 모든 임직원에게 알림이 발송된다.

---

## 📗 11. 정리

---

- **승인**: 결재 팝업에서 전결·다음 문서 이동 옵션 확인 후 처리
- **반려**: 사유 입력 필수, 기안자에게 반환
- **합의**: 합의/반대 선택, 반대해도 기본적으로 결재 진행
- **선결**: 결재 예정 문서함에서 처리, 결재 타입만 가능
- **후결**: 선결 완료 문서에 서명, 반려 불가
- **대결**: 사전 부재/위임 설정 필요, 대결자가 처리 후 원 결재자에게 후열 요청 알림
- **상신취소**: 결재 전 단계, 임시저장함으로 이동
- **회수**: 결재 진행 중, 관리자 설정 필요
- **강제반려**: 관리자 전용, 결재 완료 문서도 가능, 사유 입력 필수

> 📎 다음 글: [Part 5. 참조/열람, 수신/접수/반송, 문서함](/posts/daouoffice-approval-part5)에서 결재선 외 문서 열람 권한과 수신 처리, 문서함 구조를 다룬다.

---

## 참고 자료

- 다우오피스 헬프데스크 - 결재상신/취소: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/42425208277273>
- 다우오피스 헬프데스크 - 결재처리(결재/합의/반려): <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45253223561113>
- 다우오피스 헬프데스크 - 선결/후결/전결: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45265901184281>
- 다우오피스 헬프데스크 - 대결/후열: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337105202841>
