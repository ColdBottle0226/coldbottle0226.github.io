---
title: "딥링크 완전 정복 - URI 스킴, Intent 스킴, Universal Link, App Link"
date: 2026-02-25 00:00:00 +0900
categories: [Mobile, DeepLink]
tags: [deeplink, uri-scheme, intent-scheme, universal-link, app-link, android, ios, 딥링크]
---

##  1. 개요

---

서비스를 운영하다 보면 "앱으로 바로 연결해줘"라는 요구사항을 자주 마주친다.

마케팅팀에서 카카오톡에 공유하는 링크를 클릭했을 때 앱이 바로 열리길 원하거나, 이메일로 특정 상품 링크를 보냈을 때 앱 설치 사용자는 해당 상품 상세 화면으로 바로 이동했으면 한다는 요구다.

이걸 구현하는 기술이 **딥링크(Deep Link)**다. 그런데 막상 구현하려고 찾아보면 URI 스킴, Intent 스킴, Universal Link, App Link 등 용어가 너무 많아서 뭘 써야 할지 헷갈린다.

이번 글에서는 각 딥링크 방식의 개념과 동작 원리, 예시 코드를 정리한다.

### 📌 딥링크란?

**딥링크(Deep Link)**는 사용자를 특정 모바일 앱의 원하는 화면이나 콘텐츠로 **직접 연결**해주는 링크다.

일반 웹 링크가 특정 웹페이지로 이동시키듯, 딥링크는 특정 URL 클릭 시 **곧바로 앱을 실행하고 앱 내 지정된 화면으로 바로 이동**시킨다.

> 예를 들어 이커머스 앱에서 특정 상품의 딥링크를 카카오톡으로 공유하면, 수신자가 링크를 클릭하는 순간 앱이 열리며 해당 상품 상세 화면으로 바로 이동한다.

### 📌 딥링크 유형 한눈에 비교

| 방식 | 플랫폼 | URL 형태 | 앱 미설치 시 | 보안/안정성 |
|------|--------|---------|-----------|------------|
| **URI 스킴** | Android / iOS | `scheme://path` | 아무 동작 없음 | 낮음 |
| **Intent 스킴** | Android 전용 | `intent://path#Intent;...` | fallback URL로 이동 | 낮음 |
| **Universal Link** | iOS 전용 | `https://domain/path` | 웹으로 열림 | 높음 |
| **App Link** | Android 전용 | `https://domain/path` | 웹으로 열림 | 높음 |

---

##  2. URI 스킴 (URI Scheme)

---

### 📌 개념

**URI 스킴**은 딥링크의 가장 전통적인 방식이다. 앱마다 고유한 스킴 이름을 등록해두고, 해당 스킴으로 시작하는 URL을 클릭하면 OS가 대응되는 앱을 실행한다.

Android(`AndroidManifest.xml`)와 iOS(`Info.plist`) 모두 지원하며, 구현이 가장 단순하다는 게 장점이다. 다만 오래된 방식인 만큼 단점도 많다.

### 📌 URL 구조

```
{scheme}://{path}?{query}
```

| 요소 | 설명 | 필수 |
|------|------|------|
| `scheme` | 앱 고유 이름 (ex. `myapp`) | O |
| `path` | 앱 내 화면 경로 (ex. `/open`) | O |
| `query` | 추가 파라미터 (ex. `?id=123`) | - |

```
// 예시 - myapp 앱을 열고 특정 페이지로 이동
myapp://open?targeturl=https%3A%2F%2Fexample.com%2Fproduct%2F123
```

> 💡 `targeturl` 파라미터 값은 반드시 **URL 인코딩**된 형태여야 한다. `encodeURIComponent()`를 쓰면 된다.

### 📌 Android/iOS 등록 방법

**iOS - Info.plist**

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

**Android - AndroidManifest.xml**

```xml
<activity android:name=".MainActivity">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" />
  </intent-filter>
</activity>
```

### 📌 동작 흐름

[![image](/assets/images/deeplink/image1.svg)](/assets/images/deeplink/image1.svg)

### 📌 웹에서 앱 열기

가장 기본적인 방법은 `<a>` 태그나 `window.location`을 쓰는 것이다.

```html
<!-- 단순 링크 -->
<a href="myapp://open?targeturl=https%3A%2F%2Fexample.com">앱에서 열기</a>
```

하지만 앱이 설치되지 않은 경우 아무 반응이 없기 때문에, **스토어로 이동시키는 fallback 로직**을 함께 구현해야 한다.

```javascript
function openMyApp() {
  const androidPackageName = 'com.example.myapp';
  const appleAppStoreId   = '1234567890';
  const scheme    = 'myapp';
  const targetUrl = encodeURIComponent('https://example.com/product/123');
  const schemeUrl = `${scheme}://open?targeturl=${targetUrl}`;

  // 기기 OS 판별
  const ua = window.navigator.userAgent || '';
  let storeUrl = `https://apps.apple.com/app/id${appleAppStoreId}`;
  if (/android/i.test(ua)) {
    storeUrl = `https://play.google.com/store/apps/details?id=${androidPackageName}`;
  }

  // 앱 스킴 호출
  window.location = schemeUrl;

  // 1.5초 후에도 화면이 그대로면 앱 미설치로 판단 → 스토어로 이동
  const timer = setTimeout(() => {
    window.location.href = storeUrl;
  }, 1500);

  // 앱이 열리면 페이지가 background로 전환됨 → visibilitychange 이벤트 발생
  window.addEventListener('visibilitychange', () => {
    clearTimeout(timer);
  });
}
```

### 📌 URI 스킴의 한계

> ⚠️ URI 스킴은 단순하지만 아래 세 가지 한계가 있다.

1. **앱 미설치 시 아무 동작 없음** - fallback을 직접 구현해야 한다.
2. **스킴 이름 고유성 미보장** - 다른 앱이 같은 스킴을 쓰면 충돌한다. 악의적인 앱이 유명 앱의 스킴을 가로채는 보안 이슈도 있다.
3. **iOS Safari 문제** - `visibilitychange` 이벤트가 정상적으로 발생하지 않아 앱이 열렸음에도 스토어로 강제 이동되는 버그가 발생한다. iOS에서는 Universal Link를 쓰는 게 훨씬 낫다.

---

##  3. Intent 스킴 (Intent Scheme)

---

### 📌 개념

**Intent 스킴**은 **Android 전용** 딥링크 방식이다. 일반 URI 스킴과 유사하지만, **앱 미설치 시 처리(fallback)까지 URL 하나에 담을 수 있다**는 게 핵심 차이점이다.

주로 **Chrome 브라우저**에서 지원하며, 웹에서 Android 앱으로 전환하는 용도로 많이 쓰인다.

### 📌 URL 구조

```
intent://{경로}#Intent;
    scheme={URI스킴명};
    package={패키지명};
    S.browser_fallback_url={대체URL(인코딩)};
end;
```

| 파라미터 | 설명 | 필수 |
|---------|------|------|
| `scheme` | 앱 URI 스킴 이름 | O |
| `package` | 앱 패키지명 | O |
| `S.browser_fallback_url` | 앱 미설치 시 이동할 URL | - (없으면 오류 화면) |

### 📌 동작 흐름

[![image](/assets/images/deeplink/image2.svg)](/assets/images/deeplink/image2.svg)

### 📌 예시 코드

```html
<a
  href="intent://open#Intent;
  scheme=myapp;
  package=com.example.myapp;
  S.browser_fallback_url=https%3A%2F%2Fplay.google.com%2Fstore%2Fapps%2Fdetails%3Fid%3Dcom.example.myapp;
  end;"
>
  앱에서 열기
</a>
```

앱이 있으면 `myapp://open`으로 앱을 실행하고, 없으면 Play 스토어 페이지로 자동 이동한다. JS 타이머 없이 `<a>` 태그 하나로 앱 미설치 처리까지 해결할 수 있어 편리하다.

> 💡 `S.`로 시작하는 파라미터는 Intent에 **Extra 데이터**를 담는 Android 문법이다. `browser_fallback_url`은 Chrome이 특별하게 처리하는 reserved key다.

### 📌 주의 사항

> ⚠️ Intent 스킴 사용 시 주의할 점들이다.

- **Android + Chrome 전용** - iOS에서는 인식 자체가 안 된다.
- **사용자 직접 클릭 필요** - JS로 자동 실행(`window.location = 'intent://...'`)하면 보안상 Chrome이 차단한다.
- 삼성 인터넷, 일부 구형 브라우저에서는 동작하지 않을 수 있다.

---

##  4. 유니버셜 링크 (Universal Link)

---

### 📌 개념

**Universal Link**는 **Apple이 iOS 9에서 도입한 iOS 전용 표준 딥링크 방식**이다.

URI 스킴처럼 `myapp://` 같은 특수한 URL이 아니라, **일반 HTTPS URL**로 앱과 웹을 함께 연결한다. 앱이 설치된 경우엔 앱으로, 미설치된 경우엔 같은 URL의 웹페이지로 자연스럽게 분기된다.

도메인 소유권 인증을 기반으로 하기 때문에, 다른 앱이 링크를 가로채는 게 원천적으로 불가능하다. URI 스킴의 보안 문제를 해결한 Apple의 공식 대안이다.

### 📌 동작 원리

Universal Link가 동작하려면 **앱 측 설정**과 **웹 서버 측 설정** 두 가지가 모두 필요하다.

[![image](/assets/images/deeplink/image3.svg)](/assets/images/deeplink/image3.svg)

### 📌 AASA 파일 (apple-app-site-association)

서버의 `/.well-known/apple-app-site-association` 경로에 아래 JSON 파일을 배포해야 한다.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID1234.com.example.myapp",
        "paths": ["/product/*", "/event/*", "/*"]
      }
    ]
  }
}
```

| 필드 | 설명 |
|------|------|
| `appID` | Apple Team ID + `.` + Bundle ID 조합 |
| `paths` | Universal Link로 처리할 경로 패턴. `/*`는 전체 경로 |

> ⚠️ 파일 배포 시 주의사항이다. 파일 확장자가 없어야 하고(`.json` 아님), `Content-Type: application/json`으로 제공해야 하며, 반드시 HTTPS로 호스팅되어야 한다.

### 📌 Xcode 설정

```
Xcode > [Target] > Signing & Capabilities > + Associated Domains 추가
→ applinks:example.com 입력
```

이 설정이 앱 빌드에 포함되어야, 앱 설치 시 OS가 해당 도메인과 앱을 연결한다.

### 📌 예시 코드

```html
<!-- 앱 실행 (설치 시) / 웹 오픈 (미설치 시) -->
<button onclick="location.href='https://example.com/product/123'">
  앱에서 보기
</button>

<!-- 특정 페이지 지정 (targeturl 파라미터) -->
<button onclick="location.href='https://example.com/open?targeturl=https%3A%2F%2Fexample.com%2Fproduct%2F123'">
  앱에서 보기
</button>
```

앱 링크와 Universal Link 모두 동일한 `targeturl` 파라미터로 특정 화면을 지정할 수 있다. 딥링크 도메인/경로와 실제로 앱에서 열어야 할 URL이 다를 때 유용하다.

### 📌 특징 및 주의점

**장점**

- 한 번 연결되면 이후 **팝업 없이 바로 앱 실행** (Safari 주소창에 앱 아이콘 표시됨)
- 도메인 인증 기반이므로 **다른 앱의 가로채기 불가**
- 앱 미설치 시 **동일 URL이 웹으로 열려** 사용자 경험이 끊기지 않음

> ⚠️ 주의할 점도 있다.

- `https://` 필수 - HTTP나 IP 주소로는 동작 안 함
- **사용자가 직접 링크를 터치해야만** 동작 - JS 자동 리디렉션이나 주소창 직접 입력으론 앱이 안 열림
- Instagram, 카카오톡 인앱 브라우저에서는 웹으로 열리는 경우가 많음

---

##  5. 앱 링크 (App Link)

---

### 📌 개념

**App Link**는 **Google이 Android 6.0(Marshmallow)에서 도입한 Android 공식 표준 딥링크**다.

iOS의 Universal Link와 완전히 동일한 개념이다. HTTPS 도메인 기반으로 앱-웹을 연결하고, 도메인 소유권 인증(`assetlinks.json`)을 통해 보안성을 확보한다.

### 📌 동작 원리

[![image](/assets/images/deeplink/image4.svg)](/assets/images/deeplink/image4.svg)

### 📌 assetlinks.json 파일

서버의 `/.well-known/assetlinks.json`에 배포한다.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.myapp",
      "sha256_cert_fingerprints": [
        "AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78"
      ]
    }
  }
]
```

> 💡 **Play 앱 서명을 사용하는 경우** 로컬 키스토어의 SHA256 지문이 아니라, **Google Play Console > 테스트 및 출시 > 앱 무결성 > 앱 서명**에서 제공하는 지문을 사용해야 한다. 이 둘이 달라서 App Link가 동작하지 않는 경우가 흔하다.

### 📌 AndroidManifest.xml 설정

```xml
<activity android:name=".MainActivity">
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
      android:scheme="https"
      android:host="example.com"
      android:pathPrefix="/product" />
  </intent-filter>
</activity>
```

`android:autoVerify="true"` 속성이 핵심이다. 이게 있어야 앱 설치 시 OS가 자동으로 `assetlinks.json`을 조회해 도메인 인증을 수행한다. 인증이 성공해야 팝업 없이 바로 앱이 열린다.

### 📌 URI 스킴 / Intent 스킴 / App Link 비교

| 구분 | URI 스킴 | Intent 스킴 | App Link |
|------|---------|------------|---------|
| URL 형태 | `scheme://path` | `intent://path` | `https://host/path` |
| 플랫폼 | Android / iOS | Android 전용 | Android 전용 |
| 안정성 | 낮음 | 낮음 | 높음 |
| 미설치 처리 | 없음 | fallback URL로 이동 | 웹으로 fallback |
| 도메인 인증 | 불필요 | 불필요 | 필요 |
| Android 최소 버전 | 제한 없음 | 제한 없음 | 6.0 이상 |

---

##  6. 앱 미설치 시 스토어 유도 전략

---

딥링크를 쓸 때 빠질 수 없는 주제가 "앱이 없는 사람은 어떻게 처리할 것인가"다.

| 방식 | 미설치 처리 방법 |
|------|----------------|
| **URI 스킴** | JS `setTimeout` + `visibilitychange`로 스토어 이동 |
| **Intent 스킴** | `S.browser_fallback_url`에 Play Store URL 지정 |
| **Universal Link** | 웹 페이지에 앱 설치 배너/버튼 노출 |
| **App Link** | 웹 페이지 리디렉션 또는 설치 배너 노출 |

Universal Link / App Link는 앱 미설치 시 웹이 그대로 열리기 때문에, **해당 도메인에 실제 웹 콘텐츠가 존재**해야 한다. 없으면 사용자가 빈 페이지를 보게 된다. 웹 페이지에서 앱 설치를 유도하는 배너를 띄우거나, 스토어로 리디렉션하는 방식으로 대응한다.

```javascript
// 앱 미설치 사용자를 스토어로 안내하는 웹 페이지 예시 (Universal Link / App Link fallback 웹)
window.addEventListener('DOMContentLoaded', () => {
  const ua = navigator.userAgent;

  // Android 기기 접속 시 → Play 스토어로
  if (/android/i.test(ua)) {
    window.location.href = 'https://play.google.com/store/apps/details?id=com.example.myapp';
    return;
  }

  // iOS 기기 접속 시 → App Store로
  if (/iphone|ipad|ipod/i.test(ua)) {
    window.location.href = 'https://apps.apple.com/app/id1234567890';
    return;
  }

  // 그 외 → 웹 콘텐츠 그대로 표시
});
```

---

##  7. 브라우저/앱별 동작 현황

---

설정을 올바르게 했어도 환경에 따라 동작이 달라진다. 특히 인앱 브라우저가 문제가 많다.

| 앱 / 브라우저 | Android | iOS |
|------------|---------|-----|
| **Chrome** | App Link 동작 / URI 스킴 동작 | Universal Link 동작 / URI 스킴 동작 |
| **Safari** | — | Universal Link 동작 / URI 스킴 팝업 발생 |
| **삼성 인터넷** | App Link 미동작(웹으로) / URI 스킴 동작 | — |
| **카카오톡** | App Link 미동작(웹으로) / URI 스킴 동작 | Universal Link 미동작(웹으로) / URI 스킴 동작 |
| **Instagram** | App Link 미동작(웹으로) / URI 스킴 동작 | Universal Link 미동작(웹으로) / URI 스킴 동작 |
| **iMessage** | — | Universal Link 동작 / URI 스킴 미동작 |
| **네이버** | App Link 동작 / URI 스킴 동작 | Universal Link 동작 / URI 스킴 동작 |

> 💡 Universal Link / App Link를 설정했는데 웹으로 열린다면, 딥링크가 제대로 동작하지 않은 것이다. 인앱 브라우저들이 OS의 API를 완전히 구현하지 않아서 발생하는 문제다. 이런 환경에서는 URI 스킴이 더 잘 동작하는 경우도 있다.

---

##  8. 어떤 방식을 써야 하나?

---

[![image](/assets/images/deeplink/image5.svg)](/assets/images/deeplink/image5.svg)

실제로는 Universal Link / App Link만으로는 커버가 안 되는 환경(카카오톡, Instagram 등)이 많아서, **두 방식을 병행하는 게 현실적**이다. 인앱 브라우저에서 URI 스킴으로 우선 시도하고, 공식 브라우저에선 Universal Link / App Link가 자동으로 처리되도록 구성하는 식이다.

---

##  9. 정리

---

이 글에서 다룬 딥링크 방식의 핵심을 한 줄로 요약하면 이렇다.

- **URI 스킴** - 가장 단순. `myapp://open`. 보안/안정성 낮고 fallback 직접 구현 필요. iOS Safari 버그 주의.
- **Intent 스킴** - Android + Chrome 전용. fallback을 URL 안에 내장할 수 있어 URI 스킴보다 편리.
- **Universal Link** - iOS 표준. HTTPS URL 기반. AASA 파일 + Associated Domains 설정 필요. 보안성/UX 최고.
- **App Link** - Android 표준. iOS의 Universal Link와 동일한 개념. assetlinks.json + autoVerify 설정 필요.

실무에서 가장 중요한 건 **"어떤 환경에서 링크가 사용되는가"**를 먼저 파악하는 것이다. 카카오톡, 이메일, 웹 광고 등 각 환경마다 지원하는 딥링크 방식이 다르기 때문에, 하나만 믿기보다는 여러 방식을 조합해서 최대한 많은 환경을 커버하는 전략이 필요하다.

---

## 참고 자료

- nachocode 딥링크 가이드: <https://developer.nachocode.io/docs/guide/deep-link/intro>
- Apple - Supporting Associated Domains: <https://developer.apple.com/documentation/xcode/supporting-associated-domains>
- Google - Digital Asset Links: <https://developers.google.com/digital-asset-links/v1/getting-started>
- Android Developer - Intents and Intent Filters: <https://developer.android.com/guide/components/intents-filters>
- Android Developer - Verify Android App Links: <https://developer.android.com/training/app-links/verify-android-applinks>
