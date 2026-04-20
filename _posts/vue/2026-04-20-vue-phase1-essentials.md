---
title: "컴포넌트 기초"
date: 2026-04-20 11:00:00 +0900
categories: [Vue.js]
tags: [Vue3, Essentials, CompositionAPI, Reactivity, 템플릿문법, 생명주기, 컴포넌트]
---

Vue 3 공식 문서의 **Essentials(필수)** 섹션 전체를 다룬다. 앱 인스턴스 생성부터 템플릿 문법, 반응성 시스템, computed/watch, 조건부·리스트 렌더링, 이벤트·폼 처리, 생명주기 훅, template ref, 컴포넌트 기초까지 — Vue로 뭔가를 만들기 위해 반드시 알아야 할 것들을 정리한다.

---

## 1. 개요

### 📌 이 글이 커버하는 공식 문서 페이지

| 페이지 | 핵심 내용 |
|--------|-----------|
| 애플리케이션 생성 | `createApp`, `mount`, 앱 설정 |
| 템플릿 문법 | `{{ }}`, `v-bind`, `v-on`, 디렉티브 |
| 반응성 기초 | `ref`, `reactive`, `.value`, Proxy |
| 계산된 속성 | `computed`, 캐싱, getter/setter |
| 클래스·스타일 바인딩 | `:class`, `:style`, 객체·배열 바인딩 |
| 조건부 렌더링 | `v-if`, `v-else-if`, `v-else`, `v-show` |
| 리스트 렌더링 | `v-for`, `:key`, 배열 변이 메서드 |
| 이벤트 처리 | `v-on`, `@`, 이벤트 수식자, 키 수식자 |
| 폼 입력 바인딩 | `v-model`, 체크박스·라디오·셀렉트, 수식자 |
| 워처 | `watch`, `watchEffect`, flush 옵션 |
| 템플릿 ref | `useTemplateRef`, `ref="..."`, `defineExpose` |
| 생명주기 훅 | `onMounted`, `onUpdated`, `onUnmounted` |
| 컴포넌트 기초 | props, emit, slot, 동적 컴포넌트 |

### 📌 전체 흐름 한눈에 보기

```
createApp(App).mount('#app')
        ↓
  템플릿 렌더링 ({{ }}, v-bind, v-on)
        ↓
  반응형 상태 (ref, reactive)
        ↓
  파생 값 (computed) / 부수효과 (watch)
        ↓
  조건부·리스트 렌더링 (v-if, v-for)
        ↓
  이벤트·폼 처리 (v-on, v-model)
        ↓
  생명주기 훅 (onMounted, onUnmounted...)
        ↓
  컴포넌트 분리 (props, emit, slot)
```

---

## 2. 개념 설명

### 📌 애플리케이션 생성 — `createApp`과 `mount`

모든 Vue 앱은 `createApp`으로 인스턴스를 만들고, `.mount()`로 DOM에 연결하는 것에서 시작한다.

```js
import { createApp } from 'vue'
import App from './App.vue'

const app = createApp(App)
app.mount('#app') // <div id="app"> 내부에 렌더링
```

> 💡 `.mount()`는 모든 설정이 끝난 후 마지막에 호출해야 한다. 반환값은 애플리케이션 인스턴스가 아니라 **루트 컴포넌트 인스턴스**다.

앱 레벨 설정은 `.config`로 할 수 있다.

```js
// 앱 전역 에러 핸들러
app.config.errorHandler = (err) => {
  console.error('전역 에러:', err)
}

// 전역 컴포넌트 등록
app.component('MyButton', MyButton)
```

동일 페이지에 여러 Vue 앱을 독립적으로 마운트하는 것도 가능하다.

```js
const app1 = createApp(App1)
app1.mount('#container-1')

const app2 = createApp(App2)
app2.mount('#container-2')
```

---

### 📌 템플릿 문법

Vue 템플릿은 문법적으로 유효한 HTML이다. 내부적으로 고도로 최적화된 JS 코드로 컴파일된다.

**텍스트 보간 — Mustache `{{ }}`**

```html
<span>메시지: {{ msg }}</span>
```

`msg`가 바뀌면 자동으로 업데이트된다. HTML을 직접 렌더링하려면 `v-html`을 사용한다(XSS 위험 있으므로 신뢰된 콘텐츠에만 사용).

**속성 바인딩 — `v-bind` / `:`**

머스태시는 HTML 속성 안에서 사용할 수 없다. 대신 `v-bind`를 쓴다.

```html
<div :id="dynamicId"></div>
<button :disabled="isButtonDisabled">버튼</button>

<!-- 객체 전체를 한 번에 바인딩 -->
<div v-bind="{ id: 'container', class: 'wrapper' }"></div>

<!-- Vue 3.4+ 동일 이름 축약 -->
<div :id></div>  <!-- :id="id" 와 동일 -->
```

**JS 표현식 사용**

바인딩 내부에서 JS 표현식을 사용할 수 있다. 단, **표현식(값을 반환하는 것)만** 허용된다. 문장(`var a = 1`)은 안 된다.

```html
{{ number + 1 }}
{{ ok ? 'YES' : 'NO' }}
{{ message.split('').reverse().join('') }}
<div :id="`list-${id}`"></div>
```

**디렉티브와 수식어**

```html
<p v-if="seen">보여요</p>
<a :href="url">링크</a>
<a @click="doSomething">클릭</a>

<!-- 동적 인자 -->
<a :[attributeName]="url">동적 속성</a>
<a @[eventName]="handler">동적 이벤트</a>

<!-- 수식어 -->
<form @submit.prevent="onSubmit">...</form>
```

---

### 📌 반응성 기초 — `ref`와 `reactive`

**`ref()` — 원시값을 반응형으로**

```js
import { ref } from 'vue'

const count = ref(0)
console.log(count.value) // 0  → JS에서는 .value 필수
count.value++
```

템플릿 안에서는 `.value` 없이 자동 언래핑된다.

```html
<button @click="count++">{{ count }}</button>
```

> 💡 Vue가 `ref`의 `.value`에 getter/setter를 설치해 접근·변경을 감지한다. 일반 변수(`let count = 0`)는 감지할 수 없다.

**`reactive()` — 객체를 반응형으로**

```js
import { reactive } from 'vue'

const state = reactive({ count: 0 })
state.count++ // .value 불필요, 객체처럼 바로 접근
```

`reactive`는 ES6 Proxy로 객체를 감싼다. 원시값에는 사용할 수 없다.

**`reactive`의 한계 — 왜 `ref`를 기본으로 써야 하나**

| 한계 | 설명 |
|------|------|
| 원시값 불가 | `reactive(0)` 불가 |
| 전체 교체 시 반응성 소실 | `state = reactive({...})` 하면 연결 끊김 |
| 구조 분해 시 반응성 소실 | `let { count } = state` 후 `count++`는 추적 안 됨 |

→ **공식 문서 권장: `ref()`를 기본으로 사용**

**ref 언래핑 주의사항**

```js
const count = ref(0)
const object = { id: ref(1) }

// 최상위 ref는 언래핑됨
{{ count + 1 }} // → 1 (정상)

// 중첩된 ref는 언래핑 안 됨
{{ object.id + 1 }} // → [object Object]1 (비정상)

// 해결: 구조 분해
const { id } = object
{{ id + 1 }} // → 2 (정상)
```

**DOM 업데이트 타이밍 — `nextTick`**

반응형 상태 변경 후 DOM 업데이트는 **비동기(다음 틱)**에 일어난다. 업데이트 직후 DOM을 읽어야 한다면 `nextTick`을 사용한다.

```js
import { nextTick } from 'vue'

async function increment() {
  count.value++
  await nextTick()
  // 이제 DOM이 업데이트된 상태
}
```

---

### 📌 계산된 속성 — `computed`

템플릿에 복잡한 로직을 넣으면 유지보수가 어려워진다. 반응형 데이터를 기반으로 하는 파생 값은 `computed`로 선언한다.

```js
import { reactive, computed } from 'vue'

const author = reactive({
  name: 'Chan',
  books: ['Vue 3 가이드', 'Spring Boot 실전']
})

const publishedBooksMessage = computed(() => {
  return author.books.length > 0 ? '출판함' : '없음'
})
```

**computed vs 메서드**

| 구분 | computed | method |
|------|----------|--------|
| 캐싱 | ✅ 의존성이 변경될 때만 재계산 | ❌ 렌더링마다 항상 실행 |
| 용도 | 파생 값 | 이벤트 핸들러, 로직 |

> 💡 `Date.now()`처럼 반응형이 아닌 값에 의존하는 computed는 절대 업데이트되지 않는다.

**쓰기 가능한 computed (getter + setter)**

```js
const fullName = computed({
  get() {
    return firstName.value + ' ' + lastName.value
  },
  set(newValue) {
    [firstName.value, lastName.value] = newValue.split(' ')
  }
})
```

**모범 사례**
- getter 안에서 다른 상태를 변경하거나 비동기 요청을 하면 안 된다.
- computed 반환값은 읽기 전용으로 취급하고 직접 변경하면 안 된다.

---

### 📌 클래스·스타일 바인딩

**`:class` 바인딩**

```html
<!-- 객체: 키가 클래스명, 값이 조건 -->
<div :class="{ active: isActive, 'text-danger': hasError }"></div>

<!-- 배열 -->
<div :class="[activeClass, errorClass]"></div>

<!-- 배열 + 객체 조합 -->
<div :class="[{ active: isActive }, errorClass]"></div>

<!-- computed와 함께 (가장 강력한 패턴) -->
const classObject = computed(() => ({
  active: isActive.value && !error.value,
  'text-danger': error.value?.type === 'fatal'
}))
```

**`:style` 바인딩**

```html
<div :style="{ color: activeColor, fontSize: fontSize + 'px' }"></div>

<!-- 객체에 바인딩 -->
<div :style="styleObject"></div>

<!-- 배열 병합 -->
<div :style="[baseStyles, overridingStyles]"></div>
```

벤더 접두사(`-webkit-`, `-ms-` 등)는 Vue가 자동으로 추가한다.

---

### 📌 조건부 렌더링 — `v-if` / `v-show`

**`v-if`, `v-else-if`, `v-else`**

```html
<div v-if="type === 'A'">A</div>
<div v-else-if="type === 'B'">B</div>
<div v-else>A/B가 아님</div>

<!-- 여러 요소를 묶을 때 <template> 사용 (DOM에 렌더링 안 됨) -->
<template v-if="ok">
  <h1>제목</h1>
  <p>내용</p>
</template>
```

**`v-show`**

```html
<h1 v-show="ok">안녕하세요!</h1>
```

`v-show`는 CSS `display: none`으로 처리한다. 항상 렌더링되고 DOM에 남아 있다.

**v-if vs v-show 선택 기준**

| 구분 | v-if | v-show |
|------|------|--------|
| DOM | 조건에 따라 생성/삭제 | 항상 렌더링, CSS 토글 |
| 초기 비용 | 낮음 (false면 렌더링 안 함) | 높음 (항상 렌더링) |
| 토글 비용 | 높음 (생성/삭제 발생) | 낮음 (CSS만 변경) |
| 권장 상황 | 조건이 자주 바뀌지 않을 때 | 매우 자주 토글할 때 |

---

### 📌 리스트 렌더링 — `v-for`

```html
<!-- 배열 -->
<li v-for="(item, index) in items" :key="item.id">
  {{ index }} - {{ item.message }}
</li>

<!-- 객체 -->
<li v-for="(value, key, index) in myObject">
  {{ index }}. {{ key }}: {{ value }}
</li>

<!-- 정수 (1부터 시작) -->
<span v-for="n in 10">{{ n }}</span>
```

> 💡 `:key`는 Vue가 각 노드의 정체성을 추적할 수 있도록 반드시 제공해야 한다. 고유한 원시값(string, number)을 사용할 것.

**v-if와 v-for를 같이 쓰면 안 되는 이유**

같은 요소에 쓰면 `v-if`가 먼저 평가되어 `v-for`의 스코프 변수에 접근할 수 없다. `<template>`으로 감싸서 분리하라.

```html
<!-- 권장 -->
<template v-for="todo in todos" :key="todo.name">
  <li v-if="!todo.isComplete">{{ todo.name }}</li>
</template>
```

**배열 변이 메서드** — Vue가 자동 감지하는 메서드들

```
push(), pop(), shift(), unshift(), splice(), sort(), reverse()
```

`filter()`, `concat()`, `slice()`는 새 배열을 반환하므로, 결과를 기존 배열에 재할당해야 한다.

**계산된 속성으로 필터링/정렬**

```js
const evenNumbers = computed(() => {
  return numbers.value.filter(n => n % 2 === 0)
})
```

> 💡 `computed` 내부에서 `reverse()`나 `sort()`를 쓸 때는 원본 배열을 복사해서 사용하라. `[...numbers.value].reverse()`

---

### 📌 이벤트 처리 — `v-on` / `@`

```html
<!-- 인라인 핸들러 -->
<button @click="count++">Add 1</button>

<!-- 메서드 핸들러 -->
<button @click="greet">Greet</button>

<!-- 인라인에서 메서드 호출 + 인자 전달 -->
<button @click="say('hello')">Say hello</button>

<!-- $event로 DOM 이벤트 접근 -->
<button @click="warn('메시지', $event)">Submit</button>
```

**이벤트 수식자**

```html
<a @click.stop="doThis"></a>          <!-- 이벤트 전파 중단 -->
<form @submit.prevent="onSubmit"></form> <!-- 기본 동작 방지 -->
<a @click.stop.prevent="doThat"></a>   <!-- 체이닝 가능 -->
<div @click.self="doThat">...</div>    <!-- 자기 자신에서만 -->
<a @click.once="doThis"></a>           <!-- 한 번만 -->
```

**키 수식자**

```html
<input @keyup.enter="submit" />
<input @keyup.page-down="onPageDown" />

<!-- 시스템 키 수식자 -->
<input @keyup.alt.enter="clear" />
<div @click.ctrl="doSomething">Ctrl+Click</div>
<button @click.ctrl.exact="onCtrlClick">Ctrl만</button>
```

---

### 📌 폼 입력 바인딩 — `v-model`

`v-model`은 `:value + @input`을 하나로 합친 양방향 바인딩 디렉티브다.

```html
<!-- 텍스트 -->
<input v-model="text" />

<!-- 여러 줄 텍스트 -->
<textarea v-model="message"></textarea>

<!-- 체크박스 (배열에 바인딩) -->
<input type="checkbox" value="Jack" v-model="checkedNames" />

<!-- 라디오 -->
<input type="radio" value="One" v-model="picked" />

<!-- 셀렉트 -->
<select v-model="selected">
  <option disabled value="">선택하세요</option>
  <option>A</option>
  <option>B</option>
</select>
```

**v-model 수식자**

| 수식자 | 동작 |
|--------|------|
| `.lazy` | `input` 대신 `change` 이벤트에 동기화 |
| `.number` | 입력값을 자동으로 숫자로 변환 |
| `.trim` | 앞뒤 공백 자동 제거 |

```html
<input v-model.lazy="msg" />
<input v-model.number="age" />
<input v-model.trim="msg" />
```

---

### 📌 워처 — `watch`와 `watchEffect`

`computed`가 파생 값 계산용이라면, `watch`는 상태 변화에 반응해 **부수 효과(비동기 요청, DOM 조작 등)**를 실행하는 용도다.

**`watch`**

```js
import { ref, watch } from 'vue'

const question = ref('')

watch(question, async (newVal, oldVal) => {
  if (newVal.includes('?')) {
    // API 호출 등 부수 효과
    const res = await fetch('...')
    answer.value = await res.json()
  }
})
```

watch 소스 타입:

```js
const x = ref(0)
const y = ref(0)

watch(x, (newX) => { ... })                          // 단일 ref
watch(() => x.value + y.value, (sum) => { ... })     // getter
watch([x, () => y.value], ([newX, newY]) => { ... }) // 배열

// reactive 속성은 getter로 감싸야 함
watch(() => obj.count, (count) => { ... })
```

**옵션**

```js
watch(source, callback, {
  immediate: true, // 즉시 실행
  deep: true,      // 중첩 객체까지 감시
  once: true,      // 딱 한 번만 실행 (Vue 3.4+)
  flush: 'post'    // DOM 업데이트 후 실행
})
```

**`watchEffect`**

의존성을 명시하지 않아도, 콜백 내부에서 접근한 반응형 데이터를 자동 추적한다.

```js
watchEffect(async () => {
  // todoId.value가 자동으로 의존성으로 추적됨
  const response = await fetch(`/todos/${todoId.value}`)
  data.value = await response.json()
})
```

**watch vs watchEffect**

| 구분 | watch | watchEffect |
|------|-------|-------------|
| 의존성 추적 | 명시적 | 자동 |
| 즉시 실행 | 기본 lazy (immediate 옵션 필요) | 항상 즉시 실행 |
| 이전 값 접근 | ✅ (oldVal 인자) | ❌ |
| 정밀 제어 | ✅ | ❌ |

**부수 효과 정리 — `onWatcherCleanup`**

```js
watch(id, (newId) => {
  const controller = new AbortController()
  fetch(`/api/${newId}`, { signal: controller.signal })

  onWatcherCleanup(() => {
    controller.abort() // id가 바뀌면 이전 요청 취소
  })
})
```

---

### 📌 템플릿 ref — DOM 직접 접근

`useTemplateRef()`로 DOM 요소나 자식 컴포넌트 인스턴스에 직접 접근할 수 있다.

```vue
<script setup>
import { useTemplateRef, onMounted } from 'vue'

const input = useTemplateRef('my-input')

onMounted(() => {
  input.value.focus() // 마운트 후에만 접근 가능
})
</script>

<template>
  <input ref="my-input" />
</template>
```

> 💡 ref는 컴포넌트가 마운트된 후에만 접근 가능하다. 첫 렌더에서는 `null`이다.

**`<script setup>` 컴포넌트는 기본 비공개**

부모에서 자식 컴포넌트의 ref에 접근하려면, 자식이 `defineExpose`로 명시적으로 공개해야 한다.

```vue
<script setup>
import { ref } from 'vue'

const a = 1
const b = ref(2)

defineExpose({ a, b }) // 이것만 부모에서 접근 가능
</script>
```

---

### 📌 생명주기 훅

컴포넌트 인스턴스는 생성 → 마운트 → 업데이트 → 언마운트의 생명주기를 거친다. 각 단계에 훅을 등록해 코드를 실행할 수 있다.

```
생성: setup() / beforeCreate, created
  ↓
마운트: onBeforeMount → onMounted
  ↓
업데이트: onBeforeUpdate → onUpdated
  ↓
언마운트: onBeforeUnmount → onUnmounted
```

**자주 쓰는 훅**

```js
import { onMounted, onUpdated, onUnmounted } from 'vue'

onMounted(() => {
  // DOM 접근 가능, API 호출, 외부 라이브러리 초기화
  console.log('마운트 완료')
})

onUpdated(() => {
  // 반응형 상태 변경 후 DOM이 업데이트될 때마다
})

onUnmounted(() => {
  // 타이머 정리, 이벤트 리스너 제거, 구독 해제
})
```

> 💡 훅은 반드시 `setup()` 또는 `<script setup>` 내에서 **동기적**으로 등록해야 한다. `setTimeout` 안에서 등록하면 동작하지 않는다.

---

### 📌 컴포넌트 기초

**컴포넌트 정의와 사용**

```vue
<!-- ButtonCounter.vue -->
<script setup>
import { ref } from 'vue'
const count = ref(0)
</script>

<template>
  <button @click="count++">{{ count }}번 클릭됨</button>
</template>
```

```vue
<!-- App.vue -->
<script setup>
import ButtonCounter from './ButtonCounter.vue'
// <script setup>에서 import하면 자동으로 템플릿에서 사용 가능
</script>

<template>
  <ButtonCounter />
  <ButtonCounter /> <!-- 각 인스턴스는 독립적인 상태를 가짐 -->
</template>
```

**Props — 부모 → 자식 데이터 전달**

```vue
<!-- BlogPost.vue -->
<script setup>
defineProps(['title']) // 또는 defineProps({ title: String })
</script>

<template>
  <h4>{{ title }}</h4>
</template>
```

```html
<!-- 사용 -->
<BlogPost title="Vue 3 시작하기" />
<BlogPost :title="post.title" /> <!-- 동적 값은 v-bind -->
```

**Emit — 자식 → 부모 이벤트 전달**

```vue
<!-- 자식 컴포넌트 -->
<script setup>
const emit = defineEmits(['enlarge-text'])
</script>

<template>
  <button @click="emit('enlarge-text')">텍스트 확대</button>
</template>
```

```html
<!-- 부모 컴포넌트 -->
<BlogPost @enlarge-text="postFontSize += 0.1" />
```

**Slot — 콘텐츠 분배**

```vue
<!-- AlertBox.vue -->
<template>
  <div class="alert-box">
    <strong>오류!</strong>
    <slot /> <!-- 부모가 전달한 콘텐츠가 여기에 들어감 -->
  </div>
</template>
```

```html
<AlertBox>
  Something bad happened.
</AlertBox>
```

**동적 컴포넌트 — `<component :is>`**

```html
<!-- currentTab이 바뀌면 컴포넌트가 전환됨 -->
<component :is="tabs[currentTab]"></component>
```

> 💡 `<component :is>`로 전환 시 기존 컴포넌트는 언마운트된다. 상태를 유지하려면 `<KeepAlive>`로 감싸면 된다.

---

## 3. 종합 예제

/**
 * Phase 1의 핵심 개념을 모두 담은 TodoList 예제다.
 * ref, computed, watch, v-for, v-if, v-model, emit을 함께 사용한다.
 */

```vue
<!-- TodoList.vue -->
<script setup>
import { ref, computed, watch } from 'vue'

const newTodo = ref('')
const todos = ref([
  { id: 1, text: 'Vue 3 공식 문서 읽기', done: false },
  { id: 2, text: 'Phase 1 포스트 작성', done: false }
])

// computed: 완료되지 않은 항목 수
const remaining = computed(() =>
  todos.value.filter(t => !t.done).length
)

// watch: todos 변경 시 localStorage에 저장
watch(todos, (newTodos) => {
  localStorage.setItem('todos', JSON.stringify(newTodos))
}, { deep: true })

function addTodo() {
  if (!newTodo.value.trim()) return
  todos.value.push({
    id: Date.now(),
    text: newTodo.value,
    done: false
  })
  newTodo.value = ''
}

function removeTodo(id) {
  todos.value = todos.value.filter(t => t.id !== id)
}
</script>

<template>
  <div>
    <h2>할 일 목록 (남은 것: {{ remaining }}개)</h2>

    <!-- v-model로 입력 바인딩 -->
    <input v-model="newTodo" @keyup.enter="addTodo" placeholder="할 일 추가" />
    <button @click="addTodo">추가</button>

    <!-- v-for + :key -->
    <ul>
      <li v-for="todo in todos" :key="todo.id">
        <!-- v-model로 체크박스 바인딩 -->
        <input type="checkbox" v-model="todo.done" />
        <!-- :class로 동적 스타일 -->
        <span :class="{ done: todo.done }">{{ todo.text }}</span>
        <button @click="removeTodo(todo.id)">삭제</button>
      </li>
    </ul>

    <!-- v-if로 조건부 렌더링 -->
    <p v-if="remaining === 0">🎉 모든 할 일 완료!</p>
    <p v-else>아직 {{ remaining }}개 남았어요.</p>
  </div>
</template>

<style scoped>
.done {
  text-decoration: line-through;
  color: gray;
}
</style>
```

---

## 4. 정리

- `createApp(App).mount('#app')`으로 Vue 앱이 시작된다.
- 반응형 상태는 `ref()`(원시값)와 `reactive()`(객체)로 선언한다. 공식 권장은 `ref()` 기본 사용.
- 파생 값은 `computed`, 부수 효과는 `watch`/`watchEffect`를 사용한다.
- `v-if`는 DOM 생성/삭제, `v-show`는 CSS 토글이다. 자주 토글하면 `v-show`, 그 외엔 `v-if`.
- `v-for`에는 반드시 `:key`를 붙인다. `v-if`와 같은 요소에 쓰지 않는다.
- `v-model`은 `:value + @input`의 축약이다. `.lazy`, `.number`, `.trim` 수식자로 동작을 조정할 수 있다.
- 생명주기 훅은 `<script setup>` 안에서 동기적으로 등록해야 한다.
- 컴포넌트는 props(부모→자식), emit(자식→부모), slot(콘텐츠 분배)으로 소통한다.

---

## 5. 참고 자료

- [Vue 3 공식 문서 - 애플리케이션 생성](https://ko.vuejs.org/guide/essentials/application)
- [Vue 3 공식 문서 - 템플릿 문법](https://ko.vuejs.org/guide/essentials/template-syntax)
- [Vue 3 공식 문서 - 반응성 기초](https://ko.vuejs.org/guide/essentials/reactivity-fundamentals)
- [Vue 3 공식 문서 - 계산된 속성](https://ko.vuejs.org/guide/essentials/computed)
- [Vue 3 공식 문서 - 조건부 렌더링](https://ko.vuejs.org/guide/essentials/conditional)
- [Vue 3 공식 문서 - 리스트 렌더링](https://ko.vuejs.org/guide/essentials/list)
- [Vue 3 공식 문서 - 이벤트 처리](https://ko.vuejs.org/guide/essentials/event-handling)
- [Vue 3 공식 문서 - 폼 입력 바인딩](https://ko.vuejs.org/guide/essentials/forms)
- [Vue 3 공식 문서 - Watchers](https://ko.vuejs.org/guide/essentials/watchers)
- [Vue 3 공식 문서 - 템플릿 ref](https://ko.vuejs.org/guide/essentials/template-refs)
- [Vue 3 공식 문서 - 생명주기 훅](https://ko.vuejs.org/guide/essentials/lifecycle)
- [Vue 3 공식 문서 - 컴포넌트 기초](https://ko.vuejs.org/guide/essentials/component-basics)
