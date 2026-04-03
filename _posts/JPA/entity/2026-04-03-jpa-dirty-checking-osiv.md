---
title: 더티 체킹과 OSIV
date: 2026-04-03 09:00:00 +0900
categories: [JPA, 영속성 컨텍스트]
tags: [JPA, 영속성 컨텍스트, 더티체킹, DirtyChecking, OSIV, OpenSessionInView, LazyInitializationException]
---

## 📗 1. 더티 체킹 (Dirty Checking)

---

### 📌 em.update()가 없는 이유

JPA 이전에는 엔티티를 수정하면 개발자가 직접 UPDATE SQL을 작성하거나 `session.update(entity)` 같은 메서드를 호출해야 했다. JPA는 이 불편함을 영속성 컨텍스트의 "변경 감지(Dirty Checking)" 메커니즘으로 해결한다.

영속 상태의 엔티티는 영속성 컨텍스트가 감시하고 있다. 트랜잭션이 커밋되기 전 flush가 발생하는 시점에 영속성 컨텍스트는 관리 중인 모든 영속 엔티티를 대상으로 현재 상태와 스냅샷을 비교한다. 달라진 필드가 있으면 그 엔티티에 대한 UPDATE SQL을 쓰기 지연 SQL 저장소에 추가한다.

```java
@Transactional
public void updateMemberName(Long id, String newName) {
    // findById() → 영속 상태로 반환. 1차 캐시에 엔티티 + 스냅샷 저장됨
    Member member = memberRepository.findById(id).orElseThrow();

    // 필드 변경만 하면 됨. em.update() 같은 건 없다.
    member.updateName(newName);

    // 트랜잭션 종료 → flush → 스냅샷 비교 → name이 변경됨을 감지
    // → UPDATE SQL 자동 생성 및 실행
}
```

---

### 📌 스냅샷 비교 원리

엔티티가 1차 캐시에 등록될 때 JPA는 해당 시점의 상태를 스냅샷(복사본)으로 함께 저장한다.

```
em.find() 또는 em.persist() 시점

1차 캐시에 저장되는 것:
┌────────────────────────────────────────────────┐
│  엔티티 (현재 상태)        스냅샷 (최초 상태)    │
│  Member {                  Member {             │
│    id:    1,                 id:    1,           │
│    name:  "김철수",  ←변경   name:  "홍길동",    │
│    age:   30                 age:   30           │
│  }                         }                    │
└────────────────────────────────────────────────┘

flush 시점
    ↓
현재 상태 vs 스냅샷 비교 → name 변경 감지
    ↓
UPDATE member SET name='김철수', age=30, ... WHERE id=1
```

스냅샷 비교는 flush 시점에 관리 중인 모든 영속 엔티티를 대상으로 일어난다. 엔티티가 많을수록 비교 비용이 커지므로, 영속성 컨텍스트에 불필요하게 많은 엔티티를 올려두지 않는 것이 좋다.

더티 체킹이 동작하려면 반드시 영속 상태여야 한다. 준영속이나 비영속 상태의 엔티티를 수정해도 아무 일도 일어나지 않는다.

---

### 📌 기본 UPDATE는 왜 전체 컬럼을 포함하는가

`name`만 바꿨는데 생성되는 SQL을 확인해보면 전체 컬럼이 포함된다.

```sql
-- name만 변경했지만
UPDATE member
SET name=?, age=?, email=?, updated_at=?
WHERE member_id=?
-- age, email도 SET에 포함됨
```

이유는 성능 최적화다. UPDATE 쿼리가 항상 동일한 형태를 갖기 때문에 DB의 실행 계획 캐시를 재사용할 수 있다. 만약 변경된 컬럼에 따라 SQL이 달라진다면 매번 새로운 실행 계획을 만들어야 한다.

변경된 컬럼만 포함하는 UPDATE를 원한다면 `@DynamicUpdate`를 사용한다.

```java
@Entity
@DynamicUpdate // 변경된 컬럼만 UPDATE에 포함
public class Member extends BaseEntity { ... }

// @DynamicUpdate 적용 후 name만 변경 시
UPDATE member SET name=?, updated_at=? WHERE member_id=?
```

`@DynamicUpdate`는 매 수정마다 SQL을 동적으로 생성하므로 쿼리 캐시를 재사용하지 못한다. 컬럼이 30개 이상으로 많은 테이블이나, 컬럼마다 UPDATE 비용이 크게 다른 경우가 아니라면 기본 동작이 더 효율적이다.

---

### 📌 실습 — 더티 체킹 로그 확인

```java
@SpringBootTest
@Transactional
class DirtyCheckingTest {

    @PersistenceContext
    private EntityManager em;

    @Test
    @DisplayName("더티 체킹 — 수정만 해도 UPDATE 자동 실행")
    void dirtyCheckingTest() {
        Member member = new Member("홍길동", 30, "hong@test.com");
        em.persist(member);
        em.flush();
        em.clear();

        Member found = em.find(Member.class, member.getId()); // 영속 상태 (스냅샷 저장됨)

        System.out.println("=== 수정 (em.update 없음) ===");
        found.updateName("김철수");

        System.out.println("=== flush — UPDATE SQL 실행 예상 ===");
        em.flush(); // 스냅샷 비교 → name 변경 감지 → UPDATE 실행

        em.clear();
        Member updated = em.find(Member.class, member.getId());
        assertThat(updated.getName()).isEqualTo("김철수");
    }

    @Test
    @DisplayName("준영속 상태에서는 더티 체킹 미동작")
    void detachedNoDirtyCheckingTest() {
        Member member = new Member("홍길동", 30, "hong@test.com");
        em.persist(member);
        em.flush();

        em.detach(member); // 준영속으로 전환

        member.updateName("김철수"); // 수정해도 감지 대상에서 제외

        em.flush(); // UPDATE 실행 안 됨

        em.clear();
        Member found = em.find(Member.class, member.getId());
        assertThat(found.getName()).isEqualTo("홍길동"); // 변경 반영 안 됨
    }
}
```

---

## 📗 2. OSIV (Open Session In View)

---

### 📌 OSIV가 생긴 배경

OSIV를 이해하려면 먼저 영속성 컨텍스트의 기본 범위를 알아야 한다. OSIV를 끈 상태에서 영속성 컨텍스트는 `@Transactional` 메서드가 시작할 때 열리고 종료될 때 닫힌다. 이후 Controller에서 지연 로딩을 시도하면 영속성 컨텍스트(Session)가 이미 닫혔으므로 `LazyInitializationException: could not initialize proxy - no Session`이 발생한다.

이 예외를 피하기 위해 HTTP 요청이 들어오는 순간부터 응답이 나갈 때까지 영속성 컨텍스트를 유지하는 패턴이 OSIV다. Spring Boot에서는 기본값이 `true`다.

### 📌 Spring의 OSIV 구현 — OpenEntityManagerInViewFilter

`spring.jpa.open-in-view=true`이면 `OpenEntityManagerInViewFilter`가 서블릿 필터 수준에서 자동으로 등록된다.

```
HTTP 요청
    ↓
OpenEntityManagerInViewFilter.doFilter()
    → EntityManagerFactory에서 EntityManager 생성
    → TransactionSynchronizationManager에 바인딩 (커넥션 점유 시작)
    ↓
Controller → Service (@Transactional) → Controller → View
    ↓
OpenEntityManagerInViewFilter.doFilter() 종료
    → EntityManager.close() 호출 (커넥션 반환)
```

OSIV ON 상태에서는 `@Transactional`이 끝나도 EntityManager는 닫히지 않는다. 트랜잭션만 종료(커밋)되고 EntityManager는 살아있다. 덕분에 Controller에서도 지연 로딩이 가능하다.

### 📌 OSIV의 심각한 문제 — DB 커넥션 고갈

OSIV가 편리하지만 치명적인 단점이 있다. HTTP 요청 처리 중 내내 DB 커넥션을 점유한다. 일반적인 커넥션 풀은 10~30개 수준인데, 동시 요청이 많아지면 모든 커넥션이 점유된 채 사용 가능한 커넥션이 없어서 요청들이 커넥션 대기 상태에 빠진다.

특히 외부 API 호출처럼 응답 시간이 긴 작업이 Controller에서 이루어지면, 그 시간 동안 DB 커넥션이 아무 일도 하지 않고 잡혀 있게 된다.

| 구분 | OSIV ON | OSIV OFF |
|---|---|---|
| 영속성 컨텍스트 유지 범위 | HTTP 요청 전체 | 트랜잭션 범위만 |
| DB 커넥션 점유 시간 | 요청 시작 ~ 응답 완료 | 트랜잭션 시작 ~ 종료 |
| Controller에서 지연 로딩 | 가능 | 불가 (예외 발생) |
| 트래픽 많을 때 | 커넥션 고갈 위험 | 안전 |
| 권장 환경 | 단순한 소규모 | 실무 (권장) |

```yaml
spring:
  jpa:
    open-in-view: false  # 실무에서는 반드시 false로 설정
```

`true`인 채로 앱을 시작하면 콘솔에 아래 경고가 출력된다.

```
WARN  spring.jpa.open-in-view is enabled by default.
Therefore, database queries may be performed during view rendering.
```

---

### 📌 OSIV OFF 환경에서의 올바른 패턴

OSIV를 끄면 Service 계층의 트랜잭션 안에서만 영속성 컨텍스트가 살아있다. Controller에서는 지연 로딩이 불가능하므로 두 가지 방법으로 해결한다.

**전략 1 — Service에서 DTO로 변환하여 반환 (권장)**

트랜잭션이 살아있는 Service 안에서 엔티티를 DTO로 변환한다. DTO는 순수 자바 객체이므로 영속성 컨텍스트와 무관하게 Controller에서 자유롭게 사용할 수 있다.

```java
@Transactional(readOnly = true)
public MemberResponse findById(Long id) {
    Member member = memberRepository.findById(id).orElseThrow(
        () -> new IllegalArgumentException("Member not found: " + id)
    );
    return new MemberResponse(member); // 트랜잭션이 살아있는 동안 DTO 변환
    // 메서드 종료 → 트랜잭션·영속성 컨텍스트 종료
    // MemberResponse는 순수 자바 객체 → 문제 없음
}
```

**전략 2 — Fetch Join으로 필요한 연관 데이터를 한꺼번에 로딩**

처음 조회할 때부터 필요한 연관 데이터를 JOIN으로 함께 가져온다. 지연 로딩을 시도하지 않으므로 영속성 컨텍스트가 닫혀도 문제가 없다. 상세 내용은 Phase 6 FetchType · N+1 문제에서 다룬다.

```java
// Repository
@Query("select m from Member m join fetch m.orders where m.id = :id")
Optional<Member> findWithOrdersById(@Param("id") Long id);

// Service — 트랜잭션 안에서 orders까지 한꺼번에 로딩
@Transactional(readOnly = true)
public MemberWithOrdersResponse findWithOrders(Long id) {
    Member member = memberRepository.findWithOrdersById(id).orElseThrow();
    return new MemberWithOrdersResponse(member);
}
```

---

## 📗 3. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| 더티 체킹 | flush 시 모든 영속 엔티티의 스냅샷을 비교 → 변경 감지 → UPDATE 자동 생성 |
| 동작 조건 | 반드시 영속 상태여야 함. 준영속·비영속은 감지 안 됨 |
| 기본 UPDATE | 변경 컬럼 외에도 전체 컬럼 포함. 쿼리 캐시 재사용 목적 |
| @DynamicUpdate | 변경 컬럼만 UPDATE. 컬럼 수 30개 이상일 때 고려 |
| OSIV ON | HTTP 요청 전체에 PC·커넥션 유지. Controller 지연 로딩 가능 |
| OSIV OFF | 트랜잭션 범위에만 PC 유지. 커넥션 효율적 사용. 실무 권장 |
| OSIV OFF 대응 | Service에서 DTO 변환 또는 Fetch Join으로 필요 데이터 미리 로딩 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Spring Boot OSIV 설정: <https://docs.spring.io/spring-boot/docs/current/reference/html/data.html#data.sql.jpa-and-spring-data.open-entity-manager-in-view>
- 공식문서 - Hibernate DynamicUpdate: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#entity-mutable>
