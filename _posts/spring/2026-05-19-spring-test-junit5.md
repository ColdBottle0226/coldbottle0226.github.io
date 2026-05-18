---
title: 테스트 기초 개념과 JUnit 5
date: 2026-05-18 09:00:00 +0900
categories: [Spring, 테스트코드]
order: 0
tags: [TDD, JUnit5, SpringBoot, 단위테스트, 통합테스트, GivenWhenThen, ParameterizedTest, Nested]
---

테스트 코드를 처음 배울 때 가장 자주 듣는 말이 있다. "버그를 잡기 위해 테스트를 작성하세요."
틀린 말은 아니지만, 테스트 코드가 주는 가장 큰 가치는 버그 감지가 아니라 **변경에 대한 안전망**이다.

기능 하나를 고쳤을 때 다른 곳이 망가지지 않았는지 즉시 알 수 있고,
리팩토링할 때 기존 동작이 유지되는지 확인할 수 있고,
테스트 코드 자체가 코드가 어떻게 동작하는지 설명하는 문서가 된다.

이 글에서는 Spring Boot 테스트의 기초 개념부터 JUnit 5 핵심 사용법까지,
A부터 Z까지 실전 예시 중심으로 정리한다.

## 1. 전체 구조

| 챕터 | 내용 |
|------|------|
| 2. 왜 테스트 코드가 필요한가 | 안전망, 문서화, 설계 개선 |
| 3. 테스트의 종류 | 테스트 피라미드, 단위/통합/E2E |
| 4. FIRST 원칙 | 좋은 테스트의 조건 |
| 5. Spring Boot 테스트 생태계 | spring-boot-starter-test |
| 6. JUnit 5 구조와 의존성 | 모듈 구성, build.gradle |
| 7. 핵심 어노테이션 | @Test, @BeforeEach, @Disabled 등 |
| 8. 테스트 생명주기 | 실행 순서, 독립성 |
| 9. Given-When-Then 패턴 | 테스트 코드 작성 방법론 |
| 10. 좋은 테스트 이름 짓기 | 메서드명 컨벤션 |
| 11. 예외 검증 전략 | assertThrows vs assertThatThrownBy |
| 12. @ParameterizedTest | 다양한 입력값 테스트 |
| 13. @Nested | 테스트 그룹화 |
| 14. 실전 예제 | 도메인 클래스 테스트 전체 작성 |

---

## 2. 왜 테스트 코드가 필요한가

### 📌 실제 상황으로 생각해보기

쇼핑몰 프로젝트에서 `주문 생성 API`를 개발했다고 가정한다.

```
1. 개발 완료 후 Postman으로 수동 테스트 → 정상 작동 확인
2. 2주 후 팀원이 '재고 차감 로직'을 수정
3. 재고 로직과 주문 생성이 내부적으로 연결되어 있었음
4. 아무도 모르게 주문 생성이 깨짐
5. 배포 후 고객 클레임 발생
```

테스트 코드가 있었다면?

```java
@Test
void 주문_생성_시_재고가_차감된다() {
    // 재고 변경 코드가 수정되면 이 테스트가 빨간불 → 즉시 감지
}
```

테스트 코드는 단순히 버그를 잡는 도구가 아니라 **변경에 대한 안전망(safety net)**이다.

### 📌 테스트 코드가 주는 가치

| 가치 | 설명 |
|------|------|
| 회귀 방지 | 기존 기능이 새 코드로 인해 깨지는 것을 즉시 감지 |
| 문서화 | 테스트 코드 자체가 "이 코드는 이렇게 동작한다"는 명세서 |
| 리팩터링 용기 | 테스트가 있으면 과감하게 내부 구현을 개선 가능 |
| 설계 개선 | 테스트하기 어려운 코드 = 설계가 나쁜 코드 |

---

## 3. 테스트의 종류 — 테스트 피라미드

### 📌 테스트 피라미드

```
         /\
        /  \
       / E2E\        ← 적게, 느리게, 비싸게
      /------\
     /통합 테스트\     ← 중간
    /------------\
   /  단위 테스트  \   ← 많이, 빠르게, 저렴하게
  /--------------\
```

이 개념은 구글 엔지니어 Mike Cohn이 제안하고 Martin Fowler가 널리 알린 개념이다.
([martinfowler.com/bliki/TestPyramid](https://martinfowler.com/bliki/TestPyramid.html))

### 📌 단위 테스트 (Unit Test)

가장 작은 단위(메서드, 클래스)를 독립적으로 검증한다.

```java
class DiscountServiceTest {

    DiscountService discountService = new DiscountService();

    @Test
    void VIP_등급_회원은_10퍼센트_할인된다() {
        // Given
        int price = 10000;

        // When
        int result = discountService.calculate(price, Grade.VIP);

        // Then
        assertThat(result).isEqualTo(9000);
    }
}
```

외부 의존성(DB, HTTP) 없음, 매우 빠름(수십 ms 이내), 다른 테스트에 영향 안 받음.

### 📌 통합 테스트 (Integration Test)

여러 계층이 함께 동작하는지 검증한다.

```java
@SpringBootTest
@Transactional
class OrderServiceIntegrationTest {

    @Autowired OrderService orderService;
    @Autowired OrderRepository orderRepository;

    @Test
    void 주문_생성_후_DB에_저장된다() {
        // Given & When
        Order order = orderService.createOrder(memberId, itemId, quantity);

        // Then
        Order found = orderRepository.findById(order.getId()).orElseThrow();
        assertThat(found.getStatus()).isEqualTo(OrderStatus.ORDERED);
    }
}
```

실제 Spring 컨텍스트 로드(느림, 수 초), DB 연동 포함, 계층 간 연결이 올바른지 검증.

### 📌 E2E 테스트 (End-to-End Test)

실제 HTTP 요청부터 응답까지 전 흐름을 검증한다.

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OrderApiE2ETest {

    @Autowired TestRestTemplate restTemplate;

    @Test
    void POST_주문_API_호출시_201_반환() {
        ResponseEntity<String> response = restTemplate.postForEntity(
            "/api/orders", new OrderRequest(...), String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }
}
```

가장 느리고 비쌈. 실제 환경과 가장 유사. 소수만 유지 권장.

---

## 4. FIRST 원칙 — 좋은 테스트의 조건

| 원칙 | 영어 | 설명 |
|------|------|------|
| **F**ast | 빠른 | 수 ms 이내. 느리면 실행을 안 하게 됨 |
| **I**solated | 독립적 | 다른 테스트에 의존하지 않음 |
| **R**epeatable | 반복 가능 | 언제 실행해도 같은 결과 |
| **S**elf-validating | 자기 검증 | 수동 확인 없이 Pass/Fail 자동 판별 |
| **T**imely | 적시 | 코드 작성과 거의 동시에 작성 |

---

## 5. Spring Boot 테스트 생태계

`spring-boot-starter-test` 하나면 아래 라이브러리가 모두 포함된다.

```
spring-boot-starter-test
├── JUnit 5         → 테스트 실행 엔진
├── AssertJ         → 가독성 높은 검증
├── Mockito         → 가짜 객체(Mock) 생성
├── Hamcrest        → 매처 라이브러리 (AssertJ로 대체 추세)
├── JSONassert      → JSON 응답 검증
└── MockMvc         → HTTP 요청 시뮬레이션
```

```groovy
// build.gradle
dependencies {
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}
```

참고: [Spring Boot Testing 공식 문서](https://docs.spring.io/spring-boot/docs/current/reference/html/testing.html)

---

## 6. JUnit 5 구조와 의존성

JUnit 5는 단일 JAR가 아니라 세 모듈로 구성된다.

```
JUnit 5
├── JUnit Platform   → 테스트 실행 엔진 추상화 (IDE, Maven, Gradle 연동)
├── JUnit Jupiter    → JUnit 5 API (@Test, @BeforeEach 등) ← 실제로 쓰는 것
└── JUnit Vintage    → JUnit 3/4 하위 호환
```

Spring Boot 2.2 이상부터 JUnit 5가 기본이다.

> 💡 JUnit Vintage를 제거하고 싶다면 아래처럼 exclude를 추가할 수 있다.

```groovy
testImplementation('org.springframework.boot:spring-boot-starter-test') {
    exclude group: 'org.junit.vintage', module: 'junit-vintage-engine'
}
```

참고: [JUnit 5 공식 문서 — Architecture](https://junit.org/junit5/docs/current/user-guide/#overview-what-is-junit-5)

---

## 7. 핵심 어노테이션 완전 정리

### 📌 @Test

테스트 메서드를 선언하는 기본 어노테이션이다.

```java
import org.junit.jupiter.api.Test;

class CalculatorTest {

    @Test
    void 두_수를_더하면_합이_반환된다() {
        // Given
        Calculator calc = new Calculator();

        // When
        int result = calc.add(2, 3);

        // Then
        assertThat(result).isEqualTo(5);
    }
}
```

반환타입은 반드시 `void`. `public` 생략 가능 (JUnit 5부터 package-private도 동작).
메서드명은 한글 권장 — 무엇을 테스트하는지 명확하게.

### 📌 생명주기 어노테이션 4종

```java
@DisplayName("주문 서비스 테스트")
class OrderServiceTest {

    OrderService orderService;
    Order order;

    /** 전체 테스트 클래스에서 딱 한 번, 맨 처음 실행 */
    @BeforeAll
    static void 전체_테스트_시작_전_한번만() {
        // DB 커넥션, 무거운 자원 초기화 등
        // 반드시 static 메서드여야 함
    }

    /** 각 @Test 메서드 실행 직전마다 실행 */
    @BeforeEach
    void 각_테스트_시작_직전() {
        // 매 테스트마다 새 객체를 생성 → 테스트 간 상태 오염 방지
        orderService = new OrderService(new FakeDiscountPolicy());
        order = Order.create(memberId, itemId, 10000);
    }

    /** 각 @Test 메서드 실행 직후마다 실행 */
    @AfterEach
    void 각_테스트_종료_직후() {
        // 자원 해제, 임시 데이터 정리
    }

    /** 전체 테스트 클래스에서 딱 한 번, 맨 마지막에 실행 */
    @AfterAll
    static void 전체_테스트_종료_후_한번만() {
        // DB 연결 종료 등
    }

    @Test
    void 주문_취소_시_상태가_CANCELLED로_변경된다() {
        // ...
    }
}
```

실행 순서는 아래와 같다.

```
@BeforeAll (1회)
│
├── @BeforeEach → @Test (첫 번째) → @AfterEach
├── @BeforeEach → @Test (두 번째) → @AfterEach
│
@AfterAll (1회)
```

### 📌 @Disabled

임시로 테스트를 비활성화한다. 이유와 날짜를 반드시 명시한다.

```java
@Test
@Disabled("외부 결제 API 장애로 임시 비활성화 (2026-05-18, 이슈 #342)")
void 결제_완료_시_포인트가_적립된다() {
    // ...
}
```

### 📌 @DisplayName

IDE와 리포트에 표시되는 이름을 지정한다.

```java
@DisplayName("회원 서비스 — 회원 가입 시나리오")
class MemberServiceTest {

    @Test
    @DisplayName("정상 이메일/비밀번호로 가입 시 회원이 저장된다")
    void signUp_success() { /* ... */ }

    @Test
    @DisplayName("이미 사용 중인 이메일로 가입 시 예외가 발생한다")
    void signUp_duplicateEmail_throwsException() { /* ... */ }
}
```

---

## 8. 테스트 생명주기 — 왜 @BeforeEach에서 객체를 새로 만드는가

필드를 한 번만 초기화하면 테스트 간 상태가 누적되어 서로 오염된다.

```java
// ❌ 잘못된 예시: 필드 공유로 인한 테스트 오염
class CartTest {

    Cart cart = new Cart(); // 한 번만 생성 → 상태가 누적됨

    @Test
    void 상품_추가() {
        cart.add(new Item("사과", 1000));
        assertThat(cart.getItems()).hasSize(1); // ✅ 통과
    }

    @Test
    void 빈_장바구니_확인() {
        // 앞 테스트에서 사과가 이미 담겨 있으면 실패할 수 있음
        assertThat(cart.getItems()).isEmpty(); // ❌ 실패 가능
    }
}
```

```java
// ✅ 올바른 예시: 매 테스트마다 새로 생성
class CartTest {

    Cart cart;

    @BeforeEach
    void setUp() {
        cart = new Cart(); // 매번 깨끗한 상태
    }

    @Test
    void 상품_추가() {
        cart.add(new Item("사과", 1000));
        assertThat(cart.getItems()).hasSize(1); // ✅ 항상 통과
    }

    @Test
    void 빈_장바구니_확인() {
        assertThat(cart.getItems()).isEmpty(); // ✅ 항상 통과
    }
}
```

---

## 9. Given-When-Then 패턴 — 테스트 코드 작성 방법론

이것이 테스트 코드 작성에서 가장 중요한 개념이다.

### 📌 AAA 패턴 vs Given-When-Then

두 패턴은 표현 방식만 다를 뿐 완전히 같은 구조다.

| AAA | Given-When-Then | 의미 |
|-----|----------------|------|
| Arrange | Given | 테스트 준비 (객체 생성, 데이터 세팅) |
| Act | When | 실제 동작 실행 (테스트 대상 메서드 호출) |
| Assert | Then | 결과 검증 |

### 📌 구조 없이 작성한 경우 vs 구조화한 경우

```java
// ❌ 어디가 준비고, 어디가 실행이고, 어디가 검증인지 모름
@Test
void test1() {
    MemberService memberService = new MemberService(new FakeMemberRepository());
    Member m = new Member(1L, "홍길동", Grade.VIP);
    memberService.join(m);
    Member found = memberService.findMember(1L);
    assertThat(found).isNotNull();
    assertThat(found.getName()).isEqualTo("홍길동");
}
```

```java
// ✅ 읽기만 해도 무슨 테스트인지 바로 이해됨
@Test
void VIP_회원_가입_후_조회하면_정보가_일치한다() {

    // Given: VIP 등급의 회원이 존재한다
    MemberService memberService = new MemberService(new FakeMemberRepository());
    Member member = new Member(1L, "홍길동", Grade.VIP);

    // When: 회원 가입 후 ID로 조회한다
    memberService.join(member);
    Member foundMember = memberService.findMember(1L);

    // Then: 조회된 회원의 정보가 가입 정보와 일치한다
    assertThat(foundMember).isNotNull();
    assertThat(foundMember.getName()).isEqualTo("홍길동");
    assertThat(foundMember.getGrade()).isEqualTo(Grade.VIP);
}
```

### 📌 테스트 하나에 하나의 행동만

```java
// ❌ 여러 행동 → 어디서 실패했는지 파악 어려움
@Test
void 주문_전체_시나리오() {
    Order order = orderService.create(request);
    assertThat(order).isNotNull();

    orderService.confirm(order.getId());
    assertThat(order.getStatus()).isEqualTo(CONFIRMED);

    orderService.cancel(order.getId()); // 여기서 실패하면?
    assertThat(order.getStatus()).isEqualTo(CANCELLED);
}

// ✅ 각 행동을 분리
@Test void 주문_생성_시_상태는_ORDERED이다() { ... }
@Test void 주문_확정_시_상태는_CONFIRMED이다() { ... }
@Test void 주문_취소_시_상태는_CANCELLED이다() { ... }
```

---

## 10. 좋은 테스트 이름 짓기

테스트 메서드명은 그 자체가 문서다. 실패했을 때 이름만 보고 무엇이 문제인지 알 수 있어야 한다.

### 📌 명명 패턴 비교

| 패턴 | 예시 |
|------|------|
| 한글 서술형 (권장) | `재고가_0이면_주문_시_예외가_발생한다` |
| 영어 should 패턴 | `should_throw_exception_when_stock_is_zero` |
| 영어 메서드\_조건\_결과 | `order_whenStockIsZero_throwsException` |

```java
// ❌ 나쁜 이름
@Test void test1() { ... }
@Test void orderTest() { ... }
@Test void testCreateOrder() { ... }

// ✅ 좋은 이름 — 조건 + 행동 + 기대 결과가 명확
@Test void 재고가_0개일때_주문하면_OutOfStockException이_발생한다() { ... }
@Test void VIP_회원이_10000원_주문하면_1000원_할인된다() { ... }
@Test void 취소된_주문을_다시_취소하면_예외가_발생한다() { ... }
```

---

## 11. 예외 검증 전략

### 📌 assertThrows vs assertThatThrownBy

```java
// JUnit 5 기본: 예외 타입만 빠르게 검증할 때
@Test
void 음수_가격으로_상품_생성_시_예외가_발생한다_junit방식() {
    ProductService service = new ProductService();

    IllegalArgumentException exception = assertThrows(
        IllegalArgumentException.class,
        () -> service.createProduct("상품A", -1000)
    );
    assertThat(exception.getMessage()).contains("0 이상");
}

// AssertJ 방식: 타입 + 메시지를 체이닝으로 한 번에 (더 권장)
@Test
void 음수_가격으로_상품_생성_시_예외가_발생한다_assertj방식() {
    ProductService service = new ProductService();

    assertThatThrownBy(() -> service.createProduct("상품A", -1000))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("가격은 0 이상이어야 합니다.")
        .hasMessageContaining("0 이상");
}
```

### 📌 예외가 발생하지 않음을 검증

```java
@Test
void 유효한_이메일_형식은_검증을_통과한다() {
    EmailValidator validator = new EmailValidator();

    assertThatNoException()
        .isThrownBy(() -> validator.validate("chan@example.com"));
}
```

### 📌 어떤 방식을 쓸 것인가

| 상황 | 권장 방법 |
|------|----------|
| 예외 타입만 확인 | `assertThrows` |
| 타입 + 메시지 동시 검증 | `assertThatThrownBy` |
| 예외가 안 나야 함 | `assertThatNoException` |
| 특정 예외를 명시적으로 강조 | `assertThatExceptionOfType` |

> 💡 현업에서는 `assertThatThrownBy`가 가장 많이 쓰인다. 체이닝으로 여러 조건을 한 번에 검증할 수 있기 때문이다.

---

## 12. @ParameterizedTest — 다양한 입력값 테스트

같은 로직을 여러 입력값으로 반복 테스트할 때 사용한다.

### 📌 @ValueSource — 단순 값 목록

```java
class EmailValidatorTest {

    EmailValidator validator = new EmailValidator();

    @ParameterizedTest
    @ValueSource(strings = {
        "user@example.com",
        "hong.gildong@company.co.kr",
        "test123@gmail.com"
    })
    void 유효한_이메일_형식은_검증을_통과한다(String validEmail) {
        assertThatNoException()
            .isThrownBy(() -> validator.validate(validEmail));
    }

    @ParameterizedTest
    @ValueSource(strings = {"notanemail", "missing@", "@nodomain.com", ""})
    void 잘못된_이메일_형식은_예외가_발생한다(String invalidEmail) {
        assertThatThrownBy(() -> validator.validate(invalidEmail))
            .isInstanceOf(InvalidEmailException.class);
    }
}
```

### 📌 @CsvSource — 입력값 + 기대값 쌍

```java
class DiscountPolicyTest {

    DiscountService discountService = new DiscountService();

    @ParameterizedTest(name = "{0} 등급, {1}원 주문 시 {2}원 할인")
    @CsvSource({
        "VIP,   10000, 1000",
        "GOLD,  10000,  500",
        "BASIC, 10000,    0"
    })
    void 등급별_할인_금액이_다르다(String grade, int price, int expectedDiscount) {
        // Given
        Grade memberGrade = Grade.valueOf(grade);

        // When
        int discount = discountService.calculate(price, memberGrade);

        // Then
        assertThat(discount).isEqualTo(expectedDiscount);
    }
}
```

> 💡 `@ParameterizedTest(name = "...")` 에서 `{0}`, `{1}`은 파라미터 순서다. IDE에서 케이스별로 어떤 값이 실행됐는지 표시된다.

### 📌 @NullAndEmptySource

```java
@ParameterizedTest
@NullAndEmptySource   // null 과 "" 두 케이스를 자동으로 주입
@ValueSource(strings = {"  ", "\t", "\n"})
void 빈_값이나_null은_검증에_실패한다(String blankInput) {
    assertThatThrownBy(() -> validator.validate(blankInput))
        .isInstanceOf(IllegalArgumentException.class);
}
```

### 📌 @MethodSource — 복잡한 객체를 파라미터로

```java
class OrderServiceTest {

    static Stream<Arguments> 잘못된_주문_요청_목록() {
        return Stream.of(
            Arguments.of("수량이 0", new OrderRequest(itemId, 0, address)),
            Arguments.of("수량이 음수", new OrderRequest(itemId, -1, address)),
            Arguments.of("주소가 null", new OrderRequest(itemId, 1, null))
        );
    }

    @ParameterizedTest(name = "{0} 일 때 예외가 발생한다")
    @MethodSource("잘못된_주문_요청_목록")
    void 잘못된_주문_요청은_예외가_발생한다(String description, OrderRequest request) {
        assertThatThrownBy(() -> orderService.createOrder(request))
            .isInstanceOf(InvalidOrderException.class);
    }
}
```

---

## 13. @Nested — 테스트 그룹화

관련 테스트를 계층적으로 묶어 테스트 명세서처럼 구성한다.

```java
@DisplayName("회원 서비스 테스트")
class MemberServiceTest {

    MemberService memberService;

    @BeforeEach
    void setUp() {
        memberService = new MemberService(new FakeMemberRepository());
    }

    @Nested
    @DisplayName("회원 가입")
    class 회원가입 {

        @Test
        @DisplayName("정상 정보로 가입 시 회원이 저장된다")
        void 정상_가입() {
            // Given
            Member member = new Member("홍길동", "hong@test.com", "password123");

            // When
            memberService.join(member);

            // Then
            assertThat(memberService.findByEmail("hong@test.com"))
                .isPresent()
                .get().extracting("name").isEqualTo("홍길동");
        }

        @Test
        @DisplayName("중복 이메일로 가입 시 예외가 발생한다")
        void 중복_이메일_가입() {
            // Given
            Member first = new Member("홍길동", "hong@test.com", "pass1");
            Member duplicate = new Member("홍길순", "hong@test.com", "pass2");
            memberService.join(first);

            // When & Then
            assertThatThrownBy(() -> memberService.join(duplicate))
                .isInstanceOf(DuplicateEmailException.class)
                .hasMessageContaining("이미 사용 중인 이메일");
        }
    }

    @Nested
    @DisplayName("회원 탈퇴")
    class 회원탈퇴 {

        @BeforeEach
        void 탈퇴_전_회원_가입() {
            // 탈퇴 테스트에만 필요한 사전 작업
            memberService.join(new Member("홍길동", "hong@test.com", "pass"));
        }

        @Test
        @DisplayName("탈퇴 시 상태가 DELETED로 변경된다")
        void 탈퇴_상태_변경() { ... }
    }
}
```

IDE에서 보면 이렇게 표시된다.

```
회원 서비스 테스트
├── 회원 가입
│   ├── ✅ 정상 정보로 가입 시 회원이 저장된다
│   └── ✅ 중복 이메일로 가입 시 예외가 발생한다
└── 회원 탈퇴
    └── ✅ 탈퇴 시 상태가 DELETED로 변경된다
```

> 💡 `@Nested` 클래스 안에서도 `@BeforeEach`를 선언할 수 있다. 바깥 클래스의 `@BeforeEach` 먼저 실행 후 안쪽 `@BeforeEach`가 실행된다.

---

## 14. 실전 예제 — 도메인 클래스 테스트 전체 작성

실제 도메인 코드를 보고 테스트를 처음부터 작성한다.

### 📌 테스트 대상 도메인

```java
public class Order {

    private List<OrderItem> items;
    private OrderStatus status;

    public Order(List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("주문 항목은 1개 이상이어야 합니다.");
        }
        this.items = new ArrayList<>(items);
        this.status = OrderStatus.ORDERED;
    }

    public int getTotalPrice() {
        return items.stream().mapToInt(OrderItem::getSubtotal).sum();
    }

    public void cancel() {
        if (this.status == OrderStatus.CANCELLED) {
            throw new IllegalStateException("이미 취소된 주문입니다.");
        }
        if (this.status == OrderStatus.DELIVERED) {
            throw new IllegalStateException("배송 완료된 주문은 취소할 수 없습니다.");
        }
        this.status = OrderStatus.CANCELLED;
    }
}
```

### 📌 테스트 코드

```java
@DisplayName("주문(Order) 도메인 테스트")
class OrderTest {

    @Nested
    @DisplayName("주문 생성")
    class 주문생성 {

        @Test
        @DisplayName("주문 항목이 있으면 주문 생성이 성공한다")
        void 정상_주문_생성() {
            // Given
            List<OrderItem> items = List.of(
                new OrderItem("사과", 1000, 2),
                new OrderItem("바나나", 500, 3)
            );

            // When
            Order order = new Order(items);

            // Then
            assertThat(order.getStatus()).isEqualTo(OrderStatus.ORDERED);
            assertThat(order.getItems()).hasSize(2);
        }

        @Test
        @DisplayName("주문 항목이 비어있으면 예외가 발생한다")
        void 빈_항목으로_주문_생성_실패() {
            // Given
            List<OrderItem> emptyItems = Collections.emptyList();

            // When & Then
            assertThatThrownBy(() -> new Order(emptyItems))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("주문 항목은 1개 이상이어야 합니다.");
        }

        @Test
        @DisplayName("주문 항목이 null이면 예외가 발생한다")
        void null_항목으로_주문_생성_실패() {
            assertThatThrownBy(() -> new Order(null))
                .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("주문 총금액 계산")
    class 총금액계산 {

        @Test
        @DisplayName("각 항목의 가격 × 수량의 합이 총금액이다")
        void 총금액_올바르게_계산된다() {
            // Given
            Order order = new Order(List.of(
                new OrderItem("사과", 1000, 2),   // 2000원
                new OrderItem("바나나", 500, 3)    // 1500원
            ));

            // When
            int totalPrice = order.getTotalPrice();

            // Then
            assertThat(totalPrice).isEqualTo(3500);
        }

        @ParameterizedTest(name = "단가 {0}원 × {1}개 = {2}원")
        @CsvSource({
            "1000, 1, 1000",
            "1000, 5, 5000",
            "2500, 4, 10000"
        })
        void 단일_항목_총금액이_올바르게_계산된다(int price, int quantity, int expected) {
            Order order = new Order(List.of(new OrderItem("상품", price, quantity)));
            assertThat(order.getTotalPrice()).isEqualTo(expected);
        }
    }

    @Nested
    @DisplayName("주문 취소")
    class 주문취소 {

        Order order;

        @BeforeEach
        void setUp() {
            order = new Order(List.of(new OrderItem("사과", 1000, 1)));
        }

        @Test
        @DisplayName("주문 상태인 주문은 취소할 수 있다")
        void ORDERED_상태_취소_성공() {
            // When
            order.cancel();

            // Then
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
        }

        @Test
        @DisplayName("이미 취소된 주문을 다시 취소하면 예외가 발생한다")
        void 이미_취소된_주문_재취소_실패() {
            // Given
            order.cancel();

            // When & Then
            assertThatThrownBy(() -> order.cancel())
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("이미 취소된 주문입니다.");
        }

        @Test
        @DisplayName("배송 완료된 주문은 취소할 수 없다")
        void DELIVERED_상태_취소_실패() {
            // Given
            order.deliver();

            // When & Then
            assertThatThrownBy(() -> order.cancel())
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("배송 완료된 주문은 취소할 수 없습니다.");
        }
    }
}
```

---

## 15. 정리

- 테스트 코드는 버그 감지보다 **변경에 대한 안전망**이다. 리팩터링과 기능 추가 시 기존 동작이 유지되는지 즉시 확인할 수 있다.
- 테스트 피라미드 원칙에 따라 단위 테스트를 가장 많이, E2E 테스트를 가장 적게 작성한다.
- **Given-When-Then** 구조로 작성하면 테스트 코드가 사람이 읽을 수 있는 명세서가 된다.
- `@BeforeEach`에서 객체를 매번 새로 생성해 테스트 간 독립성을 보장한다.
- `@ParameterizedTest`로 입력값만 다른 중복 테스트를 하나로 합친다.
- `@Nested`로 테스트를 계층 구조로 묶으면 IDE에서 시각적으로 구조가 보인다.

---

## 16. 참고 자료

- [Spring Boot Testing 공식 문서](https://docs.spring.io/spring-boot/docs/current/reference/html/testing.html)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [AssertJ 공식 문서](https://assertj.github.io/doc/)
- [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)

---

> 출처: Claude Desktop 대화 (2026-05-19)
