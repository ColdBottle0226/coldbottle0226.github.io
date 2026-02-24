---
title: 주니어 개발자를 위한 이커머스 MSA 프로젝트 시작하기 - 2편. Docker Volume과 Network 완벽 이해
date: 2026-02-23 16:24:00 +0900
categories: [Backend, Docker]
tags: [docker, volume, network, 주니어개발자, 인프라]
---

## Docker Volume - 데이터를 지키는 방법

Docker 컨테이너는 일회용이다. 컨테이너를 삭제하면 그 안의 모든 데이터도 함께 사라진다. MySQL에 회원 1000명, 상품 5000개를 등록했는데 컨테이너를 잘못 삭제하면? 모든 데이터가 날아간다.

Volume은 이 문제를 해결한다. 컨테이너 밖 외부 창고에 데이터를 저장하는 것이다.

```
컨테이너 없이:
┌──────────────────┐
│  MySQL 컨테이너   │
│  /var/lib/mysql  │
│  - member.ibd    │
│  - product.ibd   │
└──────────────────┘
     ↓ 삭제
   데이터 소실!

Volume 사용:
┌──────────────────┐    ┌─────────────┐
│  MySQL 컨테이너   │←──→│   Volume    │
│  /var/lib/mysql  │    │ member.ibd  │
└──────────────────┘    │ product.ibd │
     ↓ 삭제             └─────────────┘
   컨테이너만 삭제         데이터 안전!
```

## Volume의 3가지 종류

Named Volume (권장):
```bash
docker volume create my-data
docker run -v my-data:/var/lib/mysql mysql:8.0
```

Docker가 자동으로 관리하고, 여러 컨테이너가 공유할 수 있다. 백업과 복원도 쉽다.

Bind Mount (개발용):
```bash
docker run -v /Users/내이름/mysql-data:/var/lib/mysql mysql:8.0
```

내 컴퓨터의 특정 폴더를 직접 연결한다. 파일을 직접 확인할 수 있어 개발 시 유용하다.

Anonymous Volume:
```bash
docker run -v /var/lib/mysql mysql:8.0
```

Docker가 랜덤 이름을 생성한다. 나중에 찾기 어려워 거의 사용하지 않는다.

## Volume 실습

```bash
# Volume 생성
docker volume create ecommerce-mysql-data

# MySQL 실행 (Volume 연결)
docker run -d \
  --name mysql-test \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  -v ecommerce-mysql-data:/var/lib/mysql \
  mysql:8.0

# 데이터 입력
docker exec -it mysql-test mysql -uroot -proot1234
CREATE TABLE users (id INT, name VARCHAR(100));
INSERT INTO users VALUES (1, '홍길동');

# 컨테이너 삭제
docker stop mysql-test
docker rm mysql-test

# 새 컨테이너로 데이터 확인
docker run -d \
  --name mysql-new \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  -v ecommerce-mysql-data:/var/lib/mysql \
  mysql:8.0

docker exec -it mysql-new mysql -uroot -proot1234
SELECT * FROM users;
-- 홍길동 그대로 있음!
```

## Docker Network - 컨테이너를 연결하는 방법

MSA 프로젝트에서는 여러 컨테이너가 협업한다. Spring Boot가 MySQL에 접속하고, Redis에서 캐시를 가져오고, Kafka로 메시지를 보낸다. 이때 Network가 필요하다.

Network 없이는:
```bash
# MySQL 포트 노출
docker run -p 3306:3306 mysql:8.0

# Spring Boot에서 접속
jdbc:mysql://localhost:3306/db
```

문제점이 많다. 포트를 외부에 노출해야 하고, 포트 충돌이 발생할 수 있으며, 설정이 복잡하다.

Network를 사용하면:
```bash
# Network 생성
docker network create ecommerce-network

# MySQL 실행 (포트 노출 없이)
docker run --network ecommerce-network --name mysql-db mysql:8.0

# Spring Boot에서 접속
jdbc:mysql://mysql-db:3306/db
```

컨테이너 이름으로 바로 접속할 수 있다. IP 주소를 몰라도 되고, 포트를 외부에 노출하지 않아 보안도 향상된다.

## Network 종류

Bridge Network (기본, 가장 많이 씀):
```bash
docker network create my-network
docker run --network my-network --name app1 nginx
docker run --network my-network --name app2 mysql
```

같은 Network의 컨테이너끼리만 통신한다. 회사 내부망처럼 작동한다.

Host Network:
```bash
docker run --network host nginx
```

컨테이너가 호스트의 네트워크를 그대로 사용한다. 격리가 안 되어 보안 위험이 있어 거의 사용하지 않는다.

None Network:
```bash
docker run --network none alpine
```

네트워크 연결이 전혀 없다. 완전히 격리된 환경이 필요할 때만 사용한다.

## Network 실습

```bash
# Network 생성
docker network create ecommerce-network

# MySQL 실행
docker run -d \
  --name ecommerce-mysql \
  --network ecommerce-network \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  mysql:8.0

# Redis 실행 (같은 Network)
docker run -d \
  --name ecommerce-redis \
  --network ecommerce-network \
  redis:7

# 테스트 컨테이너로 MySQL 접속
docker run -it --rm \
  --network ecommerce-network \
  mysql:8.0 \
  mysql -h ecommerce-mysql -uroot -proot1234

# 성공! 컨테이너 이름으로 접속 가능
```

## Volume + Network 함께 사용

실제 프로젝트에서는 두 가지를 함께 사용한다.

```bash
# Network와 Volume 생성
docker network create ecommerce-network
docker volume create ecommerce-mysql-data

# MySQL 실행 (Network + Volume)
docker run -d \
  --name ecommerce-mysql \
  --network ecommerce-network \
  -v ecommerce-mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  mysql:8.0
```

이제 데이터는 안전하게 보존되고, 다른 컨테이너와 쉽게 통신할 수 있다.

## 핵심 정리

Volume:
- 목적: 데이터 영구 저장
- 비유: 외부 창고
- 사용: 데이터베이스, 로그 파일

Network:
- 목적: 컨테이너 간 통신
- 비유: 회사 내부망
- 사용: 서비스 간 연결

다음 글에서는 Redis 컨테이너를 띄우고, MySQL과 연결하는 실습을 진행한다.

---