---
title: "스프링 클라우드 기반 MSA 구성 - Service Discovery"
date: 2026-04-09 09:20:00 +0900
categories: [Spring, MSA]
order: 2
tags: [SpringCloud, MSA, ServiceDiscovery, EurekaClient, DiscoveryClient, Heartbeat, Registration]
---

##  1. 개요

---

이전 글에서 **Service Registry(Eureka Server)**를 설명했다. Eureka Server는 전화번호부 서버다. 이번에는 각 서비스가 그 전화번호부에 자신을 등록하고, 타 서비스를 조회하는 클라이언트 쪽 — **Service Discovery(Eureka Client)**를 다룬다.

**Service Discovery**는 크게 두 가지 방식이 있다.

| 방식 | 설명 | 예시 |
|---|---|---|
| Server-Side Discovery | 중앙 로드 밸런서가 레지스트리를 조회해서 라우팅 | AWS ALB + ECS |
| Client-Side Discovery | **클라이언트(서비스)가 직접 레지스트리를 조회**해서 요청 | Eureka Client + Spring Cloud LoadBalancer |

Spring Cloud는 **Client-Side Discovery** 방식을 사용한다.

> 💡 공식 문서: "Having spring-cloud-starter-netflix-eureka-client on the classpath makes the app into both a Eureka 'instance' (that is, it registers itself) and a 'client' (it can query the registry to locate other services)."
> 출처: [docs.spring.io/spring-cloud-netflix](https://docs.spring.io/spring-cloud-netflix/reference/spring-cloud-netflix.html)

의존성 하나를 추가하는 것만으로 서비스가 자동으로 등록(instance)되고 조회(client) 기능을 모두 갖추게 된다.

### 📌 Client-Side Discovery 흐름

```
1. user-service 기동
   → Eureka Server에 자신을 등록 (Register)
   → "user-service = 172.17.0.4:8081" 정보 저장

2. recommendation-service에서 user-service 호출 필요
   → 로컬 캐시에 user-service 목록 있음? → 있으면 사용
   → 없거나 만료? → Eureka Server에서 Fetch
   → 172.17.0.4:8081로 실제 HTTP 요청

3. user-service 인스턴스 2개로 Scale Out
   → 두 인스턴스 모두 Eureka에 등록
   → recommendation-service는 다음 요청부터 두 인스턴스를 LoadBalancer로 분배
```

---

##  2. 핵심 개념

---

### 📌 인스턴스 메타데이터

Eureka Client가 서버에 등록할 때 전송하는 정보다.

> 공식 문서: "When a client registers with Eureka, it provides meta-data about itself — such as host, port, health indicator URL, home page, and other details."

| 메타데이터 | 기본값 | 설명 |
|---|---|---|
| `appName` (서비스명) | `spring.application.name` | Eureka에서 조회하는 키 |
| `hostname` | 머신의 호스트명 | Docker에서는 컨테이너 이름 |
| `port` | `server.port` | 서비스 포트 |
| `healthCheckUrl` | `/actuator/health` | Eureka가 상태 확인에 사용 |
| `statusPageUrl` | `/actuator/info` | Eureka 대시보드에서 링크 클릭 시 이동 |
| `instanceId` | `hostname:appName:port` | 인스턴스 구분 고유 ID |

### 📌 인스턴스 ID — Docker에서 중요한 설정

Docker 환경에서는 여러 컨테이너가 같은 호스트에 떠 있어서 기본 instanceId가 충돌할 수 있다.

```yaml
eureka:
  instance:
    # Docker 환경: 컨테이너 IP로 등록 (호스트명 대신)
    prefer-ip-address: true

    # 인스턴스 ID를 Spring Cloud 스타일로 설정 (충돌 방지)
    instance-id: ${spring.application.name}:${spring.cloud.client.ip-address}:${server.port}
```

### 📌 로컬 레지스트리 캐시

Eureka Client는 Eureka Server에서 가져온 레지스트리를 **로컬 메모리에 캐시**한다. 기본적으로 30초마다 갱신한다.

```
Eureka Server (원본 레지스트리)
    ↕ 30초마다 동기화
recommendation-service (로컬 캐시)
→ 타 서비스 호출 시 로컬 캐시에서 주소를 조회 (Eureka Server에 매번 요청하지 않음)
```

이 덕분에 Eureka Server가 잠깐 다운되어도 기존 캐시로 계속 요청이 가능하다.

---

##  3. 각 서비스에 Eureka Client 추가

---

### 📌 build.gradle 변경 (4개 Spring Boot 서비스 공통)

```groovy
/**
 * spring-cloud-starter-netflix-eureka-client를 추가하면
 * 서비스가 자동으로 Eureka에 등록(Register)되고,
 * 타 서비스 주소를 조회(Discovery)하는 기능을 모두 갖추게 된다.
 *
 * spring-cloud-starter-loadbalancer는 FeignClient와 함께
 * 클라이언트 사이드 로드 밸런싱을 위해 필요하다.
 */

ext {
    set('springCloudVersion', "2023.0.1")
}

dependencies {
    // ...기존 코드

    // Eureka Client — 등록 + 조회
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'

    // Client-Side Load Balancer (Ribbon 대체)
    implementation 'org.springframework.cloud:spring-cloud-starter-loadbalancer'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}
```

### 📌 Application.java

```java
/**
 * Spring Cloud 2023.0 (Spring Boot 3.2)부터
 * @EnableDiscoveryClient 어노테이션이 불필요하다.
 * classpath에 eureka-client 의존성이 있으면 자동으로 활성화된다.
 *
 * 단, 명시적으로 붙여도 동작에 문제 없다.
 */
@SpringBootApplication
@EnableJpaAuditing  // JPA Auditing (user-service 예시)
public class UserServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(UserServiceApplication.class, args);
    }
}
```

각 서비스별 Application 클래스:

| 서비스 | 클래스명 |
|---|---|
| user-service | `UserServiceApplication` |
| recommendation-service | `RecommendationServiceApplication` |
| ai-service | `AiServiceApplication` |
| seoul-data-service | `SeoulDataServiceApplication` |

### 📌 application.yml — 서비스별 설정

아래는 user-service 예시다. `spring.application.name`만 서비스별로 다르게 설정하면 된다.

```yaml
server:
  port: 8081

spring:
  application:
    name: user-service    # ← 이 이름으로 Eureka에 등록된다
  datasource:
    url: jdbc:mysql://mysql-user:3306/user_db
    ...

# Eureka Client 설정
eureka:
  client:
    service-url:
      # Docker Compose 환경: 컨테이너 이름(eureka-server)으로 접근
      defaultZone: http://eureka-server:8761/eureka/

    # 레지스트리 갱신 주기 (기본 30초 → 개발 환경에서 10초로 단축)
    registry-fetch-interval-seconds: 10

  instance:
    # Docker 환경: 호스트명 대신 컨테이너 IP를 Eureka에 등록
    prefer-ip-address: true

    # 하트비트 주기 (기본 30초)
    lease-renewal-interval-in-seconds: 10

    # 이 시간 동안 하트비트가 없으면 레지스트리에서 제거 (기본 90초)
    lease-expiration-duration-in-seconds: 30
```

각 서비스별 `spring.application.name`:

```yaml
# recommendation-service
spring:
  application:
    name: recommendation-service

# ai-service
spring:
  application:
    name: ai-service

# seoul-data-service
spring:
  application:
    name: seoul-data-service
```

---

##  4. DiscoveryClient로 직접 서비스 조회하기

---

`DiscoveryClient`를 주입받으면 코드에서 직접 레지스트리를 조회할 수 있다. 보통은 FeignClient나 LoadBalancer가 이 과정을 자동으로 처리하지만, 특수한 경우에 직접 사용할 수 있다.

```java
/**
 * DiscoveryClient는 Spring Cloud Commons의 추상 인터페이스다.
 * Eureka, Consul, Zookeeper 등 어떤 레지스트리를 써도
 * 동일한 코드로 서비스 인스턴스를 조회할 수 있다.
 */
@RestController
@RequiredArgsConstructor
public class DiscoveryController {

    private final DiscoveryClient discoveryClient;

    // 등록된 모든 서비스 목록 조회
    @GetMapping("/services")
    public List<String> services() {
        return discoveryClient.getServices();
    }

    // 특정 서비스의 인스턴스 목록 조회
    @GetMapping("/instances/{serviceName}")
    public List<ServiceInstance> instances(@PathVariable String serviceName) {
        return discoveryClient.getInstances(serviceName);
        // 반환 예시:
        // [ServiceInstance{serviceId='place-service', host='172.17.0.5', port=8082, ...}]
    }
}
```

---

##  5. 기동 순서와 의존성 처리

---

Eureka Client 서비스들은 기동 시 Eureka Server에 등록을 시도한다. Eureka Server가 먼저 올라와 있지 않으면 등록에 실패한다.

Docker Compose에서 기동 순서를 제어하는 방법:

```yaml
  user-service:
    build:
      context: ./services/user-service
    depends_on:
      eureka-server:
        condition: service_healthy   # Eureka Server 헬스체크 통과 후 기동
      mysql-user:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: local
      EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: http://eureka-server:8761/eureka/
```

Eureka Server가 잠깐 응답하지 못하더라도 서비스가 종료되지 않도록 재시도 설정을 추가한다.

```yaml
# 각 서비스 application.yml
eureka:
  client:
    # Eureka Server에 연결 실패 시 재시도 설정
    initial-instance-info-replication-interval-seconds: 10
    instance-info-replication-interval-seconds: 10
```

---

##  6. 트러블슈팅

---

### 📌 "Cannot execute request on any known server" 오류

Eureka Server에 등록된 서비스가 없는 상태에서 FeignClient로 호출하면 발생한다.

해결 순서:
1. `http://localhost:8761` 대시보드에서 해당 서비스가 UP 상태인지 확인
2. 해당 서비스의 `spring.application.name`이 FeignClient의 `name`과 일치하는지 확인
3. 서비스가 정상 기동됐는지 `/actuator/health` 직접 호출

### 📌 Eureka에는 UP인데 실제 요청이 실패함

원인: Eureka 레지스트리 캐시 갱신 지연. 로컬 캐시가 아직 갱신되지 않아 구 버전의 인스턴스 정보를 가지고 있을 수 있다.

해결:
```yaml
eureka:
  client:
    registry-fetch-interval-seconds: 5   # 캐시 갱신 주기를 5초로 단축
```

---

##  7. 정리

---

- Eureka Client는 classpath에 의존성만 추가하면 **자동으로 Eureka Server에 등록**되고 조회 기능도 갖춘다.
- Spring Cloud 2023.0부터 `@EnableDiscoveryClient` 어노테이션이 **불필요**하다.
- Docker 환경에서는 `prefer-ip-address: true`를 반드시 설정해야 컨테이너 간 통신이 가능하다.
- 로컬 레지스트리 캐시 덕분에 Eureka Server가 잠깐 다운되어도 **서비스 간 통신은 유지**된다.
- `spring.application.name`이 서비스의 고유 식별자이므로, FeignClient의 `name`과 반드시 일치해야 한다.

---

## 참고 자료

- Spring Cloud Netflix Eureka Client 공식 문서: <https://docs.spring.io/spring-cloud-netflix/reference/spring-cloud-netflix.html>
- Eureka Clients 상세 문서: <https://cloud.spring.io/spring-cloud-netflix/multi/multi__service_discovery_eureka_clients.html>
- Baeldung - Spring Cloud Netflix Eureka: <https://www.baeldung.com/spring-cloud-netflix-eureka>
