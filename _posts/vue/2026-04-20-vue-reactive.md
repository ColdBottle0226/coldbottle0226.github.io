---
title: "반응성과 템플릿 문법"
date: 2026-04-20 10:30:00 +0900
categories: [Vue.js]
tags: [Vue3, ref, reactive, computed, 템플릿문법, v-bind, v-for, v-model]
---

Vue 3를 쓰기 시작했을 때 가장 먼저 만나는 것이 `ref`와 `reactive`다. `.value`를 붙여야 하는지 말아야 하는지, `v-bind`와 `v-on`을 왜 `:`, `@`로 줄여 쓰는지, `v-for`에 왜 `:key`가 필수인지. 이 글은 그 물음들에 하나씩 답한다.

---

## 1. 개요

### 📌 Phase 1에서 다루는 것

```
1. 반응성 핵심  — ref, reactive, computed, 반응성 원리
2. 템플릿 문법  — 보간법, v-bind, v-on, v-if/v-show, v-for, v-model
```

모든 Vue 앱의 기반이 되는 개념이다. 이 두 가지를 확실히 이해해야 이후 컴포넌트 설계나 Composable 작성이 자연스럽게 따라온다.

---

## 2. 반응성 핵심

### 📌 ref() — 원시값 반응형

`ref()`는 원시값(number, string, boolean 등)을 반응형으로 감싸는 함수다. 반환값은 `.value` 프로퍼티를 가진 객체다.

```vue
<script setup>
import { ref } from 'vue'

const count = ref(0)       // RefImpl { value: 0 }
const name = ref('Chan')   // RefImpl { value: 'Chan' }

// script 안에서는 .value로 접근
count.value++
name.value = 'Admin'
</script>

<template>
  <!-- 템플릿 안에서는 자동 언래핑 — .value 불필요 -->
  <p>{{ count }} / {{ name }}</p>
</template>
```

> 💡 템플릿에서 `{{ count }}`로 쓸 수 있는 이유는 Vue가 컴파일 타임에 자동 언래핑(auto-unwrap)을 처리하기 때문이다. script 내부에서는 반드시 `.value`를 붙여야 한다. (출처: vuejs.org/guide/essentials/reactivity-fundamentals)

### 📌 reactive() — 객체 반응형

`reactive()`는 객체 전체를 Proxy로 감싸 반응형으로 만든다. `.value` 없이 직접 프로퍼티에 접근한다.

```vue
<script setup>
import { reactive } from 'vue'

const user = reactive({
  name: 'Chan',
  role: 'developer',
  settings: {
    theme: 'dark'  // 중첩 객체도 자동으로 반응형
  }
})

// .value 없이 직접 접근
user.name = 'Admin'
user.settings.theme = 'light'

// 주의: 객체 통째로 교체하면 반응성이 끊긴다
// user = { name: 'New' }  ← 이렇게 하면 안 됨
</script>
```

> 💡 reactive()의 대표적인 함정은 구조 분해 할당이다. `const { name } = user`처럼 분해하면 반응성이 끊긴다. `toRefs(user)`를 사용하면 ref로 변환되어 반응성을 유지할 수 있다.

### 📌 ref vs reactive — 언제 무엇을 쓸까

| 상황 | 권장 |
|------|------|
| 숫자, 문자, boolean 단일 값 | `ref()` |
| 여러 관련 상태를 묶어서 관리 | `reactive()` |
| 컴포저블에서 반환하는 상태 | `ref()` (구조 분해 시 toRefs 필요 없음) |
| 외부에서 통째로 교체할 가능성 있는 경우 | `ref()` |

실무에서는 **`ref()` 하나로 통일**하는 팀이 많다. 모든 타입에 쓸 수 있고, 코드 일관성이 높아지기 때문이다.

### 📌 computed() — 파생 값과 캐싱

/**
 * computed()는 다른 반응형 상태로부터 파생된 값을 선언한다.
 * 의존하는 반응형 값이 변경될 때만 재계산된다. (캐싱)
 * 사이드이펙트가 없는 순수한 계산에만 사용해야 한다.
 */

```vue
<script setup>
import { ref, computed } from 'vue'

const items = ref([
  { id: 1, name: '사과', done: true },
  { id: 2, name: '바나나', done: false },
  { id: 3, name: '체리', done: true }
])

// 읽기 전용 computed
const doneItems = computed(() =>
  items.value.filter(item => item.done)
)

// doneItems.value → [{ name: '사과' }, { name: '체리' }]
// items가 바뀌지 않으면 doneItems는 캐시된 값을 반환

// 읽기/쓰기 가능한 computed
const fullName = computed({
  get() { return `${firstName.value} ${lastName.value}` },
  set(val) {
    const [first, ...last] = val.split(' ')
    firstName.value = first
    lastName.value = last.join(' ')
  }
})
</script>
```

> 💡 computed vs method의 차이: method는 호출할 때마다 함수를 실행한다. computed는 의존하는 반응형 값이 변경될 때만 재계산하고 그 결과를 캐싱한다. 같은 값을 여러 곳에서 참조한다면 computed가 훨씬 효율적이다.

---

## 3. 템플릿 문법

### 📌 텍스트 보간과 디렉티브 기초

```vue
<template>
  <!-- 텍스트 보간: {{ }} -->
  <p>{{ message }}</p>

  <!-- v-html: HTML 렌더링 (XSS 주의, 신뢰할 수 있는 데이터에만 사용) -->
  <div v-html="rawHtml"></div>

  <!-- v-bind: 속성 바인딩 (단축: :) -->
  <img :src="imageUrl" :alt="imageAlt" />
  <div :class="{ active: isActive, 'text-danger': hasError }"></div>
  <div :style="{ color: textColor, fontSize: fontSize + 'px' }"></div>

  <!-- 동적 속성 이름 -->
  <button :[dynamicAttr]="value">버튼</button>
</template>
```

### 📌 v-on — 이벤트 처리

/**
 * v-on (단축: @)으로 DOM 이벤트를 리스닝한다.
 * 이벤트 수식어(modifier)로 preventDefault, stopPropagation 등을 선언적으로 처리할 수 있다.
 */

```vue
<template>
  <!-- 기본 이벤트 바인딩 -->
  <button @click="handleClick">클릭</button>

  <!-- 인라인 핸들러 -->
  <button @click="count++">+1</button>

  <!-- 이벤트 객체 전달 -->
  <button @click="handleClick($event)">클릭</button>

  <!-- 이벤트 수식어 -->
  <form @submit.prevent="onSubmit">   <!-- preventDefault -->
  <div @click.stop="doThis">          <!-- stopPropagation -->
  <input @keyup.enter="search" />     <!-- 키 수식어 -->
  <button @click.once="doOnce">       <!-- 한 번만 -->

  <!-- 여러 이벤트 동시에 -->
  <input @focus="onFocus" @blur="onBlur" />
</template>
```

### 📌 v-if / v-show — 조건 렌더링

```vue
<template>
  <!-- v-if: 조건이 false면 DOM에서 완전히 제거 -->
  <p v-if="isLoggedIn">로그인됨</p>
  <p v-else-if="isGuest">게스트</p>
  <p v-else>로그아웃 상태</p>

  <!-- v-show: 항상 DOM에 존재, display: none으로 토글 -->
  <div v-show="isVisible">보임/숨김</div>

  <!-- template으로 여러 요소를 그룹핑 (DOM에 렌더링 안 됨) -->
  <template v-if="isLoggedIn">
    <h1>환영합니다</h1>
    <p>{{ userName }}</p>
  </template>
</template>
```

> 💡 v-if vs v-show 선택 기준: 토글 빈도가 높으면 `v-show` (DOM은 유지, display만 토글). 초기 렌더링 시 조건이 false면 `v-if` (DOM 자체를 생성하지 않아 초기 비용 절감). 컴포넌트가 포함된 경우 `v-if`는 mount/unmount를 반복하므로 생명주기 훅이 매번 실행된다.

### 📌 v-for — 리스트 렌더링

/**
 * v-for는 배열이나 객체를 순회해 반복 렌더링한다.
 * :key는 Vue가 가상 DOM에서 노드를 효율적으로 식별하기 위해 반드시 필요하다.
 * index를 key로 쓰면 정렬/필터 시 예상치 못한 버그가 생기므로, 고유 id를 사용해야 한다.
 */

```vue
<script setup>
import { ref } from 'vue'
const todos = ref([
  { id: 1, text: '공부하기', done: false },
  { id: 2, text: '운동하기', done: true }
])
const userMap = reactive({ name: 'Chan', role: 'dev' })
</script>

<template>
  <!-- 배열 순회 -->
  <li v-for="todo in todos" :key="todo.id">
    {{ todo.text }} — {{ todo.done ? '완료' : '진행중' }}
  </li>

  <!-- index도 받기 -->
  <li v-for="(todo, index) in todos" :key="todo.id">
    {{ index + 1 }}. {{ todo.text }}
  </li>

  <!-- 객체 순회 -->
  <li v-for="(value, key) in userMap" :key="key">
    {{ key }}: {{ value }}
  </li>

  <!-- 숫자 범위 -->
  <span v-for="n in 5" :key="n">{{ n }}</span>
</template>
```

### 📌 v-model — 양방향 바인딩

/**
 * v-model은 v-bind와 v-on의 조합으로 만들어진 문법 설탕이다.
 * <input v-model="text" />는
 * <input :value="text" @input="text = $event.target.value" />와 동일하다.
 */

```vue
<script setup>
import { ref } from 'vue'
const text = ref('')
const checked = ref(false)
const selected = ref('A')
const multiSelected = ref([])
</script>

<template>
  <!-- 텍스트 입력 -->
  <input v-model="text" />
  <p>입력: {{ text }}</p>

  <!-- 체크박스 -->
  <input type="checkbox" v-model="checked" />
  <span>{{ checked ? '체크됨' : '미체크' }}</span>

  <!-- 셀렉트 -->
  <select v-model="selected">
    <option value="A">A</option>
    <option value="B">B</option>
  </select>

  <!-- v-model 수식어 -->
  <input v-model.trim="text" />      <!-- 앞뒤 공백 제거 -->
  <input v-model.number="count" />   <!-- 숫자로 자동 변환 -->
  <input v-model.lazy="text" />      <!-- change 이벤트에 동기화 -->
</template>
```

---

## 4. 트러블슈팅

### 📌 반응성이 동작하지 않는 흔한 실수

```javascript
// 1. reactive 구조 분해 → 반응성 끊김
const state = reactive({ count: 0 })
let { count } = state      // ← count는 이제 반응형이 아님
count++                    // UI 업데이트 안 됨

// 해결: toRefs 사용
import { toRefs } from 'vue'
const { count } = toRefs(state)  // count는 ref가 됨
count.value++              // ← 정상 동작

// 2. ref 배열에 새 값 push할 때
const list = ref([1, 2, 3])
list.value.push(4)         // ← 정상 (배열 메서드는 반응성 유지)
list.value = [...list.value, 4]  // ← 이것도 정상 (재할당)

// 3. reactive 객체 통째 교체 → 반응성 끊김
let user = reactive({ name: 'Chan' })
user = reactive({ name: 'New' })   // ← 기존 참조를 잃어 반응성 끊김
// 해결: ref로 감싸거나, 프로퍼티를 개별 업데이트
```

### 📌 v-for에서 key를 잘못 쓰는 경우

```vue
<!-- 나쁜 예: index를 key로 사용 -->
<li v-for="(item, index) in items" :key="index">
  <!-- 배열이 정렬되거나 중간에 아이템이 삽입되면 key가 뒤바뀌어 버그 발생 -->
</li>

<!-- 좋은 예: 고유 id를 key로 사용 -->
<li v-for="item in items" :key="item.id">
  {{ item.name }}
</li>
```

---

## 5. 정리

- `ref()`는 원시값, `reactive()`는 객체에 사용한다. 단순화하고 싶다면 `ref()` 하나로 통일해도 된다.
- `computed()`는 사이드이펙트 없이 순수하게 파생 값을 계산할 때 사용하며, 자동 캐싱된다.
- `v-if`는 DOM 제거, `v-show`는 display 토글이다. 토글 빈도가 높으면 `v-show`, 초기 조건이 false면 `v-if`.
- `v-for`에는 반드시 고유한 `:key`를 지정한다. index는 key로 쓰지 않는다.
- `v-model`은 `v-bind + v-on`의 문법 설탕이며, `.trim`, `.number`, `.lazy` 수식어로 동작을 조정할 수 있다.

---

## 6. 참고 자료

- [Vue 3 공식 문서 - Reactivity Fundamentals](https://vuejs.org/guide/essentials/reactivity-fundamentals)
- [Vue 3 공식 문서 - Computed Properties](https://vuejs.org/guide/essentials/computed)
- [Vue 3 공식 문서 - Template Syntax](https://vuejs.org/guide/essentials/template-syntax)
- [Vue 3 공식 문서 - Conditional Rendering](https://vuejs.org/guide/essentials/conditional)
- [Vue 3 공식 문서 - List Rendering](https://vuejs.org/guide/essentials/list)
- [Vue 3 공식 문서 - Event Handling](https://vuejs.org/guide/essentials/event-handling)
- [Vue 3 공식 문서 - Form Input Bindings](https://vuejs.org/guide/essentials/forms)