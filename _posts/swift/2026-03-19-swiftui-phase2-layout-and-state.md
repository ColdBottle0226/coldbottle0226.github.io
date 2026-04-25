---
title: SwiftUI 핵심 UI - 레이아웃 컨테이너와 상태 관리
date: 2026-03-19 01:00:00 +0900
categories: [Swift, 기본개념]
tags: [Swift, Basic]
---

##  1. 개요

---

화면을 구성하는 방법과 데이터가 바뀌면 UI가 자동으로 갱신되는 원리,
이 두 가지가 SwiftUI의 전부라고 해도 과언이 아니다.
이번 글에서는 VStack / HStack / ZStack으로 화면을 배치하는 방법과
@State / @Binding / @Observable로 데이터를 다루는 방법을 정리한다.
마지막으로 배운 내용을 조합해 실제 상품 카드 UI를 만들어본다.

### 📌 전체 구성

| 챕터 | 주제 |
|------|------|
| Ch04 | 레이아웃 컨테이너 (VStack / HStack / ZStack / Spacer / LazyVGrid) |
| Ch05 | 상태 관리 (@State / @Binding / @Observable) |
| 실습 | 상품 카드 UI 완성 |

---

##  2. 레이아웃 컨테이너

---

SwiftUI 레이아웃은 목적에 따라 컨테이너가 미리 나뉘어 있다.
HTML의 div + flexbox와 개념이 같다.

### 📌 세 가지 핵심 컨테이너

| 컨테이너 | 방향 | CSS 대응 |
|----------|------|----------|
| `VStack` | 세로 (위→아래) | `flex-direction: column` |
| `HStack` | 가로 (좌→우) | `flex-direction: row` |
| `ZStack` | 레이어 겹침 | `position: absolute` 겹치기 |

```swift
// VStack — alignment와 spacing 지정 가능
VStack(alignment: .leading, spacing: 12) {
    Text("상품명").font(.headline)
    Text("₩29,000").font(.subheadline)
    Text("재고 있음").foregroundStyle(.secondary)
}

// HStack — 가로로 나열
HStack(alignment: .center, spacing: 8) {
    Image(systemName: "star.fill")
    Text("4.8")
    Text("(128개 리뷰)").foregroundStyle(.secondary)
}

// ZStack — 이미지 위에 배지 겹치기
ZStack(alignment: .topLeading) {
    Image(systemName: "photo")          // 아래 레이어
    Text("SALE")                        // 위 레이어
        .font(.caption2).bold()
        .padding(.horizontal, 6)
        .background(Color.red)
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: 6))
        .padding(8)
}
```

### 📌 alignment 옵션

| 컨테이너 | 옵션 | CSS 대응 |
|----------|------|----------|
| VStack | `.leading` / `.center` / `.trailing` | `align-items: flex-start / center / flex-end` |
| HStack | `.top` / `.center` / `.bottom` / `.firstTextBaseline` | `align-items: flex-start / center / flex-end / baseline` |

### 📌 Spacer — 남은 공간 채우기

/**
 * Spacer()는 남은 공간을 모두 차지한다.
 * VStack 안에서는 수직으로, HStack 안에서는 수평으로 팽창한다.
 */

```swift
// 네비게이션바 패턴 — 뒤로 / 타이틀 / 완료
HStack {
    Button("뒤로") { }
    Spacer()                    // CSS: flex: 1 / margin-left: auto
    Text("주문서").bold()
    Spacer()
    Button("완료") { }
}

// 버튼 전체 너비 채우기
Button("장바구니 담기") { }
    .frame(maxWidth: .infinity)  // CSS: width: 100%
    .padding(.vertical, 12)
    .background(Color.blue)
    .foregroundStyle(.white)
```

### 📌 LazyVGrid — 격자 레이아웃

/**
 * LazyVGrid는 필요한 셀만 렌더링한다 (Lazy = 화면에 보이는 것만).
 * 상품 목록, 이미지 갤러리처럼 많은 아이템을 격자로 보여줄 때 사용한다.
 */

```swift
// 2열 균등 분할 — CSS: grid-template-columns: repeat(2, 1fr)
let columns = [GridItem(.flexible()), GridItem(.flexible())]

// 최소 너비 기반 자동 열 수 — CSS: repeat(auto-fill, minmax(150px, 1fr))
let adaptiveColumns = [GridItem(.adaptive(minimum: 150))]

ScrollView {
    LazyVGrid(columns: columns, spacing: 12) {
        ForEach(products) { product in
            ProductCard(product: product)
        }
    }
    .padding()
}
```

| GridItem 방식 | 설명 | CSS 대응 |
|--------------|------|----------|
| `.flexible()` | 균등 분할 | `repeat(N, 1fr)` |
| `.fixed(120)` | 고정 너비 | `120px 120px` |
| `.adaptive(minimum: 100)` | 최소 너비 기반 자동 열 수 | `repeat(auto-fill, minmax(100px, 1fr))` |

### 📌 주요 모디파이어

모디파이어는 뷰에 점(.)으로 체이닝해서 속성을 추가한다. **순서가 결과에 영향을 준다.**

```swift
// 순서가 다르면 결과가 다르다
Text("버튼")
    .padding(16)               // ① 여백 먼저
    .background(Color.blue)   // ② 여백 포함 파란 배경
    .clipShape(.capsule)      // ③ 캡슐 모양으로 자르기

// 순서 바꾸면 텍스트 뒤만 파란 배경, 여백은 투명
Text("버튼")
    .background(Color.blue)
    .padding(16)
```

| 모디파이어 | 역할 | CSS 대응 |
|-----------|------|----------|
| `.frame(width:height:)` | 고정 크기 | `width` / `height` |
| `.frame(maxWidth: .infinity)` | 최대 너비 확장 | `width: 100%` |
| `.padding()` | 안쪽 여백 | `padding` |
| `.foregroundStyle()` | 텍스트·아이콘 색상 | `color` |
| `.background()` | 배경 | `background` |
| `.clipShape()` | 도형으로 자르기 | `border-radius` / `clip-path` |
| `.lineLimit(n)` | 줄 수 제한 | `-webkit-line-clamp` |
| `.font(.headline)` | 시스템 타입 스케일 | `font-size` (Dynamic Type 지원) |

> 💡 모디파이어는 "새로운 뷰를 감싸서 반환"하는 방식으로 동작한다.
> 그래서 순서가 다르면 감싸는 순서가 달라져 결과도 달라진다.

---

##  3. 상태 관리

---

데이터가 바뀌면 body가 자동으로 재실행되어 UI가 갱신된다. React의 `render()`,
Vue의 반응형 데이터와 동일한 원리다.

### 📌 상황별 선택 가이드

| 상황 | 사용 | Vue 대응 |
|------|------|----------|
| 이 뷰 안에서만 필요한 값 | `@State` | `ref()` |
| 부모 값을 자식이 수정 | `@Binding` | `defineModel()` |
| 여러 화면이 공유하는 상태 | `@Observable` | Pinia store |
| 앱 전체 환경 값 (다크모드 등) | `@Environment` | `provide/inject` |

### 📌 @State — 뷰 내부 단순 상태

/**
 * @State가 붙은 변수가 바뀌면 SwiftUI가 body를 자동으로 다시 실행한다.
 * $ 기호를 붙이면 읽기 전용 값이 양방향 바인딩(Binding)으로 바뀐다.
 * Vue의 v-model과 동일한 개념이다.
 */

```swift
struct CounterView: View {
    @State private var count = 0           // 뷰가 소유하는 상태
    @State private var name = ""
    @State private var isNotificationOn = false

    var body: some View {
        VStack(spacing: 16) {
            Text("카운트: \(count)")
            Button("증가") { count += 1 }  // count 변경 → body 재실행

            TextField("이름", text: $name)  // $name — 양방향 바인딩 (v-model)
            if !name.isEmpty {
                Text("안녕하세요, \(name)!")
            }

            Toggle("알림", isOn: $isNotificationOn)
        }
    }
}
```

### 📌 @Binding — 부모↔자식 양방향 연결

/**
 * 부모의 @State를 자식이 받아서 읽고 쓸 수 있도록 연결한다.
 * 자식이 값을 바꾸면 부모의 @State가 바뀌고 부모 뷰 전체가 갱신된다.
 */

```swift
// 부모 뷰 — @State를 소유
struct ParentView: View {
    @State private var isLoggedIn = false

    var body: some View {
        VStack {
            Text(isLoggedIn ? "로그인됨" : "로그아웃 상태")
            LoginButton(isLoggedIn: $isLoggedIn)  // $로 Binding 변환해서 전달
        }
    }
}

// 자식 뷰 — @Binding으로 받음 (소유하지 않음)
struct LoginButton: View {
    @Binding var isLoggedIn: Bool     // $ 없는 일반 선언

    var body: some View {
        Button(isLoggedIn ? "로그아웃" : "로그인") {
            isLoggedIn.toggle()       // 부모의 @State가 직접 바뀜
        }
    }
}
```

데이터 흐름: `ParentView(@State)` → `$isLoggedIn` → `LoginButton(@Binding)` → `toggle()` → `ParentView 재렌더`.

### 📌 @Observable — 여러 뷰가 공유하는 상태 (iOS 17+)

/**
 * 비즈니스 로직을 뷰에서 분리할 때 사용한다.
 * iOS 17+ @Observable 매크로는 @Published 선언 없이 자동으로 변화를 감지한다.
 * iOS 16 이하는 ObservableObject + @Published + @StateObject 조합을 사용한다.
 */

```swift
// iOS 17+ 방식 (권장)
@Observable
class CartViewModel {
    var items: [CartItem] = []
    var isLoading = false

    // 계산 프로퍼티도 자동으로 변화 감지됨
    var totalPrice: Int {
        items.reduce(0) { $0 + $1.price }
    }

    func addItem(_ item: CartItem) { items.append(item) }
    func removeItem(at offsets: IndexSet) { items.remove(atOffsets: offsets) }
}

// 뷰에서 @State로 인스턴스 생성
struct CartView: View {
    @State private var vm = CartViewModel()

    var body: some View {
        List {
            ForEach(vm.items) { Text($0.name) }
            .onDelete { vm.removeItem(at: $0) }
        }
        Text("합계: ₩\(vm.totalPrice)")
    }
}
```

| 방식 | iOS | 선언 | 뷰에서 |
|------|-----|------|--------|
| `@Observable` | 17+ | 클래스에 매크로만 | `@State` |
| `ObservableObject` | 16 이하 | 프로토콜 + `@Published` | `@StateObject` / `@ObservedObject` |

---

##  4. 실습 — 상품 카드 UI

---

배운 내용을 조합해 VStack + HStack + ZStack을 중첩한 상품 카드를 만든다.

### 📌 레이아웃 트리 구조

```
VStack(alignment: .leading)         ← 카드 전체 세로
├── ZStack(alignment: .topLeading)  ← 이미지 + 배지 겹치기
│   ├── Image                       ← 상품 이미지
│   ├── Text("SALE")                ← 배지 (조건부 표시)
│   └── HStack { Spacer() + 하트버튼 } ← 위시리스트 버튼
├── VStack(alignment: .leading)     ← 텍스트 정보 세로
│   ├── Text(brand)                 ← 브랜드명
│   ├── Text(name)                  ← 상품명
│   ├── HStack { 현재가 + 원가 + 할인율 } ← 가격 가로 배치
│   └── StarRatingView              ← 별점 서브뷰
└── Button("장바구니 담기")          ← 하단 버튼
```

### 📌 데이터 모델

```swift
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let price: Int
    let originalPrice: Int?   // Optional — 할인 없으면 nil
    let rating: Double
    let reviewCount: Int
    let imageName: String
    let isNew: Bool

    // 할인율 자동 계산 — 계산 프로퍼티
    var discountRate: Int? {
        guard let original = originalPrice, original > price else { return nil }
        return Int((1 - Double(price) / Double(original)) * 100)
    }
}
```

### 📌 별점 서브뷰 분리

/**
 * 반복되거나 복잡한 부분은 별도 struct로 분리한다.
 * body가 너무 길어진다 싶으면 분리하는 것이 SwiftUI 스타일이다.
 */

```swift
struct StarRatingView: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starIcon(for: star))
                    .foregroundStyle(.yellow)
                    .font(.system(size: 10))
            }
            Text("(\(reviewCount))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func starIcon(for position: Int) -> String {
        if Double(position) <= rating { return "star.fill" }
        if Double(position) - 0.5 <= rating { return "star.leadinghalf.filled" }
        return "star"
    }
}
```

### 📌 ProductCard 완성 코드

```swift
struct ProductCard: View {
    let product: Product
    @State private var isWishlisted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 이미지 영역 — ZStack으로 배지 겹치기
            ZStack(alignment: .topLeading) {
                Image(systemName: product.imageName)
                    .font(.system(size: 48))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.blue.opacity(0.08))

                // SALE / NEW 배지 — 조건부 표시
                if let discount = product.discountRate {
                    Text("SALE")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 6))
                        .padding(8)
                } else if product.isNew {
                    Text("NEW")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 6))
                        .padding(8)
                }

                // 위시리스트 버튼 — Spacer로 오른쪽으로 밀기
                HStack {
                    Spacer()
                    Button {
                        isWishlisted.toggle()
                    } label: {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .foregroundStyle(isWishlisted ? .red : .gray)
                            .padding(8)
                    }
                }
            }

            // 텍스트 정보 영역
            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand)
                    .font(.caption).foregroundStyle(.secondary)

                Text(product.name)
                    .font(.subheadline).bold()
                    .lineLimit(1)                   // 넘치면 ... 처리

                // 가격 행 — HStack 가로 배치
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₩\(product.price.formatted())")
                        .font(.headline)

                    if let original = product.originalPrice {
                        Text("₩\(original.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                    }

                    if let discount = product.discountRate {
                        Text("\(discount)%")
                            .font(.caption).bold()
                            .foregroundStyle(.red)
                    }
                }

                StarRatingView(rating: product.rating, reviewCount: product.reviewCount)
            }
            .padding(10)

            // 하단 버튼
            Button("장바구니 담기") { }
                .font(.caption).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundStyle(.white)
        }
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .frame(width: 160)
    }
}
```

---

##  5. 정리

---

- VStack(세로) / HStack(가로) / ZStack(레이어)을 중첩해서 어떤 레이아웃도 구성할 수 있다.
- 모디파이어는 체이닝 순서가 결과에 영향을 주므로 순서를 의식하면서 작성한다.
- `@State`는 뷰 내부 단순 상태, `@Binding`은 부모→자식 연결, `@Observable`은 여러 뷰 공유 상태다.
- `$` 기호가 붙으면 읽기 전용 값이 양방향 바인딩으로 바뀐다 — Vue의 `v-model`과 동일.
- 복잡한 뷰는 서브뷰로 분리하는 것이 SwiftUI 스타일이다. body가 너무 길어진다 싶으면 분리한다.

---

## 참고 자료

- Apple 공식문서 - VStack: <https://developer.apple.com/documentation/swiftui/vstack>
- Apple 공식문서 - HStack: <https://developer.apple.com/documentation/swiftui/hstack>
- Apple 공식문서 - ZStack: <https://developer.apple.com/documentation/swiftui/zstack>
- Apple 공식문서 - LazyVGrid: <https://developer.apple.com/documentation/swiftui/lazyvgrid>
- Apple 공식문서 - State: <https://developer.apple.com/documentation/swiftui/state>
- Apple 공식문서 - Binding: <https://developer.apple.com/documentation/swiftui/binding>
- Apple 공식문서 - Observable: <https://developer.apple.com/documentation/observation/observable()>
