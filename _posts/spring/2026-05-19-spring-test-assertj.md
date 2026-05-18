---
title: AssertJ 개념
date: 2026-05-19 09:00:00 +0900
categories: [Spring, 테스트코드]
order: 1
tags: [TDD, AssertJ, JUnit5, SpringBoot, SoftAssertions, usingRecursiveComparison]
---

JUnit 5의 기본 assert 메서드만으로도 검증은 가능하다.
하지만 실패했을 때 메시지가 빈약하고, 코드를 읽을 때 어느 값이 기대값이고 어느 값이 실제값인지 헷갈린다.

AssertJ는 이 문제를 해결한다.
메서드 체이닝 방식으로 자연스러운 영어 문장처럼 검증 코드를 작성할 수 있고,
실패 시 실제 값과 기대 값을 풍부하게 출력해준다.

이 글에서는 AssertJ의 핵심 기능을 실전 예시 중심으로 정리한다.

## 1. 전체 구조

| 챕터 | 내용 |
|------|------|
| 2. 왜 AssertJ인가 | JUnit과 비교 |
| 3. 기본 타입 검증 | 숫자, 문자열, boolean, null |
| 4. 컬렉션 검증 | contains, extracting, filteredOn |
| 5. 예외 검증 심화 | assertThatThrownBy, 원인 검증 |
| 6. 객체 비교 전략 | usingRecursiveComparison |
| 7. Soft Assertions | 한 번에 여러 검증 |
| 8. 커스텀 에러 메시지 | as() |
| 9. 실전 예제 | AssertJ 종합 활용 |

---

## 2. 왜 AssertJ인가

JUnit 기본 assert와 직접 비교한다.

```java
// ── JUnit 기본 ──────────────────────────────
assertEquals("홍길동", member.getName());     // 기대값이 먼저? 실제값이 먼저? 헷갈림
assertTrue(member.isActive());
assertNotNull(member.getEmail());
assertTrue(list.contains("사과"));           // 실패해도 메시지가 부실함

// ── AssertJ ──────────────────────────────────
assertThat(member.getName()).isEqualTo("홍길동"); // 자연스러운 영어 문장
assertThat(member.isActive()).isTrue();
assertThat(member.getEmail()).isNotNull();
assertThat(list).contains("사과");           // 실패 시 실제 리스트 내용까지 출력
```

실패 메시지를 비교하면 차이가 확연하다.

```
// JUnit: 정보가 부족
AssertionFailedError: expected: <홍길동> but was: <김철수>

// AssertJ: 맥락까지 포함
org.opentest4j.AssertionFailedError:
expected: "홍길동"
 but was: "김철수"
```

참고: [AssertJ 공식 문서](https://assertj.github.io/doc/)

---

## 3. 기본 타입 검증

### 📌 숫자

```java
int price = 9000;
long count = 150L;

// 동등 비교
assertThat(price).isEqualTo(9000);
assertThat(price).isNotEqualTo(10000);

// 크기 비교
assertThat(price).isGreaterThan(0);
assertThat(price).isGreaterThanOrEqualTo(9000);
assertThat(price).isLessThan(10000);
assertThat(count).isPositive();       // > 0
assertThat(count).isNotNegative();    // >= 0

// 범위
assertThat(price).isBetween(8000, 10000);            // 양 끝 포함
assertThat(price).isStrictlyBetween(8000, 10000);    // 양 끝 제외
```

### 📌 문자열

```java
String name = "홍길동";
String email = "hong@example.com";

// 동등 비교
assertThat(name).isEqualTo("홍길동");
assertThat(name).isEqualToIgnoringCase("홍길동"); // 대소문자 무시

// 포함 관계
assertThat(email).contains("@");
assertThat(email).contains("@", ".com");      // 여러 개 동시
assertThat(email).doesNotContain("naver");
assertThat(name).startsWith("홍");
assertThat(email).endsWith(".com");

// 빈값 검사
assertThat(name).isNotEmpty();    // null도 아니고 길이도 0이 아님
assertThat(name).isNotBlank();    // 공백만인 문자열도 검출
assertThat("   ").isBlank();

// 패턴 (정규식)
assertThat(email).matches("[\\w.]+@[\\w.]+\\.[a-z]+");

// 길이
assertThat(name).hasSize(3);
```

### 📌 boolean, null

```java
assertThat(member.isActive()).isTrue();
assertThat(member.isDeleted()).isFalse();

assertThat(member).isNotNull();
assertThat(member.getDeletedAt()).isNull();

// Optional
assertThat(optional).isEmpty();
assertThat(optional).isPresent();
```

---

## 4. 컬렉션 검증

```java
List<String> fruits = List.of("사과", "바나나", "포도");
List<Member> members = List.of(
    new Member(1L, "홍길동", "VIP"),
    new Member(2L, "김철수", "BASIC")
);

// ── 크기 ─────────────────────────────────
assertThat(fruits).hasSize(3);
assertThat(fruits).hasSizeGreaterThan(2);
assertThat(fruits).isEmpty();
assertThat(fruits).isNotEmpty();

// ── 포함 여부 (순서 무관) ─────────────────
assertThat(fruits).contains("사과");
assertThat(fruits).contains("사과", "바나나");     // 여러 개
assertThat(fruits).doesNotContain("수박");
assertThat(fruits).containsOnly("사과", "바나나", "포도"); // 이것만 있어야 함
assertThat(fruits).containsAnyOf("사과", "수박");  // 하나라도 있으면

// ── 순서까지 정확히 일치 ──────────────────
assertThat(fruits).containsExactly("사과", "바나나", "포도");

// ── 순서는 무관하되 원소는 정확히 ───────────
assertThat(fruits).containsExactlyInAnyOrder("포도", "사과", "바나나");

// ── 중복 없음 ────────────────────────────
assertThat(fruits).doesNotHaveDuplicates();
```

### 📌 객체 컬렉션에서 특정 필드만 추출해서 검증

```java
// 단일 필드 추출
assertThat(members)
    .extracting("name")
    .containsExactlyInAnyOrder("홍길동", "김철수");

// 여러 필드 추출 — tuple()과 함께 사용
assertThat(members)
    .extracting("name", "grade")
    .containsExactlyInAnyOrder(
        tuple("홍길동", "VIP"),
        tuple("김철수", "BASIC")
    );

// 조건 필터링 후 검증
assertThat(members)
    .filteredOn(m -> m.getGrade().equals("VIP"))
    .hasSize(1)
    .extracting("name")
    .containsExactly("홍길동");
```

---

## 5. 예외 검증 심화

### 📌 assertThatThrownBy — 기본

```java
assertThatThrownBy(() -> service.order(itemId, -1))
    .isInstanceOf(IllegalArgumentException.class)
    .hasMessage("수량은 1 이상이어야 합니다.")        // 정확히 일치
    .hasMessageContaining("1 이상")                  // 포함
    .hasMessageStartingWith("수량은")                // 시작
    .hasMessageEndingWith("합니다.");                // 끝
```

### 📌 원인(cause) 검증

```java
assertThatThrownBy(() -> service.callExternal())
    .isInstanceOf(ExternalApiException.class)
    .hasCauseInstanceOf(HttpClientErrorException.class);
```

### 📌 assertThatExceptionOfType — 명시적 예외 타입 강조

```java
assertThatExceptionOfType(AccessDeniedException.class)
    .isThrownBy(() -> adminService.deleteUser(guestUserId))
    .withMessage("접근 권한이 없습니다.");
```

### 📌 예외가 발생하지 않음을 검증

```java
assertThatNoException()
    .isThrownBy(() -> validator.validate("valid@email.com"));
```

### 📌 언제 어떤 방식을 쓸 것인가

| 상황 | 권장 방법 |
|------|----------|
| 타입 + 메시지 동시 검증 | `assertThatThrownBy` |
| 특정 예외를 명시적으로 강조 | `assertThatExceptionOfType` |
| 예외가 안 나야 함 | `assertThatNoException` |
| 빠르게 타입만 | `assertThrows` (JUnit 5) |

---

## 6. 객체 비교 전략 — usingRecursiveComparison

`equals()`가 구현되지 않은 DTO나 응답 객체를 필드 값으로 직접 비교할 때 사용한다.

```java
// equals/hashCode 미구현 DTO
public class MemberResponse {
    private Long id;
    private String name;
    private String email;
    private LocalDateTime createdAt;
    // equals() 없음
}
```

```java
@Test
void 회원_조회_응답이_올바르다() {
    // Given
    memberRepository.save(new Member("홍길동", "hong@test.com"));

    // When
    MemberResponse response = memberService.findById(1L);

    // Then
    MemberResponse expected = new MemberResponse(1L, "홍길동", "hong@test.com", null);

    assertThat(response)
        .usingRecursiveComparison()
        .ignoringFields("createdAt")           // 특정 필드 제외
        .ignoringFieldsMatchingRegexes(".*At") // 패턴으로 제외
        .isEqualTo(expected);
}
```

### 📌 컬렉션에 적용

```java
assertThat(actualList)
    .usingRecursiveFieldByFieldElementComparator()
    .ignoringFields("id", "createdAt")
    .containsExactlyInAnyOrderElementsOf(expectedList);
```

---

## 7. Soft Assertions — 한 번에 여러 검증

일반 `assertThat`은 첫 번째 실패에서 즉시 중단된다.
Soft Assertions는 모든 검증을 실행하고 마지막에 한 번에 실패 목록을 보여준다.

```java
@Test
void 회원_정보_전체_검증() {
    Member member = memberService.findById(1L);

    // ❌ 일반 방식: 첫 번째 실패 시 멈춤
    assertThat(member.getName()).isEqualTo("홍길동");    // 여기서 실패하면
    assertThat(member.getEmail()).isEqualTo("...");      // 이건 실행 안 됨
}
```

```java
@Test
void 회원_정보_전체_검증_soft() {
    Member member = memberService.findById(1L);

    // ✅ assertSoftly: 모두 실행 후 한꺼번에 리포트
    SoftAssertions.assertSoftly(softly -> {
        softly.assertThat(member.getName()).isEqualTo("홍길동");
        softly.assertThat(member.getEmail()).isEqualTo("hong@test.com");
        softly.assertThat(member.getGrade()).isEqualTo(Grade.VIP);
        softly.assertThat(member.isActive()).isTrue();
    });
}
```

> 💡 Soft Assertions는 **여러 필드를 한 번에 검증하는 API 응답 테스트나 DTO 검증**에서 특히 유용하다. 첫 번째 실패에서 멈추면 나머지 문제를 한 번의 실행으로 발견하지 못하기 때문이다.

---

## 8. 커스텀 에러 메시지 — as()

검증 실패 시 더 친절한 메시지를 출력할 수 있다.

```java
assertThat(stock)
    .as("재고가 충분해야 주문이 가능합니다. 현재 재고: %d, 주문 수량: %d", stock, orderQty)
    .isGreaterThanOrEqualTo(orderQty);

// 실패 시 출력:
// [재고가 충분해야 주문이 가능합니다. 현재 재고: 2, 주문 수량: 5]
// expected: 5 to be less than or equal to: 2
```

`as()`는 반드시 검증 메서드 **앞에** 호출해야 한다.

---

## 9. 실전 예제 — AssertJ 종합 활용

지금까지 배운 내용을 하나의 예제로 종합한다.

```java
@DisplayName("주문 조회 서비스 — AssertJ 종합 검증")
class OrderQueryServiceTest {

    OrderQueryService queryService;

    @BeforeEach
    void setUp() {
        queryService = new OrderQueryService(fakeOrderRepository());
    }

    @Test
    @DisplayName("회원의 주문 목록 조회 시 최신순으로 반환된다")
    void 주문_목록_최신순_조회() {
        // Given
        Long memberId = 1L;

        // When
        List<OrderResponse> orders = queryService.findByMember(memberId);

        // Then
        assertThat(orders)
            .isNotEmpty()
            .hasSize(3)
            .doesNotHaveDuplicates()
            // 날짜 내림차순 정렬 확인
            .isSortedAccordingTo(
                Comparator.comparing(OrderResponse::getOrderedAt).reversed()
            )
            // 모든 주문이 해당 회원의 것인지 확인
            .allSatisfy(order ->
                assertThat(order.getMemberId()).isEqualTo(memberId)
            )
            // 특정 필드만 추출해서 상태 검증
            .extracting("status")
            .containsOnly(OrderStatus.ORDERED, OrderStatus.DELIVERED);
    }

    @Test
    @DisplayName("주문 상세 조회 시 모든 필드가 올바르다")
    void 주문_상세_조회() {
        // Given
        Long orderId = 1L;

        // When
        OrderDetailResponse detail = queryService.findDetail(orderId);

        // Then: Soft Assertions로 모든 필드 한 번에 검증
        SoftAssertions.assertSoftly(softly -> {
            softly.assertThat(detail.getOrderId()).isEqualTo(orderId);
            softly.assertThat(detail.getMemberName()).isEqualTo("홍길동");
            softly.assertThat(detail.getTotalPrice()).isEqualTo(3500);
            softly.assertThat(detail.getStatus()).isEqualTo(OrderStatus.ORDERED);
            softly.assertThat(detail.getItems())
                .hasSize(2)
                .extracting("productName")
                .containsExactlyInAnyOrder("사과", "바나나");
        });
    }

    @Test
    @DisplayName("존재하지 않는 주문 조회 시 예외가 발생한다")
    void 존재하지_않는_주문_조회() {
        assertThatThrownBy(() -> queryService.findDetail(999L))
            .isInstanceOf(OrderNotFoundException.class)
            .hasMessageContaining("999");
    }
}
```

---

## 10. 정리 — 상황별 권장 방법 정리표

| 상황 | 권장 AssertJ 방법 |
|------|----------------|
| 단순 값 비교 | `assertThat(x).isEqualTo(y)` |
| 예외 타입 + 메시지 | `assertThatThrownBy().isInstanceOf().hasMessage()` |
| 예외가 안 나야 함 | `assertThatNoException().isThrownBy()` |
| 컬렉션 포함 여부 | `.contains()` / `.containsExactlyInAnyOrder()` |
| 컬렉션 특정 필드 추출 | `.extracting("field").containsExactlyInAnyOrder()` |
| 컬렉션 필터 후 검증 | `.filteredOn(...).hasSize(...).extracting(...)` |
| equals 없는 객체 비교 | `.usingRecursiveComparison().ignoringFields()` |
| 여러 필드 동시 검증 | `SoftAssertions.assertSoftly(softly -> { ... })` |
| 실패 메시지 개선 | `.as("설명 %d", value).isEqualTo(...)` |

---

## 11. 참고 자료

- [AssertJ 공식 문서](https://assertj.github.io/doc/)
- [AssertJ GitHub](https://github.com/assertj/assertj)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [Spring Boot Testing 공식 문서](https://docs.spring.io/spring-boot/docs/current/reference/html/testing.html)

---

> 출처: Claude Desktop 대화 (2026-05-19)
