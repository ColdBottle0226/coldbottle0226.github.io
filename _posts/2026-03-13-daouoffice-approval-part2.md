---
title: 다우오피스 전자결재 업무 정리 - Part 2. 결재 유형 완전 정복
date: 2026-03-13 10:10:00 +0900
categories: [Groupware, 전자결재]
tags: [다우오피스, 전자결재, 결재유형, 합의, 확인, 감사, 선결, 후결, 전결, 대결, 후열]
---

## 📗 1. 개요

---

전자결재에서 가장 헷갈리는 부분이 결재 유형이다. 겉으로 보면 비슷해 보이는 용어들—확인과 감사, 선결과 전결, 대결과 후열—이 실제로는 명확하게 다른 개념이다.

이번 글에서는 결재 유형 하나하나를 정확하게 짚어가며 언제, 왜 사용하는지까지 함께 정리한다.

### 📌 결재 유형 전체 한눈에 보기

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 900 500" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:900px;font-family:sans-serif;">
  <rect width="900" height="500" fill="#f8f9fa" rx="12"/>
  <text x="450" y="30" text-anchor="middle" font-size="15" font-weight="bold" fill="#1a1a2e">전자결재 유형 분류</text>

  <!-- 그룹 1: 기본 결재 -->
  <rect x="20" y="50" width="420" height="200" rx="8" fill="#4361ee" opacity="0.06" stroke="#4361ee" stroke-width="1.5"/>
  <text x="34" y="70" font-size="11" font-weight="bold" fill="#4361ee">🔷 기본 결재 그룹</text>

  <rect x="30" y="80" width="120" height="155" rx="6" fill="#4361ee" opacity="0.12"/>
  <rect x="30" y="80" width="120" height="7" rx="3" fill="#4361ee"/>
  <text x="90" y="100" text-anchor="middle" font-size="11" fill="#4361ee" font-weight="bold">결재</text>
  <text x="90" y="116" text-anchor="middle" font-size="9" fill="#333">승인 또는 반려</text>
  <text x="90" y="130" text-anchor="middle" font-size="9" fill="#555">결재선 노출 O</text>
  <text x="90" y="144" text-anchor="middle" font-size="9" fill="#555">전결 옵션 가능</text>
  <text x="90" y="158" text-anchor="middle" font-size="9" fill="#555">선결 가능</text>
  <text x="90" y="172" text-anchor="middle" font-size="9" fill="#555">보류 가능</text>
  <text x="90" y="188" text-anchor="middle" font-size="9" fill="#555">반려 시 기안자 반환</text>
  <text x="90" y="225" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 핵심 결재 유형</text>

  <rect x="165" y="80" width="120" height="155" rx="6" fill="#06d6a0" opacity="0.12"/>
  <rect x="165" y="80" width="120" height="7" rx="3" fill="#06d6a0"/>
  <text x="225" y="100" text-anchor="middle" font-size="11" fill="#16825e" font-weight="bold">확인</text>
  <text x="225" y="116" text-anchor="middle" font-size="9" fill="#333">승인 또는 반려</text>
  <text x="225" y="130" text-anchor="middle" font-size="9" fill="#ef233c">결재선 노출 X</text>
  <text x="225" y="144" text-anchor="middle" font-size="9" fill="#555">이력에만 기록됨</text>
  <text x="225" y="158" text-anchor="middle" font-size="9" fill="#555">결재란에 미표시</text>
  <text x="225" y="172" text-anchor="middle" font-size="9" fill="#555">선결 가능 여부 설정</text>
  <text x="225" y="225" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 비공식 확인용</text>

  <rect x="300" y="80" width="130" height="155" rx="6" fill="#ef476f" opacity="0.12"/>
  <rect x="300" y="80" width="130" height="7" rx="3" fill="#ef476f"/>
  <text x="365" y="100" text-anchor="middle" font-size="11" fill="#b71c40" font-weight="bold">감사</text>
  <text x="365" y="116" text-anchor="middle" font-size="9" fill="#333">승인 가능</text>
  <text x="365" y="130" text-anchor="middle" font-size="9" fill="#ef233c">반려 기본 불가</text>
  <text x="365" y="144" text-anchor="middle" font-size="9" fill="#555">결재선 노출</text>
  <text x="365" y="158" text-anchor="middle" font-size="9" fill="#555">옵션으로 반려 활성화</text>
  <text x="365" y="172" text-anchor="middle" font-size="9" fill="#555">감사 부서 검토용</text>
  <text x="365" y="225" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 공식 감사 기록용</text>

  <!-- 그룹 2: 협조 결재 -->
  <rect x="460" y="50" width="220" height="200" rx="8" fill="#3a86ff" opacity="0.06" stroke="#3a86ff" stroke-width="1.5"/>
  <text x="474" y="70" font-size="11" font-weight="bold" fill="#3a86ff">🔷 협조 결재 그룹</text>

  <rect x="470" y="80" width="195" height="155" rx="6" fill="#3a86ff" opacity="0.12"/>
  <rect x="470" y="80" width="195" height="7" rx="3" fill="#3a86ff"/>
  <text x="567" y="100" text-anchor="middle" font-size="11" fill="#3a86ff" font-weight="bold">합의</text>
  <text x="567" y="116" text-anchor="middle" font-size="9" fill="#333">합의 또는 반대</text>
  <text x="567" y="130" text-anchor="middle" font-size="9" fill="#555">결재선 노출 </text>
  <text x="567" y="144" text-anchor="middle" font-size="9" fill="#555">반대해도 결재 진행(기본)</text>
  <text x="567" y="158" text-anchor="middle" font-size="9" fill="#555">병렬합의: 동시 처리</text>
  <text x="567" y="172" text-anchor="middle" font-size="9" fill="#555">순차합의: 순서대로 처리</text>
  <text x="567" y="186" text-anchor="middle" font-size="9" fill="#555">부서 단위 지정 가능</text>
  <text x="567" y="225" text-anchor="middle" font-size="9" fill="#888" font-style="italic">✦ 타 부서 협조 의사 확인</text>

  <!-- 그룹 3: 위임/간소화 결재 -->
  <rect x="700" y="50" width="185" height="200" rx="8" fill="#7209b7" opacity="0.06" stroke="#7209b7" stroke-width="1.5"/>
  <text x="714" y="70" font-size="11" font-weight="bold" fill="#7209b7">🔷 위임 / 간소화 그룹</text>

  <rect x="710" y="80" width="165" height="68" rx="6" fill="#7209b7" opacity="0.12"/>
  <rect x="710" y="80" width="165" height="7" rx="3" fill="#7209b7"/>
  <text x="792" y="100" text-anchor="middle" font-size="11" fill="#5b2a9e" font-weight="bold">전결</text>
  <text x="792" y="116" text-anchor="middle" font-size="9" fill="#333">중간 결재자가 완료 처리</text>
  <text x="792" y="130" text-anchor="middle" font-size="9" fill="#555">이후 결재자 SKIP</text>
  <text x="792" y="144" text-anchor="middle" font-size="9" fill="#555">양식별 허용 여부 설정</text>

  <rect x="710" y="162" width="165" height="78" rx="6" fill="#f77f00" opacity="0.12"/>
  <rect x="710" y="162" width="165" height="7" rx="3" fill="#f77f00"/>
  <text x="792" y="182" text-anchor="middle" font-size="11" fill="#b35700" font-weight="bold">대결</text>
  <text x="792" y="198" text-anchor="middle" font-size="9" fill="#333">부재 시 결재권한 위임</text>
  <text x="792" y="212" text-anchor="middle" font-size="9" fill="#555">대결자가 대신 결재</text>
  <text x="792" y="226" text-anchor="middle" font-size="9" fill="#555">원 결재자는 후열 처리</text>

  <!-- 그룹 4: 선결/후결 -->
  <rect x="20" y="266" width="860" height="115" rx="8" fill="#06d6a0" opacity="0.04" stroke="#06d6a0" stroke-width="1.5"/>
  <text x="34" y="284" font-size="11" font-weight="bold" fill="#16825e">🔷 시점 조정 그룹 (결재 타입에만 적용)</text>

  <rect x="30" y="292" width="270" height="78" rx="6" fill="#06d6a0" opacity="0.12"/>
  <rect x="30" y="292" width="270" height="7" rx="3" fill="#06d6a0"/>
  <text x="165" y="312" text-anchor="middle" font-size="11" fill="#16825e" font-weight="bold">선결 (先決)</text>
  <text x="165" y="328" text-anchor="middle" font-size="9" fill="#333">내 차례 전에 미리 결재</text>
  <text x="165" y="342" text-anchor="middle" font-size="9" fill="#555">'결재 예정 문서함'에서 처리</text>
  <text x="165" y="356" text-anchor="middle" font-size="9" fill="#555">합의/확인 타입은 선결 불가</text>
  <text x="165" y="368" text-anchor="middle" font-size="9" fill="#888">→ 앞 결재자에게 후결 대기 알림</text>

  <rect x="315" y="292" width="270" height="78" rx="6" fill="#118ab2" opacity="0.12"/>
  <rect x="315" y="292" width="270" height="7" rx="3" fill="#118ab2"/>
  <text x="450" y="312" text-anchor="middle" font-size="11" fill="#0a5876" font-weight="bold">후결 (後決)</text>
  <text x="450" y="328" text-anchor="middle" font-size="9" fill="#333">선결로 완료된 문서에 나중에 서명</text>
  <text x="450" y="342" text-anchor="middle" font-size="9" fill="#555">반려 불가 (이미 결재 완료된 문서)</text>
  <text x="450" y="356" text-anchor="middle" font-size="9" fill="#555">결재 대기문서에 후결 문서로 잔류</text>
  <text x="450" y="368" text-anchor="middle" font-size="9" fill="#888">→ 이력 기록용, 문서 효력 없음</text>

  <rect x="600" y="292" width="270" height="78" rx="6" fill="#ffd166" opacity="0.5"/>
  <rect x="600" y="292" width="270" height="7" rx="3" fill="#f77f00"/>
  <text x="735" y="312" text-anchor="middle" font-size="11" fill="#b35700" font-weight="bold">후열 (後閱)</text>
  <text x="735" y="328" text-anchor="middle" font-size="9" fill="#333">대결 완료 후 원 결재자가 열람</text>
  <text x="735" y="342" text-anchor="middle" font-size="9" fill="#555">반려 불가 (이미 결재 완료된 문서)</text>
  <text x="735" y="356" text-anchor="middle" font-size="9" fill="#555">결재 대기문서에 후열 문서로 잔류</text>
  <text x="735" y="368" text-anchor="middle" font-size="9" fill="#888">→ 결재 이력에만 기록</text>

  <!-- 범례 -->
  <rect x="20" y="398" width="860" height="88" rx="8" fill="white" stroke="#dee2e6" stroke-width="1"/>
  <text x="40" y="418" font-size="11" font-weight="bold" fill="#333">⚠️ 유형 선택 시 핵심 판단 기준</text>
  <text x="40" y="436" font-size="10" fill="#555">• 결재라인에 서명란이 보여야 하는가? → 결재 / 감사 / 합의 (확인은 미노출)</text>
  <text x="40" y="452" font-size="10" fill="#555">• 타 부서 협조가 필요한가? → 합의 (병렬 vs 순차 추가 선택)</text>
  <text x="40" y="468" font-size="10" fill="#555">• 급하게 먼저 결재해야 하는가? → 선결 (단, 결재 타입만 가능)</text>
  <text x="40" y="484" font-size="10" fill="#555">• 결재자가 자리를 비웠는가? → 대결 (부재/위임 설정 필요)</text>
</svg>
</div>

---

## 📗 2. 기본 결재 그룹

---

### 📌 결재 (승인)

결재선에서 가장 기본이 되는 유형이다. 승인 또는 반려를 선택할 수 있다.

**승인 시:**
- 중간 결재자가 승인하면 다음 결재자에게 알림과 함께 문서가 전달된다.
- 최종 결재자가 승인하면 문서번호가 채번되고 결재가 완료된다.
- 선택적으로 **전결** 처리가 가능하다 (이후 결재자 건너뜀).

**반려 시:**
- 반려된 문서는 최초 기안자에게 반환된다.
- 기안자는 수정 후 재기안 상신이 가능하다.
- 옵션 설정에 따라 **전단계 반려**(기안자가 아닌 직전 결재자에게 반려)도 가능하다.

> 💡 결재 의견(코멘트) 작성은 옵션이지만, 반려 시에는 필수로 작성해야 한다.

### 📌 확인

결재와 마찬가지로 승인과 반려가 모두 가능하지만, **결재문서 본문(결재란)에 표시되지 않는다.**

- 결재 이력에만 기록되며, 공식 결재란에는 나타나지 않는다.
- 중간에 내용을 검토하되 공식 서명이 필요 없는 역할에 사용한다.

> 💡 확인과 결재의 가장 큰 차이: 결재란 노출 여부. 확인은 비공식, 결재는 공식.

### 📌 감사

주로 감사 부서나 내부 감사팀이 결재선에 포함될 때 사용하는 유형이다.

- **승인**은 가능하지만, **기본적으로 반려 기능이 비활성화**된다.
- 결재란에 정보가 노출되어 확인과 달리 공식 기록으로 남는다.
- 옵션 설정으로 반려 기능을 활성화할 수 있다.

| 구분 | 결재 | 확인 | 감사 |
| --- | --- | --- | --- |
| 승인 가능 | O | O | O |
| 반려 가능 | O | O | X (옵션으로 활성화) |
| 결재란 노출 | O | X | O |
| 이력 기록 | O | O | O |
| 선결 가능 | O | 설정에 따라 다름 | 설정에 따라 다름 |
| 전결 가능 | O | X | X |

---

## 📗 3. 합의 (협조 결재)

---

결재 문서의 내용이 타 부서와 관련 있을 때, 해당 부서의 협조 의사를 확인하는 방식이다.

**핵심 특징:**
- 합의자는 `합의` 또는 `반대` 중 하나를 선택한다.
- **반대를 해도 결재 문서는 다음 결재자에게 전달된다** (기본값).
- 관리자 설정에 따라 반대 시 결재가 중단되도록 변경할 수 있다.
- 합의자를 **부서**로 지정하면 해당 부서의 부서장에게 전달된다.

### 📌 병렬합의 vs 순차합의

합의자가 2명 이상일 때 처리 방식을 선택할 수 있다.

<div style="overflow-x: auto; margin: 1.5rem 0;">
<svg viewBox="0 0 820 240" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:820px;font-family:sans-serif;">
  <defs>
    <marker id="b1" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#3a86ff"/>
    </marker>
    <marker id="b2" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
      <path d="M0,0 L0,6 L7,3 z" fill="#4361ee"/>
    </marker>
  </defs>
  <rect width="820" height="240" fill="#f8f9fa" rx="10"/>
  <text x="410" y="25" text-anchor="middle" font-size="13" font-weight="bold" fill="#1a1a2e">합의 방식 비교</text>

  <!-- 병렬합의 -->
  <text x="20" y="50" font-size="11" font-weight="bold" fill="#3a86ff">병렬합의 (동시 전달)</text>
  <rect x="20" y="58" width="75" height="32" rx="5" fill="#4361ee" opacity="0.8"/>
  <text x="57" y="78" text-anchor="middle" font-size="10" fill="white">결재 완료</text>
  <line x1="95" y1="74" x2="110" y2="60" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <line x1="95" y1="74" x2="110" y2="74" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <line x1="95" y1="74" x2="110" y2="88" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <rect x="110" y="48" width="80" height="26" rx="5" fill="#3a86ff" opacity="0.7"/>
  <text x="150" y="65" text-anchor="middle" font-size="9" fill="white">합의자 A</text>
  <rect x="110" y="61" width="80" height="26" rx="5" fill="#3a86ff" opacity="0.55"/>
  <text x="150" y="78" text-anchor="middle" font-size="9" fill="white">합의자 B</text>
  <rect x="110" y="74" width="80" height="26" rx="5" fill="#3a86ff" opacity="0.4"/>
  <text x="150" y="91" text-anchor="middle" font-size="9" fill="white">합의자 C</text>
  <line x1="190" y1="60" x2="210" y2="74" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <line x1="190" y1="74" x2="210" y2="74" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <line x1="190" y1="87" x2="210" y2="74" stroke="#3a86ff" stroke-width="1.5" marker-end="url(#b1)"/>
  <rect x="210" y="58" width="80" height="32" rx="5" fill="#06d6a0" opacity="0.8"/>
  <text x="250" y="77" text-anchor="middle" font-size="10" fill="white">다음 결재자</text>
  <text x="155" y="118" text-anchor="middle" font-size="9" fill="#3a86ff">동시에 알림 발송 → 순서 무관 처리</text>
  <text x="155" y="132" text-anchor="middle" font-size="9" fill="#555">전원 처리 완료 시 다음 단계 진행</text>

  <!-- 구분선 -->
  <line x1="370" y1="40" x2="370" y2="200" stroke="#dee2e6" stroke-width="1.5" stroke-dasharray="4,3"/>

  <!-- 순차합의 -->
  <text x="390" y="50" font-size="11" font-weight="bold" fill="#4361ee">순차합의 (순서대로 전달)</text>
  <rect x="390" y="58" width="75" height="32" rx="5" fill="#4361ee" opacity="0.8"/>
  <text x="427" y="78" text-anchor="middle" font-size="10" fill="white">결재 완료</text>
  <line x1="465" y1="74" x2="490" y2="74" stroke="#4361ee" stroke-width="1.5" marker-end="url(#b2)"/>
  <text x="477" y="67" text-anchor="middle" font-size="8" fill="#4361ee">① 전달</text>
  <rect x="490" y="60" width="75" height="28" rx="5" fill="#4361ee" opacity="0.7"/>
  <text x="527" y="78" text-anchor="middle" font-size="9" fill="white">합의자 A</text>
  <line x1="565" y1="74" x2="590" y2="74" stroke="#4361ee" stroke-width="1.5" marker-end="url(#b2)"/>
  <text x="577" y="67" text-anchor="middle" font-size="8" fill="#4361ee">② 전달</text>
  <rect x="590" y="60" width="75" height="28" rx="5" fill="#4361ee" opacity="0.5"/>
  <text x="627" y="78" text-anchor="middle" font-size="9" fill="white">합의자 B</text>
  <line x1="665" y1="74" x2="690" y2="74" stroke="#4361ee" stroke-width="1.5" marker-end="url(#b2)"/>
  <text x="677" y="67" text-anchor="middle" font-size="8" fill="#4361ee">③ 전달</text>
  <rect x="690" y="60" width="75" height="28" rx="5" fill="#06d6a0" opacity="0.8"/>
  <text x="727" y="78" text-anchor="middle" font-size="9" fill="white">다음 결재자</text>
  <text x="590" y="118" text-anchor="middle" font-size="9" fill="#4361ee">A 처리 완료 → B에게 전달</text>
  <text x="590" y="132" text-anchor="middle" font-size="9" fill="#555">한 명씩 순서대로 처리</text>

  <!-- 비교표 -->
  <rect x="20" y="155" width="780" height="72" rx="8" fill="white" stroke="#dee2e6" stroke-width="1"/>
  <rect x="20" y="155" width="780" height="24" rx="4" fill="#3a86ff" opacity="0.1"/>
  <text x="105" y="171" text-anchor="middle" font-size="10" font-weight="bold" fill="#333">구분</text>
  <text x="330" y="171" text-anchor="middle" font-size="10" font-weight="bold" fill="#3a86ff">병렬합의</text>
  <text x="600" y="171" text-anchor="middle" font-size="10" font-weight="bold" fill="#4361ee">순차합의</text>
  <line x1="190" y1="155" x2="190" y2="227" stroke="#dee2e6" stroke-width="1"/>
  <line x1="470" y1="155" x2="470" y2="227" stroke="#dee2e6" stroke-width="1"/>
  <line x1="20" y1="179" x2="800" y2="179" stroke="#dee2e6" stroke-width="1"/>
  <text x="105" y="196" text-anchor="middle" font-size="9" fill="#555">처리 속도</text>
  <text x="330" y="196" text-anchor="middle" font-size="9" fill="#555">빠름 (동시 진행)</text>
  <text x="600" y="196" text-anchor="middle" font-size="9" fill="#555">느림 (단계별 처리)</text>
  <line x1="20" y1="203" x2="800" y2="203" stroke="#dee2e6" stroke-width="1"/>
  <text x="105" y="220" text-anchor="middle" font-size="9" fill="#555">적합한 상황</text>
  <text x="330" y="220" text-anchor="middle" font-size="9" fill="#555">빠른 협조 필요, 부서 간 독립적 검토</text>
  <text x="600" y="220" text-anchor="middle" font-size="9" fill="#555">단계별 검토 필요, 이전 의견 참고해야 할 때</text>
</svg>
</div>

---

## 📗 4. 선결 / 후결

---

### 📌 선결 (先決) — 미리 결재

결재 예정자가 자신의 결재 순서가 되기 전에 미리 결재하는 기능이다.

**사용 상황:** 급한 업무로 결재를 빨리 처리해야 하는데, 앞 순서의 결재자가 아직 결재를 안 한 경우.

**선결 절차:**
```
전자결재 홈 > [결재 예정 문서] 클릭
→ 선결재할 문서 선택
→ 문서 상세 화면 상단 [선결재] 버튼 클릭
→ 결재 의견 작성 후 [승인]
```

**선결의 제약:**
- **결재 타입**으로 지정된 결재자만 선결 가능
- 합의·확인 타입으로 지정된 결재자는 선결 진행 불가
- 최종 결재자가 선결하면 → 문서 결재 완료 처리
- 선결 후 앞 순서 결재자에게 **후결 대기** 알림이 발송됨

### 📌 후결 (後決) — 나중에 서명

선결에 의해 최종 결재가 완료된 후, 중간 결재자가 나중에 결재하는 기능이다.

**중요:** 후결은 이미 완료된 문서에 대한 서명이므로, **반려가 불가능**하다. 이력 기록 및 서명 목적으로만 사용한다.

**후결 절차:**
```
전자결재 홈 > [결재 대기 문서] (후결 문서 표시됨)
→ 후결할 문서 선택
→ [후결] 버튼 클릭
→ 결재 의견 작성 후 [확인]
```

> 💡 선결 → 후결의 관계: 급할 때 뒤 순서가 먼저 결재(선결)하고, 나중에 앞 순서가 서명(후결)하는 구조다.

---

## 📗 5. 전결

---

최종 결재자 이전 결재자가 결재 프로세스를 완료하는 기능이다.

**사용 상황:** 내부 규정에 따라 중요도가 낮은 문서를 전결권자가 최종 완료 처리하는 경우.

**전결의 특징:**
- 전결자는 자신의 결재란에 서명하고, 상급자 결재란에 전결 표시
- **전결 이후 이후 결재자들은 문서를 확인할 수 없음**
- 양식별로 전결 사용 여부를 설정해야 사용 가능

**전결 절차:**
```
결재 대기 문서 > 해당 문서 클릭
→ [결재] 버튼 클릭
→ 결재 팝업에서 [전결] 옵션 체크
→ 결재 의견 작성 후 [승인]
```

| 구분 | 전결 | 선결 |
| --- | --- | --- |
| 실행 주체 | 현재 결재자 (앞쪽) | 미래 결재자 (뒤쪽) |
| 이후 결재자 처리 | 건너뜀 (문서 접근 불가) | 후결로 나중에 서명 |
| 결재 완료 시점 | 전결 처리 즉시 | 선결 처리 즉시 |
| 양식 설정 필요 | O 필요 | 별도 설정 없음 |

---

## 📗 6. 대결 / 후열

---

### 📌 대결 (代決) — 위임 결재

파견, 병가, 장기휴가 등 결재자가 자리를 비울 때 다른 사람에게 결재 권한을 위임하는 기능이다.

**사전 설정이 필요하다:**
```
임직원 포털 > 내 정보 > [부재/위임 설정]
→ 기간 설정 + 대결자 지정
→ [저장]
```

**대결 처리:**
- 대결자는 원래 결재자와 동일한 권한으로 결재를 처리한다.
- 결재선에는 대결자의 결재 정보가 기록된다.
- 대결 처리 완료 후 원래 결재자에게 **후열 요청 알림**이 발송된다.

### 📌 후열 (後閱) — 사후 열람

대결자가 결재한 문서를 원래 결재자가 추후에 열람하는 기능이다.

- 대결 완료 문서라도 원래 결재자의 결재 대기 문서에 **후열 문서**로 남아 있다.
- 후열 이력은 문서 정보에만 표시되며, 결재란에는 대결자 정보가 기록된다.
- **대결자에 의해 이미 결재가 완료된 문서이므로 반려가 불가능하다.**

```
전자결재 홈 > [결재 대기 문서] (후열 문서 표시됨)
→ 후열할 문서 선택
→ [후열] 버튼 클릭 → 열람 확인
```

| 구분 | 대결 | 후열 |
| --- | --- | --- |
| 주체 | 대결자 (위임받은 사람) | 원 결재자 |
| 시점 | 원 결재자 부재 시 | 원 결재자 복귀 후 |
| 결재 효력 | 있음 (실제 결재) | 없음 (열람만) |
| 반려 가능 | O (대결 시) | X |

---

## 📗 7. 결재 유형 전체 비교표

---

| 유형 | 처리 선택지 | 결재란 노출 | 반려 가능 | 선결 가능 | 전결 가능 | 비고 |
| --- | --- | --- | --- | --- | --- | --- |
| 결재 | 승인 / 반려 / 보류 | O | O | O | O | 핵심 결재 |
| 확인 | 승인 / 반려 | X | O | 설정마다 다름 | X | 이력에만 기록 |
| 감사 | 승인 / (반려) | O | X (옵션 활성화 가능) | 설정마다 다름 | X | 감사 부서용 |
| 합의 | 합의 / 반대 | O | X | X | X | 타 부서 협조 |
| 전결 | 승인 (이후 단계 SKIP) | O | - | - | - | 양식 설정 필요 |
| 선결 | 승인 | O | X | - | - | 결재 타입만 가능 |
| 후결 | 서명 | O | X | - | - | 선결 후 서명 |
| 대결 | 승인 / 반려 | O (대결자로) | O | - | - | 사전 위임 설정 필요 |
| 후열 | 열람 | - | X | - | - | 대결 후 원결재자 열람 |

---

## 📗 8. 정리

---

- **결재/확인/감사**는 모두 승인 가능하지만, 결재란 노출 여부와 반려 가능 여부가 다르다.
- **합의**는 협조 의사를 묻는 것으로, 반대해도 결재가 진행되는 것이 기본이다.
- **선결**은 뒤 순서가 먼저 처리, **전결**은 앞 순서가 완료 처리—방향이 반대다.
- **대결**은 부재 시 위임 결재이며, **후열**은 복귀 후 원 결재자의 사후 열람이다.
- 합의·확인 타입은 선결이 불가능하며, 확인·감사·합의는 전결이 불가능하다.

> 📎 다음 글: [Part 3. 결재 상신 & 결재선 설정](/posts/daouoffice-approval-part3)에서 실제 결재 문서를 작성하고 상신하는 전체 절차를 다룬다.

---

## 참고 자료

- 다우오피스 헬프데스크 - 결재처리(결재/합의/반려): <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45253223561113>
- 다우오피스 헬프데스크 - 선결/후결/전결: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/45265901184281>
- 다우오피스 헬프데스크 - 대결/후열: <https://helpdesk.daouoffice.co.kr/hc/ko/articles/43337105202841>
