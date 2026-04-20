---
title: "컴포넌트 심화(Props, Emit, v-model, Slot, Provide/Inject, 비동기 컴포넌트)"
date: 2026-04-20 13:00:00 +0900
categories: [Vue.js]
tags: [Vue3, Components, Props, Emit, Slots, ProvideInject, defineModel, 비동기컴포넌트]
---

Vue 3 공식 문서의 **컴포넌트 심화** 섹션 전체를 다룬다. 컴포넌트 등록 방식부터 Props 검증, 커스텀 이벤트 설계, 컴포넌트 v-model, 폴스루 속성($attrs), 슬롯(기본/네임드/스코프드), Provide/Inject, 비동기 컴포넌트까지 — 재사용 가능한 컴포넌트를 올바르게 설계하기 위해 알아야 할 모든 것을 정리한다.

---

## 1. 개요

### 📌 이 글이 커버하는 공식 문서 페이지

| 페이지 | 핵심 내용 |
|--------|-----------|
| 컴포넌트 등록 | 전역 vs 지역 등록, PascalCase 규칙 |
| Props | 타입 검증, 단방향 흐름, Boolean 변환 |
| 컴포넌트 이벤트 | `defineEmits`, 이벤트 인자, 유효성 검사 |
| 컴포넌트 v-model | `defineModel`, 다중 v-model, 커스텀 수식어 |
| 폴스루 속성 | `$attrs`, `inheritAttrs`, `useAttrs` |
| 슬롯 | 기본/네임드/스코프드 슬롯, 렌더리스 컴포넌트 |
| Provide / Inject | Props Drilling 해소, 반응형 provide |
| 비동기 컴포넌트 | `defineAsyncComponent`, 로딩·에러 상태 |

### 📌 컴포넌트 간 통신 전체 지도

```
부모 → 자식: props
자식 → 부모: emit
부모 ↔ 자식: v-model (defineModel)
부모 → 콘텐츠 주입: slot
조상 → 자손 (깊이 무관): provide / inject
```

---

## 2. 개념 설명

### 📌 컴포넌트 등록 — 전역 vs 지역

**전역 등록**

```js
import { createApp } from 'vue'
import MyComponent from './MyComponent.vue'

const app = createApp({})
app.component('MyComponent', MyComponent)
// 체이닝 가능
app.component('A', A).component('B', B)
```

전역 등록은 앱 어디서든 사용할 수 있지만 두 가지 단점이 있다.

- **트리 셰이킹 불가**: 사용하지 않아도 최종 번들에 포함된다.
- **의존 관계 불명확**: 어떤 컴포넌트가 어디서 쓰이는지 추적하기 어렵다.

**지역 등록 (권장)**

```vue
<script setup>
// <script setup>에서는 import만 하면 자동 등록
import ButtonCounter from './ButtonCounter.vue'
</script>

<template>
  <ButtonCounter />
</template>
```

> 💡 `<script setup>`에서 import한 컴포넌트는 별도의 `components:` 선언 없이 자동으로 템플릿에서 사용 가능하다.

**컴포넌트 이름 규칙**: SFC에서는 `PascalCase`를 사용한다. 네이티브 HTML 요소와 시각적으로 구분되고, IDE 자동완성에도 유리하다.

---

### 📌 Props — 타입 선언, 검증, 단방향 흐름

**Props 선언**

```vue
<script setup>
// 배열 문법 (간단)
defineProps(['title', 'likes'])

// 객체 문법 (타입 포함, 권장)
defineProps({
  title: String,
  likes: Number
})
</script>
```

**Props 검증 전체 옵션**

```js
defineProps({
  // 기본 타입 체크
  propA: Number,

  // 여러 타입 허용
  propB: [String, Number],

  // 필수값
  propC: {
    type: String,
    required: true
  },

  // null 허용 필수값
  propD: {
    type: [String, null],
    required: true
  },

  // 기본값
  propE: {
    type: Number,
    default: 100
  },

  // 객체/배열 기본값은 팩토리 함수로
  propF: {
    type: Object,
    default(rawProps) {
      return { message: 'hello' }
    }
  },

  // 커스텀 검증 함수
  propG: {
    validator(value) {
      return ['success', 'warning', 'danger'].includes(value)
    }
  }
})
```

**단방향 데이터 흐름 — props는 읽기 전용**

```js
const props = defineProps(['foo'])

// ❌ 경고 발생 — props 직접 변경 금지
props.foo = 'bar'
```

props를 변경하고 싶은 두 가지 패턴의 올바른 해결책:

```js
// 패턴 1: 초기값으로만 사용 → 로컬 ref로 복사
const props = defineProps(['initialCounter'])
const counter = ref(props.initialCounter) // 이후 props와 독립적

// 패턴 2: 변환이 필요한 경우 → computed 활용
const props = defineProps(['size'])
const normalizedSize = computed(() => props.size.trim().toLowerCase())
```

**객체 전체를 props로 펼치기**

```js
const post = { id: 1, title: 'Vue 3 가이드' }
```

```html
<!-- 아래 두 코드는 동일 -->
<BlogPost v-bind="post" />
<BlogPost :id="post.id" :title="post.title" />
```

**Boolean 타입 props 특수 규칙**

```html
<!-- :is-published="true" 와 동일 -->
<MyComponent is-published />

<!-- :is-published="false" 와 동일 -->
<MyComponent />
```

**반응형 Props 구조 분해 (Vue 3.5+)**

```js
// 3.5+에서는 구조 분해해도 반응성 유지됨
const { foo = 'hello' } = defineProps(['foo'])
// 컴파일러가 자동으로 props.foo로 변환

// 단, watch할 때는 반드시 getter로 감싸야 함
watch(() => foo, callback) // ✅
watch(foo, callback)       // ❌ 반응성 없음
```

---

### 📌 컴포넌트 이벤트 — `defineEmits`와 emit

**이벤트 발생**

```vue
<!-- 자식 컴포넌트 -->
<script setup>
const emit = defineEmits(['inFocus', 'submit'])

function buttonClick() {
  emit('submit')
}
</script>

<template>
  <!-- 템플릿에서는 $emit 직접 사용 가능 -->
  <button @click="$emit('someEvent')">클릭</button>
</template>
```

**이벤트 인자 전달**

```html
<!-- 자식: 값과 함께 이벤트 발생 -->
<button @click="$emit('increaseBy', 1)">+1</button>

<!-- 부모: 인라인 화살표 함수로 수신 -->
<MyButton @increase-by="(n) => count += n" />

<!-- 또는 메서드로 수신 (첫 번째 인자로 전달됨) -->
<MyButton @increase-by="increaseCount" />
```

> 💡 컴포넌트 이벤트는 DOM 이벤트와 달리 **버블링되지 않는다**. 직접적인 부모만 리스닝할 수 있다.

**이벤트 유효성 검사**

```js
const emit = defineEmits({
  // 유효성 없음
  click: null,

  // submit 페이로드 검증
  submit: ({ email, password }) => {
    if (email && password) return true
    console.warn('유효하지 않은 이벤트 페이로드!')
    return false
  }
})
```

**이름 규칙**: camelCase로 emit하고 부모에서는 kebab-case로 리스닝한다.

```js
emit('myEvent')         // 자식에서 camelCase로 발생
```
```html
<MyComp @my-event="handler" /> <!-- 부모에서 kebab-case로 리스닝 -->
```

---

### 📌 컴포넌트 v-model — `defineModel`

`v-model`을 컴포넌트에 구현하는 방법이다. Vue 3.4+에서는 `defineModel()`을 사용하는 것이 권장된다.

**기본 사용법**

```vue
<!-- 자식: Child.vue -->
<script setup>
const model = defineModel()
</script>

<template>
  <!-- model은 ref처럼 동작하며 부모 값과 양방향 동기화 -->
  <input v-model="model" />
</template>
```

```html
<!-- 부모 -->
<Child v-model="searchText" />
```

**내부 동작 원리** — `defineModel`은 아래 코드의 축약이다.

```vue
<!-- 3.4 이전 방식 (여전히 유효) -->
<script setup>
const props = defineProps(['modelValue'])
const emit = defineEmits(['update:modelValue'])
</script>

<template>
  <input
    :value="props.modelValue"
    @input="emit('update:modelValue', $event.target.value)"
  />
</template>
```

**v-model 인자 — 이름 지정**

```html
<!-- 부모 -->
<MyComponent v-model:title="bookTitle" />
```

```vue
<!-- 자식 -->
<script setup>
const title = defineModel('title', { required: true })
</script>
```

**다중 v-model**

```html
<!-- 부모 -->
<UserName
  v-model:first-name="first"
  v-model:last-name="last"
/>
```

```vue
<!-- 자식 -->
<script setup>
const firstName = defineModel('firstName')
const lastName = defineModel('lastName')
</script>

<template>
  <input v-model="firstName" />
  <input v-model="lastName" />
</template>
```

**커스텀 수식어 처리**

```html
<MyComponent v-model.capitalize="myText" />
```

```vue
<script setup>
const [model, modifiers] = defineModel({
  set(value) {
    // capitalize 수식어가 있으면 첫 글자 대문자
    if (modifiers.capitalize) {
      return value.charAt(0).toUpperCase() + value.slice(1)
    }
    return value
  }
})
</script>
```

---

### 📌 폴스루 속성 — `$attrs`

"폴스루 속성"이란 컴포넌트에 전달됐지만 `props`나 `emits`에 선언되지 않은 속성/이벤트 리스너다. `class`, `style`, `id`가 대표적이다.

**기본 동작 — 루트 엘리먼트에 자동 추가**

```html
<!-- 부모 -->
<MyButton class="large" @click="handler" />
```

```html
<!-- MyButton 내부 -->
<button>Click Me</button>

<!-- 렌더링 결과 -->
<button class="large">Click Me</button>  <!-- class가 자동 병합 -->
```

**`inheritAttrs: false` + `v-bind="$attrs"` — 적용 위치 제어**

루트가 아닌 특정 요소에 폴스루 속성을 적용하고 싶을 때 사용한다.

```vue
<script setup>
defineOptions({ inheritAttrs: false })
</script>

<template>
  <div class="btn-wrapper">
    <!-- $attrs를 내부 button에만 적용 -->
    <button class="btn" v-bind="$attrs">Click Me</button>
  </div>
</template>
```

**JS에서 접근 — `useAttrs()`**

```vue
<script setup>
import { useAttrs } from 'vue'
const attrs = useAttrs()
// attrs는 반응형이 아님 — 변경 감지는 onUpdated 사용
</script>
```

> 💡 다중 루트 컴포넌트는 `$attrs`를 명시적으로 바인딩해야 한다. 그렇지 않으면 런타임 경고가 발생한다.

---

### 📌 슬롯 — 콘텐츠를 컴포넌트에 주입하기

**기본 슬롯**

```vue
<!-- FancyButton.vue -->
<template>
  <button class="fancy-btn">
    <slot></slot>  <!-- 부모가 전달한 콘텐츠가 여기에 렌더링 -->
  </button>
</template>
```

```html
<!-- 부모 -->
<FancyButton>Click me!</FancyButton>

<!-- 렌더링 결과 -->
<button class="fancy-btn">Click me!</button>
```

슬롯 콘텐츠는 **부모 스코프**에서 평가된다. 자식 데이터에 접근할 수 없다.

**폴백(기본) 콘텐츠**

```vue
<button type="submit">
  <slot>
    Submit  <!-- 부모가 아무것도 전달하지 않으면 이게 렌더링됨 -->
  </slot>
</button>
```

**네임드 슬롯**

```vue
<!-- BaseLayout.vue -->
<template>
  <div class="container">
    <header>
      <slot name="header"></slot>
    </header>
    <main>
      <slot></slot>  <!-- name 없는 슬롯 = "default" -->
    </main>
    <footer>
      <slot name="footer"></slot>
    </footer>
  </div>
</template>
```

```html
<!-- 부모: v-slot: 또는 # 축약형 사용 -->
<BaseLayout>
  <template #header>
    <h1>페이지 제목</h1>
  </template>

  <!-- 기본 슬롯 (암묵적으로 #default) -->
  <p>본문 내용</p>

  <template #footer>
    <p>연락처 정보</p>
  </template>
</BaseLayout>
```

**스코프드 슬롯 — 자식 데이터를 슬롯에 노출**

슬롯 콘텐츠에서 자식 컴포넌트의 데이터가 필요할 때 사용한다.

```vue
<!-- 자식: FancyList.vue -->
<template>
  <ul>
    <li v-for="item in items">
      <!-- item 데이터를 슬롯 prop으로 전달 -->
      <slot name="item" v-bind="item"></slot>
    </li>
  </ul>
</template>
```

```html
<!-- 부모: v-slot으로 슬롯 prop 수신 -->
<FancyList :api-url="url" :per-page="10">
  <template #item="{ body, username, likes }">
    <div class="item">
      <p>{{ body }}</p>
      <p>by {{ username }} | {{ likes }} likes</p>
    </div>
  </template>
</FancyList>
```

**조건부 슬롯 — `$slots`로 콘텐츠 존재 여부 확인**

```vue
<template>
  <div class="card">
    <div v-if="$slots.header" class="card-header">
      <slot name="header" />
    </div>
    <div v-if="$slots.default" class="card-content">
      <slot />
    </div>
  </div>
</template>
```

**렌더리스 컴포넌트 패턴**

로직만 캡슐화하고 UI 렌더링은 전적으로 슬롯에 위임하는 패턴이다.

```html
<MouseTracker v-slot="{ x, y }">
  마우스 위치: {{ x }}, {{ y }}
</MouseTracker>
```

> 💡 단순한 로직 재사용이라면 Composable이 더 효율적이다. 렌더리스 컴포넌트는 로직과 시각적 출력을 함께 조합해야 할 때 유용하다.

---

### 📌 Provide / Inject — Props Drilling 해소

**문제: Props Drilling**

컴포넌트 트리가 깊어지면 중간 컴포넌트들이 관심도 없는 props를 그냥 통과시켜야 한다. `provide/inject`가 이 문제를 해결한다.

```
부모 (provide)
  └─ 중간 컴포넌트 (props 통과 없이 무관)
       └─ 깊은 자식 (inject로 직접 수신)
```

**Provide**

```vue
<!-- 조상 컴포넌트 -->
<script setup>
import { provide, ref } from 'vue'

const location = ref('North Pole')

function updateLocation() {
  location.value = 'South Pole'
}

// 반응형 값과 변경 함수를 함께 제공
provide('location', { location, updateLocation })
</script>
```

앱 레벨 provide:

```js
app.provide('message', 'hello') // 플러그인에서 자주 활용
```

**Inject**

```vue
<!-- 깊이 중첩된 자손 컴포넌트 -->
<script setup>
import { inject } from 'vue'

const { location, updateLocation } = inject('location')
</script>

<template>
  <button @click="updateLocation">{{ location }}</button>
</template>
```

**기본값 설정**

```js
const value = inject('message', '기본값')

// 비용이 큰 기본값은 팩토리 함수로
const value = inject('key', () => new ExpensiveClass(), true)
```

**읽기 전용으로 제공 — `readonly`**

```js
import { ref, provide, readonly } from 'vue'

const count = ref(0)
provide('count', readonly(count)) // 주입자가 변경 불가
```

**Symbol 키 — 충돌 방지**

대규모 앱에서는 문자열 키 대신 Symbol을 사용한다.

```js
// keys.js
export const injectionKey = Symbol()
```

```js
// 제공자
import { injectionKey } from './keys.js'
provide(injectionKey, value)

// 주입자
import { injectionKey } from './keys.js'
const value = inject(injectionKey)
```

> 💡 **반응성 원칙**: 상태 변경은 provide한 쪽에서만 처리하는 것이 좋다. 변경 함수를 함께 provide하면 데이터와 변경 로직이 한 곳에 모인다.

---

### 📌 비동기 컴포넌트 — `defineAsyncComponent`

대형 앱에서 모든 컴포넌트를 초기에 로드하면 번들 크기가 커진다. 필요한 시점에 로드하는 **코드 스플리팅**을 `defineAsyncComponent`로 구현한다.

**기본 사용법**

```js
import { defineAsyncComponent } from 'vue'

// 동적 import와 함께 사용 (번들 자동 분리)
const AsyncComp = defineAsyncComponent(() =>
  import('./components/MyComponent.vue')
)
```

```vue
<!-- <script setup> 안에서도 사용 가능 -->
<script setup>
import { defineAsyncComponent } from 'vue'

const AdminPage = defineAsyncComponent(() =>
  import('./components/AdminPageComponent.vue')
)
</script>

<template>
  <AdminPage />
</template>
```

**로딩·에러 상태 처리**

```js
const AsyncComp = defineAsyncComponent({
  // 로더 함수
  loader: () => import('./Foo.vue'),

  // 로딩 중 표시할 컴포넌트
  loadingComponent: LoadingComponent,
  delay: 200, // 로딩 컴포넌트 표시 전 지연 (기본 200ms)

  // 에러 시 표시할 컴포넌트
  errorComponent: ErrorComponent,
  timeout: 3000 // 타임아웃 (기본 Infinity)
})
```

**지연 하이드레이션 전략 (Vue 3.5+, SSR 환경)**

```js
import { defineAsyncComponent, hydrateOnIdle, hydrateOnVisible, hydrateOnInteraction } from 'vue'

// 브라우저가 유휴 상태일 때 하이드레이션
const Comp1 = defineAsyncComponent({
  loader: () => import('./Comp.vue'),
  hydrate: hydrateOnIdle()
})

// 뷰포트에 보일 때 하이드레이션
const Comp2 = defineAsyncComponent({
  loader: () => import('./Comp.vue'),
  hydrate: hydrateOnVisible()
})

// 클릭 등 상호작용 시 하이드레이션
const Comp3 = defineAsyncComponent({
  loader: () => import('./Comp.vue'),
  hydrate: hydrateOnInteraction('click')
})
```

---

## 3. 종합 예제

아래는 이 Phase에서 다룬 개념들을 하나로 엮은 **모달 컴포넌트** 예제다.

/**
 * Props, Emit, v-model(defineModel), Slot, Provide/Inject를 조합한 예제.
 * ModalProvider가 모달 열기/닫기 상태를 provide하고,
 * BaseModal은 v-model로 표시 상태를 제어한다.
 */

```vue
<!-- BaseModal.vue -->
<script setup>
// v-model로 부모와 open 상태 양방향 바인딩
const isOpen = defineModel({ default: false })

defineProps({
  title: {
    type: String,
    required: true
  },
  size: {
    type: String,
    default: 'md',
    validator: (v) => ['sm', 'md', 'lg'].includes(v)
  }
})
</script>

<template>
  <Teleport to="body">
    <div v-if="isOpen" class="modal-overlay" @click.self="isOpen = false">
      <div :class="`modal modal--${size}`">
        <header class="modal__header">
          <!-- 네임드 슬롯: header -->
          <slot name="header">
            <h2>{{ title }}</h2>
          </slot>
          <button @click="isOpen = false">✕</button>
        </header>

        <main class="modal__body">
          <!-- 기본 슬롯: 본문 콘텐츠 -->
          <slot />
        </main>

        <footer class="modal__footer">
          <!-- 스코프드 슬롯: 닫기 함수를 부모에 노출 -->
          <slot name="footer" :close="() => (isOpen = false)">
            <button @click="isOpen = false">닫기</button>
          </slot>
        </footer>
      </div>
    </div>
  </Teleport>
</template>
```

```vue
<!-- App.vue (사용 예시) -->
<script setup>
import { ref } from 'vue'
import BaseModal from './BaseModal.vue'

const isModalOpen = ref(false)
</script>

<template>
  <button @click="isModalOpen = true">모달 열기</button>

  <BaseModal v-model="isModalOpen" title="회원 정보" size="lg">
    <!-- 기본 슬롯 -->
    <p>회원 정보 내용이 들어갑니다.</p>

    <!-- 스코프드 푸터 슬롯: close 함수 활용 -->
    <template #footer="{ close }">
      <button @click="saveAndClose(close)">저장</button>
      <button @click="close">취소</button>
    </template>
  </BaseModal>
</template>
```

---

## 4. 정리

- 컴포넌트 등록은 `<script setup>`에서 import만 하면 자동 지역 등록된다. 전역 등록은 트리 셰이킹이 안 되므로 꼭 필요한 경우에만 쓴다.
- Props는 **읽기 전용**이다. 변경이 필요하면 로컬 ref로 복사하거나, computed를 활용한다.
- Props 검증에 타입·required·default·validator를 적극 활용하면 컴포넌트 사용 계약이 명확해진다.
- 컴포넌트 이벤트는 버블링되지 않는다. 형제 컴포넌트 간 통신은 상태 관리나 이벤트 버스를 써야 한다.
- `defineModel()`은 `modelValue` prop + `update:modelValue` emit의 축약이다. 인자를 줘서 이름을 지정하면 다중 v-model도 가능하다.
- 폴스루 속성(`$attrs`)은 자동으로 루트 엘리먼트에 적용된다. 다른 곳에 적용하려면 `inheritAttrs: false` + `v-bind="$attrs"`를 사용한다.
- 슬롯은 부모 스코프에서 평가된다. 자식 데이터가 필요하면 **스코프드 슬롯**(`v-slot="slotProps"`)을 사용한다.
- Provide/Inject는 Props Drilling을 피하기 위한 수단이다. 변경은 provide한 쪽에서만 처리하고, `readonly()`로 주입자가 수정하지 못하게 보호하는 것이 좋다.
- `defineAsyncComponent`로 컴포넌트를 필요한 시점에 로드하면 초기 번들 크기를 줄일 수 있다.

---

## 5. 참고 자료

- [Vue 3 공식 문서 - 컴포넌트 등록](https://ko.vuejs.org/guide/components/registration)
- [Vue 3 공식 문서 - Props](https://ko.vuejs.org/guide/components/props)
- [Vue 3 공식 문서 - 컴포넌트 이벤트](https://ko.vuejs.org/guide/components/events)
- [Vue 3 공식 문서 - 컴포넌트 v-model](https://ko.vuejs.org/guide/components/v-model)
- [Vue 3 공식 문서 - 폴스루 속성](https://ko.vuejs.org/guide/components/attrs)
- [Vue 3 공식 문서 - 슬롯](https://ko.vuejs.org/guide/components/slots)
- [Vue 3 공식 문서 - Provide / Inject](https://ko.vuejs.org/guide/components/provide-inject)
- [Vue 3 공식 문서 - 비동기 컴포넌트](https://ko.vuejs.org/guide/components/async)
