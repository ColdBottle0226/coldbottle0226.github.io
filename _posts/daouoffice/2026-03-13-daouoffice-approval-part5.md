---
title: 다우오피스 전자결재 분석 정리 - Part 5. 참조/열람, 수신/접수/반송, 문서함
date: 2026-03-13 10:40:00 +0900
categories: [업무, 결재, 다우오피스]
tags: [다우오피스, 전자결재, 참조, 열람, 수신, 접수, 반송, 문서함, 개인문서함, 부서문서함]
---

##  1. 개요

---

결재라인에 포함되지 않더라도 문서를 볼 수 있어야 하는 사람, 결재 완료 후 문서를 받아 후속 업무를 처리해야 하는 부서, 그리고 쌓인 결재 문서를 체계적으로 관리하는 문서함까지—전자결재의 마지막 퍼즐 조각들을 이번 글에서 정리한다.

### 📌 기능 요약

| 기능 | 대상 | 시점 | 목적 |
| --- | --- | --- | --- |
| 참조 | 사용자 / 부서 | 진행 중 + 완료 후 | 문서 진행 상황 공유 |
| 열람 | 사용자 (부서 불가) | 완료 후만 | 결재 완료 문서 확인 |
| 수신 | 부서 / 사용자 | 결재 완료 후 전달 | 후속 업무 처리 |
| 접수 | 수신자 / 부서장 | 수신 문서 도착 후 | 수신 문서 처리 시작 |
| 반송 | 수신자 / 부서장 | 수신 문서 도착 후 | 문서 보완 요청 |

---

##  2. 참조 / 열람

---

결재선에 포함되지 않은 사용자에게도 문서 열람 권한을 줄 수 있는 방법이 두 가지 있다. 바로 **참조**와 **열람**이다. 이름은 비슷해 보이지만 열람 가능 시점과 지정 단위가 다르다.

### 📌 참조 vs 열람 차이점 한눈에 보기

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 840 310" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:840px;font-family:sans-serif;">
  <defs>
    <marker id="ta" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#4361ee"/>
    </marker>
  </defs>
  <rect width="840" height="310" fill="#f8f9fa" rx="10"/>
  <text x="420" y="28" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">참조 vs 열람 비교</text>

  <!-- 참조 -->
  <rect x="20" y="44" width="380" height="252" rx="8" fill="#06d6a0" opacity="0.07" stroke="#06d6a0" stroke-width="1.5"/>
  <rect x="20" y="44" width="380" height="36" rx="6" fill="#06d6a0" opacity="0.85"/>
  <text x="210" y="68" text-anchor="middle" font-size="14" fill="white" font-weight="bold">👁 참조</text>

  <text x="210" y="100" text-anchor="middle" font-size="12" fill="#16825e" font-weight="bold">열람 시점</text>
  <text x="210" y="118" text-anchor="middle" font-size="10" fill="#333">결재 진행 중 + 완료 후 모두 가능</text>
  <rect x="80" y="126" width="260" height="22" rx="4" fill="#06d6a0" opacity="0.2"/>
  <text x="210" y="141" text-anchor="middle" font-size="10" fill="#16825e" font-weight="bold">실시간 진행 상황 확인 가능 O</text>

  <text x="210" y="166" text-anchor="middle" font-size="12" fill="#16825e" font-weight="bold">지정 단위</text>
  <text x="210" y="184" text-anchor="middle" font-size="10" fill="#333">사용자 단위 O + 부서 단위 O</text>
  <text x="210" y="200" text-anchor="middle" font-size="9" fill="#555">(부서로 지정 시 해당 부서 전원 참조자 등록)</text>

  <text x="210" y="224" text-anchor="middle" font-size="12" fill="#16825e" font-weight="bold">지정 가능 시점</text>
  <text x="210" y="242" text-anchor="middle" font-size="10" fill="#333">상신 시 / 결재 대기 중</text>
  <text x="210" y="258" text-anchor="middle" font-size="9" fill="#ef233c">결재 완료 후 추가 불가 X</text>
  <text x="210" y="283" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 진행 상황 공유가 필요한 사람에게</text>

  <!-- 열람 -->
  <rect x="440" y="44" width="380" height="252" rx="8" fill="#f77f00" opacity="0.07" stroke="#f77f00" stroke-width="1.5"/>
  <rect x="440" y="44" width="380" height="36" rx="6" fill="#f77f00" opacity="0.8"/>
  <text x="630" y="68" text-anchor="middle" font-size="14" fill="white" font-weight="bold">📄 열람</text>

  <text x="630" y="100" text-anchor="middle" font-size="12" fill="#b35700" font-weight="bold">열람 시점</text>
  <text x="630" y="118" text-anchor="middle" font-size="10" fill="#333">결재 완료 후에만 가능</text>
  <rect x="500" y="126" width="260" height="22" rx="4" fill="#ef233c" opacity="0.12"/>
  <text x="630" y="141" text-anchor="middle" font-size="10" fill="#ef233c" font-weight="bold">진행 중 열람 불가 X</text>

  <text x="630" y="166" text-anchor="middle" font-size="12" fill="#b35700" font-weight="bold">지정 단위</text>
  <text x="630" y="184" text-anchor="middle" font-size="10" fill="#333">사용자 단위만 O (부서 단위 불가 X)</text>
  <text x="630" y="200" text-anchor="middle" font-size="9" fill="#555"> </text>

  <text x="630" y="224" text-anchor="middle" font-size="12" fill="#b35700" font-weight="bold">지정 가능 시점</text>
  <text x="630" y="242" text-anchor="middle" font-size="10" fill="#333">상신 시 / 결재 대기 중</text>
  <text x="630" y="258" text-anchor="middle" font-size="10" fill="#2a9d8f">결재 완료 후 추가 가능 O</text>
  <text x="630" y="283" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 결재 완료 후 공유할 사람에게</text>
</svg>
</div>

### 📌 참조자 / 열람자 지정 방법

**① 결재 상신 시 지정**

```
새 결재 진행 > 문서 작성
→ [결재 정보] 클릭 > [참조자/열람자] 탭
→ 조직도에서 직원 드래그하여 추가
→ [확인]
```

**② 결재 완료 후 열람자 추가** (기안자, 결재자, 참조자만 가능)

```
문서함 > 해당 문서 클릭
→ [결재선 지정] 클릭
→ [열람자 추가] > 열람자 선택
→ [확인]
```

> 💡 참조자는 결재 완료 후 추가할 수 없지만, 열람자는 결재 완료 후에도 추가할 수 있다.

### 📌 개인 그룹 저장

자주 사용하는 참조자·열람자 조합을 개인 그룹으로 저장해 두면 반복 작업을 줄일 수 있다.

```
결재 정보 화면 > 참조자/열람자 지정 완료 후
→ 하단 [개인 그룹으로 저장] 클릭 > 그룹 이름 입력 > [확인]
이후: [개인 그룹] 탭 > 저장된 그룹 선택
```

### 📌 참조/열람 문서 조회

```
전자결재 App > [참조/열람 대기 문서] 클릭
→ 조회할 문서 선택
```

> 💡 참조자·열람자가 문서를 조회하면 문서의 열람 기록에 이름과 조회 시간이 남는다.

> 💡 참조자·열람자 지정이 되지 않는다면 관리자가 해당 결재 양식에서 참조자/열람자 사용 여부를 설정했는지 확인해야 한다.

---

##  3. 수신 / 접수 / 반송

---

결재 완료 후 지정된 부서나 사용자에게 문서를 전달하고, 후속 업무를 처리하는 기능이다. 결재로 승인을 받는 것에서 끝나지 않고, 이후 특정 부서가 추가 조치를 취해야 할 때 사용한다.

### 📌 수신 방식 두 가지

수신 기능에는 방식이 두 가지 있다. 결재선에 수신 단계를 추가하는 방식과, 별도 수신 기능으로 문서를 복제 전달하는 방식이다.

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 840 380" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:840px;font-family:sans-serif;">
  <defs>
    <marker id="ra" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#4361ee"/>
    </marker>
    <marker id="rb" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#3a86ff"/>
    </marker>
  </defs>
  <rect width="840" height="380" fill="#f8f9fa" rx="10"/>
  <text x="420" y="28" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">수신 방식 비교</text>

  <!-- 방식 1 -->
  <text x="20" y="52" font-size="11" font-weight="bold" fill="#4361ee">① 결재선 수신 방식</text>
  <text x="20" y="68" font-size="9" fill="#555">결재선 자체에 수신 단계를 추가하는 방식</text>

  <rect x="20" y="76" width="85" height="36" rx="6" fill="#4361ee" opacity="0.8"/>
  <text x="62" y="99" text-anchor="middle" font-size="10" fill="white">기안</text>

  <line x1="105" y1="94" x2="123" y2="94" stroke="#4361ee" stroke-width="1.5" marker-end="url(#ra)"/>

  <rect x="123" y="76" width="95" height="36" rx="6" fill="#4361ee" opacity="0.65"/>
  <text x="170" y="99" text-anchor="middle" font-size="10" fill="white">결재 (합의)</text>

  <line x1="218" y1="94" x2="236" y2="94" stroke="#4361ee" stroke-width="1.5" marker-end="url(#ra)"/>

  <rect x="236" y="76" width="120" height="36" rx="6" fill="#06d6a0" opacity="0.85"/>
  <text x="296" y="94" text-anchor="middle" font-size="10" fill="white">수신 부서 처리</text>
  <text x="296" y="106" text-anchor="middle" font-size="9" fill="white">(결재선에서 직접)</text>

  <!-- 방식 1 설명 -->
  <rect x="20" y="124" width="380" height="80" rx="6" fill="white" stroke="#dee2e6" stroke-width="1"/>
  <text x="34" y="142" font-size="10" fill="#16825e" font-weight="bold">O 장점</text>
  <text x="34" y="158" font-size="9" fill="#555">업무 프로세스가 단순하고 처리 속도가 빠름</text>
  <text x="34" y="172" font-size="10" fill="#ef233c" font-weight="bold">⚠️ 단점</text>
  <text x="34" y="188" font-size="9" fill="#555">기안자가 모든 수신 결재선 직접 구성 필요, 변경사항 파악 어려움</text>

  <!-- 방식 2 -->
  <text x="20" y="230" font-size="11" font-weight="bold" fill="#3a86ff">② 문서 수신 기능 방식</text>
  <text x="20" y="246" font-size="9" fill="#555">수신 부서마다 원본 문서가 복제되어 전달되는 방식</text>

  <rect x="20" y="254" width="70" height="36" rx="6" fill="#3a86ff" opacity="0.8"/>
  <text x="55" y="277" text-anchor="middle" font-size="10" fill="white">기안</text>

  <line x1="90" y1="272" x2="108" y2="272" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#rb)"/>
  <rect x="108" y="254" width="85" height="36" rx="6" fill="#3a86ff" opacity="0.65"/>
  <text x="150" y="277" text-anchor="middle" font-size="10" fill="white">결재 (합의)</text>

  <line x1="193" y1="272" x2="211" y2="272" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#rb)"/>
  <rect x="211" y="254" width="100" height="36" rx="6" fill="#7209b7" opacity="0.7"/>
  <text x="261" y="270" text-anchor="middle" font-size="9" fill="white">문서 복제</text>
  <text x="261" y="282" text-anchor="middle" font-size="9" fill="#e5c7ff">수신처별 전달</text>

  <line x1="311" y1="272" x2="329" y2="272" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#rb)"/>
  <rect x="329" y="254" width="80" height="36" rx="6" fill="#3a86ff" opacity="0.55"/>
  <text x="369" y="277" text-anchor="middle" font-size="10" fill="white">수신 / 접수</text>

  <line x1="409" y1="272" x2="427" y2="272" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#rb)"/>
  <rect x="427" y="254" width="100" height="36" rx="6" fill="#06d6a0" opacity="0.85"/>
  <text x="477" y="271" text-anchor="middle" font-size="9" fill="white">부서 내 처리</text>
  <text x="477" y="283" text-anchor="middle" font-size="9" fill="white">(결재 요청 등)</text>

  <!-- 방식 2 설명 -->
  <rect x="20" y="302" width="580" height="64" rx="6" fill="white" stroke="#dee2e6" stroke-width="1"/>
  <text x="34" y="320" font-size="10" fill="#16825e" font-weight="bold">O 장점</text>
  <text x="34" y="336" font-size="9" fill="#555">부서별로 문서가 독립 관리되어 변경사항 반영 용이, 선택적 정보 공개 가능</text>
  <text x="34" y="350" font-size="10" fill="#ef233c" font-weight="bold">⚠️ 단점</text>
  <text x="34" y="364" font-size="9" fill="#555">업무 절차 복잡, 수신처 수만큼 결재문서 생성 (원본 + 수신처별 복제본)</text>
</svg>
</div>

### 📌 수신자 지정 방법

**① 결재선 수신 방식:**
```
결재 정보 창 > 조직도에서 수신 부서/직원 드래그
→ 결재선의 '수신' 항목에 드롭 > [확인]
```

**② 문서 수신 기능 방식:**
```
결재 정보 창 > [수신자] 탭 클릭
→ 수신 부서/직원 드래그하여 추가 > [확인]
```

### 📌 수신 문서 처리 (문서 수신 기능 방식)

수신 문서가 도착하면 부서장에게 알림이 발송된다.

**접수 / 반송 권한:**

| 구분 | 부서장 | 부부서장 | 부서원 |
| --- | --- | --- | --- |
| 수신자가 '부서'일 때 | O 접수 가능 | O 접수 가능 | X 불가 |
| 수신자가 '사용자'일 때 | O 접수 가능 | O 접수 가능 | 수신자 본인만 가능 |

**접수 처리:**
```
전자결재 > [결재 수신 문서] > 접수할 문서 선택
→ [접수] 클릭 > 팝업에서 [확인]
→ 접수 완료 후 가능한 액션: 결재 요청 / 접수취소 / 문서수정 / 결재선 지정
```

**반송 처리:**
```
전자결재 > [결재 수신 문서] > 반송할 문서 선택
→ [반송] 클릭 > [확인]
→ 수신 문서가 원본 문서의 기안 문서함으로 이동
   (단, 원본 결재 문서는 결재 완료 상태 유지)
```

### 📌 수신 문서 내 결재 요청

접수된 수신 문서에 대해 부서 내부 결재를 진행할 수 있다.

```
결재 수신 문서 > [접수] 탭 > 결재 요청할 문서 선택
→ [결재 정보] 클릭 > 결재선 지정 > [확인]
→ [결재 요청] 클릭
```

> 💡 수신 문서에서 결재 요청 시 원본 결재 문서가 **자동으로 연관 문서에 등록**되어, 업무 히스토리를 쉽게 파악할 수 있다.

---

##  4. 문서함 구조

---

전자결재가 완료된 모든 문서는 문서함에 저장된다. 개인 문서함과 부서 문서함으로 나뉜다.

### 📌 개인 문서함 종류

| 문서함 | 저장되는 문서 | 비고 |
| --- | --- | --- |
| 기안 문서함 | 내가 기안한 모든 문서 | 전체 상태 포함 |
| 임시 저장함 | 임시저장 / 상신취소 / 회수된 문서 | 재작성 대기 문서 |
| 결재 문서함 | 합의자·결재자로 처리한 문서 | [진행] / [완료] 탭 분리 |
| 참조/열람 문서함 | 참조자·열람자로 지정된 문서 | |
| 수신 문서함 | 수신자·수신 부서로 지정된 문서 | [접수 대기] / [접수] 탭 |
| 발송 문서함 | 수신처 지정하여 발송한 문서 | |
| 공문 문서함 | 공문 발송 관리자로 지정된 경우 | 공문 발송 관리자만 노출 |

### 📌 부서 문서함

소속 부서의 모든 결재 문서가 저장되는 문서함이다.

- 같은 부서 사용자는 공개여부와 보안 등급에 따라 문서를 조회할 수 있다.
- 부서장·부부서장은 문서함 추가/삭제 및 문서 이관이 가능하다.
- 부서원도 '문서함 담당자'로 지정되면 부서장과 동일한 권한으로 관리 가능하다.

### 📌 문서함 관리 기능

**문서 이동:**
```
문서함 > 이동할 문서 체크박스 선택
→ [이동] 클릭 > 대상 문서함 선택 > [확인]
```

**문서 삭제:**
```
문서함 > 삭제할 문서 체크박스 선택
→ [삭제] 클릭 > [확인]
※ 기본 문서함의 문서는 삭제 불가 (개인이 생성한 하위 문서함만 가능)
```

**문서함 이관 (부서장 전용):**
```
부서 문서함 > [문서함 관리] > 이관할 문서함 선택
→ [이관] 클릭 > 대상 부서 선택 > [확인]
```

### 📌 문서함 내 검색 및 정렬

- 문서 제목, 기안자, 기안일 등으로 검색 가능
- 날짜순 / 문서번호순 정렬 가능
- 상태 필터 (진행 중 / 완료 / 반려) 적용 가능

---

##  5. 공문서 발송 / 메일 발송 / 게시판 게시

---

결재 완료 문서는 외부 전달 및 내부 공유를 위한 다양한 발송 기능을 제공한다.

### 📌 공문서 발송

결재 완료 문서를 외부 기관으로 공문을 발송하는 기능이다.

- 공문 발송 관리자로 지정된 사용자가 승인 후 발송한다.
- 공문 대기 문서함에서 발송 전 승인 처리를 할 수 있다.

```
결재 완료 문서 상세 > [공문 발송] 클릭
→ 수신처 설정 > [발송]
```

### 📌 메일 발송

결재 완료 문서를 메일로 전송하는 기능이다.

```
결재 완료 문서 상세 > [메일 발송] 클릭
→ 수신자 메일 주소 입력 > [발송]
```

> 💡 열람자로 지정된 사용자도 메일 발송이 가능하다.

### 📌 게시판 게시

결재 완료 문서를 그룹웨어 게시판에 게시하여 내부 임직원과 공유한다.

```
결재 완료 문서 상세 > [게시판 게시] 클릭
→ 대상 게시판 선택 > [게시]
```

### 📌 댓글 기능

각 결재 문서 하단에 댓글을 작성할 수 있다.

- 댓글 작성 시 해당 문서를 열람할 수 있는 모든 임직원에게 알림 발송
- 기안자, 결재자, 참조자, 열람자 모두 댓글 작성 가능

---

##  6. 정리

---

- **참조**: 진행 중 + 완료 후 열람 가능, 부서 단위 지정 가능, 완료 후 추가 불가
- **열람**: 완료 후만 열람 가능, 사용자 단위만 가능, 완료 후 추가 가능
- **수신 방식 1 (결재선 수신)**: 단순하고 빠름, 기안자가 모든 수신선 직접 구성
- **수신 방식 2 (문서 수신 기능)**: 부서별 독립 관리, 절차 복잡, 원본 + 복제본 생성
- **접수**: 부서 수신 시 부서장/부부서장만 처리 가능, 사용자 수신 시 본인만 처리 가능
- **반송**: 원본 문서 기안 문서함으로 이동, 원본 결재 완료 상태는 유지
- **문서함**: 개인(기안/임시저장/결재/참조열람/수신/발송/공문) + 부서 문서함

---

## 참고 자료

- 다우오피스 헬프데스크 - 참조/열람: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337190335641>
- 다우오피스 헬프데스크 - 수신/접수/반송: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337353211545>
- 다우오피스 헬프데스크 - 전자결재 문서함: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337557716121>
- 다우오피스 헬프데스크 - 개인 문서함: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/42425265382297>
- 다우오피스 헬프데스크 - 부서 문서함: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/42425383014425>
- 다우오피스 헬프데스크 - 공문서·메일 발송/게시: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337437947161>
