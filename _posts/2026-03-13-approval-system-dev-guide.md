---
title: 결재 시스템 구현 가이드 - 용어, 업무 흐름, 설계 포인트
date: 2026-03-13 11:00:00 +0900
categories: [Backend, 시스템설계]
tags: [결재시스템, 전자결재, 워크플로우, 결재선, 상태머신, 설계, Java, Spring, ERD]
---

## 📗 1. 개요

---

결재 시스템을 처음 구현해야 한다는 요건이 떨어졌을 때, 막막한 이유 중 하나는 도메인 용어를 정확히 모르는 상태에서 설계를 시작해야 한다는 점이다.

이번 글에서는 결재 시스템을 구현할 때 개발자가 반드시 알아야 할 핵심 용어, 업무 흐름, 데이터 구조, 상태 관리, 그리고 구현 시 고려해야 할 포인트들을 정리한다.

### 📌 전체 구조 한눈에 보기

![image](/assets/images/approval/approval_image.png)

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 900 540" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:900px;font-family:sans-serif;">
  <defs>
    <marker id="g1" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#4361ee"/>
    </marker>
    <marker id="g2" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#ef233c"/>
    </marker>
  </defs>
  <rect width="900" height="540" fill="#f8f9fa" rx="12"/>
  <text x="450" y="32" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">결재 시스템 전체 구조 (개발자 관점)</text>

  <!-- 레이어 1: 도메인 레이어 -->
  <rect x="20" y="50" width="860" height="105" rx="8" fill="#4361ee" opacity="0.06" stroke="#4361ee" stroke-width="1.5"/>
  <text x="34" y="68" font-size="11" font-weight="bold" fill="#4361ee">📦 도메인 레이어</text>

  <rect x="30" y="75" width="130" height="68" rx="6" fill="#4361ee" opacity="0.8"/>
  <text x="95" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">Document</text>
  <text x="95" y="111" text-anchor="middle" font-size="9" fill="#cfd8ff">결재 문서 본체</text>
  <text x="95" y="123" text-anchor="middle" font-size="9" fill="#cfd8ff">id, title, status</text>
  <text x="95" y="135" text-anchor="middle" font-size="9" fill="#cfd8ff">formId, content</text>

  <rect x="175" y="75" width="130" height="68" rx="6" fill="#4361ee" opacity="0.65"/>
  <text x="240" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">ApprovalLine</text>
  <text x="240" y="111" text-anchor="middle" font-size="9" fill="#cfd8ff">결재선 (순서 포함)</text>
  <text x="240" y="123" text-anchor="middle" font-size="9" fill="#cfd8ff">stepOrder, type</text>
  <text x="240" y="135" text-anchor="middle" font-size="9" fill="#cfd8ff">approverId, status</text>

  <rect x="320" y="75" width="130" height="68" rx="6" fill="#4361ee" opacity="0.5"/>
  <text x="385" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">ApprovalHistory</text>
  <text x="385" y="111" text-anchor="middle" font-size="9" fill="#cfd8ff">처리 이력</text>
  <text x="385" y="123" text-anchor="middle" font-size="9" fill="#cfd8ff">action, comment</text>
  <text x="385" y="135" text-anchor="middle" font-size="9" fill="#cfd8ff">processedAt</text>

  <rect x="465" y="75" width="130" height="68" rx="6" fill="#3a86ff" opacity="0.75"/>
  <text x="530" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">Form</text>
  <text x="530" y="111" text-anchor="middle" font-size="9" fill="#cfe0ff">결재 양식</text>
  <text x="530" y="123" text-anchor="middle" font-size="9" fill="#cfe0ff">fixedApprovalLine</text>
  <text x="530" y="135" text-anchor="middle" font-size="9" fill="#cfe0ff">retentionPeriod</text>

  <rect x="610" y="75" width="130" height="68" rx="6" fill="#3a86ff" opacity="0.55"/>
  <text x="675" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">Notification</text>
  <text x="675" y="111" text-anchor="middle" font-size="9" fill="#cfe0ff">알림</text>
  <text x="675" y="123" text-anchor="middle" font-size="9" fill="#cfe0ff">recipientId, type</text>
  <text x="675" y="135" text-anchor="middle" font-size="9" fill="#cfe0ff">isRead, sentAt</text>

  <rect x="755" y="75" width="115" height="68" rx="6" fill="#7209b7" opacity="0.65"/>
  <text x="812" y="97" text-anchor="middle" font-size="11" fill="white" font-weight="bold">Archive</text>
  <text x="812" y="111" text-anchor="middle" font-size="9" fill="#e5c7ff">문서함</text>
  <text x="812" y="123" text-anchor="middle" font-size="9" fill="#e5c7ff">boxType, docId</text>
  <text x="812" y="135" text-anchor="middle" font-size="9" fill="#e5c7ff">ownerId, deptId</text>

  <!-- 레이어 2: 상태 머신 -->
  <rect x="20" y="168" width="860" height="110" rx="8" fill="#06d6a0" opacity="0.05" stroke="#06d6a0" stroke-width="1.5"/>
  <text x="34" y="186" font-size="11" font-weight="bold" fill="#16825e">🔄 문서 상태 머신 (DocumentStatus)</text>

  <rect x="30" y="193" width="90" height="36" rx="6" fill="#dee2e6"/>
  <text x="75" y="216" text-anchor="middle" font-size="10" fill="#333">DRAFT</text>

  <line x1="120" y1="211" x2="145" y2="211" stroke="#4361ee" stroke-width="1.5" marker-end="url(#g1)"/>
  <text x="132" y="205" text-anchor="middle" font-size="8" fill="#4361ee">상신</text>

  <rect x="145" y="193" width="90" height="36" rx="6" fill="#ffd166"/>
  <text x="190" y="216" text-anchor="middle" font-size="10" fill="#333" font-weight="bold">IN_PROGRESS</text>

  <line x1="235" y1="211" x2="260" y2="211" stroke="#4361ee" stroke-width="1.5" marker-end="url(#g1)"/>
  <text x="247" y="205" text-anchor="middle" font-size="8" fill="#4361ee">승인</text>

  <rect x="260" y="193" width="90" height="36" rx="6" fill="#06d6a0"/>
  <text x="305" y="216" text-anchor="middle" font-size="10" fill="white" font-weight="bold">APPROVED</text>

  <path d="M 190,229 Q 190,255 75,255 Q 30,255 30,244" stroke="#ef233c" stroke-width="1.5" fill="none" stroke-dasharray="4,3" marker-end="url(#g2)"/>
  <text x="100" y="263" text-anchor="middle" font-size="8" fill="#ef233c">반려</text>

  <rect x="30" y="244" width="90" height="28" rx="6" fill="#ef233c" opacity="0.8"/>
  <text x="75" y="263" text-anchor="middle" font-size="10" fill="white" font-weight="bold">REJECTED</text>

  <line x1="145" y1="220" x2="120" y2="244" stroke="#6c757d" stroke-width="1.2" stroke-dasharray="3,2" marker-end="url(#g2)"/>
  <text x="115" y="238" text-anchor="middle" font-size="8" fill="#6c757d">상신취소</text>

  <rect x="370" y="193" width="105" height="36" rx="6" fill="#ffd166" opacity="0.6"/>
  <text x="422" y="211" text-anchor="middle" font-size="10" fill="#333">CANCELLED</text>
  <text x="422" y="223" text-anchor="middle" font-size="9" fill="#666">(회수/취소)</text>

  <!-- 결재선 단계 상태 -->
  <text x="550" y="195" font-size="10" font-weight="bold" fill="#7209b7">결재선 단계 상태 (StepStatus)</text>
  <rect x="550" y="202" width="75" height="26" rx="5" fill="#dee2e6"/>
  <text x="587" y="219" text-anchor="middle" font-size="9" fill="#555">PENDING</text>
  <rect x="635" y="202" width="75" height="26" rx="5" fill="#ffd166"/>
  <text x="672" y="219" text-anchor="middle" font-size="9" fill="#555">WAITING</text>
  <rect x="720" y="202" width="75" height="26" rx="5" fill="#06d6a0"/>
  <text x="757" y="219" text-anchor="middle" font-size="9" fill="white">APPROVED</text>
  <rect x="805" y="202" width="65" height="26" rx="5" fill="#ef233c" opacity="0.8"/>
  <text x="837" y="219" text-anchor="middle" font-size="9" fill="white">REJECTED</text>

  <rect x="550" y="234" width="75" height="26" rx="5" fill="#adb5bd"/>
  <text x="587" y="251" text-anchor="middle" font-size="9" fill="#333">SKIPPED</text>
  <rect x="635" y="234" width="75" height="26" rx="5" fill="#118ab2" opacity="0.7"/>
  <text x="672" y="251" text-anchor="middle" font-size="9" fill="white">DELEGATED</text>
  <rect x="720" y="234" width="75" height="26" rx="5" fill="#7209b7" opacity="0.7"/>
  <text x="757" y="251" text-anchor="middle" font-size="9" fill="white">PRE_APPROVED</text>

  <!-- 레이어 3: 결재 유형 -->
  <rect x="20" y="293" width="860" height="110" rx="8" fill="#f77f00" opacity="0.05" stroke="#f77f00" stroke-width="1.5"/>
  <text x="34" y="311" font-size="11" font-weight="bold" fill="#b35700">📋 결재 유형 (ApprovalStepType)</text>

  <rect x="30" y="317" width="108" height="72" rx="6" fill="#4361ee" opacity="0.12"/>
  <rect x="30" y="317" width="108" height="7" rx="3" fill="#4361ee"/>
  <text x="84" y="333" text-anchor="middle" font-size="10" fill="#4361ee" font-weight="bold">APPROVE</text>
  <text x="84" y="347" text-anchor="middle" font-size="9" fill="#333">기본 결재</text>
  <text x="84" y="359" text-anchor="middle" font-size="9" fill="#555">승인/반려 가능</text>
  <text x="84" y="371" text-anchor="middle" font-size="9" fill="#555">전결/선결 옵션</text>
  <text x="84" y="381" text-anchor="middle" font-size="9" fill="#555">반려 시 기안자에게</text>

  <rect x="150" y="317" width="108" height="72" rx="6" fill="#3a86ff" opacity="0.12"/>
  <rect x="150" y="317" width="108" height="7" rx="3" fill="#3a86ff"/>
  <text x="204" y="333" text-anchor="middle" font-size="10" fill="#3a86ff" font-weight="bold">AGREE</text>
  <text x="204" y="347" text-anchor="middle" font-size="9" fill="#333">합의</text>
  <text x="204" y="359" text-anchor="middle" font-size="9" fill="#555">합의/반대 가능</text>
  <text x="204" y="371" text-anchor="middle" font-size="9" fill="#555">반대해도 진행됨(기본)</text>
  <text x="204" y="381" text-anchor="middle" font-size="9" fill="#555">병렬/순차 방식 선택</text>

  <rect x="270" y="317" width="108" height="72" rx="6" fill="#06d6a0" opacity="0.12"/>
  <rect x="270" y="317" width="108" height="7" rx="3" fill="#06d6a0"/>
  <text x="324" y="333" text-anchor="middle" font-size="10" fill="#16825e" font-weight="bold">CONFIRM</text>
  <text x="324" y="347" text-anchor="middle" font-size="9" fill="#333">확인</text>
  <text x="324" y="359" text-anchor="middle" font-size="9" fill="#555">결재/반려 가능</text>
  <text x="324" y="371" text-anchor="middle" font-size="9" fill="#555">결재선 미노출</text>
  <text x="324" y="381" text-anchor="middle" font-size="9" fill="#555">이력에만 기록</text>

  <rect x="390" y="317" width="108" height="72" rx="6" fill="#ef476f" opacity="0.12"/>
  <rect x="390" y="317" width="108" height="7" rx="3" fill="#ef476f"/>
  <text x="444" y="333" text-anchor="middle" font-size="10" fill="#b71c40" font-weight="bold">AUDIT</text>
  <text x="444" y="347" text-anchor="middle" font-size="9" fill="#333">감사</text>
  <text x="444" y="359" text-anchor="middle" font-size="9" fill="#555">기본 반려 불가</text>
  <text x="444" y="371" text-anchor="middle" font-size="9" fill="#555">결재선 노출</text>
  <text x="444" y="381" text-anchor="middle" font-size="9" fill="#555">옵션으로 반려 활성화</text>

  <rect x="510" y="317" width="108" height="72" rx="6" fill="#7209b7" opacity="0.12"/>
  <rect x="510" y="317" width="108" height="7" rx="3" fill="#7209b7"/>
  <text x="564" y="333" text-anchor="middle" font-size="10" fill="#5b2a9e" font-weight="bold">RECEIVE</text>
  <text x="564" y="347" text-anchor="middle" font-size="9" fill="#333">수신</text>
  <text x="564" y="359" text-anchor="middle" font-size="9" fill="#555">문서 전달 수신</text>
  <text x="564" y="371" text-anchor="middle" font-size="9" fill="#555">접수/반송 처리</text>
  <text x="564" y="381" text-anchor="middle" font-size="9" fill="#555">후속 결재 진행 가능</text>

  <rect x="630" y="317" width="108" height="72" rx="6" fill="#f77f00" opacity="0.12"/>
  <rect x="630" y="317" width="108" height="7" rx="3" fill="#f77f00"/>
  <text x="684" y="333" text-anchor="middle" font-size="10" fill="#b35700" font-weight="bold">REFERENCE</text>
  <text x="684" y="347" text-anchor="middle" font-size="9" fill="#333">참조</text>
  <text x="684" y="359" text-anchor="middle" font-size="9" fill="#555">결재선 외 열람</text>
  <text x="684" y="371" text-anchor="middle" font-size="9" fill="#555">진행 중 조회 가능</text>
  <text x="684" y="381" text-anchor="middle" font-size="9" fill="#555">부서 단위 지정 가능</text>

  <rect x="750" y="317" width="120" height="72" rx="6" fill="#118ab2" opacity="0.12"/>
  <rect x="750" y="317" width="120" height="7" rx="3" fill="#118ab2"/>
  <text x="810" y="333" text-anchor="middle" font-size="10" fill="#0a5876" font-weight="bold">READ</text>
  <text x="810" y="347" text-anchor="middle" font-size="9" fill="#333">열람</text>
  <text x="810" y="359" text-anchor="middle" font-size="9" fill="#555">완료 후만 조회</text>
  <text x="810" y="371" text-anchor="middle" font-size="9" fill="#555">사용자 단위만</text>
  <text x="810" y="381" text-anchor="middle" font-size="9" fill="#555">완료 후 추가 가능</text>

  <!-- 레이어 4: 특수 액션 -->
  <rect x="20" y="417" width="860" height="110" rx="8" fill="#118ab2" opacity="0.05" stroke="#118ab2" stroke-width="1.5"/>
  <text x="34" y="435" font-size="11" font-weight="bold" fill="#0a5876">⚡ 특수 결재 액션 (ApprovalAction)</text>

  <rect x="30" y="443" width="118" height="72" rx="6" fill="#4361ee" opacity="0.12"/>
  <rect x="30" y="443" width="118" height="7" rx="3" fill="#4361ee"/>
  <text x="89" y="459" text-anchor="middle" font-size="10" fill="#4361ee" font-weight="bold">PRE_APPROVE (선결)</text>
  <text x="89" y="473" text-anchor="middle" font-size="9" fill="#333">내 차례 전에 미리 결재</text>
  <text x="89" y="485" text-anchor="middle" font-size="9" fill="#555">결재 예정 문서에서 처리</text>
  <text x="89" y="497" text-anchor="middle" font-size="9" fill="#555">APPROVE 타입만 가능</text>
  <text x="89" y="508" text-anchor="middle" font-size="9" fill="#555">이후 후결(POST) 처리</text>

  <rect x="162" y="443" width="118" height="72" rx="6" fill="#3a86ff" opacity="0.12"/>
  <rect x="162" y="443" width="118" height="7" rx="3" fill="#3a86ff"/>
  <text x="221" y="459" text-anchor="middle" font-size="10" fill="#3a86ff" font-weight="bold">FINAL_APPROVE (전결)</text>
  <text x="221" y="473" text-anchor="middle" font-size="9" fill="#333">중간 결재자가 완료 처리</text>
  <text x="221" y="485" text-anchor="middle" font-size="9" fill="#555">이후 단계 SKIPPED 처리</text>
  <text x="221" y="497" text-anchor="middle" font-size="9" fill="#555">이후 결재자 열람 불가</text>
  <text x="221" y="508" text-anchor="middle" font-size="9" fill="#555">양식별 허용 여부 설정</text>

  <rect x="294" y="443" width="118" height="72" rx="6" fill="#f77f00" opacity="0.12"/>
  <rect x="294" y="443" width="118" height="7" rx="3" fill="#f77f00"/>
  <text x="353" y="459" text-anchor="middle" font-size="10" fill="#b35700" font-weight="bold">DELEGATE (대결)</text>
  <text x="353" y="473" text-anchor="middle" font-size="9" fill="#333">부재 시 타인에게 위임</text>
  <text x="353" y="485" text-anchor="middle" font-size="9" fill="#555">대결자가 결재 처리</text>
  <text x="353" y="497" text-anchor="middle" font-size="9" fill="#555">결재선에는 대결자 기록</text>
  <text x="353" y="508" text-anchor="middle" font-size="9" fill="#555">원 결재자 후열 처리 가능</text>

  <rect x="426" y="443" width="118" height="72" rx="6" fill="#7209b7" opacity="0.12"/>
  <rect x="426" y="443" width="118" height="7" rx="3" fill="#7209b7"/>
  <text x="485" y="459" text-anchor="middle" font-size="10" fill="#5b2a9e" font-weight="bold">WITHDRAW (회수)</text>
  <text x="485" y="473" text-anchor="middle" font-size="9" fill="#333">기안자의 문서 회수</text>
  <text x="485" y="485" text-anchor="middle" font-size="9" fill="#555">진행 중만 가능</text>
  <text x="485" y="497" text-anchor="middle" font-size="9" fill="#555">완료 문서는 회수 불가</text>
  <text x="485" y="508" text-anchor="middle" font-size="9" fill="#555">임시저장함으로 이동</text>

  <rect x="558" y="443" width="118" height="72" rx="6" fill="#ef233c" opacity="0.12"/>
  <rect x="558" y="443" width="118" height="7" rx="3" fill="#ef233c"/>
  <text x="617" y="459" text-anchor="middle" font-size="10" fill="#b71c1c" font-weight="bold">FORCE_REJECT (강제반려)</text>
  <text x="617" y="473" text-anchor="middle" font-size="9" fill="#333">관리자 권한으로 강제처리</text>
  <text x="617" y="485" text-anchor="middle" font-size="9" fill="#555">완료 문서도 가능</text>
  <text x="617" y="497" text-anchor="middle" font-size="9" fill="#555">사유 입력 필수</text>
  <text x="617" y="508" text-anchor="middle" font-size="9" fill="#555">기안자에게 재기안 알림</text>

  <rect x="690" y="443" width="182" height="72" rx="6" fill="#06d6a0" opacity="0.12"/>
  <rect x="690" y="443" width="182" height="7" rx="3" fill="#06d6a0"/>
  <text x="781" y="459" text-anchor="middle" font-size="10" fill="#16825e" font-weight="bold">HOLD / CANCEL_APPROVAL</text>
  <text x="781" y="473" text-anchor="middle" font-size="9" fill="#333">HOLD: 보류 (나중에 처리)</text>
  <text x="781" y="485" text-anchor="middle" font-size="9" fill="#555">CANCEL: 내 결재 취소</text>
  <text x="781" y="497" text-anchor="middle" font-size="9" fill="#555">최종결재자 취소 불가</text>
  <text x="781" y="508" text-anchor="middle" font-size="9" fill="#555">다음 결재자 미처리 시만</text>
</svg>
</div>

---

## 📗 2. 핵심 도메인 용어 정리

---

결재 시스템을 구현하려면 먼저 도메인 용어를 정확히 이해해야 한다. 용어가 명확하지 않으면 DB 설계와 API 설계가 엇나간다.

### 📌 기안 / 상신

**기안(起案)**은 결재 문서를 작성하는 행위, **상신(上申)**은 작성된 문서를 결재자에게 제출하는 행위다.

실무에서는 혼용하지만, 구현 관점에서는 아래와 같이 구분한다.

| 용어 | 구현상 의미 | 상태 변화 |
| --- | --- | --- |
| 기안 | 문서 초안 생성 (임시저장 포함) | `DRAFT` |
| 상신 | 결재 요청 제출 | `DRAFT` → `IN_PROGRESS` |

### 📌 결재선 (ApprovalLine)

결재선은 문서가 거쳐야 하는 결재자들의 목록과 순서다. 단순한 배열이 아니라 각 단계마다 타입, 순서, 상태를 가진다.

```
Document
  └── ApprovalLine[]
        ├── step 1: 팀장 / type=APPROVE / status=APPROVED
        ├── step 2: 타부서 / type=AGREE / status=AGREED
        └── step 3: 본부장 / type=APPROVE / status=PENDING
```

결재선의 **현재 처리 단계**를 추적하는 포인터(`currentStep`)가 필요하다. 이 포인터를 기준으로 누구에게 알림을 보내고, 누구의 결재를 받아야 하는지 결정한다.

### 📌 결재 유형 (ApprovalStepType)

결재선의 각 단계는 역할이 다르다. 구현 시 아래 유형을 enum으로 관리하는 것이 일반적이다.

| 유형 | 상수명 | 행동 가능 | 결재선 노출 | 비고 |
| --- | --- | --- | --- | --- |
| 결재 | `APPROVE` | 승인 / 반려 | O | 기본 유형 |
| 합의 | `AGREE` | 합의 / 반대 | O | 반대해도 진행 가능 |
| 확인 | `CONFIRM` | 승인 / 반려 | X | 이력에만 기록 |
| 감사 | `AUDIT` | 승인 (반려는 옵션) | O | |
| 수신 | `RECEIVE` | 접수 / 반송 | 별도 | 문서 수신 후 처리 |

> 💡 CONFIRM과 APPROVE의 차이: 동일하게 승인/반려가 가능하지만, CONFIRM은 결재문서 본문에 서명 칸이 없고 이력에만 기록된다. `isVisible` 필드로 제어하거나 별도 타입으로 분리하면 된다.

### 📌 합의 방식 (AgreePolicy)

합의자가 여러 명일 때 처리 방식을 정의한다.

| 방식 | 상수명 | 동작 |
| --- | --- | --- |
| 순차합의 | `SEQUENTIAL` | 지정 순서대로 한 명씩 처리 |
| 병렬합의 | `PARALLEL` | 모든 합의자에게 동시 전달, 순서 무관하게 처리 가능 |

병렬합의는 "전원 완료 시 다음 단계로 넘어간다"는 로직이 필요하다. 타임아웃 처리도 고려해야 한다.

---

## 📗 3. 문서 상태 머신 설계

---

결재 시스템의 핵심은 **문서 상태 + 결재선 단계 상태**를 정확히 관리하는 것이다. 상태가 틀리면 알림, 권한, UI가 전부 틀어진다.

### 📌 문서 상태 (DocumentStatus)

```java
public enum DocumentStatus {
    DRAFT,        // 임시저장 / 기안 중
    IN_PROGRESS,  // 결재 진행 중
    APPROVED,     // 결재 완료
    REJECTED,     // 반려됨
    CANCELLED     // 상신취소 / 회수됨
}
```

**상태 전이 규칙:**

```
DRAFT → IN_PROGRESS       : 상신(기안 제출)
IN_PROGRESS → APPROVED    : 최종 결재자 승인
IN_PROGRESS → REJECTED    : 임의 단계에서 반려
IN_PROGRESS → CANCELLED   : 상신취소 or 회수
APPROVED → REJECTED       : 강제반려 (관리자 전용)
REJECTED → IN_PROGRESS    : 재기안 상신
```

### 📌 결재선 단계 상태 (StepStatus)

```java
public enum StepStatus {
    PENDING,       // 내 차례가 되지 않은 대기 상태
    WAITING,       // 내 차례, 처리 대기 중
    APPROVED,      // 승인 완료
    REJECTED,      // 반려
    AGREED,        // 합의 완료
    DISAGREED,     // 반대 표시
    SKIPPED,       // 전결로 인해 건너뜀
    DELEGATED,     // 대결로 위임됨
    PRE_APPROVED,  // 선결 처리됨 (후결 대기)
    POST_APPROVED  // 후결 처리 완료
}
```

### 📌 현재 단계 포인터 관리

결재선을 순회하며 현재 처리해야 할 단계를 찾는 로직이 자주 쓰인다.

```java
// 현재 처리 대상 단계 조회
public ApprovalLineStep getCurrentStep(List<ApprovalLineStep> steps) {
    return steps.stream()
        .filter(s -> s.getStatus() == StepStatus.WAITING)
        .findFirst()
        .orElse(null);
}

// 결재 처리 후 다음 단계 활성화
public void activateNextStep(Document doc) {
    List<ApprovalLineStep> steps = doc.getApprovalLine();
    // WAITING → APPROVED 처리 후
    // 다음 PENDING 단계를 WAITING으로 변경
    steps.stream()
        .filter(s -> s.getStatus() == StepStatus.PENDING)
        .findFirst()
        .ifPresent(next -> {
            next.setStatus(StepStatus.WAITING);
            notificationService.notifyApprover(next.getApproverId(), doc);
        });

    // 더 이상 PENDING 단계가 없으면 → 문서 상태를 APPROVED로
    boolean allDone = steps.stream()
        .noneMatch(s -> s.getStatus() == StepStatus.PENDING
                     || s.getStatus() == StepStatus.WAITING);
    if (allDone) {
        doc.setStatus(DocumentStatus.APPROVED);
        doc.setDocumentNumber(generateDocumentNumber(doc));
        archiveService.archive(doc);
    }
}
```

---

## 📗 4. ERD 설계 포인트

---

### 📌 핵심 테이블 구조

```sql
-- 결재 문서
CREATE TABLE approval_document (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    form_id       BIGINT NOT NULL,            -- 결재 양식 FK
    title         VARCHAR(255) NOT NULL,
    content       TEXT,                        -- JSON 또는 HTML
    status        VARCHAR(30) NOT NULL,        -- DocumentStatus
    drafter_id    BIGINT NOT NULL,             -- 기안자
    submitted_at  DATETIME,
    completed_at  DATETIME,
    doc_number    VARCHAR(100),               -- 최종결재 시 채번
    is_urgent     BOOLEAN DEFAULT FALSE,
    is_public     BOOLEAN DEFAULT TRUE,
    retention_days INT,
    created_at    DATETIME NOT NULL,
    updated_at    DATETIME NOT NULL
);

-- 결재선 단계
CREATE TABLE approval_line_step (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    document_id   BIGINT NOT NULL,
    step_order    INT NOT NULL,               -- 순서 (1부터)
    step_type     VARCHAR(30) NOT NULL,       -- ApprovalStepType
    approver_id   BIGINT,                     -- NULL이면 부서 단위
    dept_id       BIGINT,
    status        VARCHAR(30) NOT NULL,       -- StepStatus
    action        VARCHAR(30),               -- 실제 수행한 액션
    comment       TEXT,
    processed_at  DATETIME,
    delegate_from BIGINT,                     -- 대결인 경우 원 결재자 ID
    agree_policy  VARCHAR(20),               -- SEQUENTIAL / PARALLEL (합의용)
    UNIQUE (document_id, step_order)
);

-- 결재 이력 (감사 로그)
CREATE TABLE approval_history (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    document_id   BIGINT NOT NULL,
    step_id       BIGINT,
    actor_id      BIGINT NOT NULL,
    action        VARCHAR(30) NOT NULL,       -- ApprovalAction
    comment       TEXT,
    created_at    DATETIME NOT NULL
);

-- 참조자 / 열람자
CREATE TABLE approval_viewer (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    document_id   BIGINT NOT NULL,
    viewer_id     BIGINT,
    dept_id       BIGINT,
    viewer_type   VARCHAR(20) NOT NULL,      -- REFERENCE / READ
    is_confirmed  BOOLEAN DEFAULT FALSE,
    confirmed_at  DATETIME
);

-- 대결 위임 설정
CREATE TABLE approval_delegation (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    delegator_id  BIGINT NOT NULL,            -- 원 결재자
    delegate_id   BIGINT NOT NULL,            -- 대결자
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    DATETIME NOT NULL
);
```

> 💡 `content` 컬럼에 결재 문서 본문을 저장할 때, 양식에 따라 구조가 다르면 JSON으로 저장하거나 별도 테이블로 분리한다. 양식이 단순하면 HTML blob도 실용적인 선택이다.

---

## 📗 5. 특수 결재 구현 포인트

---

### 📌 선결 / 후결 구현

선결은 내 차례가 되기 전에 먼저 결재하는 것이다. DB 설계 관점에서는 `step_order` 순서를 무시하고 먼저 처리할 수 있어야 한다.

```java
// 선결 처리 로직
public void preApprove(Long documentId, Long approverId, String comment) {
    ApprovalLineStep myStep = findMyStep(documentId, approverId);

    // 내 차례가 아닌(PENDING) 경우에만 선결 가능
    if (myStep.getStatus() != StepStatus.PENDING) {
        throw new IllegalStateException("선결 불가: 이미 처리된 단계이거나 WAITING 상태");
    }
    if (myStep.getStepType() != ApprovalStepType.APPROVE) {
        throw new IllegalStateException("APPROVE 타입만 선결 가능");
    }

    myStep.setStatus(StepStatus.PRE_APPROVED);
    myStep.setComment(comment);
    myStep.setProcessedAt(LocalDateTime.now());

    // 선결로 최종 결재자가 처리한 경우 → 문서 완료 처리
    if (isLastStep(myStep)) {
        completeDocument(documentId);
    }

    // 후결 대기: 내 앞 단계들은 POST_APPROVE를 기다림
    // → 앞 단계 처리자에게 후결 요청 알림
}
```

**후결**: 선결로 완료된 문서에서 원래 순서의 결재자가 서명하는 것. 반려 불가.

```java
public void postApprove(Long documentId, Long approverId) {
    ApprovalLineStep myStep = findMyStep(documentId, approverId);
    // 문서가 이미 APPROVED 상태 → 반려 불가, 서명만 가능
    myStep.setStatus(StepStatus.POST_APPROVED);
    myStep.setProcessedAt(LocalDateTime.now());
}
```

### 📌 전결 구현

전결은 중간 결재자가 이후 단계를 건너뛰고 결재를 완료하는 것이다.

```java
public void finalApprove(Long documentId, Long approverId, String comment) {
    ApprovalLineStep myStep = findMyStep(documentId, approverId);

    // 최종결재자는 전결 불가 (이미 마지막)
    if (isLastStep(myStep)) {
        throw new IllegalStateException("최종 결재자는 전결 불가");
    }

    myStep.setStatus(StepStatus.APPROVED);
    myStep.setAction("FINAL_APPROVE");
    myStep.setComment(comment);

    // 이후 단계 전부 SKIPPED 처리
    List<ApprovalLineStep> laterSteps = getLaterSteps(documentId, myStep.getStepOrder());
    laterSteps.forEach(s -> s.setStatus(StepStatus.SKIPPED));

    // 문서 완료
    completeDocument(documentId);
}
```

### 📌 대결 구현

대결은 부재 시 결재 권한을 위임하는 것이다. 실제 결재는 대결자가 하지만, 원 결재자는 나중에 후열(열람)을 할 수 있다.

```java
// 결재 대기 문서 조회 시 대결 포함 로직
public List<Document> getMyPendingDocuments(Long userId) {
    // 내가 직접 결재자인 문서
    List<Document> directDocs = approvalLineRepo.findByApproverIdAndStatus(userId, StepStatus.WAITING);

    // 내가 대결자로 위임받은 문서
    List<ApprovalDelegation> delegations = delegationRepo.findActiveByDelegateId(userId);
    List<Long> delegatorIds = delegations.stream()
        .map(ApprovalDelegation::getDelegatorId).collect(toList());
    List<Document> delegatedDocs = approvalLineRepo.findByApproverIdsAndStatus(delegatorIds, StepStatus.WAITING);

    return merge(directDocs, delegatedDocs);
}

// 대결 처리 후 결재선에 기록
public void delegateApprove(Long documentId, Long delegateId, Long originalApproverId, String comment) {
    ApprovalLineStep step = findStepByApprover(documentId, originalApproverId);
    step.setStatus(StepStatus.APPROVED);
    step.setDelegateFrom(originalApproverId); // 원 결재자 기록
    step.setProcessedBy(delegateId);          // 실제 처리자
    // 후열 대기: originalApproverId에게 후열 알림
    notificationService.notifyPostView(originalApproverId, documentId);
}
```

### 📌 강제반려 구현

관리자만 가능한 예외 처리다. 이미 완료된 문서도 되돌릴 수 있다.

```java
// 관리자 권한 체크가 선행되어야 함
@PreAuthorize("hasRole('APPROVAL_ADMIN')")
public void forceReject(Long documentId, Long adminId, String reason) {
    Document doc = documentRepo.findById(documentId).orElseThrow();

    // 사유 필수
    if (!StringUtils.hasText(reason)) {
        throw new IllegalArgumentException("강제반려 사유는 필수입니다.");
    }

    doc.setStatus(DocumentStatus.REJECTED);

    // 이력 기록
    ApprovalHistory history = ApprovalHistory.builder()
        .documentId(documentId)
        .actorId(adminId)
        .action("FORCE_REJECT")
        .comment(reason)
        .createdAt(LocalDateTime.now())
        .build();
    historyRepo.save(history);

    // 기안자에게 재기안 알림
    notificationService.notifyForceReject(doc.getDrafterId(), documentId, reason);
}
```

---

## 📗 6. 문서번호 채번 설계

---

최종 결재가 완료되는 시점에 문서번호를 자동 생성해야 한다. 동시성 문제가 발생할 수 있는 지점이다.

### 📌 채번 전략

**방법 1: DB 시퀀스 + 형식 조합**

```sql
-- 연도별 시퀀스 테이블
CREATE TABLE doc_number_seq (
    form_id   BIGINT NOT NULL,
    year      CHAR(4) NOT NULL,
    seq       BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (form_id, year)
);
```

```java
// 락을 걸고 채번
@Transactional
public String generateDocumentNumber(Long formId, String formCode) {
    String year = String.valueOf(LocalDate.now().getYear());

    // SELECT ... FOR UPDATE로 동시성 제어
    DocNumberSeq seq = seqRepo.findByFormIdAndYearForUpdate(formId, year)
        .orElseGet(() -> seqRepo.save(new DocNumberSeq(formId, year, 0L)));

    seq.setSeq(seq.getSeq() + 1);
    seqRepo.save(seq);

    // 형식: [양식코드]-[년도]-[5자리 순번]
    return String.format("%s-%s-%05d", formCode, year, seq.getSeq());
}
```

**방법 2: Redis INCR + 형식 조합** (분산환경에서 더 적합)

```java
public String generateDocumentNumber(String formCode) {
    String key = "doc:seq:" + formCode + ":" + LocalDate.now().getYear();
    Long seq = redisTemplate.opsForValue().increment(key);
    return String.format("%s-%s-%05d", formCode, LocalDate.now().getYear(), seq);
}
```

---

## 📗 7. 알림 설계 포인트

---

결재 시스템에서 알림은 단순한 부가 기능이 아니다. 결재 흐름을 이끄는 핵심 트리거다.

### 📌 알림이 발송되어야 하는 시점

| 이벤트 | 수신자 |
| --- | --- |
| 상신 완료 | 첫 번째 결재자 |
| 결재(승인) | 다음 결재자 (없으면 기안자에게 완료 알림) |
| 반려 | 기안자 |
| 합의 요청 | 합의자 전원 (병렬) 또는 첫 번째 합의자 (순차) |
| 대결 처리 | 원 결재자 (후열 요청) |
| 선결 처리 | 앞 단계 결재자들 (후결 요청) |
| 강제반려 | 기안자 |
| 참조 지정 | 참조자 |
| 댓글 등록 | 해당 문서 열람 가능한 모든 사용자 |

### 📌 알림 이벤트 처리 (이벤트 기반 분리)

Spring 환경에서는 도메인 이벤트로 알림 로직을 분리하면 결재 처리 로직이 깔끔해진다.

```java
// 결재 처리 서비스
@Transactional
public void approve(Long documentId, Long approverId, String comment) {
    // ... 결재 처리 로직 ...

    // 이벤트 발행 (알림 로직 분리)
    applicationEventPublisher.publishEvent(
        new ApprovalProcessedEvent(documentId, approverId, "APPROVED", nextApproverId)
    );
}

// 알림 처리 이벤트 리스너
@EventListener
@Async
public void onApprovalProcessed(ApprovalProcessedEvent event) {
    if (event.getNextApproverId() != null) {
        notificationService.send(event.getNextApproverId(),
            NotificationType.APPROVAL_REQUESTED, event.getDocumentId());
    } else {
        // 최종 완료 → 기안자에게 완료 알림
        notificationService.send(drafterOf(event.getDocumentId()),
            NotificationType.APPROVAL_COMPLETED, event.getDocumentId());
    }
}
```

---

## 📗 8. 문서함(Archive) 설계

---

결재가 완료된 문서는 자동으로 문서함에 보관된다. 문서함은 크게 개인과 부서로 나뉜다.

### 📌 문서함 종류 및 구현 방식

| 문서함 | 조회 기준 | 비고 |
| --- | --- | --- |
| 기안 문서함 | `drafter_id = me` | 전체 상태 포함 |
| 임시 저장함 | `drafter_id = me AND status = DRAFT/CANCELLED` | |
| 결재 문서함 | `approver_id = me` (결재선 기준) | 진행/완료 탭 분리 |
| 참조/열람 문서함 | `approval_viewer.viewer_id = me` | |
| 수신 문서함 | `approval_line_step.approver_id = me AND type = RECEIVE` | |
| 부서 문서함 | `drafter의 dept_id = 내 dept_id` | 공개여부 필터 필요 |

문서함은 별도 `archive` 테이블 없이 기존 document + approval_line을 조인해서 뷰처럼 사용해도 되지만, 검색 성능을 위해 `archive` 테이블을 따로 두고 결재 완료 시 insert하는 방식을 많이 사용한다.

### 📌 공개 여부 처리

부서 문서함 조회 시 `is_public` 필드에 따라 접근을 제한해야 한다.

```java
// 부서 문서함 조회
public Page<Document> getDeptDocuments(Long deptId, Long currentUserId) {
    return documentRepo.findAll((root, query, cb) -> {
        // 공개 문서 OR 내가 결재/참조/열람자인 문서
        Predicate isPublic = cb.isTrue(root.get("isPublic"));
        Predicate isMyDoc = cb.or(
            cb.equal(root.get("drafterId"), currentUserId),
            /* 결재선 서브쿼리 */
        );
        return cb.and(
            cb.equal(root.join("drafter").get("deptId"), deptId),
            cb.or(isPublic, isMyDoc)
        );
    }, pageable);
}
```

---

## 📗 9. 정리

---

결재 시스템 구현에서 빠지기 쉬운 함정들을 정리한다.

- **상태 머신을 먼저 설계하라.** 문서 상태와 단계 상태가 명확하지 않으면 예외 케이스마다 조건문이 늘어난다.
- **결재선 순서와 현재 처리 단계 포인터를 분리하라.** `stepOrder`와 `currentActiveStep`을 혼용하면 선결/전결 같은 특수 케이스에서 복잡해진다.
- **합의 방식(병렬/순차)은 결재선 단계 레코드 구조에 영향을 준다.** 병렬합의는 같은 `stepOrder`에 여러 레코드가 생길 수 있다. 또는 별도 병렬 그룹 ID를 두는 방법도 있다.
- **강제반려와 일반 반려를 동일 로직에서 처리하지 마라.** 권한 체계와 이후 처리 방식이 다르다.
- **문서번호 채번은 트랜잭션 내 락이 필요하다.** 동시성 이슈를 초기에 설계하지 않으면 채번 중복이 발생한다.
- **알림은 도메인 로직에서 분리하라.** 이벤트 기반으로 처리해야 결재 처리 트랜잭션이 알림 실패에 영향받지 않는다.
- **대결 구현 시 원 결재자와 실제 처리자를 별도 컬럼으로 관리하라.** `processed_by`와 `approver_id`를 구분해야 결재선 표시와 후열 처리가 정확하다.

---

## 참고 자료

- 다우오피스 헬프데스크 - 전자결재 소개: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/42424955855385>
- 다우오피스 헬프데스크 - 결재처리(결재/합의/반려): <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45253223561113>
- 다우오피스 헬프데스크 - 선결/후결/전결: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45265901184281>
- 다우오피스 헬프데스크 - 대결/후열: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337105202841>
- 다우오피스 헬프데스크 - 수신/접수/반송: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337353211545>
