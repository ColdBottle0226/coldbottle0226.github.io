---
title: SwiftUI 시작하기 - 개발 환경과 앱 구조 이해
date: 2026-03-19 00:00:00 +0900
categories: [Swift, SwiftUI]
tags: [Swift, Basic]
---

## 📗 1. 개요

---

Swift를 처음 시작할 때 가장 먼저 마주하는 것은 Xcode와 낯선 파일 구조다.
이번 글에서는 SwiftUI 프로젝트를 처음 생성했을 때 만들어지는 파일들의 역할,
App → Scene → View로 이어지는 계층 구조, 그리고 Android 개발자에게 익숙한
생명주기 개념이 SwiftUI에서는 어떻게 표현되는지 정리한다.

### 📌 전체 구성

| 챕터 | 주제 |
|------|------|
| Ch01 | Xcode 프로젝트 구조 & 파일 역할 |
| Ch02 | App → Scene → View 계층 구조 |
| Ch03 | 앱 생명주기 & 뷰 생명주기 |

---

## 📗 2. Xcode 프로젝트 구조

---

### 📌 자동 생성 파일 역할

SwiftUI 프로젝트를 생성하면 다음 파일들이 자동으로 만들어진다.

| 파일 | 역할 | 웹 대응 개념 |
|------|------|-------------|
| `MyApp.swift` | 앱 진입점, @main 어노테이션 | `main.js` |
| `ContentView.swift` | 첫 번째 화면 (루트 뷰) | `pages/index.vue` |
| `Assets.xcassets` | 이미지, 색상 팔레트 | `public/` 폴더 |
| `Info.plist` | 앱 설정, 권한 선언 | `manifest.json` |
| `Preview Content` | Canvas 전용 리소스 | Storybook 전용 목업 |

> 💡 Info.plist는 카메라, 마이크, Face ID 등 권한을 반드시 여기서 선언해야 한다.
> 선언 없이 권한을 요청하면 앱이 크래시 난다.

### 📌 MyApp.swift — 전체 코드 해설

/**
 * @main 어노테이션이 붙은 구조체가 앱 전체의 시작점이 된다.
 * 프로젝트 전체에서 딱 한 곳에만 존재해야 한다.
 */

```swift
import SwiftUI        // SwiftUI 프레임워크 — 모든 UI 타입이 여기 있음

@main                 // 앱 시작점 선언. 프로젝트에 하나만 존재
struct MyApp: App {   // App 프로토콜 채택 — class가 아닌 struct
    var body: some Scene {        // 어떤 Scene으로 구성할지 반환
        WindowGroup {             // iOS 앱의 창(window) 정의
            ContentView()         // 루트 뷰 — 앱 실행 시 첫 화면
        }
    }
}
```

### 📌 ContentView.swift — 전체 코드 해설

/**
 * View 프로토콜을 채택한 struct가 화면 하나를 담당한다.
 * body는 저장된 값이 없는 연산 프로퍼티로, 상태가 바뀔 때마다 재실행된다.
 */

```swift
import SwiftUI

struct ContentView: View {           // View 프로토콜 채택 — 화면에 그릴 수 있는 뷰
    var body: some View {            // 필수 요구사항 — 실제 UI를 반환하는 연산 프로퍼티
        VStack {                     // 수직 배치 컨테이너
            Image(systemName: "globe")
                .imageScale(.large)  // 모디파이어 — 뷰 속성을 체이닝으로 추가
                .foregroundStyle(.tint)
            Text("Hello, World!")
        }
        .padding()                   // VStack 전체에 여백 추가
    }
}

#Preview {            // Canvas Preview 전용 블록 — 앱 빌드에 포함 안 됨
    ContentView()
}
```

> 💡 `some View`의 `some`은 "컴파일러가 타입을 추론할 테니 큰 타입만 알려줘"라는
> 뜻이다. TypeScript의 타입 추론과 유사하다. 처음엔 관용구로 외우고 넘어간다.

### 📌 Xcode 화면 구성

| 영역 | 역할 | 웹 대응 |
|------|------|---------|
| 좌측 Navigator | 파일 탐색기 | VS Code 사이드바 |
| 중앙 Editor | 코드 편집 + Canvas Preview | 에디터 |
| 우측 Inspector | 선택 요소 속성 | - |
| 하단 Console | print() 출력, 에러 확인 | 개발자 도구 Console |

주요 단축키: `Cmd+B` 빌드, `Cmd+R` 실행, `Cmd+.` 중지, `Option+Cmd+Return` Canvas 활성화.

---

## 📗 3. App → Scene → View 계층 구조

---

SwiftUI 앱은 항상 세 계층으로 구성된다.

| 계층 | 역할 | 웹 대응 |
|------|------|---------|
| `App` | 전체 진입점, 전역 설정 | `createApp().mount()` |
| `Scene` | 화면이 표시되는 창 단위 | `app.vue`의 루트 |
| `View` | 실제 UI 조각 | `.vue` 파일 하나 |

Flutter의 `MaterialApp → Scaffold → Widget` 트리와 동일한 구조다.
iOS는 항상 `WindowGroup` 하나만 사용하지만, iPadOS에서는 다중 창을 지원한다.

```swift
@main
struct MyApp: App {          // App 계층 — 진입점
    var body: some Scene {
        WindowGroup {        // Scene 계층 — 창 단위
            ContentView()   // View 계층 — 루트 뷰, 이후 하위 뷰 트리로 확장
        }
    }
}
```

---

## 📗 4. 앱 생명주기 & 뷰 생명주기

---

SwiftUI 생명주기는 Android와 개념은 동일하지만 표현 방식이 다르다.
Android는 Activity에 메서드를 override하지만, SwiftUI는 **뷰에 모디파이어를 붙이는** 방식을 사용한다.
생명주기는 두 레벨로 나뉜다. 화면(뷰) 단위와 앱 전체 단위다.

### 📌 Android vs SwiftUI 대응표

| Android | SwiftUI | 발생 시점 |
|---------|---------|-----------|
| `onCreate` | `.onAppear` | 화면 등장 시 |
| `onResume` | `.onAppear` + `scenePhase(.active)` | 포그라운드 복귀 시 |
| `onPause` | `scenePhase(.inactive)` | 상호작용 불가 상태 |
| `onStop` | `scenePhase(.background)` | 완전 백그라운드 |
| `onDestroy` | `.onDisappear` | 화면 사라질 때 |
| `onSaveInstanceState` | `@AppStorage` / `@SceneStorage` | 상태 영속 저장 |

### 📌 뷰 생명주기 — .onAppear / .onDisappear / .task

| 모디파이어 | 호출 시점 | 주요 용도 |
|-----------|-----------|-----------|
| `.onAppear` | 뷰가 화면에 나타날 때 (탭 전환 복귀 포함) | 타이머 시작, 분석 로그 |
| `.task` | onAppear와 동일, 뷰 소멸 시 Task 자동 취소 | API 호출 (권장) |
| `.onDisappear` | 뷰가 화면에서 사라질 때 | 타이머 정지, 구독 해제 |
| `.onChange(of:)` | 특정 값이 변경될 때 | scenePhase 감지 |

/**
 * .task는 .onAppear의 async/await 버전이다.
 * 핵심 차이: 뷰가 사라지면 실행 중인 Task가 자동으로 취소된다.
 * API 호출에는 .onAppear 대신 .task를 쓰는 것이 권장된다.
 */

```swift
struct ProductListView: View {
    @State private var products: [Product] = []
    @State private var timer: Timer?

    var body: some View {
        List(products) { ProductRow(product: $0) }
            .task {
                // 뷰 등장 시 실행 — 뷰 사라지면 자동 취소
                products = (try? await fetchProducts()) ?? []
            }
            .onAppear {
                startRefreshTimer()  // 탭 전환으로 돌아올 때마다 재실행
            }
            .onDisappear {
                timer?.invalidate()  // 타이머 정지
                timer = nil
            }
    }
}
```

### 📌 앱 전체 생명주기 — scenePhase

| ScenePhase | 의미 | Android 대응 |
|-----------|------|--------------|
| `.active` | 포그라운드, 상호작용 가능 | `onResume` |
| `.inactive` | 화면에 보이지만 상호작용 불가 (전화 수신, 앱 전환기) | `onPause` |
| `.background` | 완전 백그라운드 | `onStop` |

/**
 * @Environment(\.scenePhase)는 어떤 View에서도 읽을 수 있다.
 * App 구조체에서 감지하면 앱 전체, 특정 View에서 감지하면 해당 Scene에 한정된다.
 */

```swift
@main
struct MyApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup { ContentView() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // onResume — 포그라운드 복귀
                    reconnectWebSocket()
                    refreshAuthToken()
                case .inactive:
                    // onPause — 전화 수신, 앱 전환기
                    pauseAudioPlayback()
                case .background:
                    // onStop — 완전 백그라운드
                    saveUserData()
                    disconnectWebSocket()
                default: break
                }
            }
    }
}
```

### 📌 하이브리드 앱 실전 패턴 — WKWebView에 생명주기 전달

WKWebView 기반 하이브리드 앱에서 scenePhase를 활용하는 핵심 패턴이다.

/**
 * 앱이 포그라운드로 복귀할 때 evaluateJavaScript로 웹에 이벤트를 전달한다.
 * 웹 측에서 dispatchEvent를 수신해 세션 갱신, 데이터 재로딩 등을 처리한다.
 */

```swift
struct WebContainerView: View {
    @Environment(\.scenePhase) var scenePhase
    @State private var webView = WKWebView()

    var body: some View {
        WebViewRepresentable(webView: webView)
            .onAppear {
                webView.load(URLRequest(url: appURL))
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    // Nuxt3 웹에 포그라운드 복귀 알림
                    webView.evaluateJavaScript(
                        "window.dispatchEvent(new Event('appForeground'))"
                    )
                } else if phase == .background {
                    // 웹에 백그라운드 진입 알림
                    webView.evaluateJavaScript(
                        "window.dispatchEvent(new Event('appBackground'))"
                    )
                }
            }
    }
}
```

> 💡 뷰 생명주기(.onAppear)와 앱 생명주기(scenePhase)는 독립적으로 작동한다.
> 앱이 백그라운드로 가도 .onDisappear가 호출되지 않는다.
> 두 레벨을 혼동하지 않는 것이 중요하다.

---

## 📗 5. 정리

---

- Xcode 프로젝트는 `MyApp.swift`(진입점), `ContentView.swift`(첫 화면), `Info.plist`(권한 선언) 세 파일이 핵심이다.
- App → Scene → View 계층 구조는 Flutter의 MaterialApp → Scaffold → Widget과 동일하다.
- 생명주기는 화면 단위(`.onAppear` / `.onDisappear` / `.task`)와 앱 전체 단위(`scenePhase`)로 나뉜다.
- API 호출은 `.onAppear`보다 `.task`를 써야 뷰가 사라질 때 자동으로 취소된다.
- 하이브리드 앱에서는 `scenePhase`가 `.active`로 바뀔 때 `evaluateJavaScript`로 웹에 이벤트를 전달하는 패턴이 핵심이다.

---

## 참고 자료

- Apple 공식문서 - SwiftUI App: <https://developer.apple.com/documentation/swiftui/app>
- Apple 공식문서 - WindowGroup: <https://developer.apple.com/documentation/swiftui/windowgroup>
- Apple 공식문서 - ScenePhase: <https://developer.apple.com/documentation/swiftui/scenephase>
- Apple 공식문서 - View.onAppear: <https://developer.apple.com/documentation/swiftui/view/onappear(perform:)>
- Apple 공식문서 - View.task: <https://developer.apple.com/documentation/swiftui/view/task(priority:_:)>
- Apple Tutorials - Develop in Swift: <https://developer.apple.com/tutorials/develop-in-swift/update-the-ui-with-state>
