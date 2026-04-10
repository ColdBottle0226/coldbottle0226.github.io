---
title: "스프링 클라우드 기반 MSA 구성 - Service Registry"
date: 2026-04-09 09:10:00 +0900
categories: [Spring, MSA]
order: 1
tags: [SpringCloud, MSA, ServiceRegistry, Eureka, EurekaServer, NetflixOSS, ServiceDiscovery]
---

##  1. 개요

---

MSA에서 서비스는 언제든 새 인스턴스가 추가되거나 기존 인스턴스가 내려갈 수 있다. 스케일 아웃(Scale Out)이 일어나면 동일 서비스의 IP가 여러 개가 된다. 이 동적인 환경에서 클라이언트가 어떤 IP로 요청을 보내야 하는지 어떻게 알 수 있을까?

이 문제를 해결하는 것이 **Service Registry**다. 모든 서비스 인스턴스가 자신의 위치(IP, Port)를 등록해두는 "전화번호부" 역할을 한다.

> 💡 Spring Cloud Netflix 공식 문서는 다음과 같이 설명한다: "Service Discovery is one of the key tenets of a microservice-based architecture. Trying to hand-configure each client or some form of convention can be difficult to do and can be brittle."
> 출처: [docs.spring.io/spring-cloud-netflix](https://docs.spring.io/spring-cloud-netflix/reference/spring-cloud-netflix.html)

**Eureka**는 Netflix가 만든 Service Discovery Server이자 Client다. Spring Cloud Netflix 프로젝트를 통해 Spring Boot와 통합되어 사용된다.

### 📌 전체 동작 구조

```
[서비스 기동 시]
user-service    ──── 등록 (Register) ────▶ Eureka Server
place-service   ──── 등록 (Register) ────▶ Eureka Server

[10초마다]
user-service    ──── 하트비트 (Heartbeat) ──▶ Eureka Server
                                              (살아있음을 알림)

[타 서비스 조회 시]
recommendation-service ──── 조회 (Fetch) ──▶ Eureka Server
                       ◀──  "place-service = 172.17.0.3:8082"
```

| 개념 | 역할 |
|---|---|
| Eureka Server | 서비스 인스턴스 목록을 저장하고 제공하는 레지스트리 서버 |
| Eureka Client | 각 서비스가 Eureka Server에 자신을 등록하고 타 서비스를 조회하는 클라이언트 |
| Heartbeat | 클라이언트가 보내는 생존 신호. 설정 시간 동안 오지 않으면 레지스트리에서 제거 |
| Self-Preservation | 일정 비율 이상의 인스턴스가 동시에 사라지면 강제 제거를 막는 보호 모드 |

---

##  2. 핵심 개념

---

### 📌 Eureka Server의 저장소

Eureka Server는 **백엔드 데이터베이스를 사용하지 않는다**. 공식 문서에서 명확히 설명한다.

> "The Eureka server does not have a back end store, but the service instances in the registry all have to send heartbeats to keep their registrations up to date (so this can be done in memory)."

레지스트리는 순전히 **메모리 기반**으로 운영된다. Eureka Client도 레지스트리 복사본을 로컬 메모리에 캐시해두기 때문에, Eureka Server가 잠깐 다운되더라도 클라이언트는 캐시에서 서비스 위치를 조회할 수 있다.

### 📌 ${} — 환경변수 & Spring Property Placeholder

application.yml에 `${변수명:기본값}` 형태로 작성된 값들은 **Spring Property Placeholder** 문법이다.

```yaml
eureka:
  server:
    enable-self-preservation: ${EUREKA_SELF_PRESERVATION:false}
#                              ↑                        ↑
#                          환경변수 이름          환경변수 없을 때 기본값
```

Spring Boot가 애플리케이션을 시작할 때 아래 순서로 값을 탐색한다.

| 우선순위 | 출처 | 예시 |
|---|---|---|
| 1순위 | OS 환경변수 | `export EUREKA_SELF_PRESERVATION=true` |
| 2순위 | JVM 시스템 프로퍼티 | `-DEUREKA_SELF_PRESERVATION=true` |
| 3순위 | application.yml 기본값 | `:false` 부분 |

이 방식 덕분에 **코드를 바꾸지 않고 환경변수만 바꿔서 동작을 제어**할 수 있다. 특히 비밀번호, 포트, 도메인 같은 값은 코드에 하드코딩하면 안 되기 때문에 이 방식을 사용한다.

```yaml
# Docker Compose에서 환경변수 주입 예시
services:
  eureka-server:
    image: eureka-server
    environment:
      - SERVER_PORT=8761
      - EUREKA_INSTANCE_HOSTNAME=eureka-server   # 컨테이너 서비스명으로 통신
      - EUREKA_SELF_PRESERVATION=false
      - SPRING_PROFILES_ACTIVE=docker
```

### 📌 Heartbeat (하트비트) — 생존 신호

마이크로서비스가 Eureka Server에 등록된 후, **주기적으로 "나 살아있다"는 신호를 보내는 것**이 하트비트다.

```
[user-service] ──── "살아있어요!" ────▶ [Eureka Server]   (10초마다)
[user-service] ──── "살아있어요!" ────▶ [Eureka Server]   (10초 후)
[user-service] ──── "살아있어요!" ────▶ [Eureka Server]   (10초 후)

     ↓ (user-service 서버가 갑자기 크래시)

                                        [Eureka Server]
                                         "30초 동안 신호 없음...
                                          → user-service 제거"
```

**하트비트 타임라인 시나리오**

```
T=0s   : user-service 기동, Eureka에 등록
T=10s  : 하트비트 전송 
T=20s  : 하트비트 전송 
T=25s  : user-service OOM 크래시 (하트비트 중단)
T=30s  : 30초 만료 시간 도달 → Eureka가 "Lease expired" 마킹
T=35s  : eviction-interval(5초) 체크 → user-service 레지스트리에서 완전 제거
T=35s~ : api-gateway의 lb://user-service → 인스턴스 없음 → Circuit Breaker 동작
```

**설정값 의미**

```yaml
# 클라이언트 서비스(user-service, gateway 등) 설정
eureka:
  instance:
    lease-renewal-interval-in-seconds: 10    # 10초마다 하트비트 전송
    lease-expiration-duration-in-seconds: 30 # 30초간 하트비트 없으면 만료 마킹

# Eureka Server 설정
eureka:
  server:
    eviction-interval-timer-in-ms: 5000      # 5초마다 만료 인스턴스 청소
```

| 설정 | 위치 | 의미 |
|---|---|---|
| `lease-renewal-interval` | 클라이언트 | "나는 N초마다 하트비트를 보낸다" |
| `lease-expiration-duration` | 클라이언트 | "N초간 하트비트 없으면 제거해도 된다" |
| `eviction-interval-timer` | 서버 | "서버가 N밀리초마다 만료 인스턴스를 청소한다" |

### 📌 Self-Preservation Mode (자기 보존 모드)

네트워크 일시 단절 상황에서 서비스는 멀쩡한데 하트비트만 끊겼을 때, Eureka가 섣불리 인스턴스를 제거하는 것을 막는 보호 모드다.

**Self-Preservation이 발동하는 조건**

Eureka는 예상 하트비트 수를 계산한다.

```
예상 하트비트 = 등록된 인스턴스 수 × (60 / lease-renewal-interval) × 0.85
             = 10개 서비스    × (60 / 10초)                    × 0.85
             = 51개/분

실제 받은 하트비트가 51개 미만 → Self-Preservation 모드 진입
```

**false(개발) vs true(운영) 동작 비교**

```
[false 일 때 — 현재 개발 설정]

T=0s   : 10개 서비스 정상 운영
T=5s   : 네트워크 장애 발생, 하트비트 8개 손실
T=10s  : Eureka "하트비트 없음 → 제거" → 8개 서비스 레지스트리 삭제
T=15s  : 네트워크 복구
T=20s  : 서비스들이 재등록
결과: 10~20초 동안 서비스 중단 (빠른 피드백, 개발에 적합)

[true 일 때 — 운영 권장]

T=0s   : 10개 서비스 정상 운영
T=5s   : 네트워크 장애 발생, 하트비트 8개 손실
T=10s  : Eureka "갑자기 너무 많은 하트비트가 끊겼다
          → 내 네트워크 문제일 수도 있다
          → Self-Preservation 진입, 제거 중단"
T=15s  : 네트워크 복구, 하트비트 재개
결과: 서비스가 레지스트리에서 제거되지 않아 중단 없음 
```

> 💡 개발 환경에서 `enable-self-preservation: true`를 켜두면, 서비스를 내려도 Eureka 대시보드에 인스턴스가 계속 남아 있어 디버깅이 어렵다. 개발 환경에서만 `false`로 쓰자.

### 📌 Peer Awareness (고가용성 클러스터링)

프로덕션 환경에서는 Eureka Server를 **여러 대** 띄워 서로 레지스트리를 복제한다.

```yaml
# peer1 설정
spring:
  profiles: peer1
eureka:
  instance:
    hostname: peer1
  client:
    serviceUrl:
      defaultZone: http://peer2/eureka/   # peer2에 자신을 등록

---
# peer2 설정
spring:
  profiles: peer2
eureka:
  instance:
    hostname: peer2
  client:
    serviceUrl:
      defaultZone: http://peer1/eureka/   # peer1에 자신을 등록
```

두 서버가 서로를 바라보며 레지스트리를 동기화한다. 하나가 죽어도 나머지 서버가 계속 서비스를 제공한다.

---

##  3. 서비스 생성 및 기초 설정

---

### 📌 디렉토리 구조

```
services/eureka-server/
  ├── build.gradle
  ├── settings.gradle
  ├── Dockerfile
  └── src/main/
      ├── java/com/seouldate/eureka/
      │   └── EurekaServerApplication.java
      └── resources/
          └── application.yml
```

### 📌 build.gradle

```groovy
/**
 * Eureka Server는 Spring Cloud Netflix 프로젝트의 일부다.
 * Spring Cloud BOM(Bill of Materials)으로 버전을 일괄 관리한다.
 * Spring Boot 3.2.x ↔ Spring Cloud 2023.0.x 호환
 * 호환 매트릭스: https://spring.io/projects/spring-cloud#overview
 */
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.5'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.seouldate'
version = '0.0.1-SNAPSHOT'

java {
    sourceCompatibility = JavaVersion.VERSION_21
}

ext {
    set('springCloudVersion', "2023.0.1")
}

dependencies {
    // Eureka Server 핵심 의존성
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

dependencyManagement {
    imports {
        // Spring Cloud 버전 일괄 관리 BOM
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}

tasks.named('test') {
    useJUnitPlatform()
}
```

### 📌 EurekaServerApplication.java

```java
package com.seouldate.eureka;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

/**
 * @EnableEurekaServer 어노테이션 하나로 이 애플리케이션이
 * Eureka Service Registry로 동작하게 된다.
 * Spring Cloud가 나머지 자동 설정을 모두 처리한다.
 */
@SpringBootApplication
@EnableEurekaServer
public class EurekaServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(EurekaServerApplication.class, args);
    }
}
```

### 📌 application.yml

```yaml
server:
  port: ${SERVER_PORT:8761}   # 환경변수 없으면 기본값 8761

spring:
  application:
    name: eureka-server

eureka:
  instance:
    hostname: ${EUREKA_INSTANCE_HOSTNAME:eureka-server}
    # Docker에서는 컨테이너 서비스명으로, 로컬에서는 localhost로 사용 가능
    metadata-map:
      zone: ${EUREKA_ZONE:local}
      environment: ${SPRING_PROFILES_ACTIVE:local}

  client:
    # Eureka Server는 자기 자신을 레지스트리에 등록하면 안 된다.
    register-with-eureka: false
    # Eureka Server는 다른 서버에서 레지스트리를 가져올 필요 없다.
    fetch-registry: false
    service-url:
      defaultZone: http://${eureka.instance.hostname}:${server.port}/eureka/

  server:
    # 개발=false(빠른 피드백), 운영=true(안정성 우선)
    enable-self-preservation: ${EUREKA_SELF_PRESERVATION:false}

    # 5초마다 만료 인스턴스 정리 (기본 60초 → 단축)
    eviction-interval-timer-in-ms: 5000

    # 응답 캐시 5초마다 갱신 (기본 30초 → 실시간성 향상)
    response-cache-update-interval-ms: 5000

    # 예상 하트비트의 85% 미달 시 Self-Preservation 발동
    renewal-percent-threshold: 0.85

    # 피어 Eureka Server 동기화 대기 (단일 서버이므로 0)
    wait-time-in-ms-when-sync-empty: 0

management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics
  endpoint:
    health:
      show-details: always

logging:
  level:
    # Eureka 내부 로그가 너무 많아서 WARN으로 낮춤
    com.netflix.eureka: WARN
    com.netflix.discovery: WARN
```

### 📌 Docker Compose 추가

```yaml
eureka-server:
  build:
    context: ./services/eureka-server
    dockerfile: Dockerfile
  container_name: date-eureka-server
  restart: unless-stopped
  ports:
    - "8761:8761"
  environment:
    - SERVER_PORT=8761
    - EUREKA_INSTANCE_HOSTNAME=eureka-server
    - EUREKA_SELF_PRESERVATION=false
    - SPRING_PROFILES_ACTIVE=docker
  networks:
    - date-net
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8761/actuator/health"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 40s
```

다른 서비스들은 `depends_on`에 eureka-server를 추가해야 한다.

```yaml
user-service:
  ...
  depends_on:
    eureka-server:        # Eureka가 먼저 올라와야 등록 가능
      condition: service_healthy
    mysql-user:
      condition: service_healthy
```

---

##  4. 대시보드 확인

---

Eureka Server를 기동하고 `http://localhost:8761`에 접속하면 Eureka Dashboard가 열린다.

서비스들이 등록되면 "Instances currently registered with Eureka" 섹션에 아래처럼 표시된다.

```
Application          AMIs   Availability Zones   Status
USER-SERVICE         n/a    (1)                  UP (1) - 172.17.0.4:user-service:8081
PLACE-SERVICE        n/a    (1)                  UP (1) - 172.17.0.5:place-service:8082
RECOMMENDATION...    n/a    (1)                  UP (1) - 172.17.0.6:recommendation-service:8083
```

> 💡 Eureka는 `spring.application.name`을 대문자로 변환하여 Application 컬럼에 표시한다. `user-service` → `USER-SERVICE`.

---

##  5. 트러블슈팅

---

### 📌 "EMERGENCY! EUREKA MAY BE INCORRECTLY CLAIMING..."

Eureka Dashboard에 빨간 경고 메시지가 뜨는 경우다.

원인: Self-Preservation Mode가 활성화된 상태에서 Eureka Server가 기대한 것보다 적은 수의 하트비트를 받을 때 발생한다.

해결: 개발 환경이라면 `enable-self-preservation: false`로 설정한다. 프로덕션이라면 이 경고는 정상적인 보호 동작이므로 무시해도 된다.

### 📌 서비스를 내렸는데 Eureka에 여전히 UP으로 표시됨

원인: Eureka Client의 하트비트 만료 시간(기본 90초) 때문이다. 서비스가 꺼져도 90초가 지나야 레지스트리에서 제거된다.

해결: 개발 환경에서는 클라이언트 설정에서 만료 시간을 줄인다.

```yaml
# 각 서비스의 application.yml
eureka:
  instance:
    lease-renewal-interval-in-seconds: 10   # 10초마다 하트비트
    lease-expiration-duration-in-seconds: 30 # 30초 동안 하트비트 없으면 제거
```

---

##  6. 정리

---

- Eureka Server는 MSA에서 모든 서비스 인스턴스의 IP/Port를 관리하는 **Service Registry**다.
- 저장소가 없는 **순수 메모리 기반** 레지스트리이며, Client도 로컬에 캐시를 유지한다.
- `${변수명:기본값}` 문법으로 코드 변경 없이 **환경별 설정을 주입**할 수 있다.
- Heartbeat는 클라이언트가 "살아있음"을 알리는 신호이며, `lease-renewal-interval`로 주기를, `lease-expiration-duration`으로 만료 시간을 제어한다.
- Self-Preservation은 **네트워크 장애 시 정상 인스턴스가 오삭제되는 것을 방지**하는 보호 모드다. 개발=false, 운영=true.
- 프로덕션에서는 Self-Preservation Mode를 켜두고, Peer Awareness로 고가용성을 확보해야 한다.

> 💡 운영 배포 전 `EUREKA_SELF_PRESERVATION=true` 환경변수 주입을 잊지 말자. 현재 기본값 `false`는 개발 전용이다.

---

## 참고 자료

- Spring Cloud Netflix 공식 문서: <https://docs.spring.io/spring-cloud-netflix/reference/spring-cloud-netflix.html>
- Eureka Server 공식 문서: <https://cloud.spring.io/spring-cloud-netflix/multi/multi_spring-cloud-eureka-server.html>
- Baeldung - Spring Cloud Netflix Eureka: <https://www.baeldung.com/spring-cloud-netflix-eureka>
