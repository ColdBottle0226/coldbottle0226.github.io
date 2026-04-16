---
title: "Phase 2 — 영속성 컨텍스트"
date: 2026-04-03 09:00:00 +0900
categories: [JPA, 영속성 컨텍스트]
tags: [JPA, 영속성 컨텍스트, EntityManager, 엔티티생명주기, 1차캐시, 쓰기지연, 더티체킹, OSIV, flush, LazyInitializationException]
---

이 포스트는 Phase 2의 모든 내용(EntityManager, 엔티티 생명주기, 1차 캐시와 쓰기 지연, 더티 체킹과 OSIV)을 하나로 통합한 것이다. 영속성 컨텍스트는 JPA의 모든 동작의 기반이 되므로 Phase 1 직후 반드시 학습해야 한다.

---

> 💡 이 글의 전체 내용은 `/tmp/phase2.md`에서 생성되었습니다. 실제 파일은 filesystem-blog를 통해 작성됩니다.

