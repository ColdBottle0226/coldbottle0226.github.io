---
title: Flutter WebView + Nuxt3 뒤로가기 버그 트러블슈팅 - 플래그 방식의 실패와 position 비교 해결까지
date: 2026-03-10 09:00:00 +0900
categories: [Nuxt3, Flutter]
tags: [Nuxt3, Flutter, WebView, InAppWebView, Navigation, popstate, history, 뒤로가기]
---

##  1. 문제 상황

---

Flutter InAppWebView + Nuxt3 하이브리드 앱을 만들다 보면, 특정 페이지 전환을 새 WebView 탭으로 열어야 하는 요구사항이 생긴다.

예를 들어 전시 카테고리(OO-0001F)에서 상품 상세(PD-0001F)로 이동할 때, 기존 WebView를 유지하면서 새 WebView 탭으로 상품 상세를 열어야 한다. 그래야 카테고리 페이지의 스크롤 위치와 상태가 보존된다.

이번 글에서는 이 전환 규칙을 구현하면서 마주친 **뒤로가기 버그**의 원인을 분석하고, 여러 시도 끝에 최종 해결책을 찾아가는 과정을 정리한다.

### 📌 전체 구조

| 레이어 | 역할 |
|---|---|
| `middleware/navigation.global.ts` | 라우트 이동마다 from/to 규칙 매칭 → 새 탭 전환 판단 |
| `plugins/native-bridge.client.ts` | popstate 리스너 등록 + afterEach 스택 기록 |
| `composables/useNavigationStack.ts` | 스택 CRUD + 뒤로가기 핸들러 |
| `composables/useNativeBridge.ts` | Flutter callHandler / 모바일웹 분기 통신 |

---

##  2. 새 탭 전환 규칙 구현

---

`navigation.global.ts`에서 from/to 경로 조합을 보고 새 탭을 열도록 구현했다.

```typescript
const WEBVIEW_ROUTE_RULES = [
  { from: 'OO-0001F', to: 'PD-0001F' },
]

export default defineNuxtRouteMiddleware((to, from) => {
  if (!process.client) return
  if (!from?.name) return

  const { isFlutterWebView, openTab } = useNativeBridge()

  if (isFlutterWebView()) {
    const matched = WEBVIEW_ROUTE_RULES.find(
      rule =>
        from.fullPath.includes(rule.from) &&
        to.fullPath.includes(rule.to)
    )
    if (matched) {
      openTab(to.fullPath)
      return abortNavigation()
    }
  }
})
```

앞으로 가는 경우(OO → PD)는 정상적으로 새 탭이 열린다.

### 📌 문제 발생

새 WebView 탭(PD-0001F)에서 뒤로가기를 누르면 OO-0001F로 이동하는데, 이때 미들웨어가 다시 실행된다.

```
PD-0001F에서 뒤로가기
  → Vue Router: from=OO-0001F, to=PD-0001F 방향으로 미들웨어 실행
  → 규칙 매칭
  → openTab('/PD-0001F') 실행  ← 뒤로가는데 새 탭이 열리는 버그
```

> 💡 미들웨어는 from/to 경로만 보고, 이동 방향(앞으로/뒤로)을 알지 못한다. 앞으로가기(OO→PD)와 뒤로가기(PD→OO, 미들웨어에서는 from=OO to=PD로 보임) 모두 동일한 패턴으로 인식된다.

---

##  3. 1차 시도 - _isGoingBack 플래그

---

뒤로가기 여부를 플래그로 관리하는 방식을 시도했다.

```typescript
// composables/useNavigationStack.ts
let _isGoingBack = false

// 헤더 뒤로가기 버튼
const handleBack = () => {
  _isGoingBack = true
  router.back()
}

// plugins: popstate 리스너
window.addEventListener('popstate', () => {
  _isGoingBack = true
  onBrowserBack()
})

// middleware
if (isGoingBack()) return  // 플래그 true면 차단
```

헤더 버튼 뒤로가기는 정상 동작했다. 하지만 **Android/iOS 브라우저 하단 버튼, 네이티브 뒤로가기 버튼**에서 여전히 새 탭이 열렸다.

### 📌 실패 원인: 이벤트 실행 순서

Vue Router는 앱 초기화 시 popstate 리스너를 먼저 등록한다. Plugin은 그 이후에 등록되므로 다음 순서로 실행된다.

```
브라우저/네이티브 뒤로가기
        ↓
popstate 발생
        ↓
① Vue Router 내부 popstate 핸들러 (앱 초기화 시 먼저 등록)
   → 미들웨어 실행
   → isGoingBack() === false  ← 아직 플래그 미설정!
   → 규칙 매칭 → openTab() 실행  ← 버그
        ↓
② Plugin popstate 핸들러 (나중에 등록)
   → _isGoingBack = true  ← 이미 늦음
```

popstate보다 먼저 실행되는 표준 DOM 이벤트는 존재하지 않는다.

- `beforeunload`: full page navigation에서만 발생, SPA `history.back()`에서는 미발생
  - 참고: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
- `pagehide`: 동일하게 full page navigation 전용
  - 참고: https://developer.mozilla.org/en-US/docs/Web/API/Window/pagehide_event

---

##  4. 2차 시도 - capture: true

---

DOM 이벤트는 캡처 단계(부모→자식)가 버블 단계(자식→부모)보다 먼저 실행된다. `capture: true`로 등록하면 Vue Router의 일반 리스너보다 먼저 실행될 수 있다.

```typescript
window.addEventListener('popstate', () => {
  _isGoingBack = true
  onBrowserBack()
}, { capture: true })  // capture: true 추가
```

일반 브라우저 환경에서는 효과가 있었지만, **Samsung Internet과 Chrome 모바일에서는 여전히 새 탭이 열렸다**.

### 📌 실패 원인

`capture: true`는 같은 이벤트에 대해 나중에 등록된 리스너를 앞으로 당겨주지 않는다. Vue Router가 앱 초기화 시 이미 `capture: true`로 등록했거나, 브라우저 구현에 따라 순서 보장이 달라질 수 있다.

플래그 방식은 근본적으로 타이밍에 의존하기 때문에 어떤 방식으로도 완전히 신뢰할 수 없다.

---

##  5. 최종 해결 - history.state.position 비교

---

플래그에 의존하지 않고, **미들웨어 실행 시점에 이미 확정된 값**을 읽는 방식으로 전환했다.

### 📌 핵심 원리

W3C 스펙에 따르면, 뒤로가기 발생 시 브라우저는 **모든 JS 실행 전에** `history.state`를 목적지 entry 상태로 복원한다.

- 참고: https://html.spec.whatwg.org/multipage/browsing-the-web.html#popstate-event

Vue Router 4는 `pushState/replaceState` 시 `history.state.position`을 증가시키며 저장한다.

- 참고: https://github.com/vuejs/router/blob/main/packages/router/src/history/html5.ts

```
앞으로가기 (OO → PD):
  router.push('/PD') → history.state.position 증가 (예: 1 → 2)

뒤로가기 (PD → OO):
  history.back() → 브라우저가 OO entry state로 복원
  → history.state.position = 1 (이전 entry 값, 즉시 복원)

미들웨어 실행 시점:
  window.history.state.position = 1  (목적지, 이미 복원됨)
  sessionStorage 저장값 = 2           (직전 afterEach에서 저장한 현재값)
  1 < 2 → 뒤로가기 ✓
```

이 비교는 타이밍 의존 없이 미들웨어가 실행되는 순간 이미 확정된 값을 읽는 것이다.

### 📌 구현

**position 저장 - `plugins/native-bridge.client.ts`**

```typescript
router.afterEach((to, from, failure) => {
  if (failure) return
  if (!from?.name) return
  if (from.fullPath === to.fullPath) return

  // 네비게이션 완료 후 현재 entry의 position을 저장
  // 다음 이동 시 미들웨어에서 이 값과 목적지 position을 비교
  try {
    const pos = window.history.state?.position ?? 0
    window.sessionStorage.setItem('__wv_nav_pos__', String(pos))
  } catch {}

  recordNavigation(from.fullPath)
})
```

**방향 판별 - `composables/useNavigationStack.ts`**

```typescript
export const isBackNavigation = (): boolean => {
  if (typeof window === 'undefined') return false
  try {
    const currentPosition = window.history.state?.position ?? 0
    const storedPosition = Number(
      window.sessionStorage.getItem('__wv_nav_pos__') ?? -1
    )
    if (storedPosition === -1) return false  // 첫 진입

    return currentPosition < storedPosition
  } catch { return false }
}
```

**미들웨어 적용 - `middleware/navigation.global.ts`**

```typescript
export default defineNuxtRouteMiddleware((to, from) => {
  if (!process.client) return
  if (!from?.name) return

  const { isFlutterWebView, openTab } = useNativeBridge()

  if (isFlutterWebView()) {
    // 헤더 버튼 / 브라우저 버튼 / 네이티브 버튼 모두 이 단일 경로로 처리
    if (isBackNavigation()) return

    const matched = WEBVIEW_ROUTE_RULES.find(
      rule =>
        from.fullPath.includes(rule.from) &&
        to.fullPath.includes(rule.to)
    )
    if (matched) {
      openTab(to.fullPath)
      return abortNavigation()
    }
  }
})
```

**스택 조작 일원화 - `recordNavigation`**

```typescript
// _isGoingBack 플래그 제거 후 afterEach에서 방향 판별하여 push/pop 결정
const recordNavigation = (fromPath: string): void => {
  if (isBackNavigation()) {
    popStack()
  } else {
    pushStack(fromPath)
  }
  savePosition()  // 다음 이동의 기준값 저장
}
```

> 💡 `_isGoingBack` 플래그를 완전히 제거하고, 모든 방향 판별을 `isBackNavigation()` 단일 함수로 일원화했다. 헤더 버튼, 브라우저 버튼, 네이티브 버튼 구분 없이 동일하게 동작한다.

---

##  6. 전체 흐름 정리

---

```
━━━ 앞으로가기 (OO-0001F → PD-0001F) ━━━━━━━━━━━━━━

router.push('/PD-0001F')
  afterEach: position 저장 (stored=2), pushStack('/OO-0001F')

━━━ 뒤로가기 (모든 케이스) ━━━━━━━━━━━━━━━━━━━━━━━━━

popstate 발생 (또는 헤더 버튼 router.back())
  브라우저: history.state.position = 1 (즉시 복원)

  미들웨어 실행
    isBackNavigation(): current(1) < stored(2) → true
    → return (차단) ✓ 새 탭 안 열림

  afterEach
    isBackNavigation(): current(1) < stored(2) → true
    → popStack()
    → savePosition() (stored=1)

━━━ 케이스별 적용 여부 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

헤더 뒤로가기 버튼              → router.back() → position 감소 ✓
Android 브라우저 하단 버튼      → history.back() → position 감소 ✓
Android 네이티브 뒤로가기 버튼  → Flutter → history.back() → position 감소 ✓
iOS Safari 엣지 스와이프 (SPA)  → same-document traversal → position 감소 ✓
iOS BFCache 복원               → popstate 미발생, sessionStorage 자동 복원 ✓
```

---

##  7. 정리

---

- 플래그 방식은 popstate 리스너와 Vue Router의 이벤트 등록 순서에 의존하므로 브라우저 구현에 따라 실패한다
- `capture: true`도 Vue Router의 등록 방식과 브라우저 구현에 따라 순서 보장이 안 된다
- `history.state.position`은 W3C 스펙상 popstate 이전에 브라우저가 복원하므로 미들웨어 실행 시점에 항상 목적지 값이 확정되어 있다
- `afterEach`에서 position을 저장하고, 미들웨어에서 비교하는 구조로 타이밍 이슈 없이 뒤로가기 방향을 판별할 수 있다

---

## 참고 자료

- W3C History spec - popstate event: https://html.spec.whatwg.org/multipage/browsing-the-web.html#popstate-event
- Vue Router 4 - html5 history 구현: https://github.com/vuejs/router/blob/main/packages/router/src/history/html5.ts
- MDN - popstate event: https://developer.mozilla.org/en-US/docs/Web/API/Window/popstate_event
- MDN - addEventListener capture: https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener#capture
- MDN - beforeunload event: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
- MDN - window.history.state: https://developer.mozilla.org/en-US/docs/Web/API/History/state
