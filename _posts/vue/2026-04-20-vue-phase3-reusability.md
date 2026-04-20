---
title: "재사용성(Composable, 커스텀 디렉티브, 플러그인)"
date: 2026-04-20 13:10:00 +0900
categories: [Vue.js]
order: 3
tags: [Vue3, Composable, CustomDirective, Plugin, 재사용성, use함수, toValue]
---

Vue 3 공식 문서의 **재사용성(Reusability)** 섹션 전체를 다룬다. Composable로 상태 로직을 재사용하고, 커스텀 디렉티브로 저수준 DOM 접근을 추상화하고, 플러그인으로 앱 수준의 기능을 확장하는 법까지 — Vue에서 코드를 재사용하는 세 가지 방법을 깊이 있게 정리한다.

---

## 1. 개요

### 📌 이 글이 커버하는 공식 문서 페이지

| 페이지 | 핵심 내용 |
|--------|-----------|
| Composables | `use` 함수, 상태 로직 캡슐화, `toValue`, Mixin과의 비교 |
| 커스텀 디렉티브 | 디렉티브 훅, `binding` 인자, 함수 단축 표기 |
| 플러그인 | `install`, `app.use`, `globalProperties`, provide 활용 |

### 📌 세 가지 재사용 방법 비교

| 방법 | 용도 | 특징 |
|------|------|------|
| **Composable** | 상태를 가진 로직 재사용 | Composition API 기반, 가장 범용적 |
| **커스텀 디렉티브** | 저수준 DOM 조작 재사용 | 엘리먼트에 직접 접근이 필요할 때 |
| **플러그인** | 앱 수준 기능 추가 | 전역 컴포넌트, 디렉티브, inject 등록 |

---

## 2. 개념 설명

### 📌 Composable — 상태 로직의 재사용 단위

**컴포저블이란?**

Vue의 Composition API를 활용해 **상태를 가진 로직을 캡슐화하고 재사용**하는 함수다. 이름은 관례상 `use`로 시작한다.

상태 없는 유틸(lodash 등)은 일반 함수로도 충분하지만, 반응형 상태·생명주기·watch가 함께 필요한 로직은 컴포저블로 추출한다.

**기본 예시 — `useMouse`**

컴포넌트 내부에 직접 작성한 마우스 추적 로직:

```vue
<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const x = ref(0)
const y = ref(0)

function update(event) {
  x.value = event.pageX
  y.value = event.pageY
}

onMounted(() => window.addEventListener('mousemove', update))
onUnmounted(() => window.removeEventListener('mousemove', update))
</script>
```

이것을 컴포저블로 추출하면:

```js
// composables/useMouse.js
import { ref, onMounted, onUnmounted } from 'vue'

export function useMouse() {
  const x = ref(0)
  const y = ref(0)

  function update(event) {
    x.value = event.pageX
    y.value = event.pageY
  }

  onMounted(() => window.addEventListener('mousemove', update))
  onUnmounted(() => window.removeEventListener('mousemove', update))

  // ref를 담은 일반 객체로 반환 (구조 분해해도 반응성 유지)
  return { x, y }
}
```

```vue
<!-- 사용처 -->
<script setup>
import { useMouse } from './composables/useMouse.js'

const { x, y } = useMouse()
</script>

<template>
  <p>마우스 위치: {{ x }}, {{ y }}</p>
</template>
```

> 💡 각 컴포넌트 인스턴스가 `useMouse()`를 호출할 때마다 `x`, `y` 상태의 **독립적인 복사본**이 생성된다. 서로 간섭하지 않는다.

**컴포저블 중첩 — 작은 단위의 조합**

컴포저블은 다른 컴포저블을 호출할 수 있다. 작은 단위로 쪼개 조합하는 것이 핵심이다.

```js
// composables/useEventListener.js
import { onMounted, onUnmounted } from 'vue'

export function useEventListener(target, event, callback) {
  onMounted(() => target.addEventListener(event, callback))
  onUnmounted(() => target.removeEventListener(event, callback))
}
```

```js
// composables/useMouse.js — useEventListener를 내부에서 사용
import { ref } from 'vue'
import { useEventListener } from './useEventListener'

export function useMouse() {
  const x = ref(0)
  const y = ref(0)

  useEventListener(window, 'mousemove', (event) => {
    x.value = event.pageX
    y.value = event.pageY
  })

  return { x, y }
}
```

**비동기 상태 예시 — `useFetch`**

```js
// composables/useFetch.js
import { ref, watchEffect, toValue } from 'vue'

export function useFetch(url) {
  const data = ref(null)
  const error = ref(null)

  const fetchData = () => {
    data.value = null
    error.value = null

    // toValue(): ref/getter/일반값을 모두 정규화
    fetch(toValue(url))
      .then(res => res.json())
      .then(json => (data.value = json))
      .catch(err => (error.value = err))
  }

  // url이 ref나 getter면 변경 시마다 자동 재실행
  watchEffect(() => { fetchData() })

  return { data, error }
}
```

```vue
<script setup>
import { ref } from 'vue'
import { useFetch } from './composables/useFetch.js'

const postId = ref(1)

// postId가 바뀌면 자동으로 재요청
const { data, error } = useFetch(() => `/posts/${postId.value}`)
</script>

<template>
  <div v-if="error">에러: {{ error.message }}</div>
  <div v-else-if="data">{{ data }}</div>
  <div v-else>로딩 중...</div>
</template>
```

**`toValue()` — ref/getter/값 정규화**

Vue 3.3+에 추가된 API. 컴포저블 인자를 유연하게 받을 때 사용한다.

```js
import { toValue } from 'vue'

function useFeature(maybeRefOrGetter) {
  const value = toValue(maybeRefOrGetter)
  // ref → .value 반환
  // getter 함수 → 호출 결과 반환
  // 일반값 → 그대로 반환
}
```

**관례와 모범 사례**

| 규칙 | 내용 |
|------|------|
| 네이밍 | `use`로 시작하는 camelCase |
| 반환값 | `reactive()` 대신 ref를 담은 일반 객체 반환 (구조 분해 시 반응성 유지) |
| 부수 효과 정리 | `onUnmounted()`에서 이벤트 리스너, 타이머 등 반드시 정리 |
| 호출 위치 | `<script setup>` 또는 `setup()` 내부에서 **동기적**으로 호출 |
| SSR 고려 | DOM 관련 부수 효과는 `onMounted()` 안에서 수행 |

**반환 객체를 reactive로 감싸기**

```js
// 구조 분해 없이 속성으로 접근하고 싶을 때
const mouse = reactive(useMouse())
// mouse.x, mouse.y로 접근 가능하며 반응성도 유지됨
```

**Mixin과의 비교 — 왜 컴포저블이 더 나은가**

| 문제 | Mixin | Composable |
|------|-------|------------|
| 출처 불명확 | 속성이 어디서 왔는지 모름 | 구조 분해로 출처가 명확 |
| 네임스페이스 충돌 | 같은 키 이름 충돌 | 변수명 변경으로 해결 |
| 암묵적 결합 | 공유 속성 키에 의존 | 명시적 인자/반환값으로 연결 |

> 💡 Vue 3에서는 Mixin 사용을 더 이상 권장하지 않는다. Composable이 같은 목적을 훨씬 명확하게 달성한다.

**코드 조직화 목적의 컴포저블**

재사용이 목적이 아니더라도, 큰 컴포넌트를 논리적 단위로 분리하는 데 컴포저블을 활용할 수 있다.

```vue
<script setup>
import { useFeatureA } from './featureA.js'
import { useFeatureB } from './featureB.js'
import { useFeatureC } from './featureC.js'

const { foo, bar } = useFeatureA()
const { baz } = useFeatureB(foo)     // A의 결과를 B에 전달
const { qux } = useFeatureC(baz)    // B의 결과를 C에 전달
</script>
```

---

### 📌 커스텀 디렉티브 — 저수준 DOM 접근의 추상화

**언제 써야 하나?**

- 컴포넌트나 컴포저블로 달성하기 어려운 **직접적인 DOM 조작**이 필요할 때
- 선언적 템플릿(`v-bind` 등)으로 대체할 수 없는 경우

가장 흔한 예: 마운트 즉시 포커스, 드래그·리사이즈, 외부 라이브러리 초기화.

**`<script setup>`에서의 지역 등록**

`v` 접두사로 시작하는 camelCase 변수는 자동으로 커스텀 디렉티브로 인식된다.

```vue
<script setup>
// vFocus → 템플릿에서 v-focus로 사용
const vFocus = {
  mounted: (el) => el.focus()
}
</script>

<template>
  <input v-focus />
</template>
```

**전역 등록**

```js
const app = createApp({})
app.directive('highlight', {
  mounted(el) {
    el.classList.add('is-highlight')
  }
})
```

**디렉티브 훅 전체 목록**

```js
const myDirective = {
  // 엘리먼트 속성·이벤트 리스너 적용 전
  created(el, binding, vnode) {},

  // DOM 삽입 직전
  beforeMount(el, binding, vnode) {},

  // 부모 컴포넌트와 자식 모두 마운트된 후
  mounted(el, binding, vnode) {},

  // 부모 컴포넌트 업데이트 전
  beforeUpdate(el, binding, vnode, prevVnode) {},

  // 부모 컴포넌트와 자식 모두 업데이트된 후
  updated(el, binding, vnode, prevVnode) {},

  // 부모 컴포넌트 언마운트 전
  beforeUnmount(el, binding, vnode) {},

  // 부모 컴포넌트 언마운트 후
  unmounted(el, binding, vnode) {}
}
```

**`binding` 인자 — 디렉티브에 전달된 정보**

```html
<div v-example:foo.bar="baz"></div>
```

```js
// binding 객체
{
  arg: 'foo',               // v-example:foo 의 인자
  modifiers: { bar: true }, // .bar 수식어
  value: /* baz의 값 */,
  oldValue: /* 이전 baz 값 (updated에서만 유효) */,
  instance,                 // 컴포넌트 인스턴스
  dir                       // 디렉티브 정의 객체
}
```

**함수 단축 표기 — `mounted`와 `updated`가 동일할 때**

```js
// 객체 대신 함수로 직접 정의
app.directive('color', (el, binding) => {
  // mounted와 updated 모두 이 함수가 호출됨
  el.style.color = binding.value
})
```

```html
<div v-color="userColor"></div>
```

**객체 리터럴로 여러 값 전달**

```html
<div v-demo="{ color: 'white', text: 'hello!' }"></div>
```

```js
app.directive('demo', (el, binding) => {
  console.log(binding.value.color) // 'white'
  console.log(binding.value.text)  // 'hello!'
})
```

**동적 인자**

```html
<div v-example:[arg]="value"></div>
```

`arg`가 반응형 상태면, 컴포넌트 상태 변화에 따라 디렉티브 인자도 반응적으로 바뀐다.

> 💡 커스텀 디렉티브를 **컴포넌트**에 사용하는 건 권장하지 않는다. 루트 노드에만 적용되는데, 다중 루트 컴포넌트면 경고가 발생하고 무시된다.

---

### 📌 플러그인 — 앱 수준 기능 확장

**플러그인이란?**

앱 전체에 적용되는 기능을 하나의 단위로 묶은 것이다. `install()` 메서드를 노출하는 객체, 또는 설치 함수 자체.

```js
const myPlugin = {
  install(app, options) {
    // 여기서 앱을 구성
  }
}
```

```js
// 사용
import { createApp } from 'vue'
const app = createApp({})
app.use(myPlugin, { /* 옵션 */ })
```

**플러그인이 할 수 있는 것들**

```js
const myPlugin = {
  install(app, options) {
    // 1. 전역 컴포넌트 등록
    app.component('MyGlobalComponent', MyGlobalComponent)

    // 2. 전역 커스텀 디렉티브 등록
    app.directive('my-directive', { /* ... */ })

    // 3. 전역 provide (inject로 어디서든 수신 가능)
    app.provide('pluginData', options)

    // 4. 전역 인스턴스 속성/메서드 추가
    app.config.globalProperties.$myMethod = () => { /* ... */ }
  }
}
```

**실전 예시 — 간단한 i18n 플러그인**

```js
// plugins/i18n.js
export default {
  install(app, options) {
    // $translate('greetings.hello') 형태로 전역 사용 가능
    app.config.globalProperties.$translate = (key) => {
      return key.split('.').reduce((obj, k) => obj?.[k], options)
    }

    // provide로도 제공 — inject로 수신 가능
    app.provide('i18n', options)
  }
}
```

```js
// main.js
import i18nPlugin from './plugins/i18n'

app.use(i18nPlugin, {
  greetings: { hello: 'Bonjour!' }
})
```

```vue
<!-- 전역 속성으로 사용 -->
<template>
  <h1>{{ $translate('greetings.hello') }}</h1>
</template>
```

```vue
<!-- 또는 inject로 사용 -->
<script setup>
import { inject } from 'vue'
const i18n = inject('i18n')
console.log(i18n.greetings.hello) // 'Bonjour!'
</script>
```

> 💡 `globalProperties`는 가능한 한 적게 추가한다. 여러 플러그인이 같은 이름을 등록하면 충돌한다. `provide/inject` 패턴이 더 명시적이고 안전하다.

---

## 3. 종합 예제

Phase 3 개념을 모두 담은 실전 예제다. `useIntersectionObserver` 컴포저블, `v-lazy-img` 커스텀 디렉티브, 그리고 이를 묶는 플러그인을 만든다.

/**
 * 뷰포트에 진입할 때 이미지를 지연 로딩하는 기능이다.
 * - useIntersectionObserver: 교차 관찰 로직을 컴포저블로 추출
 * - vLazyImg: 이미지 엘리먼트에 직접 접근하는 커스텀 디렉티브
 * - lazyImagePlugin: 앱 전체에 등록하는 플러그인
 */

```js
// composables/useIntersectionObserver.js
import { ref, onMounted, onUnmounted } from 'vue'

export function useIntersectionObserver(callback, options = {}) {
  const target = ref(null)
  let observer = null

  onMounted(() => {
    observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        callback(entry.target)
        // 한 번 노출되면 관찰 중단
        observer.unobserve(entry.target)
      }
    }, options)

    if (target.value) {
      observer.observe(target.value)
    }
  })

  onUnmounted(() => {
    observer?.disconnect()
  })

  return { target }
}
```

```js
// directives/vLazyImg.js
// — 이미지 엘리먼트에 직접 접근해야 하므로 커스텀 디렉티브로 구현
export const vLazyImg = {
  mounted(el, binding) {
    // binding.value: 실제 이미지 src
    // binding.arg:   로딩 중 표시할 placeholder src (선택)
    const placeholder = binding.arg || '/images/placeholder.png'
    el.src = placeholder

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        // 뷰포트 진입 시 실제 src로 교체
        el.src = binding.value
        el.classList.add('loaded')
        observer.unobserve(el)
      }
    })

    observer.observe(el)

    // 언마운트 시 정리
    el._lazyObserver = observer
  },

  unmounted(el) {
    el._lazyObserver?.disconnect()
  }
}
```

```js
// plugins/lazyImagePlugin.js
import { vLazyImg } from '../directives/vLazyImg.js'

export const lazyImagePlugin = {
  install(app, options = {}) {
    // 전역 디렉티브 등록
    app.directive('lazy-img', vLazyImg)

    // 기본 placeholder를 provide로 공유
    app.provide('lazyImgOptions', {
      placeholder: options.placeholder || '/images/placeholder.png'
    })

    console.log('[LazyImagePlugin] 등록 완료')
  }
}
```

```js
// main.js
import { createApp } from 'vue'
import App from './App.vue'
import { lazyImagePlugin } from './plugins/lazyImagePlugin.js'

const app = createApp(App)
app.use(lazyImagePlugin, { placeholder: '/images/loading.gif' })
app.mount('#app')
```

```vue
<!-- 사용 예시: App.vue -->
<template>
  <div class="image-grid">
    <!-- v-lazy-img:placeholder값="실제src" -->
    <img
      v-for="item in items"
      :key="item.id"
      v-lazy-img="item.imageUrl"
      alt="상품 이미지"
    />
  </div>
</template>
```

---

## 4. 정리

- **Composable**은 Vue 3에서 로직 재사용의 핵심 패턴이다. `use`로 시작하고, ref를 담은 일반 객체를 반환하며, `setup()` 내에서 동기적으로 호출해야 한다.
- 컴포저블은 중첩 가능하다. 작은 단위로 쪼개 조합하는 방식이 Composition API의 강점이다.
- `toValue()`로 ref·getter·일반값을 모두 받을 수 있는 유연한 컴포저블을 작성하라.
- 반환값은 `reactive()` 대신 `ref`를 담은 일반 객체로 반환해야 구조 분해 시 반응성이 유지된다.
- **커스텀 디렉티브**는 직접적인 DOM 조작이 꼭 필요한 경우에만 사용한다. 선언적 템플릿으로 대체 가능하면 디렉티브 대신 컴포넌트/컴포저블을 쓰는 것이 낫다.
- 커스텀 디렉티브의 `mounted`와 `updated`가 동일하면 함수 단축 표기를 활용하라.
- **플러그인**은 전역 컴포넌트·디렉티브 등록, `globalProperties` 추가, `app.provide` 세 가지 수단으로 앱을 확장한다. `globalProperties`보다는 `provide/inject` 패턴이 더 명시적이다.

---

## 5. 참고 자료

- [Vue 3 공식 문서 - Composables](https://ko.vuejs.org/guide/reusability/composables)
- [Vue 3 공식 문서 - 커스텀 디렉티브](https://ko.vuejs.org/guide/reusability/custom-directives)
- [Vue 3 공식 문서 - 플러그인](https://ko.vuejs.org/guide/reusability/plugins)
- [VueUse — 커뮤니티 Composable 모음](https://vueuse.org/)
