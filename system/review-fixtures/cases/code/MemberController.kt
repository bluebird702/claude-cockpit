package com.example.member.api

import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RestController

@RestController
class MemberController(
    private val service: MemberService
) {

    @GetMapping("/api/v1/members/{id}")
    suspend fun getMember(@PathVariable id: String): ResponseEntity<MemberResponse> =
        ResponseEntity.ok(
            service.findById(MemberId.fromString(id))
                .let { MemberResponse.from(it) }
        )
}
