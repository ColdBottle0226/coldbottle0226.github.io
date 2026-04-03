---
title: EntityManager
date: 2026-04-03 09:00:00 +0900
categories: [JPA, 영속성 컨텍스트]
order: 0
tags: [JPA, 영속성 컨텍스트, EntityManager, EntityManagerFactory, ThreadLocal, PersistenceContext]
---

## 📗 1. 영속성 컨텍스트란

---

JPA를 처음 접하면 "왜 DB에 바로 저장하지 않고 영속성 컨텍스트라는 중간 단계가 있는 걸까?"라는 의문이 생긴다. 이 의문에서부터 시작하는 게 가장 이해가 빠르다.

예를 들어 한 HTTP 요청 안에서 아래와 같은 일이 벌어진다고 생각해보자.

```java
Member member = findById(1L);      // SELECT → DB 왕복 1번
member.setName("변경");
Member same = findById(1L);        // 또 SELECT → DB 왕복 2번 (중복)
orderService.process(member);      // 내부에서 또 findById(1L) → DB 왕복 3번
```

DB에 직접 요청한다면 같은 데이터를 여러 번 조회하는 중복 DB 왕복이 발생한다. 그리고 `member.setName("변경")`을 했는데, 이걸 DB에 반영하려면 개발자가 직접 UPDATE SQL을 작성하고 실행해야 한다.

영속성 컨텍스트(Persistence Context)는 이런 문제들을 해결하는 **"애플리케이션과 DB 사이의 스마트한 중간 저장소"** 다. "Entity를 영구 저장하는 환경"이라는 의미로, 눈에 보이지 않는 논리적인 개념이다.

영속성 컨텍스트가 제공하는 기능은 다음과 같다.

- 한 트랜잭션 안에서 같은 데이터를 다시 요청하면 DB에 가지 않고 캐시에서 바로 반환한다 (1차 캐시)
- 엔티티를 수정하면 자동으로 감지해서 트랜잭션 끝에 UPDATE를 실행한다 (더티 체킹)
- INSERT도 모았다가 한꺼번에 DB로 보낸다 (쓰기 지연)
- 같은 PK로 조회한 엔티티는 항상 같은 인스턴스임을 보장한다 (동일성 보장)

영속성 컨텍스트 자체는 눈에 보이는 클래스나 인터페이스가 아니다. `EntityManager`를 통해서만 접근하고 관리할 수 있다.

---

## 📗 2. EntityManagerFactory와 EntityManager

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

`EntityManagerFactory`는 애플리케이션이 시작될 때 `application.yml`의 DB 설정을 읽어서 딱 한 번 생성된다. 내부적으로 DB 드라이버 로딩, 커넥션 풀 생성, 엔티티 클래스 스캔 및 매핑 정보 파싱, SQL 방언(Dialect) 설정 등 무거운 초기화를 수행한다. 만드는 비용이 크기 때문에 하나만 만들어 전체 애플리케이션에서 공유한다. 여러 스레드가 동시에 접근해도 내부 상태를 변경하지 않으므로 스레드 안전하다.

`EntityManager`는 하나의 트랜잭션 단위로 생성되고 소멸된다. 내부에 영속성 컨텍스트를 하나씩 들고 있으며, 이 안에서 엔티티의 저장·조회·수정·삭제가 이루어진다.

`EntityManager`가 스레드 간 공유되면 안 되는 이유는 영속성 컨텍스트(내부 1차 캐시)가 상태를 가지고 있기 때문이다. 두 스레드가 동시에 하나의 EntityManager를 사용하면 서로의 엔티티가 뒤섞이는 심각한 데이터 충돌이 발생한다.

| 구분 | EntityManagerFactory | EntityManager |
|---|---|---|
| 생성 비용 | 크다 (DB 연결, 메타데이터 파싱) | 작다 |
| 개수 | 애플리케이션당 1개 | 트랜잭션당 1개 |
| 스레드 안전 | 안전 | 공유 금지 |
| 생존 범위 | 애플리케이션 전체 | 트랜잭션 범위 |

---

## 📗 3. Spring에서 EntityManager 주입 원리

---

### 📌 프록시 주입과 ThreadLocal

Spring에서 `@PersistenceContext`로 EntityManager를 주입받으면 실제 EntityManager가 주입되는 것처럼 보이지만, 사실은 **프록시 객체**가 주입된다. Spring이 이 메커니즘을 구현하는 데 `ThreadLocal`을 활용한다.

Spring이 `@PersistenceContext`를 처리하는 내부 과정을 단계별로 보면 이렇다.

**1단계 — 프록시 주입**

Spring이 `MemberService` 빈을 생성할 때 `@PersistenceContext`가 붙은 필드에 실제 EntityManager가 아닌 `SharedEntityManagerCreator`가 만든 프록시 객체를 주입한다. 이 프록시는 애플리케이션 전체 생명주기 동안 하나만 존재한다.

**2단계 — 메서드 위임**

`em.persist(member)`처럼 EntityManager 메서드를 호출하면, 프록시는 실제 EntityManager에 바로 위임하지 않고 먼저 `TransactionSynchronizationManager`에 물어본다. "지금 이 스레드에서 진행 중인 트랜잭션이 있나? 있다면 그 트랜잭션에 바인딩된 실제 EntityManager를 줘."

**3단계 — ThreadLocal 조회**

`TransactionSynchronizationManager`는 내부적으로 `ThreadLocal<Map<Object, Object>>`를 사용한다. 각 스레드는 자신만의 ThreadLocal 공간을 가지고 있어서, 스레드 A의 EntityManager와 스레드 B의 EntityManager가 완전히 격리된다.

**4단계 — 트랜잭션 시작 시점**

`@Transactional` 메서드가 호출되면 Spring AOP 프록시가 가로채서 `EntityManagerFactory.createEntityManager()`로 새 EntityManager를 생성하고, 이를 현재 스레드의 ThreadLocal에 저장한다. 이 시점이 영속성 컨텍스트의 시작이다.

**5단계 — 트랜잭션 종료 시점**

`@Transactional` 메서드가 끝나면 Spring이 커밋 또는 롤백을 수행하고, ThreadLocal에서 EntityManager를 제거한 뒤 `em.close()`를 호출한다. 이 시점이 영속성 컨텍스트의 종료다.

이 메커니즘 덕분에 싱글톤 빈인 Service 클래스에 EntityManager를 필드로 가져도 스레드 안전하게 동작한다. 프록시가 항상 현재 스레드에 맞는 실제 EntityManager를 찾아서 위임하기 때문이다.

```java
@Service
public class MemberService {

    // 주입되는 건 실제 EM이 아니라 프록시.
    // 메서드 호출 시 현재 스레드의 실제 EM을 찾아서 위임.
    @PersistenceContext
    private EntityManager em;

    @Transactional
    public void save(Member member) {
        em.persist(member); // 프록시 → ThreadLocal에서 실제 EM 조회 → 위임
    }
}
```

---

## 📗 4. EntityManager 핵심 메서드

---

### 📌 persist(entity) — 영속화

비영속 상태의 엔티티를 영속성 컨텍스트에 등록한다. 이 시점에 INSERT SQL은 실행되지 않는다. 1차 캐시에 올라가고 쓰기 지연 SQL 저장소에 INSERT 쿼리가 쌓인다.

```java
Member member = new Member("홍길동", 30, "hong@test.com"); // 비영속
em.persist(member); // 영속성 컨텍스트에 등록 — SQL 실행 안 함
// 트랜잭션 커밋 시 INSERT 실행됨
```

> 💡 `@GeneratedValue(strategy = GenerationType.IDENTITY)` 전략 예외: IDENTITY 전략은 PK를 DB가 생성하기 때문에 INSERT가 즉시 실행된다. persist() 시점에 바로 INSERT가 나가므로 쓰기 지연이 적용되지 않는다.

### 📌 find(Class, id) — 조회

1차 캐시를 먼저 확인한다. 있으면 SQL 없이 반환하고, 없으면 DB에 SELECT를 실행한 뒤 1차 캐시에 저장 후 반환한다. 반환된 엔티티는 영속 상태다.

```java
Member member = em.find(Member.class, 1L);
// 1차 캐시 HIT → SQL 없이 반환
// 1차 캐시 MISS → DB SELECT → 캐시 저장 → 반환
```

`find()`와 달리 `getReference()`는 프록시 객체를 반환한다. 실제 필드에 접근하는 시점까지 SQL을 실행하지 않는다. 연관관계 매핑에서 FK용으로만 필요한 경우에 활용한다.

### 📌 merge(entity) — 병합

준영속 또는 비영속 상태의 엔티티를 영속 상태로 전환한다. 내부 동작 순서가 중요하다.

1. 파라미터 엔티티의 PK 값으로 1차 캐시를 조회한다.
2. 1차 캐시에 없으면 DB에서 SELECT로 불러온다.
3. DB에도 없으면 새 엔티티로 판단하고 persist한다.
4. 조회한 영속 엔티티에 파라미터 엔티티의 모든 필드 값을 복사한다.
5. 그 영속 엔티티(새 인스턴스)를 반환한다.

파라미터로 넘긴 인스턴스는 `merge()` 이후에도 여전히 준영속 상태다. 반드시 반환값을 사용해야 한다.

```java
// 잘못된 사용법
em.merge(detachedMember);
// detachedMember는 여전히 준영속

// 올바른 사용법
Member managedMember = em.merge(detachedMember);
// managedMember가 영속 상태. 이것을 수정해야 더티 체킹이 동작한다.
```

### 📌 remove(entity) — 삭제

반드시 영속 상태의 엔티티를 파라미터로 넘겨야 한다. 비영속이나 준영속을 넘기면 `IllegalArgumentException`이 발생한다. `remove()` 호출 후 flush 시점에 DELETE SQL이 실행된다.

### 📌 flush() — DB 동기화

쓰기 지연 SQL 저장소에 쌓인 SQL들을 DB에 전송한다. 트랜잭션을 커밋하지는 않는다. flush 후에도 영속성 컨텍스트는 그대로 유지된다.

flush가 자동으로 발생하는 시점은 세 가지다.

- `em.flush()` 직접 호출
- 트랜잭션 커밋 시 자동 발생
- JPQL 쿼리 실행 직전 자동 발생 (1차 캐시와 DB 불일치 방지 목적)

### 📌 clear() — 영속성 컨텍스트 초기화

1차 캐시를 전부 비운다. 관리 중이던 모든 엔티티가 준영속 상태로 전환된다. 이후 `find()`는 다시 DB에 SELECT를 날린다. 벌크 연산(UPDATE/DELETE) 이후 반드시 호출해야 한다. 벌크 연산은 영속성 컨텍스트를 거치지 않고 DB에 직접 반영되기 때문에, 호출하지 않으면 1차 캐시와 DB 상태가 불일치하게 된다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 User Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html>
- 공식문서 - Spring Data JPA: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/>
