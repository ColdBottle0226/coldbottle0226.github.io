---
title: 주니어 개발자를 위한 이커머스 MSA 프로젝트 시작하기 - 3편. Redis Master-Replica 구성과 RDB/AOF 완벽 이해
date: 2026-02-23 17:08:00 +0900
categories: [Redis]
tags: [redis, master-replica, rdb, aof, 캐시, 주니어개발자]
---

## Redis란 무엇인가

Redis는 인메모리 데이터 저장소다. MySQL이 디스크에 데이터를 저장한다면, Redis는 RAM에 저장한다. RAM은 디스크보다 100배 이상 빠르다. 쿠팡에서 상품을 조회할 때 매번 MySQL에 접근하면 느리다. 자주 조회하는 상품 정보를 Redis에 캐싱하면 빠르게 응답할 수 있다.

이커머스 프로젝트에서 Redis의 역할:
- 세션 관리: 로그인 정보 (30분)
- 장바구니: 로그인 전 임시 저장 (30일)
- 캐시: 상품 정보 (10분), 전시 정보 (5분)
- 실시간 카운터: 재고, 조회수, 좋아요
- Rate Limiting: API 요청 제한

## RDB - 스냅샷 백업

RDB는 정해진 시간마다 Redis 메모리를 통째로 파일로 저장한다. 사진을 찍는 것과 같다.

```bash
save 900 1      # 15분 동안 1번 이상 변경
save 300 10     # 5분 동안 10번 이상 변경
save 60 10000   # 1분 동안 10,000번 이상 변경
```

조용한 새벽에는 15분마다 저장하고, 바쁜 점심시간에는 5분마다 저장한다. 블랙프라이데이처럼 매우 바쁠 때는 1분마다 저장한다. 상황에 맞게 자동으로 조절된다.

RDB 저장 과정 (BGSAVE):
1. 저장 조건 충족
2. Fork로 자식 프로세스 생성
3. 부모는 계속 서비스 제공, 자식은 파일 저장
4. COW (Copy-On-Write)로 메모리 효율적 사용
5. dump.rdb 파일 생성 (바이너리, 압축)

장점: 빠른 재시작, 작은 파일 크기, 쉬운 백업
단점: 마지막 저장 이후 데이터 손실 가능 (분 단위)

## AOF - 명령어 로그

AOF는 Redis에 들어온 모든 쓰기 명령어를 순서대로 기록한다. 일기장을 쓰는 것과 같다.

```bash
appendonly yes
appendfsync everysec  # 1초마다 디스크 동기화
```

동기화 정책 3가지:
- always: 매 명령어마다 저장 (안전하지만 느림)
- everysec: 1초마다 저장 (권장, 최대 1초 손실)
- no: OS에 맡김 (빠르지만 위험)

AOF 파일은 텍스트 형식이다. 명령어가 그대로 기록된다.

```
SELECT 0
SET member:1001 "홍길동"
SET product:2001 "노트북"
INCR view_count
```

Redis 재시작 시 이 명령어들을 순서대로 재실행하면 메모리 상태가 완벽하게 복원된다.

AOF Rewrite: 파일이 커지면 최적화한다. "INCR counter"를 1만 번 실행했다면, "SET counter 10000" 한 줄로 압축한다.

장점: 데이터 손실 최소화 (초 단위), 모든 명령어 기록
단점: 파일 크기 큼, 재시작 느림

권장 설정: RDB + AOF 둘 다 사용. AOF로 안전성 확보, RDB로 빠른 백업.

## Master-Replica 복제 구성

Redis 서버가 하나만 있으면 장애 시 서비스 중단이다. Master-Replica 구성으로 가용성을 높인다.

```
┌──────────────┐        ┌──────────────┐
│ Master       │───────→│ Replica      │
│ (쓰기/읽기)  │  복제  │ (읽기만)     │
│ port: 6379   │        │ port: 6380   │
└──────────────┘        └──────────────┘
```

Master에서 데이터를 쓰면 Replica에 실시간으로 복제된다. Master 장애 시 Replica를 Master로 수동 승격할 수 있다.

복제 과정:
1. 초기 연결: Replica가 Master에 연결 요청
2. Full Sync: Master가 RDB 생성 후 전송
3. Replica가 RDB 로드
4. 증분 동기화: 이후 변경분만 실시간 전송

네트워크 단절 시: Master는 Replication Backlog에 명령어 저장. 재연결 시 누락분만 전송하여 빠르게 복구.

## Redis 설정 파일 작성

redis.conf 파일로 Redis를 세밀하게 제어한다.

주요 설정:
```bash
# 네트워크
bind 0.0.0.0
port 6379

# 보안
requirepass ecommerce1234

# 메모리
maxmemory 512mb
maxmemory-policy allkeys-lru

# RDB
save 900 1
dbfilename dump.rdb
dir /data

# AOF
appendonly yes
appendfsync everysec

# 복제 (Replica만)
replicaof redis-master 6379
masterauth ecommerce1234
replica-read-only yes
```

주의사항: 인라인 주석 금지. 설정 값과 같은 줄에 주석을 쓰면 오류가 발생한다.

```bash
# ❌ 잘못된 방식
port 6379  # 포트 설정

# ✅ 올바른 방식
# 포트 설정
port 6379
```

## Docker Compose로 구성

```yaml
version: '3.8'
services:
  redis-master:
    image: redis:7-alpine
    volumes:
      - ./master/redis.conf:/usr/local/etc/redis/redis.conf
      - ./data/master:/data
    command: redis-server /usr/local/etc/redis/redis.conf
    ports:
      - "6379:6379"
    
  redis-replica:
    image: redis:7-alpine
    depends_on:
      - redis-master
    volumes:
      - ./replica/redis.conf:/usr/local/etc/redis/redis.conf
      - ./data/replica:/data
    command: redis-server /usr/local/etc/redis/redis.conf
    ports:
      - "6380:6379"
```

실행:
```bash
docker-compose up -d
docker exec -it redis-master redis-cli -a ecommerce1234 INFO replication
```

## 장애 복구 시나리오

Master 장애 발생:
```bash
# 1. Master 다운 확인
docker stop redis-master

# 2. Replica를 Master로 승격
docker exec -it redis-replica redis-cli -a ecommerce1234
REPLICAOF NO ONE

# 3. 애플리케이션 연결을 Replica로 변경
# redis.port=6380

# 4. Master 복구 후 Replica로 전환
docker start redis-master
docker exec -it redis-master redis-cli -a ecommerce1234
REPLICAOF redis-replica 6379
```

데이터는 모두 보존되고, 서비스는 계속 제공된다.

## 핵심 정리

RDB: 스냅샷, 빠른 복구, 분 단위 손실
AOF: 명령어 로그, 안전한 복구, 초 단위 손실
Master-Replica: 가용성 확보, 장애 대응

프로덕션 권장 설정:
- RDB + AOF 모두 활성화
- appendfsync everysec
- Master-Replica 구성
- 정기적인 백업

다음 글에서는 MongoDB 컨테이너를 구성하고, 로그와 비정형 데이터를 저장하는 방법을 다룬다.

---

