---
title: "Docker Swarm으로 클러스터 구축하기 - 단일 서버에서 오케스트레이션까지"
date: 2026-02-12 04:00:00 +0900
categories: [DevOps, Docker]
tags: [docker, docker-swarm, orchestration, cluster, high-availability]
---

## Docker Compose의 한계

지금까지 배운 Docker Compose는 개발 환경이나 소규모 운영 환경에서는 완벽하다. 하지만 프로젝트가 커지면 문제가 생긴다.

### 단일 장애점 (SPOF: Single Point of Failure)

Compose는 기본적으로 **한 대의 서버**에서만 돌아간다. 이 서버가 죽으면 서비스가 통째로 멈춘다.

### 확장성 한계

서버 한 대로 감당할 수 있는 처리량에는 한계가 있다. 사용자가 폭발적으로 늘어나면 컨테이너를 여러 개 띄워야 하는데, 한 대의 서버에서는 리소스가 부족하다.

### 무중단 배포 어려움

컨테이너를 재시작하는 동안은 서비스가 일시적으로 멈춘다. 사용자가 많은 서비스에서는 치명적이다.

이런 문제를 해결하기 위해 **Docker Swarm**이 등장했다.

## Docker Swarm이란

Docker Swarm은 여러 대의 서버(호스트)를 하나의 클러스터로 묶어서 관리하는 **오케스트레이션 도구**다. Kubernetes와 비슷한 역할을 하지만, 설정이 훨씬 간단하다.

### 핵심 개념

**클러스터(Cluster)**: 여러 대의 서버를 하나의 논리적인 단위로 묶은 것

**노드(Node)**: 클러스터를 구성하는 각각의 서버
- **Manager Node**: 클러스터를 제어하는 관리자 역할
- **Worker Node**: 실제로 컨테이너를 실행하는 일꾼 역할

**서비스(Service)**: Compose의 "서비스"와 비슷하지만, 여러 노드에 걸쳐 컨테이너를 분산 실행할 수 있다

**레플리카(Replica)**: 동일한 컨테이너를 여러 개 띄운 것

## 아키텍처

```
┌───────────────────────────────────────────────┐
│              Manager Node (리더)               │
│  - 클러스터 전체 상태 관리                       │
│  - 스케줄링 (어느 노드에 컨테이너 띄울지 결정)    │
└───────────────────────────────────────────────┘
                     │
    ┌────────────────┼────────────────┐
    ↓                ↓                ↓
┌──────────┐    ┌──────────┐    ┌──────────┐
│ Worker 1 │    │ Worker 2 │    │ Worker 3 │
│  ▢ ▢ ▢   │    │  ▢ ▢ ▢   │    │  ▢ ▢ ▢   │
└──────────┘    └──────────┘    └──────────┘
   컨테이너         컨테이너         컨테이너
```

## Swarm 클러스터 구성

### 1. Swarm 초기화 (Manager Node)

```bash
docker swarm init --advertise-addr 192.168.0.10
```

이 명령어를 실행하면 현재 서버가 Manager Node가 되고, 클러스터가 생성된다. 그리고 Worker Node를 추가하기 위한 **토큰(join token)**이 출력된다.

```
Swarm initialized: current node (abc123...) is now a manager.

To add a worker to this swarm, run the following command:
    docker swarm join --token SWMTKN-1-xxx... 192.168.0.10:2377
```

### 2. Worker Node 추가

다른 서버에서 위에서 받은 명령어를 실행한다.

```bash
docker swarm join --token SWMTKN-1-xxx... 192.168.0.10:2377
```

### 3. 노드 목록 확인

```bash
docker node ls
```

```
ID              HOSTNAME    STATUS  AVAILABILITY  MANAGER STATUS
abc123*         manager1    Ready   Active        Leader
def456          worker1     Ready   Active        
ghi789          worker2     Ready   Active        
```

## 서비스 배포

### 기본 서비스 생성

```bash
docker service create \
  --name web-server \
  --replicas 3 \
  -p 80:8080 \
  my-repo/spring-server:latest
```

- `--replicas 3`: 동일한 컨테이너를 3개 띄운다
- `-p 80:8080`: 외부 80번 포트를 내부 8080번과 연결

Swarm은 자동으로 3개의 컨테이너를 **서로 다른 노드에 분산**해서 배포한다.

### 서비스 상태 확인

```bash
docker service ps web-server
```

```
ID      NAME          NODE      DESIRED STATE  CURRENT STATE
1       web-server.1  worker1   Running        Running 2 minutes
2       web-server.2  worker2   Running        Running 2 minutes
3       web-server.3  manager1  Running        Running 2 minutes
```

### 서비스 스케일링

사용자가 갑자기 늘어나서 컨테이너를 더 띄워야 한다면?

```bash
docker service scale web-server=5
```

명령어 하나로 컨테이너가 3개에서 5개로 늘어난다. Swarm이 알아서 적절한 노드에 배포한다.

## Docker Stack - Compose for Swarm

Swarm에서도 Compose와 비슷하게 YAML 파일로 서비스를 정의할 수 있다.

### docker-compose-stack.yml

```yaml
version: '3.8'

services:
  web:
    image: my-repo/spring-server:latest
    ports:
      - "80:8080"
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1
        delay: 10s
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://db:3306/mydb

  db:
    image: mysql:8.0
    volumes:
      - db-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

volumes:
  db-data:
```

### deploy 섹션

Swarm 전용 설정이다.

**replicas**: 컨테이너 개수

**restart_policy**: 컨테이너가 죽으면 자동으로 재시작

**update_config**: 무중단 배포 설정
- `parallelism: 1`: 한 번에 1개씩 업데이트
- `delay: 10s`: 다음 업데이트까지 10초 대기

**placement**: 특정 노드에만 배포
- MySQL은 Manager Node에만 배포하도록 제한 (데이터 관리를 위해)

### 스택 배포

```bash
docker stack deploy -c docker-compose-stack.yml my-app
```

### 스택 제거

```bash
docker stack rm my-app
```

## 자동 복구 (Self-Healing)

Swarm의 가장 강력한 기능이다.

만약 Worker1 서버가 죽으면?
- Worker1에 있던 컨테이너들을 Swarm이 자동으로 감지
- 살아있는 다른 노드(Worker2, Manager)에 컨테이너를 다시 생성
- 서비스는 계속 유지됨

사용자는 서버 한 대가 죽었다는 사실조차 모를 수 있다!

## Docker Compose vs Docker Swarm

| 항목 | Docker Compose | Docker Swarm |
|------|----------------|--------------|
| 서버 대수 | 1대 | 여러 대 |
| 고가용성 | X | O |
| 자동 복구 | X | O (Self-Healing) |
| 스케일링 | 수동 | 자동/수동 |
| 무중단 배포 | 어려움 | 쉬움 |
| 학습 곡선 | 쉬움 | 중간 |

## 언제 Swarm을 써야 할까?

**Compose로 충분한 경우**
- 개발 환경
- 소규모 내부 서비스
- 서버 1대로 충분한 트래픽

**Swarm이 필요한 경우**
- 운영 환경
- 높은 가용성이 필요한 서비스
- 무중단 배포가 필요한 경우
- 여러 서버에 부하를 분산해야 하는 경우

---

## 참고

- 공식 문서: https://docs.docker.com/engine/swarm/
