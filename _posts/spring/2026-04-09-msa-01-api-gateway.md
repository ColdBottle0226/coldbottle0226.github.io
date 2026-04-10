---
title: "스프링 클라우드 기반 MSA 구성 - API Gateway"
date: 2026-04-09 09:00:00 +0900
categories: [Spring, MSA]
order: 0
tags: [SpringCloud, MSA, APIGateway, SpringCloudGateway, Zuul, WebFlux, Predicate, Filter]
---

##  1. 개요

---

MSA(Microservice Architecture)를 처음 구성할 때 가장 먼저 마주치는 질문이 있다.

> "클라이언트가 서비스가 여러 개인데, 주소를 몇 개나 알아야 하지?"

예를 들어 서울 데이트 앱처럼 user-service(8081), place-service(8082), recommendation-service(8083)가 따로 떠 있다면, 클라이언트는 각 서비스 주소를 전부 알고 있어야 한다. 거기에 JWT 검증, Rate Limit, CORS 처리까지 서비스마다 각자 구현해야 한다면 중복 코드가 폭발한다.

이 문제를 해결하는 것이 **API Gateway**다. 모든 요청의 단일 진입점(Single Entry Point)이 되어, 인증·라우팅·필터링을 한 곳에서 처리한다.

> 💡 Spring Cloud 공식 문서는 Spring Cloud Gateway를 "Spring 6, Spring Boot 3, Project Reactor 기반으로 구축된 API Gateway"로 정의하며, 라우팅, 보안, 모니터링/메트릭, 복원력(Resiliency)을 제공하는 것을 목표로 한다고 설명한다.
> 출처: [docs.spring.io/spring-cloud-gateway](https://docs.spring.io/spring-cloud-gateway/reference/index.html)

### 📌 Zuul vs Spring Cloud Gateway

과거에는 Netflix Zuul을 많이 사용했지만, 현재는 **Spring Cloud Gateway가 공식 대체재**다.

| 구분 | Netflix Zuul 1.x | Spring Cloud Gateway |
|---|---|---|
| 기반 기술 | Servlet API (Blocking I/O) | Project Reactor (Non-blocking I/O) |
| Spring Cloud 지원 | 2020년 이후 deprecated | 현재 공식 지원 |
| 성능 | 스레드 풀 기반, 동시성 한계 있음 | 이벤트 루프 기반, 고동시성 처리 |
| Spring Boot 3 호환 | ❌ | ✅ |
| WebFlux 통합 | ❌ | ✅ (네이티브) |

> 💡 Zuul 2.x는 Netty 기반이지만 Spring Cloud 생태계와 통합이 없다. 신규 프로젝트에서는 반드시 Spring Cloud Gateway를 선택해야 한다.

### 📌 전체 요청 처리 흐름

```
Client 요청
  → Spring Cloud Gateway
    → Gateway Handler Mapping (라우트 매칭)
      → Gateway Web Handler
        → Pre Filter 실행 (JWT 검증, Rate Limit, Logging...)
          → 하위 서비스 (user-service, place-service 등)로 프록시
        → Post Filter 실행 (응답 헤더 추가, 로깅...)
  → Client 응답 반환
```

공식 문서에 따르면 필터는 "프록시 요청 전(pre)"과 "프록시 요청 후(post)" 두 단계로 나뉘어 실행된다.

---

##  2. 핵심 개념 3가지: Route, Predicate, Filter

---

Spring Cloud Gateway의 모든 기능은 이 세 가지 개념으로 설명된다.

### 📌 Route (라우트)

게이트웨이의 기본 구성 단위다. 하나의 Route는 다음 4가지로 구성된다.

- **ID**: 라우트 식별자 (문자열)
- **URI**: 요청을 전달할 목적지 (하위 서비스 주소)
- **Predicates**: 이 라우트를 적용할 조건 모음
- **Filters**: 요청/응답을 변환하는 필터 모음

> 💡 공식 문서: "A route is matched if the aggregate predicate is true." — 모든 Predicate 조건이 참일 때 해당 Route가 매칭된다.

### 📌 Predicate (조건자)

HTTP 요청의 어떤 속성을 기준으로 라우트를 매칭할지 결정한다. Java 8의 `Predicate<ServerWebExchange>`를 기반으로 한다.

주요 내장 Predicate:

| Predicate | 설명 | 예시 |
|---|---|---|
| `Path` | URL 경로 패턴 매칭 | `/api/users/**` |
| `Method` | HTTP 메서드 매칭 | `GET`, `POST` |
| `Header` | 요청 헤더 값 매칭 | `X-Request-Id, \d+` |
| `Host` | 호스트명 패턴 매칭 | `**.example.org` |
| `Query` | 쿼리 파라미터 매칭 | `param=value` |
| `After` / `Before` | 특정 시간 이후/이전 요청만 허용 | `datetime` |
| `RemoteAddr` | 클라이언트 IP 대역 매칭 | `192.168.0.0/24` |

### 📌 Filter (필터)

요청을 하위 서비스로 보내기 전(pre)이나 받은 후(post)에 요청/응답을 변환한다.

주요 내장 Filter:

| Filter | 설명 |
|---|---|
| `AddRequestHeader` | 요청 헤더 추가 |
| `AddResponseHeader` | 응답 헤더 추가 |
| `RewritePath` | URL 경로 재작성 |
| `StripPrefix` | URL 경로 앞부분 제거 |
| `RequestRateLimiter` | Redis 기반 Rate Limiting |
| `CircuitBreaker` | Resilience4j Circuit Breaker 연동 |
| `Retry` | 실패 시 재시도 |
| `DedupeResponseHeader` | 중복 응답 헤더 제거 |

---

##  3. 기초 설정

---

### 📌 의존성 추가

```groovy
/**
 * Spring Cloud Gateway는 WebFlux(Reactor) 기반이다.
 * spring-boot-starter-web과 함께 사용하면 충돌이 발생하므로
 * Gateway 모듈에는 web 의존성을 추가하면 안 된다.
 */
ext {
    set('springCloudVersion', "2023.0.1")
}

dependencies {
    // Gateway 핵심 의존성 (WebFlux 포함)
    implementation 'org.springframework.cloud:spring-cloud-starter-gateway'

    // Eureka Client (서비스 디스커버리 연동)
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'

    // Rate Limiting (Redis 기반)
    implementation 'org.springframework.boot:spring-boot-starter-data-redis-reactive'

    // Actuator (헬스체크, 메트릭)
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}
```

### 📌 application.yml 기본 라우팅 설정

```yaml
server:
  port: 3001

spring:
  application:
    name: api-gateway

  cloud:
    gateway:
      # 전역 CORS 설정
      globalcors:
        cors-configurations:
          '[/**]':
            allowedOriginPatterns: "*"
            allowedMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
            allowedHeaders: "*"
            allowCredentials: true

      routes:
        # user-service 라우팅
        - id: user-service
          uri: lb://user-service          # lb:// = Eureka + LoadBalancer
          predicates:
            - Path=/api/auth/**, /api/users/**
          filters:
            - RewritePath=/api/(?<segment>.*), /$\{segment}

        # place-service 라우팅
        - id: place-service
          uri: lb://place-service
          predicates:
            - Path=/api/places/**, /api/events/**
          filters:
            - RewritePath=/api/(?<segment>.*), /$\{segment}

        # recommendation-service 라우팅
        - id: recommendation-service
          uri: lb://recommendation-service
          predicates:
            - Path=/api/recommendations/**, /api/courses/**, /api/feedbacks/**
          filters:
            - RewritePath=/api/(?<segment>.*), /$\{segment}

# Eureka 등록
eureka:
  client:
    service-url:
      defaultZone: http://eureka-server:8761/eureka/
  instance:
    prefer-ip-address: true
```

> 💡 `lb://user-service`에서 `lb://`는 Spring Cloud LoadBalancer를 사용해 Eureka에 등록된 `user-service` 인스턴스를 동적으로 조회하라는 의미다. IP를 하드코딩하지 않아도 된다.

### 📌 Application.java

```java
/**
 * @EnableEurekaClient는 Spring Cloud 2023.0에서 자동 설정으로 통합됐다.
 * classpath에 Eureka Client 의존성이 있으면 어노테이션 없이도 자동 등록된다.
 */
@SpringBootApplication
public class ApiGatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}
```

### 📌 JWT 검증 Global Filter

```java
/**
 * GlobalFilter는 모든 라우트에 자동 적용되는 필터다.
 * JWT 검증처럼 모든 요청에 공통 적용할 로직을 여기에 작성한다.
 *
 * GatewayFilter는 특정 라우트에만 적용하고 싶을 때 사용한다.
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter implements GlobalFilter, Ordered {

    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    // 인증 없이 통과시킬 경로 목록
    private static final List<String> WHITE_LIST = List.of(
        "/api/auth/login",
        "/api/auth/register",
        "/api/auth/refresh"
    );

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();

        // 화이트리스트 경로는 필터 통과
        if (WHITE_LIST.stream().anyMatch(path::startsWith)) {
            return chain.filter(exchange);
        }

        String authHeader = exchange.getRequest().getHeaders().getFirst(AUTHORIZATION_HEADER);

        if (authHeader == null || !authHeader.startsWith(BEARER_PREFIX)) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        // JWT 검증 로직 (user-service 공개키로 서명 검증)
        String token = authHeader.substring(BEARER_PREFIX.length());
        // ... 검증 로직 ...

        return chain.filter(exchange);
    }

    @Override
    public int getOrder() {
        return -1; // 가장 먼저 실행 (낮을수록 먼저)
    }
}
```

### 📌 Rate Limiting 설정

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: recommendation-service
          uri: lb://recommendation-service
          predicates:
            - Path=/api/recommendations/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 10    # 초당 10개 허용
                redis-rate-limiter.burstCapacity: 20    # 순간 최대 20개
                redis-rate-limiter.requestedTokens: 1
                key-resolver: "#{@ipKeyResolver}"       # IP 기준으로 제한
```

```java
/**
 * Rate Limit의 키 기준을 정의한다.
 * IP 기준: 동일 IP에서 오는 요청을 함께 묶어 제한
 * userId 기준: 로그인 사용자별로 제한하려면 JWT에서 추출
 */
@Bean
public KeyResolver ipKeyResolver() {
    return exchange -> Mono.just(
        exchange.getRequest().getRemoteAddress().getAddress().getHostAddress()
    );
}
```

---

##  4. 트러블슈팅

---

### 📌 "spring-boot-starter-web과 충돌"

```
Description: Spring MVC found on classpath, which is incompatible with Spring Cloud Gateway.
```

원인: Spring Cloud Gateway는 WebFlux 기반이라 `spring-boot-starter-web`과 공존할 수 없다.

해결: Gateway 모듈의 `build.gradle`에서 `spring-boot-starter-web` 의존성을 제거하거나, `exclude`로 제외한다.

```groovy
// 잘못된 예 — web과 gateway 동시 사용
implementation 'org.springframework.boot:spring-boot-starter-web'
implementation 'org.springframework.cloud:spring-cloud-starter-gateway' // 충돌!

// 올바른 예 — gateway만 사용
implementation 'org.springframework.cloud:spring-cloud-starter-gateway' // WebFlux 포함
```

### 📌 "lb:// 사용 시 503 Service Unavailable"

원인: Eureka Server가 아직 올라오지 않았거나, 대상 서비스가 Eureka에 등록되지 않은 상태에서 요청이 들어온 경우.

해결:

```yaml
spring:
  cloud:
    gateway:
      discovery:
        locator:
          enabled: true   # Eureka 등록된 서비스를 자동으로 라우트에 추가
```

---

##  5. 정리

---

- Spring Cloud Gateway는 Zuul을 대체하는 공식 API Gateway로, **Non-blocking(WebFlux) 기반**이라 고동시성 환경에서 유리하다.
- 모든 라우팅은 **Route(ID + URI + Predicates + Filters)** 단위로 구성된다.
- `lb://서비스명` 형식으로 **Eureka + LoadBalancer 자동 연동**이 가능하다.
- **GlobalFilter**로 JWT 검증·Rate Limit 같은 공통 관심사를 게이트웨이 한 곳에서 처리할 수 있다.

---

## 참고 자료

- Spring Cloud Gateway 공식 문서: <https://docs.spring.io/spring-cloud-gateway/reference/index.html>
- Spring 공식 가이드 - Building a Gateway: <https://spring.io/guides/gs/gateway/>
- Baeldung - Exploring Spring Cloud Gateway: <https://www.baeldung.com/spring-cloud-gateway>
