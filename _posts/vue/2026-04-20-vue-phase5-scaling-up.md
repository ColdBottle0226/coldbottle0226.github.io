---
title: "확장하기 SFC, 라우팅, 상태관리(Pinia), 테스트, SSR)"
date: 2026-04-20 16:00:00 +0900
categories: [Vue.js]
tags: [Vue3, SFC, VueRouter, Pinia, Vitest, SSR, 상태관리, 테스트]
---

Vue 3 공식 문서의 **확장하기(Scaling Up)** 섹션 전체를 다룬다. SFC가 왜 권장되는지부터 Vue Router로 SPA 라우팅을 구성하는 법, Pinia로 전역 상태를 관리하는 법, Vitest + Vue Test Utils로 테스트를 작성하는 법, 그리고 SSR의 원리와 주의사항까지 — 실제 앱을 만들 때 반드시 알아야 할 확장 전략을 한 번에 정리한다.

---

## 1. 개요

### 📌 이 글이 커버하는 공식 문서 페이지

| 페이지 | 핵심 내용 |
|--------|-----------|
| 싱글 파일 컴포넌트 | SFC 구조, `@vue/compiler-sfc`, 관심사 분리 철학 |
| 라우팅 | 클라이언트 사이드 라우팅, Vue Router 개요 |
| 상태 관리 | 단순 패턴 → Pinia, Vuex와 비교 |
| 테스트 | 단위/컴포넌트/E2E, Vitest, @vue/test-utils |
| SSR | SSR vs SSG, 하이드레이션, Nuxt, 요청 간 상태 오염 |

### 📌 실제 Vue 앱 구성 전체 지도

```
SFC (.vue)          → 컴포넌트 작성 단위
 ↓
Vue Router          → 페이지 간 이동 (SPA 라우팅)
 ↓
Pinia               → 컴포넌트 간 공유 상태 관리
 ↓
Vitest + Test Utils → 단위·컴포넌트 테스트
 ↓
SSR / Nuxt          → SEO·성능이 중요한 경우
```

---

## 2. 개념 설명

### 📌 싱글 파일 컴포넌트 (SFC)

**SFC란?**

`.vue` 확장자를 가진 파일로, 컴포넌트의 **템플릿(HTML) + 로직(JS) + 스타일(CSS)**을 하나에 캡슐화한다.

```vue
<script setup>
import { ref } from 'vue'
const greeting = ref('Hello World!')
</script>

<template>
  <p class="greeting">{{ greeting }}</p>
</template>

<style scoped>
.greeting {
  color: red;
  font-weight: bold;
}
</style>
```

**SFC를 써야 하는 이유**

| 이점 | 설명 |
|------|------|
| 사전 컴파일 | 런타임 컴파일 비용 없이 최적화된 코드로 변환 |
| 컴포넌트 범위 CSS | `<style scoped>`로 스타일 충돌 방지 |
| IDE 지원 | 자동완성·타입체크·HMR(핫 리로딩) |
| Composition API 편의 문법 | `<script setup>` |
| 컴파일 타임 최적화 | 템플릿과 스크립트 교차 분석 |

**동작 방식**

SFC는 `@vue/compiler-sfc`에 의해 표준 JS + CSS로 변환된다. 빌드 도구(Vite, webpack)와 통합해서 사용한다.

```js
// 컴파일된 SFC는 표준 ES 모듈
import MyComponent from './MyComponent.vue'
```

> 💡 **"관심사 분리 = 파일 분리"가 아니다.** 컴포넌트 단위로 응집도 높게 묶는 것이 현대 UI 개발의 모범 사례다. HTML/CSS/JS를 물리적으로 분리하는 것보다 논리적 단위인 컴포넌트로 분리하는 것이 유지보수에 유리하다.

---

### 📌 라우팅 — Vue Router

**클라이언트 사이드 라우팅이란?**

SPA에서는 서버가 HTML을 매번 새로 보내는 대신, 클라이언트 JS가 URL 변경을 감지하고 렌더링할 컴포넌트를 교체한다. 브라우저의 History API 또는 hashchange 이벤트를 활용한다.

**최소 구현 예시 (라이브러리 없이)**

```vue
<script setup>
import { ref, computed } from 'vue'
import Home from './Home.vue'
import About from './About.vue'
import NotFound from './NotFound.vue'

const routes = { '/': Home, '/about': About }
const currentPath = ref(window.location.hash)

window.addEventListener('hashchange', () => {
  currentPath.value = window.location.hash
})

const currentView = computed(() =>
  routes[currentPath.value.slice(1) || '/'] || NotFound
)
</script>

<template>
  <a href="#/">Home</a> | <a href="#/about">About</a>
  <component :is="currentView" />
</template>
```

**실제 앱 → Vue Router 사용 권장**

간단한 해시 라우팅 이상의 기능(중첩 라우트, 네비게이션 가드, 동적 라우트, 코드 스플리팅 등)이 필요하면 공식 라이브러리인 **Vue Router**를 사용한다.

```bash
npm install vue-router
```

```js
// router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import Home from '@/views/Home.vue'
import About from '@/views/About.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: Home },
    { path: '/about', component: About },
    // 동적 라우트
    { path: '/user/:id', component: UserDetail },
    // 404 처리
    { path: '/:pathMatch(.*)*', component: NotFound }
  ]
})

export default router
```

```js
// main.js
import { createApp } from 'vue'
import App from './App.vue'
import router from './router'

createApp(App).use(router).mount('#app')
```

```vue
<!-- App.vue -->
<template>
  <nav>
    <RouterLink to="/">Home</RouterLink>
    <RouterLink to="/about">About</RouterLink>
  </nav>
  <RouterView /> <!-- 현재 라우트에 해당하는 컴포넌트가 렌더링됨 -->
</template>
```

---

### 📌 상태 관리 — Pinia

**왜 전역 상태 관리가 필요한가?**

여러 컴포넌트가 동일한 상태를 공유해야 할 때, props/emit 체인이 깊어지면(Prop Drilling) 유지보수가 어렵다. 공유 상태를 컴포넌트 외부의 전역 단위로 분리하면 해결된다.

**단순 패턴 — `reactive()`로 공유 스토어**

```js
// store.js
import { reactive } from 'vue'

export const store = reactive({
  count: 0,
  increment() {
    this.count++
  }
})
```

```vue
<!-- 어디서든 import해서 사용 -->
<script setup>
import { store } from './store.js'
</script>
<template>
  <button @click="store.increment()">{{ store.count }}</button>
</template>
```

이 방식은 단순하지만 DevTools 통합, HMR, SSR 지원이 없어 규모가 커지면 한계가 있다.

**Pinia — Vue 공식 상태 관리 라이브러리**

```bash
npm install pinia
```

```js
// main.js
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
app.use(createPinia())
app.mount('#app')
```

**스토어 정의 — `defineStore`**

```js
// stores/counter.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// Composition API 스타일 (권장)
export const useCounterStore = defineStore('counter', () => {
  // state
  const count = ref(0)
  const name = ref('Chan')

  // getter (computed)
  const doubleCount = computed(() => count.value * 2)

  // action
  function increment() {
    count.value++
  }

  async function fetchUser(id) {
    const res = await fetch(`/api/users/${id}`)
    name.value = (await res.json()).name
  }

  return { count, name, doubleCount, increment, fetchUser }
})
```

**스토어 사용**

```vue
<script setup>
import { useCounterStore } from '@/stores/counter'
import { storeToRefs } from 'pinia'

const counter = useCounterStore()

// storeToRefs: 구조 분해 시 반응성 유지
const { count, doubleCount } = storeToRefs(counter)
// action은 직접 구조 분해 가능
const { increment } = counter
</script>

<template>
  <p>Count: {{ count }}</p>
  <p>Double: {{ doubleCount }}</p>
  <button @click="increment">+1</button>
</template>
```

**Pinia vs Vuex 비교**

| 항목 | Pinia | Vuex |
|------|-------|------|
| API 스타일 | Composition API 기반 | Options API 기반 |
| Mutation | ❌ 없음 (action에서 직접 변경) | ✅ 필수 |
| TypeScript | 강력한 타입 추론 | 별도 설정 필요 |
| DevTools | ✅ 타임라인·인스펙터 | ✅ |
| SSR | ✅ 지원 | ✅ 지원 |
| 현황 | ✅ 공식 권장 | 유지보수 모드 |

> 💡 새 프로젝트는 무조건 Pinia를 써야 한다. Vuex는 유지보수 모드로, 새 기능이 추가되지 않는다.

---

### 📌 테스트

**세 가지 테스트 유형**

| 유형 | 범위 | 속도 | 도구 |
|------|------|------|------|
| 단위 테스트 | 함수, 컴포저블 | 빠름 | Vitest |
| 컴포넌트 테스트 | 컴포넌트 UI·동작 | 중간 | Vitest + @vue/test-utils |
| E2E 테스트 | 전체 페이지 흐름 | 느림 | Playwright, Cypress |

**Vitest 설정**

```bash
npm install -D vitest happy-dom @testing-library/vue @vue/test-utils
```

```js
// vite.config.js
import { defineConfig } from 'vite'

export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom'
  }
})
```

**단위 테스트 — 순수 함수**

```js
// helpers.js
export function increment(current, max = 10) {
  if (current < max) return current + 1
  return current
}
```

```js
// helpers.test.js
import { increment } from './helpers'

describe('increment', () => {
  test('현재 숫자를 1 증가시킨다', () => {
    expect(increment(0, 10)).toBe(1)
  })
  test('최대값을 넘어서 증가시키지 않는다', () => {
    expect(increment(10, 10)).toBe(10)
  })
})
```

**컴포저블 테스트**

반응성 API만 사용하는 컴포저블은 직접 호출해서 검증한다.

```js
// useCounter.js
import { ref } from 'vue'
export function useCounter() {
  const count = ref(0)
  const increment = () => count.value++
  return { count, increment }
}
```

```js
// useCounter.test.js
import { useCounter } from './useCounter'

test('useCounter', () => {
  const { count, increment } = useCounter()
  expect(count.value).toBe(0)
  increment()
  expect(count.value).toBe(1)
})
```

생명주기 훅이나 `provide/inject`에 의존하는 컴포저블은 호스트 컴포넌트로 감싸야 한다.

```js
// test-utils.js
import { createApp } from 'vue'

export function withSetup(composable) {
  let result
  const app = createApp({
    setup() {
      result = composable()
      return () => {}
    }
  })
  app.mount(document.createElement('div'))
  return [result, app]
}
```

**컴포넌트 테스트 — @vue/test-utils**

```vue
<!-- Stepper.vue -->
<script setup>
import { ref } from 'vue'
const props = defineProps({ max: { type: Number, default: 10 } })
const count = ref(0)
const increment = () => { if (count.value < props.max) count.value++ }
</script>
<template>
  <span data-testid="stepper-value">{{ count }}</span>
  <button data-testid="increment" @click="increment">+</button>
</template>
```

```js
// Stepper.test.js
import { mount } from '@vue/test-utils'
import Stepper from './Stepper.vue'

test('max를 넘어서 증가하지 않는다', async () => {
  const wrapper = mount(Stepper, { props: { max: 1 } })

  expect(wrapper.find('[data-testid=stepper-value]').text()).toBe('0')

  await wrapper.find('[data-testid=increment]').trigger('click')
  expect(wrapper.find('[data-testid=stepper-value]').text()).toBe('1')

  // max를 넘어서 클릭해도 1 유지
  await wrapper.find('[data-testid=increment]').trigger('click')
  expect(wrapper.find('[data-testid=stepper-value]').text()).toBe('1')
})
```

**컴포넌트 테스트 원칙**

| 해야 할 것 | 하지 말아야 할 것 |
|-----------|-----------------|
| 사용자 입력 → DOM 결과 검증 | 내부 상태(ref 값) 직접 검증 |
| props/events/slots 테스트 | 비공개 메서드 직접 호출 |
| `data-testid`로 요소 선택 | 구현 세부사항에 의존 |

**E2E 테스트 — Playwright (권장)**

```bash
npm install -D @playwright/test
```

```js
// tests/e2e/navigation.spec.js
import { test, expect } from '@playwright/test'

test('홈 → 어바웃 네비게이션', async ({ page }) => {
  await page.goto('http://localhost:5173')
  await page.click('a[href="/about"]')
  await expect(page).toHaveURL('/about')
  await expect(page.locator('h1')).toContainText('About')
})
```

---

### 📌 SSR (서버 사이드 렌더링)

**SSR이란?**

Vue 컴포넌트를 서버에서 HTML 문자열로 렌더링하고 브라우저로 전송한다. 브라우저에서는 이 정적 HTML을 인터랙티브 앱으로 "하이드레이트"한다.

**SSR의 장점**

| 장점 | 설명 |
|------|------|
| 빠른 FCP | JS 로딩 전에 완성된 HTML 표시 |
| SEO | 크롤러가 완성된 HTML을 바로 인덱싱 |
| 통합된 개발 모델 | 서버·클라이언트 동일 Vue 코드 |

**SSR의 트레이드오프**

- 브라우저 전용 API(`window`, `document`)를 서버에서 쓸 수 없다
- 더 복잡한 빌드 설정 (서버용 + 클라이언트용 번들)
- Node.js 서버가 필요 (정적 파일 서버 불가)
- 더 많은 서버 CPU 부하

**기본 SSR 흐름**

```js
// 서버 (Node.js)
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

const app = createSSRApp({
  data: () => ({ count: 1 }),
  template: `<button @click="count++">{{ count }}</button>`
})

const html = await renderToString(app)
// → '<button>1</button>'
```

```js
// 클라이언트: createApp 대신 createSSRApp 사용
import { createSSRApp } from 'vue'

const app = createSSRApp({ /* 서버와 동일한 앱 */ })
app.mount('#app') // 하이드레이션 수행
```

**코드 구조 — 서버·클라이언트 공유**

```js
// app.js (공유 코드)
import { createSSRApp } from 'vue'
export function createApp() {
  return createSSRApp({
    data: () => ({ count: 1 }),
    template: `<button @click="count++">{{ count }}</button>`
  })
}

// client.js
import { createApp } from './app.js'
createApp().mount('#app')

// server.js
import { createApp } from './app.js'
// 각 요청마다 createApp() 호출 → 새 인스턴스 생성
```

**SSR vs SSG 선택 기준**

| 구분 | SSR | SSG |
|------|-----|-----|
| 데이터 | 요청마다 달라짐 | 빌드 시점에 고정 |
| 배포 | Node.js 서버 필요 | 정적 파일 서버 가능 |
| 적합한 경우 | 동적 콘텐츠, 사용자별 데이터 | 블로그, 문서, 마케팅 페이지 |

**SSR 주의사항**

**1. 요청 간 상태 오염**

모듈 스코프에 선언한 싱글턴 상태는 여러 요청에 걸쳐 공유되어 사용자 간 데이터 노출 위험이 있다.

```js
// ❌ 위험: 모든 요청이 같은 인스턴스를 공유
export const store = reactive({ user: null })

// ✅ 안전: 요청마다 새 인스턴스 생성
export function createApp() {
  const app = createSSRApp(...)
  const store = createStore() // 요청마다 새로 생성
  app.provide('store', store)
  return { app, store }
}
```

**2. 브라우저 전용 API**

`window`, `document` 등은 SSR에서 사용 불가. `onMounted` 안으로 이동하거나 조건부로 처리한다.

```js
// ❌ 서버에서 오류 발생
const width = window.innerWidth

// ✅ 클라이언트에서만 실행
onMounted(() => {
  const width = window.innerWidth
})
```

**3. 라이프사이클 훅**

SSR에서는 `onMounted`, `onUpdated`가 실행되지 않는다. `setup()` / `<script setup>` 루트 스코프에서 부수 효과를 발생시키면 안 된다.

**4. 하이드레이션 불일치**

서버 렌더링 HTML과 클라이언트 렌더링 결과가 다르면 오류가 발생한다.

```html
<!-- ❌ 잘못된 HTML 중첩 → 하이드레이션 불일치 원인 -->
<p><div>hi</div></p>

<!-- ✅ 올바른 구조 -->
<div><p>hi</p></div>
```

**상위 레벨 솔루션 — Nuxt**

SSR의 복잡성을 추상화한 풀스택 Vue 프레임워크다.

```bash
npx nuxi@latest init my-nuxt-app
```

- 파일 시스템 기반 라우팅
- 자동 코드 스플리팅
- SSR / SSG / SPA 혼합 지원
- Pinia, Vue Router 기본 내장
- 배포 최적화 (Nitro 엔진)

---

## 3. 종합 예제 — Pinia + Vue Router + Vitest

아래는 실제 Vue 앱에서 Pinia 스토어를 Vue Router와 함께 쓰고 Vitest로 테스트하는 패턴이다.

```js
// stores/auth.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const isLoggedIn = computed(() => !!user.value)

  async function login(credentials) {
    const res = await fetch('/api/login', {
      method: 'POST',
      body: JSON.stringify(credentials)
    })
    user.value = await res.json()
  }

  function logout() {
    user.value = null
  }

  return { user, isLoggedIn, login, logout }
})
```

```js
// router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: () => import('@/views/Home.vue') },
    {
      path: '/dashboard',
      component: () => import('@/views/Dashboard.vue'),
      // 네비게이션 가드: 비로그인 시 리다이렉트
      beforeEnter: () => {
        const auth = useAuthStore()
        if (!auth.isLoggedIn) return '/'
      }
    }
  ]
})

export default router
```

```js
// stores/auth.test.js
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from './auth'

beforeEach(() => {
  // 테스트마다 새 Pinia 인스턴스 사용
  setActivePinia(createPinia())
})

test('초기 상태에서 로그인하지 않은 상태다', () => {
  const auth = useAuthStore()
  expect(auth.isLoggedIn).toBe(false)
})

test('logout하면 user가 null이 된다', () => {
  const auth = useAuthStore()
  auth.user = { id: 1, name: 'Chan' }
  auth.logout()
  expect(auth.user).toBeNull()
  expect(auth.isLoggedIn).toBe(false)
})
```

---

## 4. 정리

- **SFC**는 `.vue` 파일로 템플릿·로직·스타일을 하나에 캡슐화한다. 사전 컴파일, scoped CSS, HMR, IDE 지원이 주요 이점이다.
- **Vue Router**는 SPA 라우팅의 공식 솔루션이다. `createWebHistory()`(HTML5 History API)를 기본으로 쓰고, `<RouterView>`와 `<RouterLink>`로 라우트 기반 UI를 구성한다.
- **Pinia**는 Vue 3 공식 상태 관리 라이브러리다. Composition API 스타일로 state/getter/action을 하나의 함수에 정의한다. `storeToRefs()`로 구조 분해 시 반응성을 유지한다.
- **Vitest**는 Vite 기반 프로젝트의 공식 테스트 프레임워크다. `@vue/test-utils`로 컴포넌트를 마운트하고, 사용자 입력을 시뮬레이션하며, DOM 출력을 검증한다.
- **SSR**은 서버에서 HTML을 렌더링해 FCP와 SEO를 개선한다. 요청 간 상태 오염, 브라우저 API 접근, 하이드레이션 불일치를 주의해야 한다. 실제 프로덕션에서는 **Nuxt**를 사용하는 것을 강력히 권장한다.

---

## 5. 참고 자료

- [Vue 3 공식 문서 - SFC](https://ko.vuejs.org/guide/scaling-up/sfc)
- [Vue 3 공식 문서 - 라우팅](https://ko.vuejs.org/guide/scaling-up/routing)
- [Vue 3 공식 문서 - 상태 관리](https://ko.vuejs.org/guide/scaling-up/state-management)
- [Vue 3 공식 문서 - 테스트](https://ko.vuejs.org/guide/scaling-up/testing)
- [Vue 3 공식 문서 - SSR](https://ko.vuejs.org/guide/scaling-up/ssr)
- [Vue Router 공식 문서](https://router.vuejs.org/)
- [Pinia 공식 문서](https://pinia.vuejs.org/)
- [Vitest 공식 문서](https://vitest.dev/)
- [Nuxt 공식 문서](https://nuxt.com/)
