---
title: "내장 컴포넌트(Transition, TransitionGroup, KeepAlive, Teleport, Suspense)"
date: 2026-04-20 13:15:00 +0900
categories: [Vue.js]
tags: [Vue3, Transition, KeepAlive, Teleport, Suspense, 내장컴포넌트, 애니메이션]
---

Vue 3 공식 문서의 **내장 컴포넌트(Built-ins)** 섹션 전체를 다룬다. `<Transition>`으로 진입·퇴장 애니메이션을 적용하고, `<TransitionGroup>`으로 리스트를 부드럽게 움직이고, `<KeepAlive>`로 컴포넌트 상태를 보존하고, `<Teleport>`로 DOM 계층을 탈출하고, `<Suspense>`로 비동기 의존성을 조율하는 법까지 — 별도 설치 없이 Vue 어디서든 쓸 수 있는 다섯 가지 내장 컴포넌트를 깊이 정리한다.

---

## 1. 개요

### 📌 이 글이 커버하는 공식 문서 페이지

| 컴포넌트 | 역할 |
|----------|------|
| `<Transition>` | 단일 요소/컴포넌트의 진입·퇴장 애니메이션 |
| `<TransitionGroup>` | v-for 리스트의 삽입·제거·이동 애니메이션 |
| `<KeepAlive>` | 동적 컴포넌트 전환 시 상태 캐시·유지 |
| `<Teleport>` | 컴포넌트 DOM을 다른 위치로 렌더링 |
| `<Suspense>` | 비동기 컴포넌트 트리의 로딩 상태 조율 |

### 📌 각 컴포넌트를 언제 써야 하는가

```
화면 전환·등장에 부드러운 효과가 필요하다   → Transition / TransitionGroup
탭 전환 시 입력값·스크롤 위치를 유지해야 한다 → KeepAlive
모달·토스트를 body에 렌더링해야 한다         → Teleport
여러 비동기 컴포넌트 로딩을 하나로 관리한다   → Suspense
```

---

## 2. 개념 설명

### 📌 `<Transition>` — 진입·퇴장 애니메이션

`<Transition>`은 슬롯 내 단일 요소/컴포넌트가 **DOM에 삽입되거나 제거될 때** 자동으로 CSS 클래스를 추가·제거해 애니메이션을 적용한다.

트리거 조건: `v-if`, `v-show`, 동적 컴포넌트(`<component :is>`), 특수 `key` 속성 변경.

**트랜지션 클래스 6종**

```
진입: v-enter-from → v-enter-active → v-enter-to
퇴장: v-leave-from → v-leave-active → v-leave-to
```

| 클래스 | 적용 시점 |
|--------|-----------|
| `v-enter-from` | 삽입 직전 추가 → 1프레임 후 제거 |
| `v-enter-active` | 전체 진입 동안 유지 (duration, easing 정의) |
| `v-enter-to` | 1프레임 후 추가 → 애니메이션 종료 시 제거 |
| `v-leave-from` | 퇴장 트리거 즉시 추가 → 1프레임 후 제거 |
| `v-leave-active` | 전체 퇴장 동안 유지 (duration, easing 정의) |
| `v-leave-to` | 1프레임 후 추가 → 애니메이션 종료 시 제거 |

**기본 페이드 예시**

```vue
<script setup>
import { ref } from 'vue'
const show = ref(true)
</script>

<template>
  <button @click="show = !show">토글</button>
  <Transition>
    <p v-if="show">hello</p>
  </Transition>
</template>

<style>
.v-enter-active,
.v-leave-active {
  transition: opacity 0.5s ease;
}
.v-enter-from,
.v-leave-to {
  opacity: 0;
}
</style>
```

**네임드 트랜지션 — `name` prop**

`name`을 지정하면 클래스 접두사가 `v-` 대신 해당 이름으로 바뀐다.

```html
<Transition name="fade">
  <p v-if="show">hello</p>
</Transition>
```

```css
/* v- 대신 fade- 접두사 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
```

**슬라이드 + 페이드 조합**

```css
.slide-fade-enter-active {
  transition: all 0.3s ease-out;
}
.slide-fade-leave-active {
  transition: all 0.8s cubic-bezier(1, 0.5, 0.8, 1);
}
.slide-fade-enter-from,
.slide-fade-leave-to {
  transform: translateX(20px);
  opacity: 0;
}
```

**CSS 애니메이션 (`@keyframes`)**

```css
.bounce-enter-active {
  animation: bounce-in 0.5s;
}
.bounce-leave-active {
  animation: bounce-in 0.5s reverse;
}
@keyframes bounce-in {
  0%   { transform: scale(0); }
  50%  { transform: scale(1.25); }
  100% { transform: scale(1); }
}
```

**커스텀 트랜지션 클래스 — 외부 라이브러리 연동**

Animate.css 같은 라이브러리를 직접 연결할 수 있다.

```html
<Transition
  enter-active-class="animate__animated animate__tada"
  leave-active-class="animate__animated animate__bounceOutRight"
>
  <p v-if="show">hello</p>
</Transition>
```

**트랜지션 모드 — `mode` prop**

두 요소 간 전환 시 기본은 동시 애니메이션이다. 순차적으로 처리하려면 `mode`를 사용한다.

```html
<!-- 퇴장 완료 후 진입 시작 (가장 많이 씀) -->
<Transition mode="out-in">
  <component :is="activeComponent" />
</Transition>
```

**초기 렌더링 트랜지션 — `appear`**

```html
<Transition appear>
  <p>처음 렌더링될 때도 트랜지션 적용</p>
</Transition>
```

**JS 훅으로 세밀한 제어**

CSS 대신 GSAP 같은 JS 애니메이션 라이브러리를 쓸 때 활용한다.

```html
<Transition
  :css="false"
  @before-enter="onBeforeEnter"
  @enter="onEnter"
  @after-enter="onAfterEnter"
  @leave="onLeave"
  @after-leave="onAfterLeave"
>
  <p v-if="show">hello</p>
</Transition>
```

```js
function onEnter(el, done) {
  // done()을 반드시 호출해야 트랜지션이 종료됨
  gsap.from(el, { opacity: 0, y: -20, onComplete: done })
}
function onLeave(el, done) {
  gsap.to(el, { opacity: 0, y: 20, onComplete: done })
}
```

> 💡 JS 전용 트랜지션은 `:css="false"`를 반드시 추가한다. CSS 감지를 건너뛰어 성능이 더 좋고, CSS 규칙이 간섭하지 않는다.

**`key` 속성으로 트랜지션 강제 트리거**

같은 요소의 내용이 바뀔 때도 트랜지션을 발생시키려면 `:key`를 활용한다.

```html
<Transition>
  <!-- count가 바뀔 때마다 새 요소로 인식 → 트랜지션 발생 -->
  <span :key="count">{{ count }}</span>
</Transition>
```

**재사용 가능한 트랜지션 컴포넌트**

```vue
<!-- MyTransition.vue -->
<template>
  <Transition name="my-transition" @enter="onEnter" @leave="onLeave">
    <slot></slot>
  </Transition>
</template>
```

```html
<!-- 사용 — 내장 Transition처럼 사용 가능 -->
<MyTransition>
  <div v-if="show">Hello</div>
</MyTransition>
```

> 💡 **성능 팁**: `transform`과 `opacity`를 우선 사용한다. `height`, `margin` 등 레이아웃을 트리거하는 속성은 매 프레임마다 레이아웃 계산이 일어나 성능 비용이 크다.

---

### 📌 `<TransitionGroup>` — 리스트 애니메이션

`<TransitionGroup>`은 `v-for`로 렌더링되는 리스트 아이템의 **삽입·제거·순서 변경**에 애니메이션을 적용한다.

**`<Transition>`과의 차이점**

| 구분 | `<Transition>` | `<TransitionGroup>` |
|------|---------------|---------------------|
| 래퍼 요소 | 렌더링 안 함 | `tag` prop으로 지정 가능 |
| 트랜지션 모드 | 지원 | ❌ 미지원 |
| key | 선택 | **필수** |
| 이동 트랜지션 | ❌ | ✅ (`v-move` 클래스) |

**기본 사용법**

```html
<TransitionGroup name="list" tag="ul">
  <li v-for="item in items" :key="item">
    {{ item }}
  </li>
</TransitionGroup>
```

```css
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
```

**이동 트랜지션 — 주변 아이템도 부드럽게**

아이템이 삽입·제거될 때 주변 아이템이 자연스럽게 이동하려면 `v-move`(또는 `{name}-move`) 클래스를 추가한다.

```css
/* 이동하는 요소에 트랜지션 적용 */
.list-move,
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
/* 퇴장 아이템을 레이아웃 흐름에서 제거해야 이동 계산이 올바름 */
.list-leave-active {
  position: absolute;
}
```

**스태거 효과 — 인덱스 기반 순차 등장**

```html
<TransitionGroup
  tag="ul"
  :css="false"
  @before-enter="onBeforeEnter"
  @enter="onEnter"
>
  <li
    v-for="(item, index) in list"
    :key="item"
    :data-index="index"
  >
    {{ item }}
  </li>
</TransitionGroup>
```

```js
function onBeforeEnter(el) {
  el.style.opacity = 0
}
function onEnter(el, done) {
  gsap.to(el, {
    opacity: 1,
    delay: el.dataset.index * 0.15, // 인덱스만큼 지연
    onComplete: done
  })
}
```

---

### 📌 `<KeepAlive>` — 컴포넌트 상태 캐시

동적 컴포넌트를 전환할 때 기본적으로 이전 컴포넌트는 **언마운트**된다. 상태(입력값, 스크롤 위치 등)도 사라진다. `<KeepAlive>`로 감싸면 언마운트 대신 **비활성화(deactivated)** 상태로 캐시된다.

**기본 사용법**

```html
<!-- 캐시 없음: 전환 시 상태 초기화 -->
<component :is="activeComponent" />

<!-- KeepAlive: 전환해도 상태 유지 -->
<KeepAlive>
  <component :is="activeComponent" />
</KeepAlive>
```

**특정 컴포넌트만 캐시 — `include` / `exclude`**

매칭은 컴포넌트의 `name` 옵션 기준이다.

```html
<!-- 문자열 (쉼표 구분) -->
<KeepAlive include="ComponentA,ComponentB">
  <component :is="view" />
</KeepAlive>

<!-- 정규식 -->
<KeepAlive :include="/A|B/">
  <component :is="view" />
</KeepAlive>

<!-- 배열 -->
<KeepAlive :include="['ComponentA', 'ComponentB']">
  <component :is="view" />
</KeepAlive>
```

> 💡 Vue 3.2.34+부터 `<script setup>` 컴포넌트는 파일명 기반으로 `name`이 자동 추론된다.

**최대 캐시 수 — `max`**

LRU(가장 오래 미사용 제거) 방식으로 동작한다.

```html
<KeepAlive :max="10">
  <component :is="activeComponent" />
</KeepAlive>
```

**캐시된 컴포넌트의 생명주기**

| 훅 | 호출 시점 |
|----|-----------|
| `onActivated` | 마운트 시 + 캐시에서 다시 삽입될 때 |
| `onDeactivated` | 캐시로 이동할 때 + 언마운트 시 |

```vue
<script setup>
import { onActivated, onDeactivated } from 'vue'

onActivated(() => {
  // 캐시에서 복원될 때마다 최신 데이터 로드
  fetchLatestData()
})

onDeactivated(() => {
  // 타이머, 구독 등 정리
  clearInterval(timer)
})
</script>
```

---

### 📌 `<Teleport>` — DOM 계층 탈출

`<Teleport>`는 컴포넌트의 템플릿 일부를 **다른 DOM 위치**에 렌더링한다. 논리적 부모-자식 관계는 유지되지만, 실제 DOM은 지정한 위치에 삽입된다.

**왜 필요한가?**

- `position: fixed` 모달이 조상의 `transform`/`z-index`에 영향받는 문제
- 중첩된 DOM 계층에서 z-index 관리가 복잡한 문제

**기본 사용법**

```vue
<template>
  <button @click="open = true">모달 열기</button>

  <!-- 실제 DOM은 <body> 하위에 렌더링됨 -->
  <Teleport to="body">
    <div v-if="open" class="modal">
      <p>모달 내용</p>
      <button @click="open = false">닫기</button>
    </div>
  </Teleport>
</template>
```

**`to` prop**: CSS 선택자 문자열 또는 실제 DOM 노드.

**조건부 비활성화 — `disabled`**

```html
<!-- 모바일에서는 인라인, 데스크톱에서는 body로 텔레포트 -->
<Teleport :disabled="isMobile" to="body">
  <div class="overlay">...</div>
</Teleport>
```

**다중 텔레포트 — 동일 대상**

여러 `<Teleport>`가 같은 대상에 append 방식으로 순서대로 렌더링된다.

```html
<Teleport to="#modals"><div>A</div></Teleport>
<Teleport to="#modals"><div>B</div></Teleport>
<!-- 결과: #modals 안에 A, B 순서로 삽입 -->
```

**지연 텔레포트 — `defer` (Vue 3.5+)**

텔레포트 대상이 같은 컴포넌트 트리 내 더 늦게 렌더링되는 경우 사용한다.

```html
<Teleport defer to="#late-div">...</Teleport>
<!-- 더 뒤에 있는 요소 -->
<div id="late-div"></div>
```

> 💡 `<Teleport>`는 렌더링 DOM만 이동한다. `provide/inject`, props, 이벤트 등 논리적 부모-자식 관계는 그대로 유지된다.

---

### 📌 `<Suspense>` — 비동기 의존성 조율

`<Suspense>`는 컴포넌트 트리 내 여러 비동기 의존성이 해결될 때까지 **로딩 상태**를 표시하는 내장 컴포넌트다. (실험적 기능)

**비동기 의존성 두 종류**

1. `async setup()`을 가진 컴포넌트 (최상위 `await` 포함 `<script setup>`)
2. `defineAsyncComponent`로 만든 비동기 컴포넌트

```vue
<!-- async setup 컴포넌트 -->
<script setup>
// 최상위 await → 자동으로 비동기 의존성이 됨
const res = await fetch('/api/posts')
const posts = await res.json()
</script>
```

**기본 사용법**

```html
<Suspense>
  <!-- 비동기 의존성을 가진 컴포넌트 -->
  <Dashboard />

  <!-- 로딩 중 표시할 fallback -->
  <template #fallback>
    <LoadingSpinner />
  </template>
</Suspense>
```

**상태 흐름**

```
초기 렌더링
  → 비동기 의존성 발견 → pending 상태 (fallback 표시)
  → 모든 의존성 해결 → resolved 상태 (default 슬롯 표시)
  
재렌더링 (루트 노드 교체 시만 pending으로 돌아감)
  → 새 콘텐츠 해결 전까지 이전 콘텐츠 유지
  → timeout 초과 시 fallback으로 전환
```

**이벤트**

```html
<Suspense
  @pending="onPending"     <!-- 대기 상태 진입 -->
  @resolve="onResolved"    <!-- 해결 완료 -->
  @fallback="onFallback"   <!-- fallback 표시 -->
>
  ...
</Suspense>
```

**에러 처리**

`<Suspense>` 자체는 에러 처리를 하지 않는다. 부모에서 `onErrorCaptured()`로 처리한다.

```vue
<script setup>
import { onErrorCaptured } from 'vue'

onErrorCaptured((err) => {
  console.error('비동기 에러 포착:', err)
  return false // 에러 전파 중단
})
</script>
```

---

## 3. 종합 — 네 가지 내장 컴포넌트 조합 패턴

실제 애플리케이션에서는 이 내장 컴포넌트들을 조합해서 쓴다. 공식 문서 권장 중첩 순서:

```html
<RouterView v-slot="{ Component }">
  <template v-if="Component">
    <!-- 1. Transition: 페이지 전환 애니메이션 -->
    <Transition mode="out-in">
      <!-- 2. KeepAlive: 페이지 상태 보존 -->
      <KeepAlive>
        <!-- 3. Suspense: 비동기 컴포넌트 로딩 처리 -->
        <Suspense>
          <component :is="Component" />
          <template #fallback>
            <div class="page-loading">로딩 중...</div>
          </template>
        </Suspense>
      </KeepAlive>
    </Transition>
  </template>
</RouterView>
```

**모달 컴포넌트 — Teleport + Transition 조합**

```vue
<script setup>
import { ref } from 'vue'
const isOpen = defineModel({ default: false })
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="isOpen" class="modal-overlay" @click.self="isOpen = false">
        <div class="modal-container">
          <slot />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style>
.modal-enter-active,
.modal-leave-active {
  transition: all 0.3s ease;
}
.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
.modal-enter-from .modal-container,
.modal-leave-to .modal-container {
  transform: scale(0.9);
}
</style>
```

**탭 인터페이스 — KeepAlive + Transition 조합**

```vue
<script setup>
import { ref, shallowRef } from 'vue'
import TabA from './TabA.vue'
import TabB from './TabB.vue'

const tabs = { TabA, TabB }
const currentTab = ref('TabA')
</script>

<template>
  <div class="tab-buttons">
    <button
      v-for="tab in Object.keys(tabs)"
      :key="tab"
      @click="currentTab = tab"
    >{{ tab }}</button>
  </div>

  <Transition name="tab" mode="out-in">
    <KeepAlive>
      <component :is="tabs[currentTab]" :key="currentTab" />
    </KeepAlive>
  </Transition>
</template>

<style>
.tab-enter-active,
.tab-leave-active { transition: opacity 0.2s; }
.tab-enter-from,
.tab-leave-to { opacity: 0; }
</style>
```

**리스트 CRUD — TransitionGroup**

```vue
<script setup>
import { ref } from 'vue'

const items = ref([
  { id: 1, text: 'Vue 3 공부' },
  { id: 2, text: '블로그 작성' }
])

function addItem() {
  items.value.splice(
    Math.floor(Math.random() * (items.value.length + 1)),
    0,
    { id: Date.now(), text: `새 항목 ${items.value.length + 1}` }
  )
}

function removeItem(id) {
  items.value = items.value.filter(item => item.id !== id)
}
</script>

<template>
  <button @click="addItem">랜덤 추가</button>

  <TransitionGroup name="list" tag="ul">
    <li v-for="item in items" :key="item.id">
      {{ item.text }}
      <button @click="removeItem(item.id)">삭제</button>
    </li>
  </TransitionGroup>
</template>

<style>
.list-move,
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
.list-leave-active {
  position: absolute; /* 이동 계산을 위해 레이아웃에서 제거 */
}
</style>
```

---

## 4. 정리

- `<Transition>`은 단일 요소의 DOM 진입·퇴장에 6개의 CSS 클래스를 자동 관리한다. `name` prop으로 접두사를 지정하고, `mode="out-in"`으로 퇴장 후 진입 순서를 보장한다.
- `<TransitionGroup>`은 `v-for` 리스트에 사용한다. 이동 트랜지션을 위해 `{name}-move` 클래스와 `position: absolute`(퇴장 요소용)를 함께 설정해야 한다.
- `<KeepAlive>`는 동적 컴포넌트 전환 시 상태를 보존한다. `include`/`exclude`로 선택적 캐시가 가능하며, 캐시된 컴포넌트는 `onActivated`/`onDeactivated` 훅으로 라이프사이클을 관리한다.
- `<Teleport>`는 모달·토스트 등 DOM 위치가 중요한 UI에 쓴다. `to` prop으로 대상을 지정하며, `disabled` prop으로 조건부 비활성화가 가능하다. 논리적 부모-자식 관계는 그대로 유지된다.
- `<Suspense>`는 실험적 기능이다. `async setup`이나 비동기 컴포넌트를 가진 트리에서 단일 로딩 상태를 표시할 수 있다. 에러 처리는 부모의 `onErrorCaptured`로 별도 구현해야 한다.
- 실전에서는 `Transition > KeepAlive > Suspense` 순서로 중첩하고, `<Teleport>`는 모달 등 독립적인 오버레이 UI에 활용한다.

---

## 5. 참고 자료

- [Vue 3 공식 문서 - Transition](https://ko.vuejs.org/guide/built-ins/transition)
- [Vue 3 공식 문서 - TransitionGroup](https://ko.vuejs.org/guide/built-ins/transition-group)
- [Vue 3 공식 문서 - KeepAlive](https://ko.vuejs.org/guide/built-ins/keep-alive)
- [Vue 3 공식 문서 - Teleport](https://ko.vuejs.org/guide/built-ins/teleport)
- [Vue 3 공식 문서 - Suspense](https://ko.vuejs.org/guide/built-ins/suspense)
- [애니메이션 기법 가이드](https://ko.vuejs.org/guide/extras/animation)
