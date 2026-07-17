package com.example.account.api

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController

@RestController
class AccountController(
    private val service: AccountService
) {

    @GetMapping("/api/v1/accounts/{id}")
    suspend fun getAccount(@PathVariable id: String): AccountResponse =
        service.findById(AccountId.fromString(id))
            .let { AccountResponse.from(it) }

    @PostMapping("/api/v1/accounts")
    suspend fun createAccount(@RequestBody request: CreateAccountRequest): ResponseEntity<AccountResponse> {
        val account = service.create(request.toCommand())
        return ResponseEntity.status(HttpStatus.CREATED).body(AccountResponse.from(account))
    }
}
