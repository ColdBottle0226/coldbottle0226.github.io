---
title: 엔티티 생명주기
date: 2026-04-03 09:00:00 +0900
categories: [JPA, 영속성 컨텍스트]
order: 1
tags: [JPA, 영속성 컨텍스트, 엔티티생명주기, 비영속, 영속, 준영속, LazyInitializationException]
---

##  1. 4가지 상태 개요

---

엔티티는 영속성 컨텍스트와의 관계에 따라 4가지 상태 중 하나에 속한다.

| 상태 | 설명 | 특징 |
|---|---|---|
| 비영속 (New) | new로 생성한 순수 자바 객체 | JPA와 무관 |
| 영속 (Managed) | 영속성 컨텍스트가 관리 중 | 더티 체킹, 지연 로딩 가능 |
| 준영속 (Detached) | 관리에서 벗어난 상태 | PK 있음, 더티 체킹 안됨 |
| 삭제 (Removed) | 삭제 예약 상태 | flush 시 DELETE 실행 |

---

##  2. 비영속 (New / Transient)

---

`new` 키워드로 생성한 순수 자바 객체다. JPA와 아무 관련이 없고, 영속성 컨텍스트도 DB도 이 객체의 존재를 모른다. `em.contains(member)`를 호출하면 `false`를 반환한다. 이 상태에서는 어떤 SQL도 발생하지 않는다.

```java
Member member = new Member("홍길동", 30, "hong@test.com");
// 순수 자바 객체. JPA와 무관.
System.out.println(em.contains(member)); // false
```

---

##  3. 영속 (Managed)

---

영속성 컨텍스트가 해당 엔티티를 관리하는 상태다. 영속 상태에 들어오는 방법은 세 가지다.

- `em.persist()` — 새 엔티티를 영속성 컨텍스트에 등록
- `em.find()` 또는 JPQL 조회 — DB에서 불러온 엔티티는 자동으로 영속 상태
- `em.merge()`의 반환값 — 준영속 엔티티를 merge하면 반환된 새 인스턴스가 영속

```java
em.persist(member);                          // persist → 영속
Member found = em.find(Member.class, 1L);    // find → 영속
```

영속 상태의 엔티티가 갖는 특권은 다음과 같다.

**더티 체킹**: 필드를 수정하면 트랜잭션 커밋 시 UPDATE SQL이 자동 실행된다. `em.update()`같은 메서드는 존재하지 않는다.

**지연 로딩 가능**: `@ManyToOne(fetch = LAZY)` 같은 연관 엔티티에 접근할 때 필요한 시점에 SQL이 자동 실행된다. 영속성 컨텍스트가 살아있어야만 동작한다.

**1차 캐시 조회**: 같은 트랜잭션 내에서 같은 PK로 다시 조회하면 SQL 없이 캐시에서 반환된다.

```java
@Transactional
public void updateMemberName(Long id, String newName) {
    Member member = memberRepository.findById(id).orElseThrow();
    // member는 영속 상태
    member.updateName(newName); // 수정만 하면 됨
    // 트랜잭션 종료 → 더티 체킹 → UPDATE SQL 자동 실행
    // memberRepository.save(member) 불필요
}
```

> 💡 이미 영속 상태인 엔티티에 `save()`를 다시 호출하면 내부적으로 불필요한 `merge()` 과정이 생긴다. 영속 상태에서는 수정만 하면 된다.

---

##  4. 준영속 (Detached)

---

영속 상태였다가 영속성 컨텍스트의 관리에서 벗어난 상태다. 한 번은 영속 상태였으므로 PK 값을 가지고 있다는 점이 비영속과의 차이다.

준영속 상태로 전환되는 방법은 세 가지다.

```java
em.detach(member); // 특정 엔티티 하나만 준영속으로 전환
em.clear();        // 영속성 컨텍스트 전체 초기화 → 모든 엔티티 준영속
em.close();        // EntityManager 종료 → 모든 엔티티 준영속
// Spring에서는 @Transactional 메서드 종료 시 자동으로 close()
```

준영속 상태에서는 더티 체킹이 동작하지 않아 수정해도 DB에 반영되지 않는다.

### 📌 LazyInitializationException — 준영속의 가장 큰 함정

준영속 상태에서 지연 로딩을 시도하면 영속성 컨텍스트가 없으므로 프록시를 초기화할 수 없어 `LazyInitializationException`이 발생한다. 실무에서 가장 자주 만나는 JPA 예외다.

```java
// OSIV OFF 환경에서의 문제 시나리오

// Service 계층 (@Transactional 있음)
@Transactional(readOnly = true)
public Member findMember(Long id) {
    return memberRepository.findById(id).orElseThrow();
    // member는 영속 상태로 반환됨
} // @Transactional 종료 → 영속성 컨텍스트 닫힘 → member가 준영속으로 전환

// Controller 계층 (트랜잭션 없음)
public ResponseEntity<?> getMember(Long id) {
    Member member = memberService.findMember(id); // 이미 준영속
    List<Order> orders = member.getOrders();       // 프록시 객체
    int size = orders.size();                      // 실제 데이터 접근 시도
    // → LazyInitializationException 발생!
    // "could not initialize proxy - no Session"
}
```

이 예외가 발생하면 "영속성 컨텍스트가 닫힌 상태에서 지연 로딩을 시도했구나"라고 바로 파악해야 한다. 해결 방법은 다음 중 하나다.

- Service 계층에서 DTO로 변환해서 반환 (권장)
- Fetch Join으로 필요한 연관 데이터를 한꺼번에 로딩
- OSIV를 켜두기 (트래픽 많은 서비스에서는 커넥션 고갈 위험이 있어 비권장)

### 📌 merge()의 동작 방식 — 준영속 → 영속

준영속 상태의 엔티티를 다시 영속 상태로 만들려면 `em.merge()`를 사용한다. 내부적으로 다음 순서로 동작한다.

1. 파라미터 엔티티의 PK로 1차 캐시를 확인한다.
2. 없으면 DB에서 SELECT로 조회한다.
3. 조회한 엔티티에 파라미터 엔티티의 값을 복사한다.
4. 그 엔티티를 영속 상태로 반환한다.

파라미터로 넘긴 객체는 `merge()` 후에도 준영속 상태로 남는다. 반환된 새 인스턴스가 영속 상태다.

```java
Member detached = ...; // 준영속

Member managed = em.merge(detached);
// detached — 여전히 준영속 (이걸 수정해도 DB에 반영 안 됨)
// managed — 영속 상태 (이걸 수정해야 더티 체킹 동작)
```

---

##  5. 삭제 (Removed)

---

`em.remove()`를 호출하면 삭제 상태가 된다. 반드시 영속 상태의 엔티티를 파라미터로 넘겨야 한다. 비영속이나 준영속을 넘기면 `IllegalArgumentException`이 발생한다.

```java
Member member = em.find(Member.class, 1L); // 반드시 영속 상태
em.remove(member); // 삭제 예약 → 쓰기 지연 SQL 저장소에 DELETE 추가
// flush 시 DELETE SQL 실행, 트랜잭션 커밋 후 비영속 상태가 됨
```

---

##  6. 실습 — 생명주기 상태 직접 확인

---

`em.contains()`로 현재 엔티티가 영속 상태인지 확인할 수 있다.

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
        System.out.println("[비영속] " + em.contains(member)); // false

        // 2. 영속
        em.persist(member);
        assertThat(em.contains(member)).isTrue();
        System.out.println("[영속] " + em.contains(member)); // true

        // 3. 준영속
        em.detach(member);
        assertThat(em.contains(member)).isFalse();
        System.out.println("[준영속] " + em.contains(member)); // false

        // 4. merge() — 반환값이 영속, 원본은 준영속 그대로
        Member merged = em.merge(member);
        assertThat(em.contains(member)).isFalse();  // 원본 여전히 준영속
        assertThat(em.contains(merged)).isTrue();   // 반환값이 영속
        System.out.println("[merge 원본] " + em.contains(member)); // false
        System.out.println("[merge 반환] " + em.contains(merged)); // true
    }
}
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 User Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html>
