---
title: Nuxt3 컴포저블 / 전역 미들웨어 / router.afterEach 패턴 정리
date: 2026-03-10 09:30:00 +0900
categories: [Nuxt3]
tags: [Nuxt3, Composable, Middleware, afterEach, Vue Router, sessionStorage, abortNavigation]
---

## 📗 1. 개요

---

Nuxt3에서 네비게이션 제어 코드를 작성하다 보면 어디에 어떤 로직을 넣어야 하는지 헷갈린다. 컴포저블, 전역 미들웨어, router.afterEach는 각각 실행 시점과 역할이 다르기 때문에 잘못 배치하면 sessionStorage 쓰기 타이밍 오류나 리스너 중복 등록 같은 버그가 생긴다.

이번 글에서는 세 가지의 개념과 실행 순서를 정리하고, 네비게이션 스택 관리에 어떻게 적용했는지 설명한다.

### 📌 역할 분리 요약

| 레이어 | 파일 | 실행 시점 | 주요 역할 |
|---|---|---|---|
| 컴포저블 | `composables/*.ts` | 호출하는 곳의 컨텍스트 | 재사용 가능한 로직, 상태 관리 |
| 전역 미들웨어 | `middleware/*.global.ts` | 매 라우트 이동 전 | 이동 허용/차단/리다이렉트 판단 |
| Plugin (afterEach) | `plugins/*.client.ts` | 라우트 이동 완료 후 | 부수효과 (스택 기록, position 저장) |

---

## 📗 2. 컴포저블 (Composable)

---

컴포저블은 `use`로 시작하는 함수로, Vue의 Composition API를 활용한 재사용 가능한 로직 단위다.

Nuxt3는 `composables/` 디렉토리 내의 `use`로 시작하는 함수를 자동으로 import 해준다.

- 참고: https://nuxt.com/docs/guide/directory-structure/composables

### 📌 auto-import 규칙

```
composables/useNativeBridge.ts
  → export const useNativeBridge = () => { ... }
  → 어디서든 import 없이 useNativeBridge() 호출 가능

composables/useNavigationStack.ts
  → export const useNavigationStack = () => { ... }
  → 어디서든 import 없이 useNavigationStack() 호출 가능
```

단, `use`로 시작하지 않는 standalone export 함수는 auto-import 대상이 아니다.

```typescript
// 이건 auto-import 안됨
export const isBackNavigation = () => { ... }

// 미들웨어에서 사용하려면 useNavigationStack() return에 포함해야 함
export const useNavigationStack = () => {
  const isBackNavigation = () => { ... }
  return { isBackNavigation }
}
```

### 📌 모듈 레벨 vs 함수 레벨 선언

컴포저블 안에서 `useRouter()`, `useRuntimeConfig()` 같은 Nuxt composable은 반드시 **함수 내부에서** 호출해야 한다.

```typescript
// 잘못된 예 - 모듈 최상단에서 호출하면 "Nuxt instance unavailable" 오류
const router = useRouter()

export const useNavigationStack = () => {
  // 올바른 예 - 함수 내부에서 호출
  const router = useRouter()
}
```

- 참고: https://nuxt.com/docs/guide/concepts/composables#usage

### 📌 모듈 레벨 변수 활용

컴포저블 함수 바깥(모듈 레벨)에 선언한 변수는 앱 생명주기 동안 단일 인스턴스로 유지된다. 여러 컴포넌트에서 컴포저블을 호출해도 같은 변수를 참조한다.

```typescript
// 모듈 레벨 - sessionStorage 키 상수, 순수 함수
const STACK_KEY = '__wv_nav_stack__'

const getStack = (): string[] => { ... }
const pushStack = (path: string): void => { ... }
const popStack = (): string | undefined => { ... }

// 컴포저블 함수
export const useNavigationStack = () => {
  // 이 안에서 getStack, pushStack, popStack을 사용
}
```

---

## 📗 3. 전역 미들웨어 (Global Middleware)

---

`middleware/` 디렉토리에 `.global.ts`로 끝나는 파일을 두면 모든 라우트 이동마다 자동으로 실행된다.

- 참고: https://nuxt.com/docs/guide/directory-structure/middleware#global-middleware

### 📌 실행 시점

미들웨어는 **네비게이션이 확정되기 전**에 실행된다. 이 시점에 라우터 이동을 허용하거나 차단하거나 리다이렉트할 수 있다.

```
사용자가 /a → /b 이동
        ↓
전역 미들웨어 실행  ← 이동 확정 전
  → return          : 이동 허용
  → abortNavigation(): 이동 차단 (from 페이지 유지)
  → navigateTo('/c') : 다른 경로로 리다이렉트
        ↓
이동 확정
        ↓
router.afterEach 실행  ← 이동 완료 후
```

### 📌 가드 패턴

SSR에서 window에 접근하거나 최초 진입/새로고침 시 from이 undefined인 케이스를 가드해야 한다.

```typescript
export default defineNuxtRouteMiddleware((to, from) => {
  // SSR에서 window 접근 방지
  if (!process.client) return

  // 새로고침 / 최초 진입: from이 undefined
  if (!from?.fullPath) return

  // 하이드레이션 가상 이동: from.name이 없음
  // 참고: https://github.com/nuxt/nuxt/issues/14736
  if (!from.name) return

  // 동일 경로 이동
  if (from.fullPath === to.fullPath) return

  // 실제 로직
})
```

### 📌 abortNavigation과 afterEach failure

`abortNavigation()`으로 이동을 차단하면 `router.afterEach`의 세 번째 파라미터 `failure`에 값이 들어온다.

```typescript
router.afterEach((to, from, failure) => {
  if (failure) return  // abort/cancel/duplicate 모두 제외

  // failure 코드
  // aborted(4)    : abortNavigation() 호출 시
  // cancelled(8)  : 이동 중 새 이동으로 취소
  // duplicated(16): 동일 경로 이동
})
```

- 참고: https://router.vuejs.org/guide/advanced/navigation-failures.html

### 📌 defineNuxtRouteMiddleware 내부에서 composable 호출

미들웨어의 콜백 내부는 Nuxt 컨텍스트 안이므로 composable을 안전하게 호출할 수 있다.

```typescript
export default defineNuxtRouteMiddleware((to, from) => {
  // 안전하게 호출 가능
  const { isFlutterWebView, openTab } = useNativeBridge()
  const { isBackNavigation } = useNavigationStack()
})
```

- 참고: https://nuxt.com/docs/guide/directory-structure/middleware#when-middleware-runs

---

## 📗 4. Plugin과 router.afterEach

---

Nuxt Plugin은 앱 초기화 시 **단 한 번** 실행된다. `.client.ts`로 끝나는 파일은 클라이언트에서만 실행된다.

- 참고: https://nuxt.com/docs/guide/directory-structure/plugins#client-plugins

### 📌 Plugin에서 DOM 이벤트 리스너를 등록하는 이유

미들웨어는 라우트 변경마다 실행되는 **함수**이므로, 여기서 `window.addEventListener`를 호출하면 라우트가 바뀔 때마다 리스너가 중복 등록된다.

```typescript
// 잘못된 예 - 미들웨어에서 리스너 등록
export default defineNuxtRouteMiddleware(() => {
  window.addEventListener('popstate', handler)  // 라우트마다 중복 등록!
})

// 올바른 예 - Plugin에서 리스너 등록 (앱 초기화 시 1회만)
export default defineNuxtPlugin(() => {
  window.addEventListener('popstate', handler)  // 1회만 등록 ✓
})
```

### 📌 beforeEach가 아닌 afterEach를 쓰는 이유

스택 기록과 position 저장은 네비게이션이 완전히 확정된 후에 해야 한다.

| 구분 | beforeEach (미들웨어) | afterEach |
|---|---|---|
| 실행 시점 | 네비게이션 확정 전 | 네비게이션 완전 완료 후 |
| sessionStorage 쓰기 | 불안정 (이동이 취소될 수 있음) | 안정 |
| 이동 제어 | return / abortNavigation / navigateTo | 불가 (이미 이동 완료) |
| 부수효과 (스택, 로그) | 부적합 | 적합 |

```typescript
const router = useRouter()

router.afterEach((to, from, failure) => {
  if (failure) return          // 취소/중단된 이동 제외
  if (!from?.name) return      // 새로고침/하이드레이션 제외
  if (from.fullPath === to.fullPath) return

  // 이 시점은 네비게이션 완료 후 → sessionStorage 안전하게 쓰기 가능
  recordNavigation(from.fullPath)
})
```

### 📌 새로고침 시 스택 유지

`from.name`이 없으면 새로고침 또는 하이드레이션 가상 이동이다. 이 케이스에서 `recordNavigation`을 호출하면 스택이 초기화되는 버그가 생긴다.

```typescript
// afterEach에서 from.name 가드
if (!from?.name) return  // 새로고침 시 스택/position 그대로 유지

// sessionStorage는 탭이 살아있는 동안 유지되므로
// 새로고침 후에도 이전 스택이 그대로 남아있음
```

---

## 📗 5. sessionStorage 선택 이유

---

네비게이션 스택을 어디에 저장할지 선택지를 비교했다.

| 저장소 | 특징 | 적합성 |
|---|---|---|
| Pinia / useState | 앱 전역 공유 | 부적합 (WebView 탭 간 공유됨) |
| localStorage | 탭 간, 세션 간 공유 | 부적합 (다른 탭과 공유됨) |
| sessionStorage | 탭(브라우징 컨텍스트)마다 독립 격리 | 적합 |

`window.open(..., 'noopener')`로 열거나 Flutter `openTab()`으로 새 WebView를 열면 독립된 브라우징 컨텍스트가 생성되고, sessionStorage는 완전히 격리된 빈 상태로 시작된다.

- 참고: https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage

---

## 📗 6. 정리

---

- 컴포저블은 `use`로 시작해야 Nuxt auto-import 대상이 된다. Nuxt composable은 반드시 함수 내부에서 호출한다
- 전역 미들웨어는 이동 전에 실행되므로 허용/차단 판단에 적합하고, sessionStorage 쓰기에는 부적합하다
- DOM 이벤트 리스너는 Plugin에서 단 한 번 등록한다. 미들웨어에서 등록하면 중복된다


---

## 참고 자료

- Nuxt3 공식 - Composables: https://nuxt.com/docs/guide/directory-structure/composables
- Nuxt3 공식 - Middleware: https://nuxt.com/docs/guide/directory-structure/middleware
- Nuxt3 공식 - Plugins: https://nuxt.com/docs/guide/directory-structure/plugins
- Vue Router - Navigation Failures: https://router.vuejs.org/guide/advanced/navigation-failures.html
- Nuxt3 공식 - abortNavigation: https://nuxt.com/docs/api/utils/abort-navigation
- MDN - sessionStorage: https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage
- GitHub Nuxt issue - from.name 가드: https://github.com/nuxt/nuxt/issues/14736
