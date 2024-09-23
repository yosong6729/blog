---
title: "API 개발 기본"
date: 2024-09-23T16:35:17+09:00
# weight: 1
# aliases: ["/first"]
tags: ["spring boot", "JPA"]
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

## 회원 등록 API

**회원 등록 API**

```java
@RestController
@RequiredArgsConstructor
public class MemberApiController {

    private final MemberService memberService;
    
    
    @PostMapping("/api/v1/members")
    public CreateMemberResponse saveMemberV1(@RequestBody @Valid Member member) {
        Long id = memberService.join(member);
        return new CreateMemberResponse(id);
    }
    
    @Data
    static class CreateMemberRequest {
        private String name;
    }
    @Data
    static class CreateMemberResponse {
        private Long id;
        public CreateMemberResponse(Long id) {
            this.id = id;
        }
    }
}
```

### V1 : 엔티티를 Request Body에 직접 매핑

- 문제점
    - 엔티티에 프레젠테이션 계층을 위한 로직이 추가된다.
    - @NotEmpty 같은 검증을 위한 로직이 엔티티에 들어간다.
    - 회원 엔티티를 위한 API가 다양하게 만들어 지는데, 한 엔티티에 각각의 API를 위한 모든 요청 요구사항을 담기는 어렵다.
    - 엔티티가 변경되면 API 스펙이 변경된다.
- 결론
    - API 요청 스펙에 맞추어 별도의 DTO를 파라미터로 받는다.

### V2 엔티티 대신에 DTO를 RequestBody에 매핑

```java
@PostMapping("/api/v2/members")
public CreateMemberResponse saveMemberV2(@RequestBody @Valid CreateMemberRequest request) {

    Member member = new Member();
    member.setName(request.getName());

    Long id = memberService.join(member);

    return new CreateMemberResponse(id);
}
```

- Member엔티티 대신에 CreateMemberRequest를 RequestBody와 매핑
- 엔티티와 프레젠테이션 계층을 위한 로직 분리
- 엔티티와 API 스펙 분리
- 엔티티가 변해도 API 스펙 변화X

---

## 회원 수정 API

```java
//수정 API
@PutMapping("/api/v2/members/{id}")
public UpdateMemberResponse updateMemberV2(
        @PathVariable("id") Long id,
        @RequestBody @Valid UpdateMemberRequest request) {

    //수정할때 가급적이면 변경감지(member가져와서 값만 수정하면 자동으로 변경감지되서 update됨) 쓰기
    memberService.update(id, request.getName());
    Member findMember = memberService.findOne(id);
    return new UpdateMemberResponse(findMember.getId(), findMember.getName());
}

@Data
static class UpdateMemberRequest {
    private String name;
}

@Data
@AllArgsConstructor //엔티티에는 에노테이션 getter정도만씀. 자제하는편. 이유는?, DTO에는 많이씀
static class UpdateMemberResponse {
    private Long id;
    private String name;
}
```

회원 수정도 DTO를 요청 파라미터에 매핑한다.

```java
@Service
@Transactional(readOnly = true)
@RequiredArgsConstructor
public class MemberService {

		private final MemberRepository memberRepository;
		
		@Transactional
    public void update(Long id, String name) {
        Member member = memberRepository.findOne(id);
        member.setName(name);
    }
}
```

변경 감지로 데이터 수정

> 오류정정: 회원 수정 API updateMemberV2 은 회원 정보를 부분 업데이트 한다. 여기서 PUT 방식을 사용했는데, PUT은 전체 업데이트를 할 때 사용하는 것이 맞다. 부분 업데이트를 하려 PATCH를 사용하거나 POST를 사용하는 것이 REST 스타일에 맞다.
> 

---

## 회원 조회 API

### 회원조회 V1: 응답 값으로 엔티티를 직접 외부에 노출

```java
@RestController
@RequiredArgsConstructor
public class MemberApiController {

    private final MemberService memberService;
    
     //조회 V1: 안 좋은 버전, 모든 엔티티가 노출, @JsonIgnore -> 이건 정말 최악, api가 이거 하나인가! 화면에 종속적이지 마라!
    @GetMapping("/api/v1/members")
    public List<Member> memebersV1() {
        return memberService.findMembers();
    }
}
```

회원 조회 V1의

- 문제점
    - 엔티티에 프레젠테이션 계층을 위한 로직 추가
    - 엔티티 모든값 노출
    - 응답 스펙을 맞추기 위한 로직  추가(@JsonIgnore, 별도의 view 로직 등)
    - 같은 엔티티에 용도에 따라 다양한 API가 만들어지는데 한 엔티티에 각각의 API를 위한 프레젠테이션 응답 로직을 담기는 어려움
    - 엔티티 변경되면 API 스펙 변화
    - 컬렉션 직접 반환시 후에 API 스펙 변경이 어려움
- 결론
    - API 응답 스펙에 맞추어 별도의 DTO 반환

### 회원 조회 V2:응답 값으로 엔티티가 아닌 별도의 DTO 사용

```java
@GetMapping("/api/v2/members")
public Result memberV2() {
    List<Member> findmembers = memberService.findMembers();
    List<MemberDto> collect = findmembers.stream()
            .map(m -> new MemberDto(m.getName()))
            .collect(Collectors.toList());

    return new Result(collect);
}

@Data
@AllArgsConstructor
static class Result<T> {
    private T data;
}

@Data
@AllArgsConstructor
static class MemberDto {
    private String name;
}
```

---

- 엔티티를 DTO로 볂완해서 반환
- 엔티티가 변해도 API 스펙 변경X
- Result 클래스로 컬렉션을 감싸서 필요한 필드 추가 가능