---
title: "Repository 계층 구조 — JpaRepository가 제공하는 것들"
date: 2026-04-14 09:00:00 +0900
categories: [JPA, 리포지토리]
tags: [JPA, 리포지토리, JpaRepository, CrudRepository, SimpleJpaRepository, SpringDataJPA]
order: 1
---

## 1. 개요

---

Spring Data JPA를 쓰다 보면 `JpaRepository`를 상속하는 인터페이스 하나만 만들어도 저장, 조회, 삭제가 전부 동작한다. 왜 그런지, 내부에서 무슨 일이 벌어지는지 이해하고 있어야 나중에 커스터마이징이나 성능 튜닝을 제대로 할 수 있다.

이 글에서는 Repository 인터페이스 계층 구조, 각 계층이 제공하는 메서드, 그리고 실제 구현체인 `SimpleJpaRepository`의 동작 원리를 살펴본다.

| 주제 | 내용 |
|---|---|
| Repository 계층 | `Repository` → `CrudRepository` → `PagingAndSortingRepository` → `JpaRepository` |
| 실제 구현체 | `SimpleJpaRepository` — Spring이 런타임에 자동 생성 |
| 트랜잭션 기본 전략 | 클래스 레벨 `readOnly = true`, 쓰기 메서드만 `readOnly = false` |
| 프록시 빈 등록 | `@Repository` 없이도 자동 Bean 등록되는 이유 |

---

## 2. 계층 구조

---

### 📌 인터페이스 상속 다이어그램

```
«interface»
Repository<T, ID>
    │  마커 인터페이스 — 메서드 없음. Spring이 스캔 대상을 식별하는 용도
    │
«interface»
CrudRepository<T, ID>
    │  기본 CRUD 제공 (save, findById, delete 등)
    │
«interface»
PagingAndSortingRepository<T, ID>
    │  페이징 + 정렬 추가
    │
«interface»
JpaRepository<T, ID>
    │  JPA 특화 기능 추가 (flush, saveAll, getReferenceById 등)
    │
«class»
SimpleJpaRepository<T, ID>    ← Spring이 런타임에 생성하는 실제 구현체
```

개발자는 `JpaRepository`를 상속하는 인터페이스만 선언하면 된다. 구현 클래스는 Spring Data JPA가 런타임에 `SimpleJpaRepository`를 기반으로 자동 생성한다.

```java
// 이것만 선언하면 CRUD + 페이징 + JPA 특화 기능이 전부 제공된다
public interface BookRepository extends JpaRepository<Book, Long> {
}
```

---

## 3. 각 계층이 제공하는 메서드

---

### 📌 CrudRepository

```java
<S extends T> S save(S entity);           // 저장 (신규 persist / 기존 merge)
<S extends T> Iterable<S> saveAll(Iterable<S> entities);
Optional<T> findById(ID id);              // PK 조회 — Optional 반환
boolean existsById(ID id);               // 존재 여부 확인
Iterable<T> findAll();                   // 전체 조회
Iterable<T> findAllById(Iterable<ID> ids);
long count();                            // 전체 건수
void deleteById(ID id);                  // PK로 삭제
void delete(T entity);                   // 엔티티로 삭제
void deleteAll(Iterable<T> entities);    // 다수 삭제 (하나씩 로드 후 삭제)
void deleteAll();                        // 전체 삭제
```

### 📌 PagingAndSortingRepository — CrudRepository에 추가

```java
Iterable<T> findAll(Sort sort);          // 정렬 조회
Page<T> findAll(Pageable pageable);      // 페이징 조회
```

### 📌 JpaRepository — 위 모두에 추가

```java
// 반환 타입 강화: Iterable → List
List<T> findAll();
List<T> findAll(Sort sort);
List<T> findAllById(Iterable<ID> ids);
<S extends T> List<S> saveAll(Iterable<S> entities);

// JPA 특화
void flush();                            // 영속성 컨텍스트 → DB 즉시 반영
<S extends T> S saveAndFlush(S entity);  // save + flush 한 번에
<S extends T> List<S> saveAllAndFlush(Iterable<S> entities);

// 프록시 반환 (지연 로딩용)
T getReferenceById(ID id);               // getOne() deprecated 대체

// 배치 삭제
void deleteAllInBatch(Iterable<T> entities);  // DELETE 쿼리 1번
void deleteAllByIdInBatch(Iterable<ID> ids);
void deleteAllInBatch();                      // 전체 DELETE 쿼리 1번
```

> 💡 `deleteAll()`과 `deleteAllInBatch()`의 차이를 반드시 알아야 한다. `deleteAll()`은 엔티티를 하나씩 SELECT 후 DELETE한다. 100건이면 SELECT 100번 + DELETE 100번이다. `deleteAllInBatch()`는 `DELETE FROM book` 단일 쿼리 한 방이다. 대량 삭제 시 반드시 `InBatch` 버전을 써야 한다.

---

## 4. SimpleJpaRepository — 실제 구현체

---

### 📌 소스 핵심 부분

```java
@Repository
@Transactional(readOnly = true)   // 클래스 레벨: 모든 메서드 기본이 읽기 전용
public class SimpleJpaRepository<T, ID> implements JpaRepositoryImplementation<T, ID> {

    private final JpaEntityInformation<T, ?> entityInformation;
    private final EntityManager em;

    // 쓰기 메서드는 개별적으로 @Transactional(readOnly = false) 재선언
    @Override
    @Transactional
    public <S extends T> S save(S entity) {
        Assert.notNull(entity, "Entity must not be null");

        if (entityInformation.isNew(entity)) {
            em.persist(entity);      // 신규 엔티티 → persist
            return entity;
        } else {
            return em.merge(entity); // 이미 존재 → merge
        }
    }

    @Override
    @Transactional
    public void deleteById(ID id) {
        Assert.notNull(id, "The given id must not be null");
        findById(id).ifPresent(this::delete);  // SELECT 후 DELETE
    }

    @Override
    public Optional<T> findById(ID id) {
        // readOnly 트랜잭션에서 실행 — 스냅샷 생략, flush skip
        return Optional.ofNullable(
            em.find(getDomainClass(), id)
        );
    }
}
```

### 📌 트랜잭션 전략 — readOnly = true가 기본인 이유

`@Transactional(readOnly = true)`가 클래스 레벨에 붙어 있다는 점이 중요하다.

읽기 전용 트랜잭션은 세 가지 이점이 있다. 첫째, Hibernate의 Dirty Checking(변경 감지)을 위한 스냅샷을 생성하지 않는다. 둘째, 트랜잭션 종료 시 flush를 skip한다. 셋째, DB 드라이버나 커넥션 풀이 읽기 전용 커넥션을 최적화할 수 있다.

쓰기 메서드(`save`, `delete` 등)는 메서드 레벨에서 `@Transactional`(readOnly=false)을 재선언해서 오버라이드한다.

### 📌 save() 내부의 isNew() 판단 기준

`save()`가 `persist`를 호출할지 `merge`를 호출할지 결정하는 기준이 `isNew()`다.

| 상황 | isNew() 결과 | 동작 |
|---|---|---|
| `@Id` 필드가 null | true | persist |
| `@Id` 필드에 값이 있음 | false | merge |
| `@Version` 필드가 null | true | persist |
| `Persistable` 인터페이스 구현 | 직접 정의 | 커스텀 |

```java
// @Id를 직접 할당하는 경우 isNew()가 항상 false → merge 호출 문제
// Persistable을 구현해서 해결
@Entity
public class Book implements Persistable<String> {

    @Id
    private String isbn;   // 직접 할당 PK

    @CreatedDate
    private LocalDateTime createdAt;

    @Override
    public String getId() { return isbn; }

    @Override
    public boolean isNew() {
        return createdAt == null;  // createdAt이 null이면 신규로 판단
    }
}
```

---

## 5. @NoRepositoryBean

---

중간 계층 공통 인터페이스를 만들 때 사용한다.

```java
/**
 * 모든 Repository에 공통 메서드를 추가하고 싶을 때 중간 인터페이스를 만든다.
 * @NoRepositoryBean이 없으면 Spring이 이 인터페이스도 Bean으로 만들려다 실패한다.
 */
@NoRepositoryBean
public interface BaseRepository<T, ID> extends JpaRepository<T, ID> {
    List<T> findByDeletedAtIsNull();   // 소프트 딜리트 공통 메서드
}

// 실제 Repository에서 상속
public interface BookRepository extends BaseRepository<Book, Long> { }
public interface MemberRepository extends BaseRepository<Member, Long> { }
```

---

## 6. @Repository가 없어도 되는 이유

---

```java
// @Repository 어노테이션이 없어도 정상 동작한다
public interface BookRepository extends JpaRepository<Book, Long> { }
```

Spring Data JPA는 `JpaRepository`를 상속하는 인터페이스를 스캔해서 자동으로 Bean을 등록한다. `SimpleJpaRepository` 자체에 `@Repository`가 붙어 있어서 JDBC 예외를 Spring의 `DataAccessException` 계층으로 변환하는 기능도 자동으로 적용된다.

단, `@EnableJpaRepositories`의 `basePackages` 범위 안에 위치해야 한다. Spring Boot에서는 메인 클래스 패키지 하위를 자동 스캔하므로 별도 설정 없이 동작한다.

---

## 7. 정리

---

- `JpaRepository`는 `CrudRepository` → `PagingAndSortingRepository`를 상속하며 JPA 특화 기능을 추가한 최상위 인터페이스다
- 실제 구현체는 `SimpleJpaRepository`이고, Spring Data JPA가 런타임에 자동 생성한다
- 클래스 레벨 `@Transactional(readOnly = true)`가 기본이며, 쓰기 메서드만 재선언한다
- `save()`는 `isNew()` 결과에 따라 `persist`/`merge`를 분기한다. PK를 직접 할당하는 경우 `Persistable`로 해결한다
- 대량 삭제는 `deleteAllInBatch()`를 써야 쿼리 한 방으로 처리된다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA 공식 문서](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/)
- [SimpleJpaRepository 소스](https://github.com/spring-projects/spring-data-jpa/blob/main/spring-data-jpa/src/main/java/org/springframework/data/jpa/repository/support/SimpleJpaRepository.java)
