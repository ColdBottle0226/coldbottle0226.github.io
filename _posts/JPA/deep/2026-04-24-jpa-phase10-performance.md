---
title: "JPA 성능 최적화"
date: 2026-04-24 13:00:00 +0900
categories: [JPA, 심화 개념]
tags: [JPA, 성능최적화, Modifying, 벌크연산, readOnly, 읽기전용트랜잭션, 2차캐시, EhCache, Caffeine, p6spy, HibernateStatistics, clearAutomatically, flushAutomatically]
---

##  1. 벌크 연산과 읽기 전용 트랜잭션

---

### 📌 @Modifying 벌크 UPDATE/DELETE

벌크 연산은 **영속성 컨텍스트를 거치지 않고 DB에 직접 실행**된다. 이 때문에 실행 전후로 영속성 컨텍스트 상태와 DB 상태가 불일치하는 문제가 생길 수 있다.

```java
// 벌크 연산 후 영속성 컨텍스트 불일치 시나리오
@Service
@RequiredArgsConstructor
public class BookService {

    private final BookRepository bookRepository;

    @Transactional
    public void priceUpdateTest() {
        // 1. 조회 — book.price = 10000 이 1차 캐시에 캐싱됨
        Book book = bookRepository.findById(1L).orElseThrow();
        System.out.println("벌크 전: " + book.getPrice()); // 10000

        // 2. 벌크 UPDATE — DB에서는 price = 11000으로 변경됨
        bookRepository.bulkUpdatePrice(1.1, "IT");

        // 3. 1차 캐시에서 반환 — DB와 불일치!
        Book sameBook = bookRepository.findById(1L).orElseThrow();
        System.out.println("벌크 후: " + sameBook.getPrice()); // 10000 (잘못된 값!)
    }
}
```

### 📌 clearAutomatically와 flushAutomatically

```java
/**
 * clearAutomatically = true:
 * 벌크 연산 실행 후 영속성 컨텍스트를 자동으로 clear한다.
 * 이후 조회는 1차 캐시가 아닌 DB에서 최신 데이터를 가져온다.
 *
 * flushAutomatically = true:
 * 벌크 연산 전에 flush를 먼저 수행한다.
 * 아직 DB에 반영되지 않은 변경사항을 먼저 내보낸 후 벌크 연산을 실행한다.
 */
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.price = b.price * :rate WHERE b.category = :category")
int bulkUpdatePrice(@Param("rate") double rate, @Param("category") String category);
```

`flushAutomatically`가 필요한 이유:

```java
@Transactional
public void dangerousPattern() {
    Book book = new Book("새 책", 10000, "IT");
    bookRepository.save(book); // 아직 flush 안 됨 (쓰기 지연)

    // flushAutomatically = false면 위 save가 아직 DB에 없는 상태에서 벌크 UPDATE 실행
    // → 방금 저장한 책이 벌크 UPDATE에서 누락됨
    bookRepository.bulkUpdatePrice(1.1, "IT");
}
```

### 📌 실전 벌크 연산 패턴

```java
// 소프트 딜리트 (논리 삭제)
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.deletedAt = :now WHERE b.id IN :ids")
int softDeleteByIds(@Param("ids") List<Long> ids, @Param("now") LocalDateTime now);

// 연체 대출 상태 일괄 변경
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("UPDATE LoanRecord lr SET lr.status = 'OVERDUE' " +
       "WHERE lr.dueDate < :today AND lr.status = 'ACTIVE'")
int markOverdueLoans(@Param("today") LocalDate today);

// 만료 세션 일괄 삭제
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("DELETE FROM UserSession s WHERE s.expiredAt < :now")
int deleteExpiredSessions(@Param("now") LocalDateTime now);
```

---

### 📌 @Transactional(readOnly = true) — 읽기 전용 트랜잭션

`readOnly = true`로 설정하면 세 가지 성능 이점이 있다.

**① Dirty Checking 스냅샷 생략**

읽기 전용 트랜잭션에서는 Hibernate가 엔티티를 영속성 컨텍스트에 등록할 때 **스냅샷을 생성하지 않는다.** 스냅샷은 Dirty Checking을 위해 필드 값 전체를 복사하는 작업이므, 엔티티가 많을수록 메모리와 CPU 비용이 줄어든다.

**② flush 스킵**

트랜잭션 종료 시 변경 감지 후 flush하는 과정 자체가 생략된다.

**③ DB 드라이버/커넥션 풀 최적화**

일부 JDBC 드라이버와 커넥션 풀(HikariCP 등)은 read-only 트랜잭션을 별도의 Read Replica로 라우팅하거나, 내부적으로 최적화를 적용한다.

```java
@Service
public class MemberService {

    // 읽기 메서드 — readOnly = true
    @Transactional(readOnly = true)
    public MemberResponse findById(Long id) {
        Member member = memberRepository.findById(id).orElseThrow();
        return MemberResponse.from(member);
    }

    // 쓰기 메서드 — readOnly = false (기본값)
    @Transactional
    public void updateName(Long id, String name) {
        Member member = memberRepository.findById(id).orElseThrow();
        member.updateName(name);
    }
}
```

`SimpleJpaRepository`가 클래스 레벨에 `@Transactional(readOnly = true)`를 선언하고 `save()`, `delete()` 등 쓰기 메서드만 재선언하는 이유가 바로 이 성능 최적화 때문이다.

---

##  2. 2차 캐시 (Second-Level Cache)

---

### 📌 1차 캐시 vs 2차 캐시

| 항목 | 1차 캐시 | 2차 캐시 |
|---|---|---|
| 범위 | 트랜잭션 단위 (EntityManager 단위) | 애플리케이션 전체 (공유) |
| 생명주기 | 트랜잭션 시작 ~ 종료 | 애플리케이션 시작 ~ 종료 |
| 저장 위치 | JVM Heap | JVM Heap 또는 외부 저장소 |
| 동시성 | 단일 스레드 | 동시 접근 처리 필요 |
| 자동 적용 | 항상 | 명시적 설정 필요 |

2차 캐시는 트랜잭션이 끝나도 캐시가 유지된다. 자주 조회되고 변경이 적은 데이터(코드 테이블, 카테고리 등)에 효과적이다.

### 📌 EhCache / Caffeine 연동

**의존성 추가:**

```kotlin
// EhCache
implementation("org.springframework.boot:spring-boot-starter-cache")
implementation("org.ehcache:ehcache:3.10.8")
implementation("org.hibernate.orm:hibernate-jcache")

// 또는 Caffeine
implementation("com.github.ben-manes.caffeine:caffeine")
```

**application.yml 설정:**

```yaml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          use_query_cache: true
          region:
            factory_class: org.hibernate.cache.jcache.internal.JCacheRegionFactory
```

### 📌 @Cache 어노테이션

```java
import org.hibernate.annotations.Cache;
import org.hibernate.annotations.CacheConcurrencyStrategy;

@Entity
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
public class Category {

    @Id @GeneratedValue
    private Long id;

    private String name;

    @OneToMany(mappedBy = "category")
    @Cache(usage = CacheConcurrencyStrategy.READ_ONLY)  // 컬렉션에도 적용 가능
    private List<Book> books = new ArrayList<>();
}
```

### 📌 CacheConcurrencyStrategy 종류

| 전략 | 설명 | 사용 케이스 |
|---|---|---|
| `READ_ONLY` | 읽기 전용. 수정하면 예외 발생 | 변경이 없는 불변 데이터 |
| `NONSTRICT_READ_WRITE` | 수정 시 캐시 무효화. 짧은 불일치 허용 | 가끔 변경되는 데이터 |
| `READ_WRITE` | 소프트 락으로 일관성 보장 | 수정이 있지만 동시성 필요 |
| `TRANSACTIONAL` | JTA 환경에서 완전한 트랜잭션 지원 | 완전한 일관성이 필요한 경우 |

> 💡 2차 캐시는 만능이 아니다. 캐시 무효화 시점을 잘 관리하지 않으면 오래된 데이터를 반환하는 문제가 생긴다. 실무에서는 2차 캐시보다 Redis 같은 외부 캐시를 Spring Cache(`@Cacheable`)와 함께 사용하는 경우가 더 일반적이다.

---

##  3. 모니터링 — Hibernate Statistics, p6spy, Actuator

---

### 📌 Hibernate Statistics

```yaml
spring:
  jpa:
    properties:
      hibernate:
        generate_statistics: true
logging:
  level:
    org.hibernate.stat: DEBUG
```

통계 정보를 직접 조회하는 방법:

```java
@Autowired
private EntityManagerFactory emf;

public void printStatistics() {
    Statistics stats = emf.unwrap(SessionFactory.class).getStatistics();
    System.out.println("총 쿼리 실행 수: " + stats.getQueryExecutionCount());
    System.out.println("2차 캐시 HIT 수: " + stats.getSecondLevelCacheHitCount());
    System.out.println("2차 캐시 MISS 수: " + stats.getSecondLevelCacheMissCount());
    System.out.println("엔티티 로딩 수: " + stats.getEntityLoadCount());
    System.out.println("컬렉션 로딩 수: " + stats.getCollectionLoadCount());
}
```

### 📌 p6spy — 파라미터 바인딩 포함 SQL 로깅

기본 Hibernate SQL 로그는 파라미터가 `?`로 출력된다. p6spy를 사용하면 실제 파라미터 값이 포함된 SQL을 확인할 수 있다.

```kotlin
// build.gradle.kts
implementation("com.github.gavlyukovskiy:p6spy-spring-boot-starter:1.9.0")
```

```yaml
# application.yml
decorator:
  datasource:
    p6spy:
      enable-logging: true
      logging: slf4j
```

p6spy가 적용되면 다음과 같이 실제 파라미터 값이 포함된 SQL이 출력된다:

```sql
-- Hibernate 기본 로그
select b1_0.book_id,b1_0.title,b1_0.price from book b1_0 where b1_0.category=?

-- p6spy 로그 (파라미터 포함)
select b1_0.book_id,b1_0.title,b1_0.price from book b1_0 where b1_0.category='IT'
```

> 💡 p6spy는 개발/테스트 환경에서만 사용한다. 운영 환경에서는 성능에 영향을 줄 수 있으므로 반드시 비활성화해야 한다.

### 📌 Spring Actuator Metrics

```kotlin
implementation("org.springframework.boot:spring-boot-starter-actuator")
```

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, metrics, info
  metrics:
    export:
      enabled: true
```

`/actuator/metrics/hibernate.sessions.open`, `/actuator/metrics/hibernate.query.executions` 등으로 Hibernate 관련 메트릭을 확인할 수 있다. Prometheus + Grafana와 연동하면 실시간 모니터링 대시보드를 구성할 수 있다.

---

##  4. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| 벌크 연산 | 영속성 컨텍스트 우회. clearAutomatically + flushAutomatically 필수 |
| readOnly = true | 스냅샷 생략, flush 스킵, DB 라우팅 최적화. 조회 메서드에 기본 적용 권장 |
| 2차 캐시 | 애플리케이션 전체 공유 캐시. 변경이 적은 참조 데이터에 효과적 |
| @Cache | 엔티티/컬렉션에 2차 캐시 적용. CacheConcurrencyStrategy 전략 선택 필요 |
| Hibernate Statistics | 쿼리 실행 수, 캐시 HIT/MISS 등 성능 지표 모니터링 |
| p6spy | 파라미터 포함 SQL 로깅. 개발/테스트 환경에서만 사용 |
| Actuator Metrics | Hibernate 메트릭 HTTP 엔드포인트 노출. Prometheus/Grafana 연동 가능 |

---

## 참고 자료

- 공식문서 - Hibernate 6 Caching: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#caching>
- 공식문서 - Hibernate 6 Statistics: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#statistics>
- p6spy GitHub: <https://github.com/gavlyukovskiy/spring-boot-data-source-decorator>
- Spring Boot Actuator: <https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html>
