---
title: 1차 캐시와 쓰기 지연
date: 2026-04-03 09:00:00 +0900
categories: [JPA, 영속성 컨텍스트]
order: 2
tags: [JPA, 영속성 컨텍스트, 1차캐시, 쓰기지연, flush, JPQL, BatchInsert]
---

##  1. 1차 캐시 (First-Level Cache)

---

### 📌 내부 구조

1차 캐시는 `EntityManager` 내부에 있는 `HashMap` 구조다. key는 `@Id` 필드(PK)의 값이고, value는 엔티티 인스턴스와 그 스냅샷(최초 상태 복사본)의 쌍이다. 엔티티를 `persist()`하거나 `find()`로 조회하면 이 Map에 등록된다.

```
1차 캐시 내부
┌──────────────────────────────────────────────┐
│  key(@Id)  →  value(Entity + Snapshot)       │
│  1L        →  Member{name="홍길동"} + 복사본  │
│  2L        →  Member{name="김철수"} + 복사본  │
└──────────────────────────────────────────────┘
```

스냅샷(복사본)도 함께 저장하는 이유는 더티 체킹(변경 감지)에 사용하기 위해서다. flush 시점에 현재 엔티티 상태와 스냅샷을 비교해서 달라진 필드가 있으면 UPDATE SQL을 생성한다.

### 📌 find() 동작 흐름

`em.find(Member.class, 1L)`을 호출하면 다음 순서로 동작한다.

1. 1차 캐시에서 key=`1L`을 찾는다.
2. 있으면 SQL 없이 즉시 반환한다 (Cache HIT).
3. 없으면 DB에 SELECT SQL을 실행한다 (Cache MISS).
4. 결과 Row를 엔티티 객체로 변환한다.
5. 변환된 엔티티와 스냅샷을 1차 캐시에 저장한다.
6. 영속 상태의 엔티티를 반환한다.

### 📌 1차 캐시의 두 가지 핵심 효과

**동일성(Identity) 보장**

같은 트랜잭션 내에서 같은 PK로 조회한 엔티티는 항상 `==` 비교 결과가 `true`다.

```java
Member m1 = em.find(Member.class, 1L); // DB SELECT → 캐시 저장
Member m2 = em.find(Member.class, 1L); // 캐시에서 반환 (SQL 없음)

System.out.println(m1 == m2); // true — 완전히 같은 인스턴스
```

Phase 1에서 다뤘던 JDBC의 동일성 불일치 문제가 여기서 해결된다. 자바 컬렉션에서 같은 객체를 꺼내는 것과 동일하게 동작한다.

**불필요한 DB 조회 방지**

같은 트랜잭션 내에서 `findById(1L)`을 두 번 호출하면 두 번째 호출은 SQL을 전혀 실행하지 않는다. 하나의 요청 내에서 같은 엔티티를 여러 레이어에서 반복 조회하는 경우 DB 왕복을 줄여준다.

> 💡 1차 캐시는 트랜잭션 범위에서만 유효하다. 트랜잭션 A에서 캐시에 올려놓은 엔티티는 트랜잭션 B에서 볼 수 없다. 여러 요청에 걸쳐 공유되는 애플리케이션 수준 캐시(2차 캐시)와는 완전히 다르다.

---

##  2. 쓰기 지연 (Transactional Write-Behind)

---

### 📌 동작 원리

`em.persist()`를 호출해도 즉시 INSERT SQL이 실행되지 않는다. SQL은 **쓰기 지연 SQL 저장소**에 누적되었다가 flush 시점에 한꺼번에 DB로 전송된다.

```java
@Transactional
public void saveMembers() {
    em.persist(new Member("홍길동", 30, "hong@test.com")); // SQL 저장소에 INSERT 추가
    em.persist(new Member("김철수", 25, "kim@test.com"));  // SQL 저장소에 INSERT 추가
    em.persist(new Member("이영희", 28, "lee@test.com"));  // SQL 저장소에 INSERT 추가
    // 여기까지 SQL 실행 없음
} // 메서드 종료 → 트랜잭션 커밋 → flush → INSERT 3개 한꺼번에 DB 전송
```

### 📌 쓰기 지연의 실질적인 이점 — JDBC Batch

쓰기 지연은 단순히 SQL을 늦게 실행하는 것 이상의 의미가 있다. `hibernate.jdbc.batch_size`를 설정하면 Hibernate가 JDBC의 `PreparedStatement.addBatch()` / `executeBatch()`를 활용해서 여러 INSERT를 한 번의 DB 왕복으로 처리한다.

```yaml
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 50      # INSERT 50개를 묶어서 한 번에 전송
        order_inserts: true   # INSERT 순서 정렬로 배치 효율 향상
        order_updates: true   # UPDATE 순서 정렬
```

단, `@GeneratedValue(strategy = GenerationType.IDENTITY)` 전략을 쓰면 배치 INSERT가 비활성화된다. IDENTITY 전략은 DB에 INSERT한 직후 생성된 PK를 가져와야 하기 때문에 INSERT를 즉시 실행해야 한다. 대량 INSERT가 필요한 경우 `SEQUENCE` 전략 또는 UUID를 PK로 사용하는 것을 고려해야 한다.

---

##  3. flush — 영속성 컨텍스트와 DB 동기화

---

flush는 영속성 컨텍스트의 변경 내용(쓰기 지연 SQL 저장소에 쌓인 SQL들)을 DB에 전송하는 동작이다. **커밋과는 다르다.** flush를 해도 트랜잭션은 유지되고, 롤백하면 DB 반영도 취소된다.

### 📌 flush 발생 3가지 시점

**① em.flush() 직접 호출**

벌크 연산 전에 직접 호출하거나, 테스트에서 SQL 실행을 확인할 때 사용한다.

**② 트랜잭션 커밋 시 자동 발생**

가장 일반적인 경우다. `@Transactional` 메서드가 정상 종료될 때 Spring이 커밋을 호출하고, 이 시점에 Hibernate가 flush를 자동으로 실행한다.

**③ JPQL 쿼리 실행 직전 자동 발생**

이것이 많은 사람이 놓치는 포인트다. JPQL은 SQL로 변환되어 DB에서 직접 실행된다. 만약 영속성 컨텍스트에만 있고 DB에는 아직 반영되지 않은 데이터가 있다면 JPQL 결과에서 그 데이터가 빠지는 문제가 생긴다. JPA는 이를 방지하기 위해 JPQL 실행 직전에 자동으로 flush를 수행한다.

```java
@Transactional
public void jpqlAutoFlushTest() {
    // 홍길동을 persist했지만 아직 DB에 없음
    Member member = new Member("홍길동", 30, "hong@test.com");
    em.persist(member);

    // JPQL 실행 직전 → 자동 flush → 홍길동이 DB에 INSERT됨
    // JPQL은 DB에서 실행되므로 flush된 결과가 포함됨
    List<Member> members = em.createQuery(
        "select m from Member m where m.name = :name", Member.class)
        .setParameter("name", "홍길동")
        .getResultList();

    assertThat(members).hasSize(1); // 자동 flush 덕분에 홍길동이 조회됨
}
```

---

##  4. 실습

---

### 📌 1차 캐시 HIT 로그 확인

```java
@SpringBootTest
@Transactional
class FirstLevelCacheTest {

    @PersistenceContext
    private EntityManager em;

    @Test
    @DisplayName("1차 캐시 HIT — 두 번째 find에서 SQL 미실행")
    void firstLevelCacheHitTest() {
        Member saved = new Member("홍길동", 30, "hong@test.com");
        em.persist(saved);
        em.flush();
        em.clear(); // 1차 캐시 비움

        System.out.println("=== 첫 번째 find — DB SELECT 실행 예상 ===");
        Member m1 = em.find(Member.class, saved.getId());

        System.out.println("=== 두 번째 find — SQL 없이 캐시에서 반환 예상 ===");
        Member m2 = em.find(Member.class, saved.getId());

        assertThat(m1).isSameAs(m2); // == true
        System.out.println("동일 인스턴스: " + (m1 == m2)); // true
    }
}
```

실행 로그를 보면 SELECT가 한 번만 나타난다.

```
=== 첫 번째 find — DB SELECT 실행 예상 ===
Hibernate: select m1_0.member_id, ... from member m1_0 where m1_0.member_id=?

=== 두 번째 find — SQL 없이 캐시에서 반환 예상 ===
(SQL 출력 없음)

동일 인스턴스: true
```

### 📌 쓰기 지연 SQL 실행 타이밍 확인

```java
@Test
@DisplayName("쓰기 지연 — persist 후 flush 전까지 SQL 미실행")
void writeBehindTest() {
    System.out.println("=== persist 시작 (SQL 없어야 함) ===");
    Member m1 = new Member("홍길동", 30, "hong@test.com");
    Member m2 = new Member("김철수", 25, "kim@test.com");

    em.persist(m1);
    System.out.println("m1 persist 완료");
    em.persist(m2);
    System.out.println("m2 persist 완료");

    System.out.println("=== flush 호출 (INSERT 실행 예상) ===");
    em.flush();
    System.out.println("=== flush 완료 ===");
}
```

실행 로그를 보면 persist 직후에는 SQL이 없고 flush 시점에 INSERT가 한꺼번에 실행된다.

```
=== persist 시작 (SQL 없어야 함) ===
m1 persist 완료
m2 persist 완료
=== flush 호출 (INSERT 실행 예상) ===
Hibernate: insert into member (age, ...) values (?, ...)
Hibernate: insert into member (age, ...) values (?, ...)
=== flush 완료 ===
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 Batching Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#batch>
