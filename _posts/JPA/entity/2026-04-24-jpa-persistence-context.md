---
title: 영속성 컨텍스트
date: 2026-04-24 09:10:00 +0900
categories: [JPA, 기본 개념]
order: 1
tags: [JPA, 영속성 컨텍스트, EntityManager, EntityManagerFactory, ThreadLocal, PersistenceContext, 엔티티생명주기, 비영속, 영속, 준영속, 1차캐시, 쓰기지연, flush, JPQL, BatchInsert, 더티체킹, DirtyChecking, DynamicUpdate, OSIV, OpenSessionInView, LazyInitializationException]
---

##  1. 영속성 컨텍스트란

---

JPA를 처음 접하면 "왜 DB에 바로 저장하지 않고 영속성 컨텍스트라는 중간 단계가 있는 걸까?"라는 의문이 생긴다.

예를 들어 한 HTTP 요청 안에서 아래와 같은 일이 벌어진다고 생각해보자.

```java
Member member = findById(1L);      // SELECT → DB 왕복 1번
member.setName("변경");
Member same = findById(1L);        // 또 SELECT → DB 왕복 2번 (중복)
orderService.process(member);      // 내부에서 또 findById(1L) → DB 왕복 3번
```

DB에 직접 요청한다면 같은 데이터를 여러 번 조회하는 중복 DB 왕복이 발생한다. 그리고 `member.setName("변경")`을 했는데, 이걸 DB에 반영하려면 개발자가 직접 UPDATE SQL을 작성하고 실행해야 한다.

영속성 컨텍스트(Persistence Context)는 이런 문제들을 해결하는 **"애플리케이션과 DB 사이의 스마트한 중간 저장소"** 다. 영속성 컨텍스트가 제공하는 기능은 다음과 같다.

- 한 트랜잭션 안에서 같은 데이터를 다시 요청하면 DB에 가지 않고 캐시에서 바로 반환한다 (1차 캐시)
- 엔티티를 수정하면 자동으로 감지해서 트랜잭션 끝에 UPDATE를 실행한다 (더티 체킹)
- INSERT도 모았다가 한꺼번에 DB로 보낸다 (쓰기 지연)
- 같은 PK로 조회한 엔티티는 항상 같은 인스턴스임을 보장한다 (동일성 보장)

영속성 컨텍스트 자체는 눈에 보이는 클래스나 인터페이스가 아니다. `EntityManager`를 통해서만 접근하고 관리할 수 있다.

---

##  2. EntityManagerFactory와 EntityManager

---

### 📌 계층 구조

```
애플리케이션 시작
       ↓
EntityManagerFactory (1개, 무거운 객체)
  - DB 연결풀, 메타데이터 파싱
  - 스레드 안전
       ↓ 요청(트랜잭션)마다 생성
EntityManager (N개, 가벼운 객체)
  - 영속성 컨텍스트 보유
  - 스레드 공유 절대 금지
```

`EntityManagerFactory`는 애플리케이션이 시작될 때 딱 한 번 생성된다. 내부적으로 DB 드라이버 로딩, 커넥션 풀 생성, 엔티티 클래스 스캔 및 매핑 정보 파싱, SQL 방언(Dialect) 설정 등 무거운 초기화를 수행한다.

`EntityManager`는 하나의 트랜잭션 단위로 생성되고 소멸된다. `EntityManager`가 스레드 간 공유되면 안 되는 이유는 영속성 컨텍스트(내부 1차 캐시)가 상태를 가지고 있기 때문이다.

| 구분 | EntityManagerFactory | EntityManager |
|---|---|---|
| 생성 비용 | 크다 | 작다 |
| 개수 | 애플리케이션당 1개 | 트랜잭션당 1개 |
| 스레드 안전 | 안전 | 공유 금지 |
| 생존 범위 | 애플리케이션 전체 | 트랜잭션 범위 |

### 📌 Spring에서 EntityManager 주입 원리 — 프록시와 ThreadLocal

Spring에서 `@PersistenceContext`로 EntityManager를 주입받으면 실제 EntityManager가 아닌 **프록시 객체**가 주입된다.

`em.persist(member)`처럼 메서드를 호출하면, 프록시는 `TransactionSynchronizationManager`에 "지금 이 스레드에서 진행 중인 트랜잭션에 바인딩된 실제 EntityManager"를 요청한다. `TransactionSynchronizationManager`는 내부적으로 `ThreadLocal<Map<Object, Object>>`를 사용한다. 각 스레드는 자신만의 ThreadLocal 공간을 가지고 있어서, 스레드 A의 EntityManager와 스레드 B의 EntityManager가 완전히 격리된다.

`@Transactional` 메서드가 호출되면 Spring AOP 프록시가 가로채서 `EntityManagerFactory.createEntityManager()`로 새 EntityManager를 생성하고, 이를 현재 스레드의 ThreadLocal에 저장한다. 메서드가 끝나면 커밋 또는 롤백 후 ThreadLocal에서 EntityManager를 제거하고 `em.close()`를 호출한다.

이 메커니즘 덕분에 싱글톤 빈인 Service 클래스에 EntityManager를 필드로 가져도 스레드 안전하게 동작한다.

```java
@Service
public class MemberService {

    @PersistenceContext
    private EntityManager em; // 주입되는 건 실제 EM이 아니라 프록시

    @Transactional
    public void save(Member member) {
        em.persist(member); // 프록시 → ThreadLocal에서 실제 EM 조회 → 위임
    }
}
```

### 📌 EntityManager 핵심 메서드

**persist(entity)** — 비영속 상태의 엔티티를 영속성 컨텍스트에 등록한다. 이 시점에 INSERT SQL은 실행되지 않는다. 1차 캐시에 올라가고 쓰기 지연 SQL 저장소에 INSERT 쿼리가 쌓인다.

> 💡 `@GeneratedValue(strategy = GenerationType.IDENTITY)` 전략 예외: IDENTITY 전략은 PK를 DB가 생성하기 때문에 INSERT가 즉시 실행된다.

**find(Class, id)** — 1차 캐시를 먼저 확인한다. 있으면 SQL 없이 반환하고, 없으면 DB에 SELECT를 실행한 뒤 1차 캐시에 저장 후 반환한다. `getReference()`는 프록시 객체를 반환한다. 실제 필드에 접근하는 시점까지 SQL을 실행하지 않는다.

**merge(entity)** — 준영속 또는 비영속 상태의 엔티티를 영속 상태로 전환한다. 파라미터로 넘긴 인스턴스는 `merge()` 이후에도 여전히 준영속 상태다. 반드시 반환값을 사용해야 한다.

```java
// 올바른 사용법
Member managedMember = em.merge(detachedMember);
// managedMember가 영속 상태. 이것을 수정해야 더티 체킹이 동작한다.
```

**remove(entity)** — 반드시 영속 상태의 엔티티를 파라미터로 넘겨야 한다. 비영속이나 준영속을 넘기면 `IllegalArgumentException`이 발생한다.

**flush()** — 쓰기 지연 SQL 저장소에 쌓인 SQL들을 DB에 전송한다. 트랜잭션을 커밋하지는 않는다. flush 후에도 영속성 컨텍스트는 그대로 유지된다.

flush가 자동으로 발생하는 시점은 세 가지다.
- `em.flush()` 직접 호출
- 트랜잭션 커밋 시 자동 발생
- JPQL 쿼리 실행 직전 자동 발생 (1차 캐시와 DB 불일치 방지 목적)

**clear()** — 1차 캐시를 전부 비운다. 관리 중이던 모든 엔티티가 준영속 상태로 전환된다. 벌크 연산(UPDATE/DELETE) 이후 반드시 호출해야 한다.

---

##  3. 엔티티 생명주기

---

### 📌 4가지 상태 개요

| 상태 | 설명 | 특징 |
|---|---|---|
| 비영속 (New) | new로 생성한 순수 자바 객체 | JPA와 무관 |
| 영속 (Managed) | 영속성 컨텍스트가 관리 중 | 더티 체킹, 지연 로딩 가능 |
| 준영속 (Detached) | 관리에서 벗어난 상태 | PK 있음, 더티 체킹 안됨 |
| 삭제 (Removed) | 삭제 예약 상태 | flush 시 DELETE 실행 |

### 📌 비영속 (New / Transient)

`new` 키워드로 생성한 순수 자바 객체다. JPA와 아무 관련이 없고, `em.contains(member)`를 호출하면 `false`를 반환한다.

### 📌 영속 (Managed)

영속 상태에 들어오는 방법은 `em.persist()`, `em.find()` 또는 JPQL 조회, `em.merge()`의 반환값이다.

영속 상태의 특권:
- **더티 체킹**: 필드를 수정하면 트랜잭션 커밋 시 UPDATE SQL이 자동 실행된다.
- **지연 로딩 가능**: `@ManyToOne(fetch = LAZY)` 같은 연관 엔티티에 접근할 때 필요한 시점에 SQL이 자동 실행된다.
- **1차 캐시 조회**: 같은 트랜잭션 내에서 같은 PK로 다시 조회하면 SQL 없이 캐시에서 반환된다.

```java
@Transactional
public void updateMemberName(Long id, String newName) {
    Member member = memberRepository.findById(id).orElseThrow();
    member.updateName(newName); // 수정만 하면 됨
    // 트랜잭션 종료 → 더티 체킹 → UPDATE SQL 자동 실행
    // memberRepository.save(member) 불필요
}
```

> 💡 이미 영속 상태인 엔티티에 `save()`를 다시 호출하면 내부적으로 불필요한 `merge()` 과정이 생긴다.

### 📌 준영속 (Detached)

영속 상태였다가 영속성 컨텍스트의 관리에서 벗어난 상태다. 한 번은 영속 상태였으므로 PK 값을 가지고 있다는 점이 비영속과의 차이다.

준영속 상태로 전환되는 방법:

```java
em.detach(member); // 특정 엔티티 하나만 준영속으로 전환
em.clear();        // 영속성 컨텍스트 전체 초기화 → 모든 엔티티 준영속
em.close();        // EntityManager 종료
// Spring에서는 @Transactional 메서드 종료 시 자동으로 close()
```

### 📌 LazyInitializationException — 준영속의 가장 큰 함정

준영속 상태에서 지연 로딩을 시도하면 영속성 컨텍스트가 없으므로 프록시를 초기화할 수 없어 `LazyInitializationException`이 발생한다. 실무에서 가장 자주 만나는 JPA 예외다.

```java
// OSIV OFF 환경에서의 문제 시나리오
@Transactional(readOnly = true)
public Member findMember(Long id) {
    return memberRepository.findById(id).orElseThrow();
} // @Transactional 종료 → 영속성 컨텍스트 닫힘 → member가 준영속으로 전환

// Controller 계층 (트랜잭션 없음)
public ResponseEntity<?> getMember(Long id) {
    Member member = memberService.findMember(id); // 이미 준영속
    List<Order> orders = member.getOrders();       // 프록시 객체
    int size = orders.size();                      // → LazyInitializationException 발생!
}
```

이 예외가 발생하면 "영속성 컨텍스트가 닫힌 상태에서 지연 로딩을 시도했구나"라고 바로 파악해야 한다.

### 📌 merge()의 동작 방식 — 준영속 → 영속

1. 파라미터 엔티티의 PK로 1차 캐시를 확인한다.
2. 없으면 DB에서 SELECT로 조회한다.
3. 조회한 엔티티에 파라미터 엔티티의 값을 복사한다.
4. 그 엔티티를 영속 상태로 반환한다.

파라미터로 넘긴 객체는 `merge()` 후에도 준영속 상태로 남는다. 반환된 새 인스턴스가 영속 상태다.

### 📌 삭제 (Removed)

`em.remove()`를 호출하면 삭제 상태가 된다. 반드시 영속 상태의 엔티티를 파라미터로 넘겨야 한다.

### 📌 실습 — 생명주기 상태 직접 확인

```java
@SpringBootTest
@Transactional
class EntityLifecycleTest {

    @PersistenceContext
    private EntityManager em;

    @Test
    @DisplayName("엔티티 생명주기 4가지 상태 확인")
    void lifecycleTest() {
        // 1. 비영속
        Member member = new Member("홍길동", 30, "hong@test.com");
        assertThat(em.contains(member)).isFalse();

        // 2. 영속
        em.persist(member);
        assertThat(em.contains(member)).isTrue();

        // 3. 준영속
        em.detach(member);
        assertThat(em.contains(member)).isFalse();

        // 4. merge() — 반환값이 영속, 원본은 준영속 그대로
        Member merged = em.merge(member);
        assertThat(em.contains(member)).isFalse();  // 원본 여전히 준영속
        assertThat(em.contains(merged)).isTrue();   // 반환값이 영속
    }
}
```

---

##  4. 1차 캐시와 쓰기 지연

---

### 📌 1차 캐시 내부 구조

1차 캐시는 `EntityManager` 내부에 있는 `HashMap` 구조다. key는 `@Id` 필드(PK)의 값이고, value는 엔티티 인스턴스와 그 스냅샷(최초 상태 복사본)의 쌍이다.

```
1차 캐시 내부
┌──────────────────────────────────────────────┐
│  key(@Id)  →  value(Entity + Snapshot)       │
│  1L        →  Member{name="홍길동"} + 복사본  │
│  2L        →  Member{name="김철수"} + 복사본  │
└──────────────────────────────────────────────┘
```

스냅샷을 함께 저장하는 이유는 더티 체킹(변경 감지)에 사용하기 위해서다.

### 📌 1차 캐시의 두 가지 핵심 효과

**동일성(Identity) 보장** — 같은 트랜잭션 내에서 같은 PK로 조회한 엔티티는 항상 `==` 비교 결과가 `true`다.

```java
Member m1 = em.find(Member.class, 1L); // DB SELECT → 캐시 저장
Member m2 = em.find(Member.class, 1L); // 캐시에서 반환 (SQL 없음)
System.out.println(m1 == m2); // true
```

**불필요한 DB 조회 방지** — 같은 트랜잭션 내에서 `findById(1L)`을 두 번 호출하면 두 번째 호출은 SQL을 전혀 실행하지 않는다.

> 💡 1차 캐시는 트랜잭션 범위에서만 유효하다. 여러 요청에 걸쳐 공유되는 2차 캐시와는 완전히 다르다.

### 📌 쓰기 지연 (Transactional Write-Behind)

`em.persist()`를 호출해도 즉시 INSERT SQL이 실행되지 않는다. SQL은 쓰기 지연 SQL 저장소에 누적되었다가 flush 시점에 한꺼번에 DB로 전송된다.

```java
@Transactional
public void saveMembers() {
    em.persist(new Member("홍길동", 30, "hong@test.com")); // SQL 저장소에 추가
    em.persist(new Member("김철수", 25, "kim@test.com"));  // SQL 저장소에 추가
    em.persist(new Member("이영희", 28, "lee@test.com"));  // SQL 저장소에 추가
    // 여기까지 SQL 실행 없음
} // 트랜잭션 커밋 → flush → INSERT 3개 한꺼번에 DB 전송
```

### 📌 쓰기 지연의 실질적인 이점 — JDBC Batch

`hibernate.jdbc.batch_size`를 설정하면 Hibernate가 JDBC의 `addBatch()` / `executeBatch()`를 활용해서 여러 INSERT를 한 번의 DB 왕복으로 처리한다.

```yaml
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 50
        order_inserts: true
        order_updates: true
```

단, `IDENTITY` 전략을 쓰면 배치 INSERT가 비활성화된다. 대량 INSERT가 필요한 경우 `SEQUENCE` 전략 또는 UUID를 PK로 사용하는 것을 고려해야 한다.

### 📌 flush — 영속성 컨텍스트와 DB 동기화

flush는 영속성 컨텍스트의 변경 내용을 DB에 전송하는 동작이다. **커밋과는 다르다.** flush를 해도 트랜잭션은 유지되고, 롤백하면 DB 반영도 취소된다.

**JPQL 쿼리 실행 직전 자동 flush**는 많은 사람이 놓치는 포인트다. JPQL은 SQL로 변환되어 DB에서 직접 실행된다. 만약 영속성 컨텍스트에만 있고 DB에는 아직 반영되지 않은 데이터가 있다면 JPQL 결과에서 그 데이터가 빠지는 문제가 생긴다. JPA는 이를 방지하기 위해 JPQL 실행 직전에 자동으로 flush를 수행한다.

```java
@Transactional
public void jpqlAutoFlushTest() {
    Member member = new Member("홍길동", 30, "hong@test.com");
    em.persist(member);

    // JPQL 실행 직전 → 자동 flush → 홍길동이 DB에 INSERT됨
    List<Member> members = em.createQuery(
        "select m from Member m where m.name = :name", Member.class)
        .setParameter("name", "홍길동")
        .getResultList();

    assertThat(members).hasSize(1); // 자동 flush 덕분에 조회됨
}
```

### 📌 실습 — 1차 캐시 HIT 로그 확인

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
        em.clear();

        System.out.println("=== 첫 번째 find — DB SELECT 실행 예상 ===");
        Member m1 = em.find(Member.class, saved.getId());

        System.out.println("=== 두 번째 find — SQL 없이 캐시에서 반환 예상 ===");
        Member m2 = em.find(Member.class, saved.getId());

        assertThat(m1).isSameAs(m2); // == true
    }
}
```

### 📌 실습 — 쓰기 지연 SQL 실행 타이밍 확인

```java
@Test
@DisplayName("쓰기 지연 — persist 후 flush 전까지 SQL 미실행")
void writeBehindTest() {
    System.out.println("=== persist 시작 (SQL 없어야 함) ===");
    em.persist(new Member("홍길동", 30, "hong@test.com"));
    em.persist(new Member("김철수", 25, "kim@test.com"));
    System.out.println("=== flush 호출 (INSERT 실행 예상) ===");
    em.flush();
    System.out.println("=== flush 완료 ===");
}
```

---

##  5. 더티 체킹 (Dirty Checking)

---

### 📌 em.update()가 없는 이유

영속 상태의 엔티티는 영속성 컨텍스트가 감시하고 있다. 트랜잭션이 커밋되기 전 flush가 발생하는 시점에 영속성 컨텍스트는 관리 중인 모든 영속 엔티티를 대상으로 현재 상태와 스냅샷을 비교한다. 달라진 필드가 있으면 그 엔티티에 대한 UPDATE SQL을 쓰기 지연 SQL 저장소에 추가한다.

```java
@Transactional
public void updateMemberName(Long id, String newName) {
    Member member = memberRepository.findById(id).orElseThrow();
    member.updateName(newName);
    // 트랜잭션 종료 → flush → 스냅샷 비교 → name이 변경됨을 감지
    // → UPDATE SQL 자동 생성 및 실행
}
```

### 📌 스냅샷 비교 원리

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

더티 체킹이 동작하려면 반드시 영속 상태여야 한다. 준영속이나 비영속 상태의 엔티티를 수정해도 아무 일도 일어나지 않는다.

### 📌 기본 UPDATE는 왜 전체 컬럼을 포함하는가

`name`만 바꿨는데 생성되는 SQL에 전체 컬럼이 포함되는 이유는 성능 최적화다. UPDATE 쿼리가 항상 동일한 형태를 갖기 때문에 DB의 실행 계획 캐시를 재사용할 수 있다.

변경된 컬럼만 포함하는 UPDATE를 원한다면 `@DynamicUpdate`를 사용한다.

```java
@Entity
@DynamicUpdate // 변경된 컬럼만 UPDATE에 포함
public class Member extends BaseEntity { ... }
```

`@DynamicUpdate`는 매 수정마다 SQL을 동적으로 생성하므로 쿼리 캐시를 재사용하지 못한다. 컬럼이 30개 이상으로 많은 테이블이 아니라면 기본 동작이 더 효율적이다.

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

        Member found = em.find(Member.class, member.getId()); // 영속 상태

        System.out.println("=== 수정 (em.update 없음) ===");
        found.updateName("김철수");

        System.out.println("=== flush — UPDATE SQL 실행 예상 ===");
        em.flush();

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

##  6. OSIV (Open Session In View)

---

### 📌 OSIV가 생긴 배경

OSIV를 끈 상태에서 영속성 컨텍스트는 `@Transactional` 메서드가 시작할 때 열리고 종료될 때 닫힌다. 이후 Controller에서 지연 로딩을 시도하면 영속성 컨텍스트(Session)가 이미 닫혔으므로 `LazyInitializationException: could not initialize proxy - no Session`이 발생한다.

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

OSIV가 편리하지만 치명적인 단점이 있다. HTTP 요청 처리 중 내내 DB 커넥션을 점유한다. 동시 요청이 많아지면 모든 커넥션이 점유된 채 사용 가능한 커넥션이 없어서 요청들이 커넥션 대기 상태에 빠진다.

| 구분 | OSIV ON | OSIV OFF |
|---|---|---|
| 영속성 컨텍스트 유지 범위 | HTTP 요청 전체 | 트랜잭션 범위만 |
| DB 커넥션 점유 시간 | 요청 시작 ~ 응답 완료 | 트랜잭션 시작 ~ 종료 |
| Controller에서 지연 로딩 | 가능 | 불가 (예외 발생) |
| 트래픽 많을 때 | 커넥션 고갈 위험 | 안전 |

```yaml
spring:
  jpa:
    open-in-view: false  # 실무에서는 반드시 false로 설정
```

`true`인 채로 앱을 시작하면 콘솔에 경고가 출력된다.

### 📌 OSIV OFF 환경에서의 올바른 패턴

**전략 1 — Service에서 DTO로 변환하여 반환 (권장)**

```java
@Transactional(readOnly = true)
public MemberResponse findById(Long id) {
    Member member = memberRepository.findById(id).orElseThrow(
        () -> new IllegalArgumentException("Member not found: " + id)
    );
    return new MemberResponse(member); // 트랜잭션이 살아있는 동안 DTO 변환
}
```

**전략 2 — Fetch Join으로 필요한 연관 데이터를 한꺼번에 로딩**

```java
@Query("select m from Member m join fetch m.orders where m.id = :id")
Optional<Member> findWithOrdersById(@Param("id") Long id);

@Transactional(readOnly = true)
public MemberWithOrdersResponse findWithOrders(Long id) {
    Member member = memberRepository.findWithOrdersById(id).orElseThrow();
    return new MemberWithOrdersResponse(member);
}
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 User Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html>
- 공식문서 - Spring Data JPA: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/>
- 공식문서 - Spring Boot OSIV 설정: <https://docs.spring.io/spring-boot/docs/current/reference/html/data.html#data.sql.jpa-and-spring-data.open-entity-manager-in-view>
- 공식문서 - Hibernate Batching Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#batch>
