---
title: "[Querydsl] 순수 JPA와 Querydsl"
date: 2024-10-10T17:34:13+09:00
# weight: 1
# aliases: ["/first"]
tags: ["Querydsl"]
author: "yosong6729"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: true
disableHLJS: false # to disable highlightjs
disableShare: true
hideSummary: false
searchHidden: true
ShowReadingTime: false
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowWordCount: false
ShowRssButtonInSectionTermList: true
UseHugoToc: false
---

> 해당 글은 김영한님의 인프런 강의 [실전! Querydsl](https://www.inflearn.com/course/querydsl-%EC%8B%A4%EC%A0%84)을 듣고 내용을 정리하기 위한 것으로 자세한 설명은 해당 강의를 통해 확인할 수 있습니다.
> 

---

## 순수 JPA 리포지토리와 Querydsl

**순수 JPA 리포지토리**

```java
@Repository
public class MemberJpaRepository {

    private final EntityManager em;
    private final JPAQueryFactory queryFactory;

    public MemberJpaRepository(EntityManager em) {
        this.em = em;
        this.queryFactory = new JPAQueryFactory(em);
    }

    public void save(Member member) {
        em.persist(member);
    }

    public Optional<Member> findById(Long id) {
        Member findMember = em.find(Member.class, id);
        return Optional.ofNullable(findMember);
    }

    public List<Member> findAll() {
        return em.createQuery("select m From Member m", Member.class)
                .getResultList();
    }
    
    public List<Member> findByUsername(String username) {
        return em.createQuery("select m From Member m" +
                        " where m.username = :username", Member.class)
                .setParameter("username", username)
                .getResultList();
    }
 }
```

기본적인 member저장, 단건 조회, 모두 조회, username으로 조회를 JPA로 작성했다.

**순수 JPA 리포지토리 테스트**

```java
@SpringBootTest
@Transactional
class MemberJpaRepositoryTest {

    @Autowired
    EntityManager em;

    @Autowired
    MemberJpaRepository memberJpaRepository;

    @Test
    public void basicTest() {
        Member member = new Member("member1", 10);
        memberJpaRepository.save(member);

        Member findMember = memberJpaRepository.findById(member.getId()).get();

        assertThat(findMember).isEqualTo(member);

        List<Member> result1 = memberJpaRepository.findAll();
        assertThat(result1).containsExactly(member);

        List<Member> result2 = memberJpaRepository.findByUsername("member1");
        assertThat(result2).containsExactly(member);
    }
}
```

리포지토리에 작성한 순수 JPA를 테스트한 코드이고 이상없이 동작한다.

### Querydsl 사용

**순수 JPA 리포지토리 - Querydsl 추가**

```java
public List<Member> findAll_Querydsl() {
    return queryFactory
            .selectFrom(member)
            .fetch();
}

public List<Member> findByUsername_Querydsl(String username) {
        return queryFactory
                .selectFrom(member)
                .where(member.username.eq(username))
                .fetch();
}
```

member를 모두 조회하는것과 username으로 member를 조회하는 코드를 Querydsl로 작성해 보았다.

**Querydsl 테스트 추가**

```java
@Test
public void basicTest() {
    Member member = new Member("member1", 10);
    memberJpaRepository.save(member);

    Member findMember = memberJpaRepository.findById(member.getId()).get();

    assertThat(findMember).isEqualTo(member);

    List<Member> result1 = memberJpaRepository.findAll_Querydsl();
    assertThat(result1).containsExactly(member);

    List<Member> result2 = memberJpaRepository.findByUsername_Querydsl("member1");
    assertThat(result2).containsExactly(member);
}
```

리포지토리에 작성한 Querydsl 코드를 테스트 코드이고 문제없이 작동한다.

### JPAQueryFactory 스프링 빈 등록

다음과 같이 JPQQueryFactory를 스프링 빈으로 등록해서 주입받아 사용해도 된다.

```java
@Bean
JPAQueryFactory jpaQueryFactory(EntityManager em) {
        return new JPAQueryFactory(em);
}
```

> 동시성 문제는 걱정하지 않아도 된다. 왜냐하면 여기서 스프링이 주입해주는 엔티티 매니저는 실제 동작 시점에 진짜 엔티티 매니저를 찾아주는 프록시용 가짜 엔티티 매니저이다. 이 가짜 엔티티 매니저는 실제 사용 시점에 트랜잭션 단위로 실제 엔티티 매니저(영속성 컨텍스트)를 할당해준다.
더 자세한 내용은 자바 ORM 표준 JPA 책 13.1 트랜잭션 범위의 영속성 컨텍스트를 참고하자.
> 

---

## 동적 쿼리와 성능 최적화 조회 - Builder 사용

**MemberTeamDto - 조회 최적화용 DTO 추가**

```java
@Data
public class MemberTeamDto {

    private Long memberId;
    private String username;
    private int age;
    private Long teamId;
    private String teamName;

    @QueryProjection
    public MemberTeamDto(Long memberId, String username, int age, Long teamId, String teamName) {
        this.memberId = memberId;
        this.username = username;
        this.age = age;
        this.teamId = teamId;
        this.teamName = teamName;
    }
}
```

@QueryProjection을 추가했고 QMemberTeamDto를 생성하기위해서 ./gradlew complieJava를 실행해야한다.

> @QueryProjection을 사용하면 해당 DTO가 Querydsl을 의존하게 되는데 이런 의존이 싫으면 해당 에노테이션을 제거하고 Projection.bean(), fiedls(), constructor()을 사용하면 된다.
> 

**회원 검색 조건**

```java
@Data
public class MemberSearchCondition {
    //회원명, 팀명, 나이(ageGoe, ageLoe)
    private String username;
    private String teamName;
    private Integer ageGoe;
    private Integer ageLoe;
}
```

### 동적쿼리 - Builder 사용

**Builder를 사용한 예제**

```java
public List<MemberTeamDto> searchByBuilder(MemberSearchCondition condition) {
    BooleanBuilder builder = new BooleanBuilder();

    if (hasText(condition.getUsername())) {
        builder.and(member.username.eq(condition.getUsername()));
    }

    if (hasText(condition.getTeamName())) {
        builder.and(team.name.eq(condition.getTeamName()));
    }

    if (condition.getAgeGoe() != null) {
        builder.and(member.age.goe(condition.getAgeGoe()));
    }

    if (condition.getAgeLoe() != null) {
        builder.and(member.age.loe(condition.getAgeLoe()));
    }

    return queryFactory
            .select(new QMemberTeamDto(
                    member.id,
                    member.username,
                    member.age,
                    team.id,
                    team.name
            ))
            .from(member)
            .leftJoin(member.team, team)
            .where(builder)
            .fetch();
}
```

Builder를 사용하고 회원 명, 팀명, 나이 조건을 동적으로 추가해서 Querydsl을 작성한다.

**조회 예제 테스트**

```java
@Test
public void searchTest() {
    Team teamA = new Team("teamA");
    Team teamB = new Team("teamB");
    em.persist(teamA);
    em.persist(teamB);

    Member member1 = new Member("member1", 10, teamA);
    Member member2 = new Member("member2", 20, teamA);

    Member member3 = new Member("member3", 30, teamB);
    Member member4 = new Member("member4", 40, teamB);

    em.persist(member1);
    em.persist(member2);
    em.persist(member3);
    em.persist(member4);

    MemberSearchCondition condition = new MemberSearchCondition();
    condition.setAgeGoe(35);
    condition.setAgeLoe(40);
    condition.setTeamName("teamB");

    List<MemberTeamDto> result = memberJpaRepository.searchByBuilder(condition);

    assertThat(result).extracting("username").containsExactly("member4");
}
```

username의 조건은 없고, 나이는 35이상, 40 이하로 했고 팀명은 teamB로 테스트한 결과 member4가 나오고 올바르게 동작한것을 확인했다.

쿼리 결과를 보면 where절에 username의 조건은 없고 팀명과 나이의 조건이 들어간것을 확인할수 있다.

![image.png](images/image.png)

---

## 동적 쿼리와 성능 최적화 조회 - Where절 파라미터 사용

**Where절에 파라미터를 사용한 예제**

```java
public List<MemberTeamDto> search(MemberSearchCondition condition) {
    return queryFactory
            .select(new QMemberTeamDto(
                    member.id,
                    member.username,
                    member.age,
                    team.id,
                    team.name
            ))
            .from(member)
            .leftJoin(member.team, team)
            .where(
                    usernameEq(condition.getUsername()),
                    teamNameEq(condition.getTeamName()),
                    ageGoe(condition.getAgeGoe()),
                    ageLoe(condition.getAgeLoe())
            )
            .fetch();
}

private BooleanExpression usernameEq(String username) {
    return hasText(username) ? member.username.eq(username) : null;
}

private BooleanExpression teamNameEq(String teamName) {
    return hasText(teamName) ? team.name.eq(teamName) : null;

}

private BooleanExpression ageGoe(Integer ageGoe) {
    return ageGoe != null ? member.age.goe(ageGoe) : null;
}

private BooleanExpression ageLoe(Integer ageLoe) {
    return ageLoe != null ? member.age.loe(ageLoe) : null;
}
```

where 절에 들어가는 타입은 Predicate도 가능하지만 나중에 조합이 가능하게 하려면 BooleanExpression으로 해야하기때문에 BooleanExpression으로 해주는것이 좋다.

**where 절에 파라미터 방식을 사용하면 조건 재사용 가능**

다음과 같이 where절에 파라미터 방식을 사용하면 재사용이 가능하다.

```java
public List<Member> findMember(MemberSearchCondition condition) {
        return queryFactory
                .selectFrom(member)
                .leftJoin(member.team, team)
                .where(usernameEq(condition.getUsername()),
                                teamNameEq(condition.getTeamName()),
                                ageGoe(condition.getAgeGoe()),
                                ageLoe(condition.getAgeLoe()))
                .fetch();
}
```

---

## 조회 API 컨트롤러 개발

이후에 편리한 데이터 확인을 위해서 샘플 데이터를 추가하고 테스트 케이스 실행에 영향을 주지 않도록 다음과 같이 프로파일을 설정한다.

**프로파일 설정**

src/main/resources/application.properties

```yaml
spring.profiles.active=local
```

테스트트 기존 applicaiton.properties를 복사해서 다음 경로로 복사하고, 프로파일을 test로 수정

src/test/resources/application.properties

```yaml
spring.profiles.active=test
```

위 처럼 분리하면 main 소스코드와 테스트 소스 코드 실행시 프로파일을 분리할 수 있다.

**샘플 데이터 추가**

```java
@Profile("local")
@Component
@RequiredArgsConstructor
public class InitMember {

    private final InitMemberService initMemberService;

    @PostConstruct
    public void init() {
        initMemberService.init();
    }

    @Component
    static class InitMemberService {
        @PersistenceContext
        private EntityManager em;

        @Transactional
        public void init() {
            Team teamA = new Team("teamA");
            Team teamB = new Team("teamB");
            em.persist(teamA);
            em.persist(teamB);

            for (int i = 0; i < 100; i++) {
                Team selectedTeam = i % 2 == 0 ? teamA : teamB;
                em.persist(new Member("member" + i, i, selectedTeam));
            }
        }
    }
}
```

InitMember.init() 메서드 안에 InitMemberService.init() 메서드의 내용을 그대로 작성하면 안되는지 궁금증이 생길수 있는데 스프링 라이프 사이클 때문에 @PostConstruct, @Transaction을 분리해야하기때문에 위 처럼 분리해줘야 한다.

**조회 컨트롤러**

```java
@RestController
@RequiredArgsConstructor
public class MemberController {

    private final MemberJpaRepository memberJpaRepository;

    @GetMapping("/v1/members")
    public List<MemberTeamDto> searchMemberV1(MemberSearchCondition condition) {
        return memberJpaRepository.search(condition);
    }
}
```

스프링 서버 시작시 local인지 test인지 다음과 같이 확인이 가능하다.

![image.png](images/image%201.png)

postman으로 http://localhost:8080/v1/members?teamName=teamB&ageGoe=31&ageLoe=35 로 실행시 다음과 같이 올바르게 결과가 나오는 것을 확인할수 있다.

![image.png](images/image%202.png)

쿼리 결과도 다음과 같이 팀명과 나이 조건이 들어간것을 확인할수 있다.

![image.png](images/image%203.png)
