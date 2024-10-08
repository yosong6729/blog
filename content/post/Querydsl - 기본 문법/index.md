---
title: "[Querydsl]기본 문법"
date: 2024-10-07T22:17:33+09:00
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

예제 도메인 모델을 엔티티 클래스와 ERD만 확인하고 넘어가겠다.

![image.png](images/image.png)

---

## JPQL vs Querydsl

**테스트 기본 코드**

```java
@SpringBootTest
@Transactional
public class QuerydslBasicTest {

    @PersistenceContext
    EntityManager em;
    
    @BeforeEach
    public void before() {
        queryFactory = new JPAQueryFactory(em);
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
    }
}
```

@BeforeEach로 각 테스트 실행전에 데이터를 세팅한다.

**Querydsl vs JPQL**

```java
@Test
public void startJPQL() {
    String qlString =
            "select m from Member m" +
            " where m.username =: username";
    Member findMember = em.createQuery(qlString, Member.class)
            .setParameter("username", "member1")
            .getSingleResult();

    assertThat(findMember.getUsername()).isEqualTo("member1");
}

    @Test
    public void startQuerydsl() {
          JPAQueryFactory queryFactory = new JPAQueryFactory(em);
        QMember m = new QMember("m");

        Member findMember = queryFactory
                .select(m)
                .from(m)
                .where(m.username.eq("member1"))
                .fetchOne();

        assertThat(findMember.getUsername()).isEqualTo("member1");
    }
```

- EntityManger로 JPAQueryFactory를 생성한다.
- QMember m = new QMember(”m”);의 “m”은 어떤 QMember인지 구분하기 위한 것이다.
- Querydsl은 JPQL 빌더이다.
- JPQL은 문자이기때문에 실행시점에 오류가 발생하지만, Querydsl은 자바 코드이기때문에 컴파일 시점에 오류가 발생한다.
- JPQL은 파라미터 바인딩을 직접 하지만, Querydsl은 파라미터 바인딩을 자동처리가 된다.

### JPAQueryFactory를 필드로

```java
@SpringBootTest
@Transactional
public class QuerydslBasicTest {

    @PersistenceContext
    EntityManager em;

    JPAQueryFactory queryFactory;

    @BeforeEach
    public void before() {
        queryFactory = new JPAQueryFactory(em);
        //...
    }
    
     @Test
    public void startQuerydsl() {
        QMember m = new QMember("m");

        Member findMember = queryFactory
                .select(m)
                .from(m)
                .where(m.username.eq("member1"))
                .fetchOne();

        assertThat(findMember.getUsername()).isEqualTo("member1");
    }
}
```

> JPAQueryFactory를 필드로 제공하면 동시성 문제는 JPAQueryFactory를 생성할때 제공하는 EntityManager(em)에 달려있다. 스프링 프레임워크는 여러 쓰레드에서 동시에 같은 EntityManager에 접근해도, **트랜잭션 마다 별도의 영속성 컨텍스트를 제공**하기 때문에, 동시성 문제는 걱정하지 않아도 된다.
> 

---

## 기본 Q-Type 활용

**Q클래스 인스턴스를 사용하는 2가지 방법**

```java
QMember qMember = new QMember("m"); //별칭 직접 지정
QMember qMember = QMember.member; //기본 인스턴스 사용
```

**기본 인스턴스를 static import와 함께 사용하기**

```java
import static study.querydsl.entity.QMember.*;

@Test
public void startQuerydsl() {
    Member findMember = queryFactory
            .select(member)
            .from(member)
            .where(member.username.eq("member1"))
            .fetchOne();

    assertThat(findMember.getUsername()).isEqualTo("member1");
}
```

기본 인스턴스와 static import를 함께사용하면 코드를 간략화 할수 있다.

다음 설정을 추가하면 실행되는 JPQL을 볼수 있다.

```yaml
spring.jpa.properties.hibernate.use_sql_comments: true
```

테스트 코드를 실행하면 다음과 같이 /* ~~ */로 표시되는 JPQL을 확인할수 있고, 이후에 SQL문을 확인 할수 있다.

![image.png](images/image%201.png)

위 JPQL코드에서 from Member member1의 “member1”은 Qmember 클래스안에 다음과 같이 정의된 것으로 나오게된다.

![image.png](images/image%202.png)

> 같은 테이블을 조인해야 하는 경우가 아니면 기본 인스턴스를 사용하자
> 

---

## 검색 조건 쿼리

**기본 검색 쿼리**

```java
@Test
public void search() {
    Member findMember = queryFactory
            .selectFrom(member)
            .where(member.username.eq("member1")
                    .and(member.age.eq(10)))
            .fetchOne();

    assertThat(findMember.getUsername()).isEqualTo("member1");
}
```

쿼리 결과로 and 조건이 붙은걸 확인 할수 있다.

![image.png](images/image%203.png)

검색 조건은 .and(), or()를 메서드 체인으로 연결할수 있다. select, from을 selectFrom으로 합칠 수 있다.

### JPQL이 제공하는 모든 검색 조건 제공

```java
member.username.eq("member1") // username = 'member1'
member.username.ne("member1") //username != 'member1'
member.username.eq("member1").not() // username != 'member1'

member.username.isNotNull() //이름이 is not null

member.age.in(10, 20) // age in (10,20)
member.age.notIn(10, 20) // age not in (10, 20)
member.age.between(10,30) //between 10, 30

member.age.goe(30) // age >= 30
member.age.gt(30) // age > 30
member.age.loe(30) // age <= 30
member.age.lt(30) // age < 30

member.username.like("member%") //like 검색
member.username.contains("member") // like ‘%member%’ 검색 
member.username.startsWith("member") //like ‘member%’ 검색
```

### AND 조건을 파라미터로 처리

```java
@Test
public void searchAndParam() {
    Member findMember = queryFactory
            .selectFrom(member)
            .where(
                    member.username.eq("member1"),
                    member.age.eq(10))
            .fetchOne();

    assertThat(findMember.getUsername()).isEqualTo("member1");
}
```

where()에 파라미터로 검색 조건을 추가하면 AND 조건이 추가된다.

파라미터 검색 조건으로 null이 오면 null 값을 무시하기떄문에 메서드 추출을 활용해서 동적 쿼리를 만들수 있다.

쿼리 결과로 and 조건이 추가된것을 확인 할수 있다.

![image.png](images/image%204.png)

---

## 결과 조회

- fetch(): 리스트 조회, 데이터 없으면 빈 리스트 반환
- fetchOne(): 단 건 조회
    - 결과가 없으면: null
    - 결과가 둘 이상이면: com.querydsl.core.NonUniqueResultException 예외 발생
- fetchFirst(): limit(1).fetchOne()
- fetchResults(): 페이징 정보 포함, total count 쿼리 추가 실행
- fetchCount(): count 쿼리로 변경해서 count 수 조회

```java
@Test
public void resultFetch() {
        //List
    List<Member> fetch = queryFactory
            .selectFrom(member)
            .fetch();
        
        //단 건 조회
    Member fetchOne = queryFactory
            .selectFrom(member)
            .fetchOne();
        
        //처음 한 건 조회
    Member fetchFirst = queryFactory
            .selectFrom(member)
            .fetchFirst();
        
        //페이징에서 사용
    QueryResults<Member> results = queryFactory
            .selectFrom(member)
            .fetchResults();

//        results.getTotal();
//        List<Member> content = results.getResults();
        
        //count 쿼리로 변경
    long count = queryFactory
            .selectFrom(member)
            .fetchCount();
}
```

fetchResults()는 totalCout의 값을 가져와야해서 다음과 같이 쿼리가 총 2번 실행 된다.

![image.png](images/image%205.png)

![image.png](images/image%206.png)

---

## 정렬

회원 정렬 순서

1. 회원 나이 내림차순(desc)
2. 회원 이름 올림차순(asc)

단 2에서 회원 이름이 없으면 마지막에 출력(nulls last)

```java
@Test
public void sort() {
    em.persist(new Member(null, 100));
    em.persist(new Member("member5", 100));
    em.persist(new Member("member6", 100));

    List<Member> result = queryFactory
            .selectFrom(member)
            .where(member.age.eq(100))
            .orderBy(member.age.desc(), member.username.asc().nullsLast())
            .fetch();

    Member member5 = result.get(0);
    Member member6 = result.get(1);
    Member memberNull = result.get(2);
    assertThat(member5.getUsername()).isEqualTo("member5");
    assertThat(member6.getUsername()).isEqualTo("member6");
    assertThat(memberNull.getUsername()).isNull();
}
```

- 일반 정렬
    - desc(): 내림차순, asc(): 올림차순
- null 데이터 순서 부여
    - nullsLast(): null 마지막, nullsFirst(): null 처음

---

## 페이징

**조회 건수 제한**

```java
@Test
public void paging1() {
    List<Member> result = queryFactory
            .selectFrom(member)
            .orderBy(member.username.desc())
            .offset(1)
            .limit(2)
            .fetch();

    assertThat(result.size()).isEqualTo(2);

}
```

- offset(1): 0부터 시작이고 offset을 1로 설정
- limit(2): 최대 2건 조회

**전체 조회 수가 필요하면?**

```java
@Test
public void paging2() {
    QueryResults<Member> queryResults = queryFactory
            .selectFrom(member)
            .orderBy(member.username.desc())
            .offset(1)
            .limit(2)
            .fetchResults();

    assertThat(queryResults.getTotal()).isEqualTo(4);
    assertThat(queryResults.getLimit()).isEqualTo(2);
    assertThat(queryResults.getOffset()).isEqualTo(1);
    assertThat(queryResults.getResults().size()).isEqualTo(2);

}
```

> 실무에서 페이징 쿼리를 작성할 때, 데이터를 조회하는 쿼리는 여러 테이블을 조인해야 하지만, count 쿼리는 조인이 필요 없는 경우도 있다. 그런데 이렇게 자동화된 count 쿼리는 원본 쿼리와 같이 모두 조인을 해버리기 때문에 성능이 안나올 수 있다. count 쿼리에 조인이 필요없는 성능 최적화가 필요하다면, count 전용 쿼리를 별도로 작성해야 한다.
> 

---

## 집합

### 집합 함수

회원수, 나이 합, 평균 나이, 최대 나이, 최소 나이를 구해보자

```java
@Test
public void aggregation() {
    List<Tuple> result = queryFactory
            .select(
                    member.count(),
                    member.age.sum(),
                    member.age.avg(),
                    member.age.max(),
                    member.age.min()
            )
            .from(member)
            .fetch();

    Tuple tuple = result.get(0);
    assertThat(tuple.get(member.count())).isEqualTo(4);
    assertThat(tuple.get(member.age.sum())).isEqualTo(100);
    assertThat(tuple.get(member.age.avg())).isEqualTo(25);
    assertThat(tuple.get(member.age.max())).isEqualTo(40);
    assertThat(tuple.get(member.age.min())).isEqualTo(10);

}
```

JPQL이 제공하는 모든 집합 함수를 제공한다.

쿼리 결과는 다음과 같이 작성된다.

![image.png](images/image%207.png)

실무에서는 튜플많이 쓰지 않고 DTO를 사용하는 방법을 많이 사용한다.

### GroupBy 사용

팀의 이름과 각 팀의 평균 연령을 구해보자

```java
@Test
public void group() throws Exception{
    List<Tuple> result = queryFactory
            .select(
                    team.name,
                    member.age.avg()
            )
            .from(member)
            .join(member.team, team)
            .groupBy(team.name)
            .fetch();

    Tuple teamA = result.get(0);
    Tuple teamB = result.get(1);

    assertThat(teamA.get(team.name)).isEqualTo("teamA");
    assertThat(teamA.get(member.age.avg())).isEqualTo(15);

    assertThat(teamB.get(team.name)).isEqualTo("teamB");
    assertThat(teamB.get(member.age.avg())).isEqualTo(35);

}
```

쿼리 결과는 다음과 같이 나온다.

![image.png](images/image%208.png)

**groupBy(), having() 예시**

```java
…
        .groupBy(item.price)
        .having(item.price.gt(1000))
...
```

---

## 조인 - 기본 조인

### 기본 조인

조인의 기본 문법은 첫 번째 파라미터에 조인 대상을 지정하고, 두 번째 파라미터에 별칭(alias)으로 사용할 Q 타입을 지정하면 된다.

```java
join(조인 대상, 별칭으로 사용할 Q타입)
```

**기본 조인**

팀 A에 소속된 모드 회원을 조회 해보자

```java
@Test
public void join() {
    List<Member> result = queryFactory
            .selectFrom(member)
            .join(member.team, team)
            .where(team.name.eq("teamA"))
            .fetch();

    assertThat(result)
            .extracting("username")
            .containsExactly("member1", "member2");
}
```

- join(), innerJoin(): 내부 조인
- leftJoin(): left 외부 조인
- rightJoin(): right 외부 조인

쿼리 결과를 보면 조인이 되는것을 확이할 수 있다.

![image.png](images/image%209.png)

### 세타 조인

세타 조인은 연관관계가 없는 필드로 조인하는 것이다.

회원의 이름이 팀 이름과 같은 회원을 조회 해보자

```java
@Test
public void theta_join() {
    em.persist(new Member("teamA"));
    em.persist(new Member("teamB"));
    em.persist(new Member("teamC"));

    List<Member> result = queryFactory
            .select(member)
            .from(member, team)
            .where(member.username.eq(team.name))
            .fetch();

    assertThat(result)
            .extracting("username")
            .containsExactly("teamA", "teamB");

}
```

- from 절에 여러 엔티티를 선택해서 세타 조인을 할수있다.
- 조인 on을 사용하면 외부 조인이 가능하다.

쿼리 결과에서 세타 조인이 되는 것을 확인 할수 있다.

![image.png](images/image%2010.png)

---

## 조인 - on절

### 조인 대상 필터링

회원과 팀을 조인하면서, 팀 이름이 teamA인 팀만 조인하고 회원은 모두 조회해보자.

```java
@Test
public void join_on_filtering() {
    List<Tuple> result = queryFactory
            .select(member, team)
            .from(member)
            .leftJoin(member.team, team).on(team.name.eq("teamA"))
            .fetch();

    for (Tuple tuple : result) {
        System.out.println("tuple = " + tuple);
    }
}
```

쿼리 결과와 result는 다음과 같다.

![image.png](images/image%2011.png)

```
t=[Member(id=3, username=member1, age=10), Team(id=1, name=teamA)]
t=[Member(id=4, username=member2, age=20), Team(id=1, name=teamA)]
t=[Member(id=5, username=member3, age=30), null]
t=[Member(id=6, username=member4, age=40), null]
```

> on 절을 활용해 조인 대상을 필터링 할 때, 외부조인이 아니라 내부조인(inner join)을 사용하면, where 절에서 필터링 하는 것과 기능이 동일하다. 따라서 on 절을 활용한 조인 대상 필터링을 사용할 때, 내부조인 이면 익숙한 where 절로 해결하고, 정말 외부조인이 필요한 경우에만 이 기능을 사용하자.
> 

**내부조인을 사용하고 where절에서 필터링**

```java
@Test
public void join_on_filtering() {
    List<Tuple> result = queryFactory
            .select(member, team)
            .from(member)
            .join(member.team, team)
            .where(team.name.eq("teamA"))
//                .leftJoin(member.team, team).on(team.name.eq("teamA"))
            .fetch();

    for (Tuple tuple : result) {
        System.out.println("tuple = " + tuple);
    }
}
```

이전거와 동일한 결과이다.

### 연관관계 없는 엔티티 외부 조인

회원의 이름과 팀의 이름이 같은 대상을 외부 조인 해보자.

```java
@Test
public void join_on_no_relation() {
    em.persist(new Member("teamA"));
    em.persist(new Member("teamB"));
    em.persist(new Member("teamC"));

    List<Tuple> result = queryFactory
            .select(member, team)
            .from(member)
            .leftJoin(team).on(member.username.eq(team.name))
            .fetch();

    for (Tuple tuple : result) {
        System.out.println("tuple = " + tuple);
    }
}
```

- 연관관계 없는 외부 조인은 일반 조인과 문법이 다르다. leftJoin() 부분에 일반 조인과 다르게 엔티티 하나만 들어간다.
    - 일반조인: leftJoin(member.team, team)
    - on조인: from(member).leftJoin(team).on(xxx)

**쿼리 결과와 result**

![image.png](images/image%2012.png)

```
t=[Member(id=3, username=member1, age=10), null]
t=[Member(id=4, username=member2, age=20), null]
t=[Member(id=5, username=member3, age=30), null]
t=[Member(id=6, username=member4, age=40), null]
t=[Member(id=7, username=teamA, age=0), Team(id=1, name=teamA)]
t=[Member(id=8, username=teamB, age=0), Team(id=2, name=teamB)]
```

---

## 조인 - 페치 조인

**페치 조인 미적용**

지연로딩으로 Member SQL 쿼리만 실행된다.

```java
@PersistenceUnit
EntityManagerFactory emf;

@Test
public void fetchJoinNo() {
    em.flush();
    em.clear();

    Member findMember = queryFactory
            .selectFrom(member)
            .where(member.username.eq("member1"))
            .fetchOne();

    boolean loaded = emf.getPersistenceUnitUtil().isLoaded(findMember.getTeam());
    assertThat(loaded).as("페치 조인 미적용").isFalse();

}
```

EntityManagerFactory.getPersistenceUnitUtil().isLoaded()로 이미 초기화가 된 엔티티인지 아닌지 알수있다.

**쿼리 결과**

![image.png](images/image%2013.png)

페치 조인 적용 전에는 member만 조회하는것을 알수 있다.

**페치 조인 적용**

즉시로딩으로 Members, Team SQL 쿼리 조인으로 한번에 조회한다.

```java
@Test
public void fetchJoinUse() {
    em.flush();
    em.clear();

    Member findMember = queryFactory
            .selectFrom(member)
            .join(member.team, team).fetchJoin()
            .where(member.username.eq("member1"))
            .fetchOne();

    boolean loaded = emf.getPersistenceUnitUtil().isLoaded(findMember.getTeam());
    assertThat(loaded).as("페치 조인 미적용").isTrue();

}
```

join(), leftJoin()등 조인 기능 뒤에 fetchJoin()을 추가하면 된다.

쿼리 결과로 페치 조인이 잘 적용된것을 확인할수 있다.

![image.png](images/image%2014.png)

---

## 서브 쿼리

서브 쿼리를 사용하기 위해서  com.querydsl.jpa.JPAExpressions을사용한다.

**서브 쿼리 eq 사용**

나이가 가장 많은 회원을 조회 해보자.

```java
@Test
public void subQuery() {

    QMember memberSub = new QMember("memberSub");

    List<Member> result = queryFactory
            .selectFrom(member)
            .where(member.age.eq(
                                JPAExpressions
                            .select(memberSub.age.max())
                            .from(memberSub)
            ))
            .fetch();

    assertThat(result).extracting("age")
            .containsExactly(40);
}
```

서브 쿼리에 중복되는 alias를 가진 Qtype을 사용하면 안되기때문에 Qtype을 새로 생성해준다.

쿼리 결과를 보면 where절에 서브 쿼리가 적용된것을 확인할수 있다.

![image.png](images/image%2015.png)

**서브 쿼리 goe 사용**

```java
@Test
public void subQueryGoe() {

    QMember memberSub = new QMember("memberSub");

    List<Member> result = queryFactory
            .selectFrom(member)
            .where(member.age.goe(
                            JPAExpressions
                                    .select(memberSub.age.avg())
                            .from(memberSub)
            ))
            .fetch();

    assertThat(result).extracting("age")
            .containsExactly(30, 40);
}
```

쿼리 결과에서 where절에 ≥의 서브 쿼리가 적용된것을 확인할 수 있다.

![image.png](images/image%2016.png)

**서브쿼리 여러 건 처리 in 사용**

```java
@Test
public void subQueryIn() {

    QMember memberSub = new QMember("memberSub");

    List<Member> result = queryFactory
            .selectFrom(member)
            .where(member.age.in(
                            JPAExpressions
                                    .select(memberSub.age)
                            .from(memberSub)
                            .where(memberSub.age.gt(10))
            ))
            .fetch();

    assertThat(result).extracting("age")
            .containsExactly(20, 30, 40);
}
```

쿼리 결과를 보면 where 절에 in 서브 쿼리가 적용된것을 확인할수 있다.

![image.png](images/image%2017.png)

**select 절에 subquery**

```java
@Test
public void selectSubQuery() {

    QMember memberSub = new QMember("memberSub");

    List<Tuple> result = queryFactory
            .select(member.username,
                            JPAExpressions
                                    .select(memberSub.age.avg())
                            .from(memberSub)
            )
            .from(member)
            .fetch();

    for (Tuple tuple : result) {
        System.out.println("tuple = " + tuple);
    }
}
```

쿼리 결과를 보면 select절에 서브 쿼리가 적용된것을 확인할수 있다.

![image.png](images/image%2018.png)

**static import 활용**

```java
import static com.querydsl.jpa.JPAExpressions.select;

List<Tuple> result = queryFactory
        .select(member.username,
                select(memberSub.age.avg())
                        .from(memberSub)
        )
        .from(member)
        .fetch();
```

JPAExpressions을 static import를 활용해서 코드를 가독성있게 바꾸었다.

**from절의 서브쿼리 한계**

JPA  JPQL 서브쿼리의 한계점은 **from 절의 서브쿼리는 지원하지 않고 Querydsl도 지원하지 않는다**. 하이버네이트 구현체를 사용하면 select 절의 서브쿼리는 지원하고 Querydsl도 하이버네이트 구현체를 사용하면 select 절의 서브쿼리를 지원한다.

from절의 서브쿼리 해결방안

1. 가능하다면 서브쿼리를 join으로 변경한다.
2. 애플리케이션에서 쿼리를 2번 분리해서 실행한다.
3. nativeSQL을 사용한다.

---

## Case 문

select, where, order by 에서 사용 가능하다.

**단순한 조건**

```java
@Test
public void basicCase() {
    List<String> result = queryFactory
            .select(member.age
                    .when(10).then("열살")
                    .when(20).then("스무살")
                    .otherwise("기타"))
            .from(member)
            .fetch();

    for (String s : result) {
        System.out.println("s = " + s);
    }
}
```

쿼리 결과를 보면 select절에 Case문이 적용된것을 확인할수 있다.

![image.png](images/image%2019.png)

result 출력 결과

![image.png](images/image%2020.png)

**복잡한 조건**

```java
@Test
public void complexCase() {
    List<String> result = queryFactory
            .select(new CaseBuilder()
                    .when(member.age.between(0, 20)).then("0~20살")
                    .when(member.age.between(21, 30)).then("21~30살")
                    .otherwise("기타")
            )
            .from(member)
            .fetch();

    for (String s : result) {
        System.out.println("s = " + s);
    }
}
```

복잡한 조건에서는 **CaseBuilder**를 사용한다.

쿼리 결과를 보면  복잡한 case문이 적용된것을 확인할수 있다.

![image.png](images/image%2021.png)

result 출력 결과

![image.png](images/image%2022.png)

**orderBy에서 Case 문 함께 사용**

다음과 같은 임의의 순서로 회원을 출력해보자

1. 0 ~ 30살이 아닌 회원을 가장 먼저 출력
2. 0 ~ 20살 회원 출력
3. 21 ~ 30살 회원 출력

```java
@Test
public void OrderByCase() {
    NumberExpression<Integer> rankPath = new CaseBuilder()
            .when(member.age.between(0, 20)).then(2)
            .when(member.age.between(21, 30)).then(1)
            .otherwise(3);

    List<Tuple> result = queryFactory
            .select(member.username, member.age, rankPath)
            .from(member)
            .orderBy(rankPath.desc())
            .fetch();

    for (Tuple tuple : result) {
        String username = tuple.get(member.username);
        Integer age = tuple.get(member.age);
        Integer rank = tuple.get(rankPath);
        System.out.println("username = " + username + " age = " + age + " rank = " +
                rank);
    }

}
```

Querydsl은 자바 코드로 작성하기 때문에 rankPath처럼 복잡한 조건을 변수로 선언해서 select절, orderBy절에서 함께 사용할 수 있다.

**result 출력 결과**

```
username = member4 age = 40 rank = 3
username = member1 age = 10 rank = 2
username = member2 age = 20 rank = 2
username = member3 age = 30 rank = 1
```

---

## 상수, 문자 더하기

상수가 필요하면 Expressions.constant(xxx)를 사용한다.

```java
@Test
public void constant() {
    List<Tuple> result = queryFactory
            .select(member.username, Expressions.constant("A"))
            .from(member)
            .fetch();

    for (Tuple tuple : result) {
        System.out.println("tuple = " + tuple);
    }
}
```

쿼리에서는 상수를 더한것이 적용되지않고 결과에서는 상수를 받는다.

![image.png](images/image%2023.png)

result 출력 결과

![image.png](images/image%2024.png)

### 문자 더하기 concat

```java
@Test
public void concat() {
    String result = queryFactory
            .select(member.username.concat("_").concat(member.age.stringValue()))
            .from(member)
            .where(member.username.eq("member1"))
            .fetchOne();

    System.out.println("result = " + result);
}
```

쿼리 결과를 보면 concat이 적용된것을 확인할수 있다.

![image.png](images/image%2025.png)

result 출력 결과

![image.png](images/image%2026.png)

> 문자가 아닌 다른 타입들은 stringValue()로 문자로 변환할 수 있다. 이 방법은 ENUM을 처리할 때도 자주 사용한다.
>