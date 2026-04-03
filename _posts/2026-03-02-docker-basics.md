---
title: Docker 기초 — VM과의 차이부터 Compose까지
date: 2026-03-02 00:00:00 +0900
categories: [Docker]
tags: [Docker, DockerCompose, Dockerfile, MSA, 인프라]
---

## 📗 1. 개요

---

이커머스 서비스를 MSA로 구성하다 보면 MySQL, Redis, MongoDB, Kafka 같은 인프라를 팀원 전원이 동일한 환경에서 실행해야 하는 상황이 생긴다. 이번 글에서는 Docker가 왜 필요한지부터 시작해서 Image, Container, Volume, Network 핵심 개념과 Dockerfile, Docker Compose 사용법까지 정리한다.

### 📌 전체 구조

| 개념 | 한 줄 요약 |
| --- | --- |
| Image | 실행 환경이 담긴 설계도 (읽기 전용) |
| Container | 이미지를 실행한 실제 프로세스 |
| Volume | 컨테이너가 삭제돼도 데이터를 유지하는 저장소 |
| Network | 컨테이너끼리 이름으로 통신하는 가상 네트워크 |
| Dockerfile | 내 앱을 이미지로 만드는 설계 파일 |
| Docker Compose | 여러 컨테이너를 YAML 파일 하나로 관리 |

---

## 📗 2. 왜 Docker가 필요한가

---

### 📌 환경 불일치 문제

신입 개발자가 로컬에서 열심히 개발을 완료했다. Java 17, MySQL 8.0 환경에서 잘 동작한다. 팀장한테 배포 요청을 받았다.

```
팀원 A (Mac M1):    Java 11 + MySQL 5.7 → 에러 ❌
팀원 B (Windows):   Java 17 + MySQL 8.0 → 경로 문제 ❌
운영 서버 (Linux):  Java 17 + MySQL 8.0 → 또 다른 에러 ❌
```

원인 파악하는 데만 반나절이 걸린다. 이게 바로 환경 불일치 문제다.

이커머스 MSA 프로젝트엔 MySQL, Redis, MongoDB, Kafka, Elasticsearch, Qdrant 6가지 인프라가 있다. 각자 버전도 다르고 설정도 다르다. 팀원이 이걸 전부 직접 설치하면 버전 충돌, 설정 꼬임, "저는 안 되는데요?" 무한 반복이 생긴다.

Docker는 이 문제를 표준화된 컨테이너 박스로 해결한다.

```
팀원 전원이 동일한 docker-compose.yml 파일 1개 공유
                  ↓
      docker compose up 명령 하나
                  ↓
MySQL 8.0 + Redis 7.0 + MongoDB 6.0 동일하게 실행
                  ↓
      "내 컴퓨터에선 됐는데요?" 가 사라짐
```

> 💡 Docker는 애플리케이션과 그 실행 환경(OS, 라이브러리, 설정 포함)을 컨테이너라는 격리된 단위로 패키징하고 실행하는 플랫폼이다.

---

## 📗 3. VM vs Docker

---

### 📌 VM이 무거운 이유

VM은 하드웨어 자체를 통째로 가상화한다. Guest OS 전체를 포함하기 때문에 1개당 수 GB RAM을 차지하고, 부팅에 수십 초가 걸린다.

```
내 Mac (Host)
  └── Hypervisor
        ├── VM 1: Guest OS (Linux) + App   ← 수 GB
        └── VM 2: Guest OS (Linux) + App   ← 수 GB
```

### 📌 Docker가 가벼운 이유

Docker는 OS 전체를 가상화하지 않는다. Host OS의 커널을 공유하고 프로세스만 격리한다. OS 없이 앱과 라이브러리만 포함하기 때문에 수백 MB 수준이고, 시작 시간은 1~3초다.

```
내 Mac (Host)
  └── Host OS Kernel (공유)
        ├── 컨테이너 1: App + 라이브러리   ← 수백 MB
        └── 컨테이너 2: App + 라이브러리   ← 수백 MB
```

### 📌 비교 표

| 항목 | VM | Docker 컨테이너 |
| --- | --- | --- |
| 가상화 대상 | 하드웨어 전체 | 프로세스만 격리 |
| OS 포함 | Guest OS 전체 | Host OS 커널 공유 |
| 용량 | 수 GB | 수 MB ~ 수백 MB |
| 시작 속도 | 수십 초 ~ 분 | 1~3초 |
| 격리 수준 | 완전한 격리 | 프로세스 수준 격리 |
| 주요 용도 | 완전한 서버 환경 | 앱 실행 환경 표준화 |

### 📌 Mac에서 Docker는 어떻게 동작하나

Docker 컨테이너는 Linux 커널이 필요하다. macOS와 Linux 커널은 다르기 때문에 Docker Desktop은 Mac 위에 경량 Linux VM을 하나 띄운다. 이 VM은 Docker Desktop이 자동으로 관리하기 때문에 신경 쓸 필요 없다.

```
내 Mac (macOS)
  └── Docker Desktop
        └── 경량 Linux VM (내부에 숨겨져 있음)
              └── Docker 컨테이너들이 여기서 실행됨
```

---

## 📗 4. 핵심 개념 4가지

---

### 📌 Image — 설계도

이미지는 MySQL 8.0을 실행하는 데 필요한 모든 것이 담긴 파일이다. OS 라이브러리, MySQL 바이너리, 설정 파일, 실행 명령어가 전부 포함된다. 읽기 전용이기 때문에 한 번 만들어지면 수정할 수 없다.

레이어 구조로 구성되기 때문에 `mysql:8.0`과 `mysql:5.7`은 베이스 레이어를 공유하며 디스크를 절약한다.

```bash
docker pull mysql:8.0       # Docker Hub에서 이미지 받기
docker images               # 로컬 이미지 목록
docker rmi mysql:8.0        # 이미지 삭제
docker inspect mysql:8.0    # 레이어 구조 상세 확인
```

### 📌 Container — 실행 중인 프로세스

컨테이너는 이미지로 만든 실제 실행 중인 프로세스다. 같은 이미지로 컨테이너를 여러 개 만들 수 있고, 각각은 완전히 독립적이다. 컨테이너를 삭제해도 이미지는 남는다.

```
이미지(mysql:8.0) → 컨테이너(ecommerce-mysql)
레시피             → 실제 요리
```

컨테이너 상태 흐름:
```
이미지
  │ docker run
Created → Running → Stopped → (docker rm) → 삭제됨
              │
              └── docker exec (내부 명령 실행)
```

```bash
docker run -d \
  --name ecommerce-mysql \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  -p 3306:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0

docker ps                             # 실행 중 목록
docker ps -a                          # 전체 목록 (정지 포함)
docker exec -it ecommerce-mysql bash  # 내부 접속
docker logs -f ecommerce-mysql        # 실시간 로그
docker stop ecommerce-mysql           # 정지
docker rm ecommerce-mysql             # 삭제
```

### 📌 Volume — 데이터 영속성

볼륨이 필요한 이유를 실험으로 확인할 수 있다.

```bash
# 볼륨 없이 MySQL 실행
docker run -d --name mysql-test -e MYSQL_ROOT_PASSWORD=root1234 mysql:8.0

# DB 생성 후 컨테이너 삭제
docker exec mysql-test mysql -u root -proot1234 -e "CREATE DATABASE testdb;"
docker rm -f mysql-test

# 다시 실행하면 testdb가 사라짐 😱
```

컨테이너는 일회용 프로세스다. 삭제하면 내부 데이터도 함께 사라진다. 볼륨은 컨테이너 바깥에 독립 저장소를 만들어서 이 문제를 해결한다.

```
[볼륨 연결 후]
컨테이너
  └── /var/lib/mysql ←── [볼륨: mysql-data]
                          (컨테이너 삭제해도 데이터 유지)
```

볼륨 종류:
```bash
# Named Volume: Docker가 관리, docker volume ls에 표시됨
-v mysql-data:/var/lib/mysql

# Bind Mount: 내 Mac 폴더 직접 연결, Finder에서 확인 가능
-v /Users/chan/docker/mysql:/var/lib/mysql
# docker volume ls에는 표시 안 됨 (Docker 관리 볼륨이 아님)
```

```bash
docker volume ls                  # Named Volume 목록
docker volume inspect mysql-data  # 상세 정보
docker volume prune               # 미사용 볼륨 삭제 (주의)
```

### 📌 Network — 컨테이너 간 통신

Spring Boot 컨테이너에서 MySQL에 접속할 때 `localhost:3306`을 쓰면 실패한다. 컨테이너 내부의 localhost는 컨테이너 자기 자신이기 때문이다.

같은 Docker 네트워크 안에서는 컨테이너 이름이 주소가 된다.

```bash
# 잘못된 방법 ❌
jdbc:mysql://localhost:3306

# 올바른 방법 ✅ (컨테이너 이름으로 접근)
jdbc:mysql://mysql:3306
```

```bash
docker network create ecommerce-network

docker run -d --name mysql --network ecommerce-network mysql:8.0
docker run -d --name redis --network ecommerce-network redis:7.0

# 같은 네트워크라면 이름으로 통신 가능
docker exec redis ping mysql  # ✅
```

포트 바인딩과 네트워크의 관계:
```
내 Mac
  │ -p 3306:3306 (포트 바인딩)
  ↓
ecommerce-network (Docker 가상 네트워크)
  ├── mysql 컨테이너 :3306   ← 컨테이너끼리 mysql:3306
  ├── redis 컨테이너 :6379
  └── spring 컨테이너 :8082

-p 포트바인딩 = "내 Mac ↔ 컨테이너" 연결
네트워크       = "컨테이너 ↔ 컨테이너" 연결
```

> 💡 `-p` 포트 바인딩과 Docker 네트워크는 독립적으로 동작하는 서로 다른 레이어다. DB툴 접속은 포트 바인딩, 서비스 간 통신은 네트워크 이름으로 각각 처리한다.

---

## 📗 5. Dockerfile

---

### 📌 왜 필요한가

Docker Hub에는 `mysql:8.0`, `redis:7.0` 같은 공식 이미지가 있다. 하지만 우리가 만든 Spring Boot 앱은 없다. 직접 이미지를 만들어야 하고, 그 설계도가 Dockerfile이다.

```
Dockerfile → (docker build) → 이미지 → (docker run) → 컨테이너
```

### 📌 주요 명령어

```dockerfile
FROM eclipse-temurin:17-jre-alpine  # 베이스 이미지 (항상 첫 줄)
WORKDIR /app                        # 컨테이너 내 작업 폴더
COPY build/libs/*.jar app.jar       # 내 Mac 파일 → 컨테이너
RUN chmod +x gradlew                # 이미지 빌드 중 실행 (레이어로 저장)
ENV SPRING_PROFILES_ACTIVE=local    # 환경변수 기본값
EXPOSE 8083                         # 사용할 포트 문서화
ENTRYPOINT ["java", "-jar", "app.jar"]  # 컨테이너 시작 명령 (덮어쓰기 불가)
CMD ["--spring.profiles.active=local"]  # 기본 인자 (docker run 시 덮어쓰기 가능)
```

### 📌 Multi-stage Build

한 단계로만 빌드하면 JDK, 빌드 도구, 소스코드가 최종 이미지에 전부 포함되어 약 700MB가 된다. Multi-stage Build를 사용하면 JRE + JAR만 포함한 약 200MB 이미지를 만들 수 있다.

```dockerfile
# Stage 1: 빌드
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN ./gradlew bootJar --no-daemon

# Stage 2: 실행 (JDK 없이 JRE만 사용)
FROM eclipse-temurin:17-jre-alpine AS runner
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

```bash
docker build -t member-service:1.0 .            # 현재 폴더의 Dockerfile로 빌드
docker build --no-cache -t member-service:1.0 . # 캐시 없이 빌드
```

---

## 📗 6. Docker Compose

---

### 📌 왜 필요한가

인프라 6개를 매번 `docker run` 명령어로 실행하면 길고 반복적인 명령어를 실수 없이 입력해야 한다. 팀원과 설정을 맞추기도 어렵다. Docker Compose는 이 모든 것을 YAML 파일 하나로 관리한다.

```bash
docker compose up -d    # 전부 실행
docker compose down     # 전부 종료
```

### 📌 기본 구조

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: ecommerce-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql/my.cnf:/etc/mysql/my.cnf
    networks:
      - ecommerce-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-proot1234"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  mysql-data:

networks:
  ecommerce-network:
    driver: bridge
```

### 📌 주요 옵션

| 옵션 | 설명 |
| --- | --- |
| `image` | 사용할 Docker Hub 이미지 |
| `build` | 직접 만든 앱은 Dockerfile 경로 지정 |
| `environment` | 환경변수 설정 |
| `ports` | `내Mac포트:컨테이너포트` |
| `volumes` | Named Volume 또는 Bind Mount |
| `networks` | 연결할 네트워크 |
| `restart` | 재시작 정책 (`unless-stopped` 권장) |
| `healthcheck` | 컨테이너 상태 확인 방법 |
| `depends_on` | 다른 서비스가 healthy 후 시작 |

### 📌 depends_on — 시작 순서 제어

```yaml
member-service:
  build: ./member-service
  depends_on:
    mysql:
      condition: service_healthy  # mysql이 healthy일 때만 시작
```

### 📌 .env 파일로 민감 정보 분리

비밀번호를 docker-compose.yml에 직접 넣으면 보안상 위험하다. `.env` 파일로 분리하고 `.gitignore`에 추가한다.

```bash
# .env
MYSQL_ROOT_PASSWORD=root1234
REDIS_PASSWORD=redis1234
```

```yaml
# docker-compose.yml
environment:
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

### 📌 주요 명령어

```bash
docker compose up -d              # 전체 백그라운드 실행
docker compose up -d --build      # 이미지 재빌드 후 실행
docker compose ps                 # 서비스 상태 확인
docker compose logs -f mysql      # 실시간 로그
docker compose exec mysql bash    # 서비스 내부 접속
docker compose down               # 종료 (볼륨 유지)
docker compose down -v            # 종료 + 볼륨 삭제 (데이터 초기화)
docker compose config             # 설정 파일 유효성 검사
```

---

## 📗 7. 명령어 치트시트

---

```bash
# 이미지
docker pull mysql:8.0 / docker images / docker rmi mysql:8.0

# 컨테이너
docker run -d --name myapp myapp:1.0
docker ps / docker ps -a
docker exec -it myapp bash
docker logs -f myapp
docker stop myapp / docker rm myapp
docker stats                     # 리소스 사용량 실시간

# 볼륨
docker volume ls / docker volume inspect myvolume / docker volume prune

# 네트워크
docker network create mynet / docker network ls / docker network inspect mynet

# 시스템 정리
docker system prune -a           # 미사용 전부 정리
docker system df                 # 디스크 사용량 확인
```

---

## 📗 8. 정리

---

- Docker는 환경 불일치 문제를 컨테이너로 해결한다. VM과 달리 OS 전체를 가상화하지 않고 Host 커널을 공유하기 때문에 가볍고 빠르다.
- Volume은 컨테이너 삭제 후에도 데이터를 유지한다. Named Volume은 Docker가 관리하고, Bind Mount는 내 Mac 폴더를 직접 연결한다.
- Network 안에서는 컨테이너 이름이 주소가 된다. `localhost`가 아닌 `mysql:3306`으로 접근해야 한다.
- Dockerfile의 Multi-stage Build로 최종 이미지에서 JDK와 소스코드를 제거하면 이미지 크기를 3분의 1로 줄일 수 있다.
- Docker Compose는 여러 컨테이너 설정을 YAML 파일 하나로 관리한다. `depends_on`으로 시작 순서를 제어하고, `.env`로 민감 정보를 분리한다.

---

## 참고 자료

- 공식문서 - Docker 전체: <https://docs.docker.com>
- 공식문서 - Docker Hub: <https://hub.docker.com>
- 공식문서 - Docker Compose: <https://docs.docker.com/compose>
- 공식문서 - Dockerfile Best Practices: <https://docs.docker.com/develop/develop-images/dockerfile_best-practices>
