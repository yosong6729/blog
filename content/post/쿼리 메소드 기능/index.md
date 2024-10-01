---
title: "쿼리 메소드 기능"
date: 2024-09-30T22:22:10+09:00
# weight: 1
# aliases: ["/first"]
tags: ["spring data JPA"]
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

> 해당 글은 김영한님의 인프런 강의 [스프링부트와 JPA활용2 - API 개발과 성능 최적화](https://www.inflearn.com/course/%EC%8A%A4%ED%94%84%EB%A7%81%EB%B6%80%ED%8A%B8-JPA-API%EA%B0%9C%EB%B0%9C-%EC%84%B1%EB%8A%A5%EC%B5%9C%EC%A0%81%ED%99%94)을 듣고 내용을 정리하기 위한 것으로 자세한 설명은 해당 강의를 통해 확인할 수 있습니다.
> 

---

쿼리 메소드 기능 3가지

- 메소드 이름으로 쿼리 생성
- 메소드 이름으로 JPA NamedQuery 호출
- @Query 어노테이션을 사용해서 리포지토리 인터페이스 쿼리 직접 정의

## 메소드 이름으로 쿼리 생성

메소드 이름을 분석해서 JPQL 쿼리를 실행한다.

이름과 나이를 기준으로 회원을 조회하는 상황이다.

**순수 JPA 리포지토리**

```java
public List<Member> findByUsernameAndAgeGreaterThen(String username, int age) {
    return em.createQuery("select m from Member m where m.username = :username and m.age > :age", Member.class)
            .setParameter("username", username)
            .setParameter("age", age)
            .getResultList();
}
```

**순수 JPA 테스트 코드**

```java
@Test
public void findByUsernameAndAgeGreaterThen() {
    Member m1 = new Member("AAA", 10);
    Member m2 = new Member("AAA", 20);
    memberJpaRepository.save(m1);
    memberJpaRepository.save(m2);

    List<Member> result = memberJpaRepository.findByUsernameAndAgeGreaterThen("AAA", 15);

    assertThat(result.get(0).getUsername()).isEqualTo("AAA");
    assertThat(result.get(0).getAge()).isEqualTo(20);
    assertThat(result.size()).isEqualTo(1);

}
```

**스프링 데이터 JPA**

```java
public interface MemberRepository extends JpaRepository<Member, Long> {

        List<Member> findByUsernameAndAgeGreaterThan(String username, int age);

}
```

**쿼리 결과**

![image.png](images/image.png)

스프링 데이터 JPA는 메소드 이름을 분석해서 JPQL을 생성하고 실행한다.

메소드이름의 Username은 파라미터의 username과 equal 조건이고 Age는 GreatherThan이여서 파라미터의 age보다 크거나 작다의 조건이 된다.

**쿼리 메소드 필터 조건**

[스프링 데이터 JPA 공식 문서 참고](https://docs.spring.io/spring-data/jpa/reference/jpa/query-methods.html#jpa.query-methods.query-creation)

**스프링 데이터 JPA가 제공하는 쿼리 메소드 기능**

- 조회: find…By, read…By, query…By, get…By
    - [공식 문서 참고](https://docs.spring.io/spring-data/jpa/reference/jpa/query-methods.html#jpa.query-methods.query-creation)
    - ex) findHelloBy 처럼 …에 식별하기 위한 내용(설명)이 들어가도 된다.
- COUNT: count…By 반환타입
- EXISTS: exists…By 반환타입
- 삭제: delete…By, remove…By
- DISTINCT: findDistinct, findMemberDistinctBy
- LIMIT: findFirst3, findFirst, findTop, findTop3
    - [공식 문서 참고](https://docs.spring.io/spring-data/jpa/reference/repositories/query-methods-details.html#repositories.limit-query-result)

> 이 기능은 엔티티의 필드명이 변경되면 인터페이스에 정의한 메서드 이름도 꼭 함께 변경해야 한다. 그렇지않으면 애플리케이션을 시작하는 시점에 오류가 발생한다.
이렇게 애플리케이션 로딩 시점에 오류를 인지할 수 있는 것이 스프링 데이터 JPA의 매우 큰 장점이다.
> 

---

## JPA NamedQuery

@NamedQuery 어노테이션으로 Named 쿼리 정의

```java
@NamedQuery(
        name="Member.findByUsername",
        query = "select m from Member m where m.username = :username"
)
public class Member {
        //...
}
```

**JPA를 직접 사용해서 Named 쿼리 호출**

```java
@Repository
public class MemberJpaRepository {

        //...

    public List<Member> findByUsername(String username) {
        return em.createNamedQuery("Member.findByUsername", Member.class)
                .setParameter("username", username)
                .getResultList();
    }
}
```

**스프링 데이터 JPA로 NamedQuery 사용**

```java
@Query(name = "Member.findByUsername")
List<Member> findByUsername(@Param("username") String username);
```

@Query를 생략하고 메서드 이름만을 Named쿼리를 호출할수 있다.

**스프링 데이터 JPA로 Named 쿼리 호출**

```java
public interface MemberRepository 
extends JpaRepository<Member, Long> { // 여기서 선언한 Member 도메인 클래스

        List<Member> findByUsername(@Param("username") String username);
}
```

1. 스프링 데이터 JPA는 선언한 “도메인 클래스 + .(점) + 메서드 이름”으로 Named 쿼리를 찾아서 실행
2. 실행할 Named 쿼리가 없을시 메서드 이름으로 쿼리 생성 전약을 사용

> 스프링 데이터 JPA를 사용하면 실무에서 Named Query를 직접 등록해서 사용하는 일은 드물다. 대신 @Query를 사용해서 리파지토리 메소드에 쿼리를 직접 정의한다
> 

---

## @Query, 리포지토리 메소드에 쿼리 정의하기

**메서드 JPQL 쿼리 작성**

```java
public interface MemberRepository extends JpaRepository<Member, Long> {

    @Query("select m from Member m where m.username = :username and m.age = :age")
    List<Member> findUser(@Param("username") String username, @Param("age") int age);		
}
```

- @org.springframework.data.jpa.repository.Query 어노테이션을 사용
- 실행할 메서드에 정적 쿼리를 직접 작성하므로 이름 없는 Named 쿼리라 할 수 있다.
- JPA Named 쿼리처럼 @Query(…)에서 m.usererrss 처럼 잘못 작성하면 어플리케이션 실행 시점에 문법 오류를 발견할수 있는 큰 장점이 있다.

> 메서드 이름으로 쿼리 생성 기능은 파라미터가 증가하면 메서드 이름이 지저분해지기때문에 @Query 기능을 자주 사용함
> 

---

## @Query, 값, DTO 조회하기

**단순히 값 하나를 조회**

```java
@Query("select m.username from Member m")
List<String> findUsernameList();
```

JPA 값 타입(@Embedded)도 이 방식으로 조회할 수 있다.

**MemberDto**

```java
@Data
public class MemberDto {

    private Long id;
    private String username;
    private String teamName;

    public MemberDto(Long id, String username, String teamName) {
        this.id = id;
        this.username = username;
        this.teamName = teamName;
    }
}
```

**DTO로 직접 조회**

```java
@Query("select new study.data_jpa.dto.MemberDto(m.id, m.username, t.name) from Member m join m.team t")
List<MemberDto> findMemberDto();
```

DTO로 직접 조회하려면 JPA의 new 명령어를 사용해야하고 생성자가 맞는 DTO가 필요하다.(JPA 사용 방식과 동일)

---

## 파라미터 바인딩

파라미터 바인딩은 위치 기반, 이름 기반이 있다.

```java
select m from Member m where m.username = ?0 //위치 기반
select m from Member m where m.username = :name //이름 기반
```

위치 기반은 순서 실수가 바뀌거나하면 심각한 오류가 발생할수 있기때문에 코드 가독성과 유지보수를 위해 이름 기반 파라미터 바인딩을 사용하는것이 좋다.

**파라미터 바인딩**

```java
public interface MemberRepository extends JpaRepository<Member, Long> {
        @Query("select m from Member m where m.username = :username and m.age = :age")
    List<Member> findUser(@Param("username") String username, @Param("age") int age);
}
```

**컬렉션 파라미터 바인딩**

```java
@Query("select m from Member m where m.username in :names")
List<Member> findByNames(@Param("names") List<String> names); //Collection가능
```

Collcetion 타입으로 in절을 지원한다.

---

## 반환 타입

스프링 데이터 JPA는 유연한 반환 타입을 지원한다.

```java
List<Member> findByUsername(String name); //컬렉션
Member findByUsername(String name); //단건
Optional<Member> findByUsername(String name); //단건 Optional
```

자세한건 [스프링 데이터 JPA 공식 문서](https://docs.spring.io/spring-data/jpa/reference/repositories/query-return-types-reference.html#appendix.query.return.types)를 참고하면 된다.

**조회 결과 많거나 없으면 어떻게 될까?**

- 컬렉션
    - 결과 없음: **빈 컬렉션 반환(**실무에서 if(…≠ null) 쓰는거 조심), 즉 **null이 아님을 보장**한다.
- 단건 조회
    - 결과 없음: null 반환
    - 결과가 2건 이상: javax.persistence.NonUniqueResultException 예외 발생

> 단건으로 지정한 메서드를 호출하면 스프링 데이터 JPA는 내부에서 JPQL의 Query.getSingleResult() 메서드를 호출한다. 이 메서드를 호출했을 때 조회 결과가 없으면 javax.persistence.NoResultException
> 
> 
> 예외가 발생하는데 개발자 입장에서 다루기가 상당히 불편하다. 스프링 데이터 JPA는 단건을 조회할 때 이 예외가 발생하면 예외를 무시하고 대신에 null을 반환한다.
> 

---

## 순수 JPA 페이징과 정렬

JPA에서 페이징을 하는 방법은 무엇일까?

다음 조건으로 페이징과 정렬을 사용하는 예제 코드를 보자.

- 검색조건: 나이 10살
- 정렬 조건: 이름으로 내림차순
- 페이징 조건: 첫번째 페이지, 페이지당 보여줄 데이터는 3건

**JPA 페이징 리포지토리 코드**

```java
public List<Member> findByPage(int age, int offset, int limit) {
    return em.createQuery("select m from Member m where m.age =: age order by m.username desc", Member.class)
            .setParameter("age", age)
            .setFirstResult(offset)
            .setMaxResults(limit)
            .getResultList();
}

public long totalCount(int age) {
    return em.createQuery("select count(m) from Member m where m.age =: age", Long.class)
            .setParameter("age", age)
            .getSingleResult();
}
```

**JPA 페이징 테스트 코드**

```java
@Test
public void paging() {
    //given
    memberJpaRepository.save(new Member("member1", 10));
    memberJpaRepository.save(new Member("member2", 10));
    memberJpaRepository.save(new Member("member3", 10));
    memberJpaRepository.save(new Member("member4", 10));
    memberJpaRepository.save(new Member("member5", 10));

    int age = 10;
    int offset = 0;
    int limit = 3;
    //when
    List<Member> members = memberJpaRepository.findByPage(age, offset, limit);
    long totalCount = memberJpaRepository.totalCount(age);

    //페이지 계산 공식 적용...
    // totalPage = totalCount / size ...
    // 마지막 페이지 ...
    // 최초 페이지 ..

    //then
    assertThat(members.size()).isEqualTo(3);
    assertThat(totalCount).isEqualTo(5);
}
```

---

## 스프링 데이터 JPA 페이징과 정렬

**페이징과 정렬 파라미터**

- org.springframework.data.domain.**Sort**: 정렬 기능
- org.springframework.data.domain.**Pageable:** 페이징 기능(내부에 Sort 포함)

org.springframework.data…는 JPA가 아니다. 즉 관계형 DB, 몽고 DB 간의 페이징을 공통화 시킨다.

**특별한 반환 타입**

- org.springframework.data.domain.**Page**: **추가 count 쿼리 결과를 포함**하는 페이징
- org.springframework.data.domain.**Slice**: **추가 count 쿼리 없이** 다음 페이지만 확인 가능(내부적으로 limit + 1 조회, 더보기… 같은거라고 생각하면 된다.)
- List(자바 컬렉션): **추가 count 쿼리 없이** 결과만 반환

**페이징과 정렬 사용 예제**

```java
Page<Member> findByUsername(String name, Pageable pageable);
Slice<Member> findByUsername(String name, Pageable pageable);
List<Member> findByUsername(String name, Pageable pageable);
List<Member> findByUsername(String name, Sort sort);
```

- 반환 값이 Page는 getTotalElements()의 값을 위해서 count 쿼리를 사용한다.
- 반환 값이 Slice는 count 쿼리 사용 X
- 반환 값이 List는 count 쿼리 사용 X

다음 조건으로 페이징과 정렬을 사용하는 예제 코드를 확인해보자

- 검색조건: 나이 10살
- 정렬 조건: 이름으로 내림차순
- 페이징 조건: 첫번째 페이지, 페이지당 보여줄 데이터는 3건

**Page 사용 예제 정의 코드**

```java
 public interface MemberRepository extends Repository<Member, Long> {
         Page<Member> findByAge(int age, Pageable pageable);
 }
```

**Page 사용 예제 실행 코드**

```java
//페이징 조건과 정렬 조건 설정
@Test
public void page() throws Exception {
        //given
        memberRepository.save(new Member("member1", 10));
        memberRepository.save(new Member("member2", 10));
        memberRepository.save(new Member("member3", 10));
        memberRepository.save(new Member("member4", 10));
        memberRepository.save(new Member("member5", 10));
        
        //when
        PageRequest pageRequest = PageRequest.of(0, 3, Sort.by(Sort.Direction.DESC, 
        "username"));
        Page<Member> page = memberRepository.findByAge(10, pageRequest);
        
        //then
        List<Member> content = page.getContent(); //조회된 데이터
        assertThat(content.size()).isEqualTo(3); //조회된 데이터 수 
        assertThat(page.getTotalElements()).isEqualTo(5); //전체 데이터 수
        assertThat(page.getNumber()).isEqualTo(0); //페이지 번호
        assertThat(page.getTotalPages()).isEqualTo(2); //전체 페이지 번호
        assertThat(page.isFirst()).isTrue(); //첫번째 항목인가?
        assertThat(page.hasNext()).isTrue(); //다음 페이지가 있는가?
}
```

- findByAge의 두번째 파라미터는 Pageble 인터페이스다. 따라서 실제 사용할때는 해당 인터페이스를 구현한 org.springframework.data.domain.PageRequest 객체를 사용한다.
- PageRequest 생성자의 첫 번째 파라미터에는 현재 페이지를, 두 번째 파라미터에는 조회할 데이터 수를 입력한다. 여기에 추가로 정렬 정보도 파라미터로 사용할수 있다.

PageRequest pageRequest = PageRequest.of(0, 3, Sort.by(Sort.Direction.DESC, "username"));의 쿼리를 보면 member를 조회하는것과 count 쿼리가 나가는것을 알수 있다.

![image.png](images/image%201.png)

![image.png](images/image%202.png)

member를 반복문으로 출력한 결과를 확인해보면 올바르게 실행된것을 알수있다.

![image.png](images/image%203.png)

> Page는 1부터 시작이 아니라 0부터 시작이다.
> 

**Page 인터페이스**

```java
public interface Page<T> extends Slice<T> {
        int getTotalPages();     //전체 페이지 수
        long getTotalElements(); //전체 데이터 수
        <U> Page<U> map(Function<? super T, ? extends U> converter); //변환기
}
```

**Slice 인터페이스**

```java
public interface Slice<T> extends Streamable<T> {
        int getNumber();            //현재 페이지
        int getSize();              //페이지 크기
        int getNumberOfElements();  //현재 페이지에 나올 데이터 수
        List<T> getContent();       //조회된 데이터
        boolean hasContent();       //조회된 데이터 존재 여부
        Sort getSort();             //정렬 정보
        boolean isFirst();          //현재 페이지가 첫 페이지 인지 여부
        boolean isLast();           //현재 페이지가 마지막 페이지 인지 여부
        boolean hasNext();          //다음 페이지 여부
        boolean hasPrevious();      //이전 페이지 여부
        Pageable getPageable();     
        Pageable nextPageable();    
        //페이지 요청 정보
        //다음 페이지 객체
        Pageable previousPageable();//이전 페이지 객체
        <U> Slice<U> map(Function<? super T, ? extends U> converter); //변환기
}
```

**count 쿼리 분리**

```java
@Query(value = "select m from Member m left join fetch m.team t"
                ,countQuery = "select count(m.username) from Member m")
Page<Member> findByAge(int age, Pageable pageable);
```

하이버네이트 6 이전에는 쿼리가 복잡해지면 카운트 쿼리도 그 복잡함을 가지고 가서 조인을 많이해서 성능이 느려지는 경우가 있었다. 하지만 하이버네이트 6 이후에는 **left join을 해도 count 쿼리에는 조인 절이 추가 되지 않는다.** 아래는 쿼리 결과다.

![image.png](images/image%204.png)

![image.png](images/image%205.png)

[**Top, First 사용 참고**](https://docs.spring.io/spring-data/jpa/reference/repositories/query-methods-details.html#repositories.limit-query-result)

```java
List<Member> findTop3By();
```

**페이지를 유지하면서 엔티티를 DTO로 변환하기**

```java
Page<Member> page = memberRepository.findByAge(10, pageRequest);
Page<MemberDto> dtoPage = page.map(m -> new MemberDto());
```

엔티티를 API에 그대로 반환하면 안되기 때문에 위와 같이 Dto로 변형해서 반환한다.

---

## 벌크성 수정 쿼리

**JPA를 사용한 벌크성 수정 쿼리**

```java
public int bulkAgePlus(int age) {
    return em.createQuery("update Member m set m.age = m.age + 1" +
                    " where m.age >= :age")
            .setParameter("age", age)
            .executeUpdate();
}
```

executeUpdate()는 응답 값의 개수를 반환한다.

**JPA를 사용한 벌크성 수정 쿼리 테스트**

```java
@Test
public void bulkUpdate() {
    //given
    memberJpaRepository.save(new Member("member1", 10));
    memberJpaRepository.save(new Member("member2", 19));
    memberJpaRepository.save(new Member("member3", 20));
    memberJpaRepository.save(new Member("member4", 21));
    memberJpaRepository.save(new Member("member5", 40));

    //when
    int resultCount = memberJpaRepository.bulkAgePlus(20);

    //then
    assertThat(resultCount).isEqualTo(3);
}
```

**스프링 데이터 JPA를 사용한 벌크성 수정 쿼리**

```java
@Modifying(clearAutomatically = true)
@Query("update Member m set m.age = m.age + 1 where m.age >= :age")
int bulkAgePlus(@Param("age") int age);
```

@Modifying 어노테이션이 없으면 executeUpdate()가 실행되지 않고 getResultList() 또는 getSingleResult()가 실행되기때문에 값을 변경할때는 Modifying 어노테이션을 넣어줘야한다.

**스프링 데이터 JPA를 사용한 벌크성 수정 쿼리 테스트**

```java
@Test
public void bulkUpdate() throws Exception {
        //given
        memberRepository.save(new Member("member1", 10));
        memberRepository.save(new Member("member2", 19));
        memberRepository.save(new Member("member3", 20));
        memberRepository.save(new Member("member4", 21));
        memberRepository.save(new Member("member5", 40));
        
        //when
        int resultCount = memberRepository.bulkAgePlus(20);
        //then
        
        assertThat(resultCount).isEqualTo(3);
}
```

- 벌크성 수정, 삭제 쿼리는 @Modifying 어노테이션을 사용
    - 사용하지 않으면 org.hibernate.hql.internal.QueryExecutionRequestException: Not supported for DML operations 예외 발생
- 벌크성 쿼리를 실행하고 나서 영속성 컨텍스트 초기화: @Modifying(clearAutomatically = true)(이 옵션의 기본값은 false)
    - 영속성 컨텍스트 초기화를 하는 이유는 벌크 연산은 영속성 컨텍스트에서 값을 조회해서 수정하거나 삭제하지않고 DB에 값을 수정하거나 삭제하기 때문에 초기화 해야한다.
    - 이 옵션 없이 회원을 findById로 다시 조회하면 영속성 컨텍스트에 과거 값이 남아서 문제가 될 수 있다. 만약 다시 조회해야 한다면 영속성 컨텍스트를 초기화 하자.

> 벌크 연산은 영속성 컨텍스트를 무시하고 실행하기 때문에, 영속성 컨텍스트에 있는 엔티티의 상태와 DB에 엔티티 상태가 달라질 수 있다.
> 

권장 방안

1. 영속성 컨텍스트에 엔티티가 없는 상태에서 벌크 연산을 먼저 실행한다.
2. 부득이하게 영속성 컨텍스트에 엔티티가 있으면 벌크 연산 직후 영속성 컨텍스트를 초기화 한다.

---

## @EntityGraph

연관된 엔티티들을 SQL 한번에 조회하는 방법을 알아보자

**member → team은 지연로딩 관계**이기 때문에 다음과 같이 team의 데이터를 조회할 때 마다 쿼리가 샐행된다.(N + 1문제 발생)

```java
@Test
public void findMemberLazy() {
    //given
    //member1 -> teamA
    //member2 -> teamB
    Team teamA = new Team("teamA");
    Team teamB = new Team("teamB");
    teamRepository.save(teamA);
    teamRepository.save(teamB);
    Member member1 = new Member("member1", 10, teamA);
    Member member2 = new Member("member1", 10, teamB);
    memberRepository.save(member1);
    memberRepository.save(member2);

    em.flush();
    em.clear();

    List<Member> members = memberRepository.findAll();
    for (Member member : members) {
        System.out.println("member = " + member.getUsername());
        System.out.println("member.team = " + member.getTeam().getName());
    }
}
```

다음의 쿼리 결과를 보면 member를 조회하고 team을 조죄하는 쿼리가 나간다.

![image.png](images/image%206.png)

참고: 다음과 같이 지연 로딩 여부를 확인할 수 있다.

```java
//Hibernate 기능으로 확인
Hibernate.isInitialized(member.getTeam())
//JPA 표준 방법으로 확인
PersistenceUnitUtil util = 
em.getEntityManagerFactory().getPersistenceUnitUtil();
util.isLoaded(member.getTeam());
```

연관된 엔티티를 한번에 조회하려면 페치 조인이 필요하다

**JPQL 페치 조인**

```java
@Query("select m from Member m left join fetch m.team")
List<Member> findMemberFetchJoin();
```

항상 쿼리를 페치조인의 쿼리를 작성하기는 번거롭다. 그래서 스프링 데이터 JPA는 JPA가 제공하는 엔티티 그래프 기능을 편리하게 사용하게 도와준다. 이 기능을 사용하면 JPQL
없이 페치 조인을 사용할 수 있다. (JPQL + 엔티티 그래프도 가능)

**EntityGraph**

```java
//공통 메서드 오버라이드
@Override
@EntityGraph(attributePaths = {"team"})
List<Member> findAll();

//JPQL + 엔티티 그래프
@EntityGraph(attributePaths = {"team"})
@Query("select m from Member m")
List<Member> findMemberEntityGraph();

//메서드 이름으로 쿼리에서 특히 편리하다.
@EntityGraph(attributePaths = {"team"})
List<Member> findByUsername(String username)
```

- 페치 조인(FETCH JOIN)의 간편 버전
- LEFT OUTER JOIN 사용

**NamedEntityGraph 사용 방법**

```java
@NamedEntityGraph(name = "Member.all", attributeNodes = 
@NamedAttributeNode("team"))
@Entity
public class Member {}
```

```java
@EntityGraph("Member.all")
@Query("select m from Member m")
List<Member> findMemberEntityGraph();
```

---

## JPA Hint, Lock

JPA 쿼리 힌트(SQL 힌트가 아니라 JPA 구현체에게 제공하는 힌트)

**쿼리 힌트 사용**

```java
 @QueryHints(value = @QueryHint(name = "org.hibernate.readOnly", value = "true"))
 Member findReadOnlyByUsername(String username);
```

변경 감지를 하기위해서는 스냅샷으로 저장한 초기 상태의 엔티티 객체와 실제 엔티티 객체를 가지기 때문에 메모리를 먹고, 더티체킹하는 과정의 비용이 든다.

그래서 단순히 조회만 할때 성능 향상을 위해 쿼리 힌트를 사용하는데 무분별하게 사용하기 보다는 성능 테스트를 해보고 사용하는것이 좋다.

**쿼리 힌트 사용 테스트**

```java
@Test
public void queryHint() {
    //given
    Member member1 = new Member("member1", 10);
    memberRepository.save(member1);
    em.flush();
    em.clear();

    Member findMember = memberRepository.findReadOnlyByUsername("member1");
    findMember.setUsername("member2");

    em.flush();

}
```

쿼리 힌트 @QueryHints(value = @QueryHint(name = "org.hibernate.readOnly", value = "true"))로 인해 em.flush()에서 member의 username을 “member2”로 바꾸는 Update 쿼리 실행이 되지 않는다.

**쿼리 힌트 Page 추가 예제**

```java
@QueryHints(value = { @QueryHint(name = "org.hibernate.readOnly", 
                               value = "true")},
          forCounting = true)
Page<Member> findByUsername(String name, Pageable pageable);
```

- org.springframework.data.jpa.repository.QueryHints 어노테이션 사용
- forCounting: 반환 타입으로 Page 인터페이스를 적용하면 추가로 호출하는 페이징을 위한 count 쿼리도 쿼리 힌트 적용기본값 (true)

**Lock**

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
List<Member> findByUsername(String name);
```

쿼리 결과로 마지막에 for update가 생긴것을 알수있따.

![image.png](images/image%207.png)

- org.springframework.data.jpa.repository.Lock 어노테이션을 사용
- JPA가 제공하는 락은 JPA 책 16.1 트랜잭션과 락 절을 참고