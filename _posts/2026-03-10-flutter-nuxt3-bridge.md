---
title: Flutter InAppWebView + Nuxt3 JS 브릿지 통신 설계
date: 2026-03-10 10:00:00 +0900
categories: [Flutter, Nuxt3]
tags: [Flutter, InAppWebView, Nuxt3, Bridge, callHandler, JavaScript, 하이브리드앱, WebView]
---

## 📗 1. 개요

---

Flutter 앱 안에 Nuxt3 웹을 WebView로 띄우는 하이브리드 앱을 만들 때, 네이티브 기능(탭 열기/닫기, 기기 정보, 앱 정보 등)을 웹에서 호출해야 하는 상황이 생긴다.

이번 글에서는 Flutter InAppWebView와 Nuxt3 사이의 브릿지 통신을 어떻게 설계하는지 정리한다.

### 📌 전체 구조

| 방향 | 방법 | 용도 |
|---|---|---|
| JS → Flutter | `window.flutter_inappwebview.callHandler()` | 탭 열기/닫기, 기기 정보 요청 |
| Flutter → JS | `evaluateJavascript('window.receiveFromNative(...)')` | 데이터 전달, 이벤트 알림 |

---

## 📗 2. Flutter InAppWebView 기본 원리

---

Flutter `InAppWebView` 위젯은 앱 안에 웹 뷰를 띄운다. 웹뷰가 초기화되면 `flutter_inappwebview` 객체를 `window`에 자동으로 주입한다.

- 참고: https://inappwebview.dev/docs/webview/javascript/javascript-handlers/

### 📌 JS → Flutter: callHandler

웹에서 Flutter 쪽 함수를 호출하려면 `callHandler`를 사용한다.

```typescript
// JS 쪽
const result = await window.flutter_inappwebview.callHandler(
  'handlerName',  // Flutter에서 등록한 핸들러 이름
  { method: 'openTab', path: '/product/001' }
)
```

Flutter 쪽에서는 `addJavaScriptHandler`로 해당 핸들러를 등록해 둔다.

```dart
// Flutter 쪽
webViewController.addJavaScriptHandler(
  handlerName: 'handlerName',
  callback: (args) {
    final data = args[0];
    // data['method'], data['path'] 등으로 분기 처리
    return {'status': true};
  },
);
```

`callHandler`는 Promise를 반환하므로 `await`로 결과를 받을 수 있다.

### 📌 Flutter → JS: evaluateJavascript

Flutter에서 JS로 데이터를 전달하거나 이벤트를 발생시킬 때는 `evaluateJavascript`로 JS 코드를 직접 실행한다.

```dart
// Flutter 쪽
await webViewController.evaluateJavascript(
  source: "window.receiveFromNative('pushToken', { token: '$token' })"
);
```

JS 쪽에서는 `window.receiveFromNative`를 미리 정의해 둔다.

```typescript
// JS 쪽 (plugin에서 등록)
window.receiveFromNative = (type: string, data: any) => {
  console.log('[NativeBridge] Flutter 메시지 수신:', type, data)
  // type에 따라 분기 처리
}
```

---

## 📗 3. useNativeBridge 설계

---

Flutter/비Flutter 환경 분기를 매 호출마다 처리하면 코드가 지저분해진다. `useNativeBridge` 컴포저블로 분기를 한 곳에서 처리한다.

### 📌 환경 판별

`window.flutter_inappwebview` 객체의 존재 여부로 Flutter WebView 환경을 판별한다.

```typescript
const isFlutterWebView = (): boolean =>
  typeof window !== 'undefined' &&
  !!(window as any).flutter_inappwebview
```

### 📌 callFlutter 공통 래퍼

```typescript
const callFlutter = async (
  method: string,
  params: Record<string, any> = {}
): Promise<any | void> => {
  const args = { method, ...params }

  // Flutter WebView 환경: 실제 callHandler 통신
  if (isFlutterWebView()) {
    const result = await (window as any).flutter_inappwebview
      .callHandler(handlerName, args)
    if (result === undefined || result === null) return
    if (typeof result === 'string') {
      try { return JSON.parse(result) } catch { return result }
    }
    return result
  }

  // 비Flutter 환경 (모바일웹 / 로컬): 브라우저 API 또는 Mock
  if (method === 'openTab' && params.path) {
    // noopener: 새 탭의 sessionStorage를 부모 탭으로부터 격리
    window.open(`${window.location.origin}${params.path}`, '_blank', 'noopener')
    return { status: true }
  }
  if (method === 'closeTab') {
    window.close()
    return { status: true }
  }

  // 나머지 메서드는 Mock 응답
  const mock: Record<string, any> = {
    appInfo:    { status: true, data: { name: 'App', version: '1.0.0' } },
    deviceInfo: { status: true, data: { model: 'Unknown', os: 'Unknown' } },
    gotoHome:   { status: true },
  }
  return mock[method] ?? null
}
```

### 📌 공개 API

```typescript
const appInfo    = async () => await callFlutter('appInfo')
const deviceInfo = async () => await callFlutter('deviceInfo')
const openTab    = async (path: string) => await callFlutter('openTab', { path })
const closeTab   = async () => await callFlutter('closeTab')
const gotoHome   = async () => await callFlutter('gotoHome')
```

---

## 📗 4. window.open의 noopener와 sessionStorage 격리

---

모바일웹 환경에서 `openTab()`은 `window.open`으로 새 탭을 열어 Flutter 새 WebView 탭과 동일한 동작을 시뮬레이션한다.

기본 `window.open`은 부모 탭의 sessionStorage를 복사한다. 네비게이션 스택을 탭마다 독립적으로 관리하려면 `noopener`가 필수다.

```typescript
// noopener 없으면: 부모 탭 sessionStorage 복사됨
window.open(url, '_blank')

// noopener 있으면: 독립된 브라우징 컨텍스트 → sessionStorage 빈 상태로 시작
window.open(url, '_blank', 'noopener')
```

- 참고: https://developer.mozilla.org/en-US/docs/Web/API/Window/open#noopener

Flutter InAppWebView의 새 WebView 인스턴스는 항상 독립된 컨텍스트로 시작하므로, `noopener`를 지정한 `window.open`이 같은 동작을 재현한다.

### 📌 window.close() 제약

`window.close()`는 `window.open()`으로 열린 탭에서만 동작한다. 직접 URL을 입력해 진입한 탭에서는 브라우저 보안 정책상 차단된다.

```typescript
// 정상 동작: window.open()으로 열린 탭에서 닫기
window.close()

// 동작 안 함: 직접 URL 입력으로 진입한 탭에서 닫기
```

- 참고: https://developer.mozilla.org/en-US/docs/Web/API/Window/close

---

## 📗 5. Plugin에서 브릿지 초기화

---

`plugins/native-bridge.client.ts`에서 앱 초기화 시 브릿지 객체를 window에 노출한다.

```typescript
export default defineNuxtPlugin(() => {
  const bridge = useNativeBridge()

  // 컴포넌트 외부(Flutter evaluateJavascript 등)에서 직접 접근 가능하도록 노출
  ;(window as any).__webviewBridge = bridge

  // Flutter → JS 방향 수신 핸들러 등록
  ;(window as any).receiveFromNative = (type: string, data: any) => {
    console.log('[NativeBridge] Flutter 메시지 수신:', type, data)
  }
})
```

컴포넌트에서는 `useNativeBridge()`를 직접 호출해 사용한다.

```vue
<script setup lang="ts">
const { handleBack, handleHome } = useNavigationStack()
</script>

<template>
  <button @click="handleBack">←</button>
  <button @click="handleHome">🏠</button>
</template>
```

---

## 📗 6. Android 네이티브 뒤로가기와 WebView

---

Flutter 앱 안의 WebView에서 Android 네이티브 뒤로가기 버튼을 누르면, Flutter가 WebView에 `history.back()`을 전달한다.

```
Android 네이티브 뒤로가기
        ↓
Flutter: webViewController.goBack() 또는 history.back() 전달
        ↓
WebView: history.back() 실행 → popstate 이벤트 발생
        ↓
JS: popstate 리스너에서 처리
```

WebView의 히스토리가 없으면 Flutter 네이티브 레이어가 WebView를 닫는다. 이 경우 JS 개입 없이 Flutter가 알아서 처리한다.

- 참고: https://developer.android.com/guide/navigation/custom-back

---

## 📗 7. 플랫폼별 뒤로가기 동작 비교

---

| 케이스 | popstate 발생 | JS 처리 필요 |
|---|---|---|
| Android 브라우저 하단 버튼 | ✅ 발생 | 스택 pop |
| Android 네이티브 버튼 (Flutter 앱) | ✅ 발생 (히스토리 있을 때) | 스택 pop |
| Android 네이티브 버튼 (Flutter 앱, 히스토리 없음) | ❌ 미발생 | Flutter가 WebView 닫음 |
| iOS Safari 엣지 스와이프 (SPA) | ✅ 발생 | 스택 pop |
| iOS window.open 탭 뒤로가기 버튼 | ❌ 미발생 | iOS가 탭 닫고 opener 복귀 |
| iOS BFCache 복원 | ❌ 미발생 | sessionStorage 자동 복원 |

- SPA에서 iOS 스와이프가 popstate를 발생시키는 이유: https://github.com/w3c/csswg-drafts/issues/8333
- BFCache 동작 원리: https://web.dev/articles/bfcache

---

## 📗 8. 정리

---

- `window.flutter_inappwebview` 주입 여부로 Flutter 환경을 판별한다
- `callHandler`로 JS → Flutter 단방향 호출, `evaluateJavascript`로 Flutter → JS 단방향 호출로 양방향 통신을 구성한다
- 모바일웹 시뮬레이션은 `window.open(noopener)` / `window.close()`로 Flutter 새 탭 동작을 재현한다
- `noopener`는 sessionStorage 격리를 위해 필수다
- Android 네이티브 뒤로가기는 Flutter가 `history.back()`을 전달하므로 popstate로 처리하면 된다
- iOS의 `window.open` 탭 뒤로가기와 BFCache 복원은 JS 개입 없이 브라우저/OS가 처리한다

---

## 참고 자료
- Flutter InAppWebView - JavaScript Handlers: https://inappwebview.dev/docs/webview/javascript/javascript-handlers/
- MDN - window.open noopener: https://developer.mozilla.org/en-US/docs/Web/API/Window/open#noopener
- MDN - window.close: https://developer.mozilla.org/en-US/docs/Web/API/Window/close
- Android - Custom back navigation: https://developer.android.com/guide/navigation/custom-back
- W3C csswg - same-document traversal popstate: https://github.com/w3c/csswg-drafts/issues/8333
- web.dev - BFCache: https://web.dev/articles/bfcache
