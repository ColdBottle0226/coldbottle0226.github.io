---
title: "Docker Compose로 다중 컨테이너 관리하기 - Spring Boot + MySQL 실전"
date: 2026-02-12 03:00:00 +0900
categories: [DevOps, Docker]
tags: [docker, docker-compose, spring-boot, mysql, multi-container]
---

## Docker Compose가 필요한 이유

지금까지 우리는 하나의 컨테이너를 실행하는 법을 배웠다. 하지만 실제 프로젝트는 한 개의 서비스만으로 돌아가지 않는다.

예를 들어, Spring Boot 애플리케이션이 있다면 보통 이렇게 구성된다.

- **Spring Boot 서버**: 비즈니스 로직을 처리
- **MySQL**: 데이터를 저장
- **Redis**: 캐시 및 세션 관리

이 3개를 따로따로 `docker run`으로 실행하면 엄청나게 복잡하다.

```bash
docker run -d --name mysql ...
docker run -d --name redis ...
docker run -d --name spring-server --link mysql --link redis ...
```

옵션도 많고, 컨테이너 간의 연결도 복잡하다. 여기서 **Docker Compose**가 등장한다.

## Docker Compose란

한 줄로 정의하면, "여러 개의 컨테이너를 YAML 파일 하나로 한 방에 관리하는 도구"다.

`docker-compose.yml`이라는 파일 하나에 서비스 정의를 다 적어놓고, `docker-compose up` 명령어 한 방이면 컨테이너들이 다 올라간다. 종료도 `docker-compose down` 한 방이다.

## Spring Boot + MySQL 예제

### 프로젝트 구조

```
my-project/
├── docker-compose.yml
├── Dockerfile
└── build/
    └── libs/
        └── myapp.jar
```

### docker-compose.yml 작성

```yaml
version: '3.8'

services:
  # MySQL 서비스
  mysql:
    image: mysql:8.0
    container_name: mysql-container
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: mydb
      MYSQL_USER: myuser
      MYSQL_PASSWORD: mypassword
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql

  # Spring Boot 서비스
  spring-server:
    build: .
    container_name: spring-server
    depends_on:
      - mysql
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/mydb
      SPRING_DATASOURCE_USERNAME: myuser
      SPRING_DATASOURCE_PASSWORD: mypassword
    ports:
      - "8080:8080"

volumes:
  mysql-data:
```

## 핵심 개념 설명

### services

각 컨테이너가 하나의 서비스다. 이 파일에서는 `mysql`과 `spring-server` 두 개의 서비스를 정의했다.

### depends_on

`spring-server`가 `mysql`에 의존한다는 의미다. 즉, MySQL 컨테이너가 먼저 실행되고, 그 다음에 Spring Boot 컨테이너가 실행된다.

### 네트워크 - DNS 자동 설정

여기서 마법이 일어난다. Docker Compose는 자동으로 **전용 네트워크(bridge)**를 만들고, 모든 서비스를 그 네트워크 안에 넣어준다.

그리고 가장 신기한 건, **서비스 이름이 곧 호스트 이름(Domain Name)**이 된다는 것이다.

```
jdbc:mysql://mysql:3306/mydb
            ^^^^^
         서비스 이름이 바로 호스트 이름!
```

보통 로컬에서 개발할 때는 `localhost`를 쓰지만, 도커 컨테이너 안에서는 `mysql`이라는 이름으로 MySQL 서버에 접속할 수 있다. 

이게 가능한 이유는 Docker Compose가 내부 DNS를 설정해주기 때문이다. 즉, 같은 네트워크 안에 있는 컨테이너끼리는 **서비스 이름만 알면 자동으로 찾아서 연결**된다.

### volumes - 데이터 영속성

```yaml
volumes:
  - mysql-data:/var/lib/mysql
```

컨테이너는 기본적으로 **휘발성**이다. 컨테이너를 삭제하면 안의 데이터도 다 날아간다.

MySQL 같은 데이터베이스는 데이터가 날아가면 안 되니까, **Volume**이라는 특별한 저장소를 만들어서 데이터를 호스트 컴퓨터에 보관한다.

컨테이너를 삭제해도 `mysql-data`라는 Volume은 남아있고, 나중에 다시 컨테이너를 실행하면 기존 데이터가 그대로 보인다.

## 실행 방법

### 실행하기

```bash
docker-compose up -d
```

- `-d`: 백그라운드 실행 (없으면 터미널에 로그가 쭉 뜬다)

### 종료하기

```bash
docker-compose down
```

컨테이너는 전부 삭제되지만, Volume은 남아있어서 데이터는 보존된다.

### 로그 확인

```bash
docker-compose logs -f spring-server
```

특정 서비스의 로그를 실시간으로 확인할 수 있다.

## 개발 환경 구성 팁

### 하이브리드 방식

로컬 개발 시 모든 걸 컨테이너에 넣지 않고, **애플리케이션 코드는 IDE에서 직접 실행**하고 **DB와 Redis만 Docker Compose로 띄우는** 방식이 편하다.

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: devdb

  redis:
    image: redis:7
    ports:
      - "6379:6379"
```

이렇게 설정하면 IDE에서 Spring Boot를 실행하면서 `localhost:3306`으로 MySQL에, `localhost:6379`로 Redis에 접근할 수 있다.

### Dev Containers

VSCode 등에서 제공하는 Dev Containers 기능을 사용하면 개발 환경 자체를 컨테이너로 만들 수 있다. `.devcontainer/devcontainer.json` 파일을 설정하면 된다.

## Docker Compose 요약

- 여러 컨테이너를 YAML 파일 하나로 관리
- 네트워크와 DNS를 자동으로 설정
- 서비스 이름으로 컨테이너 간 통신 가능
- Volume으로 데이터 영속성 보장
- 개발 환경 구성이 매우 간편

---

## 참고

- 공식 문서: https://docs.docker.com/compose/
