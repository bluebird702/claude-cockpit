package com.example.auth.application

import com.example.auth.domain.AuthToken
import com.example.auth.domain.TokenRepository
import java.time.Duration
import org.springframework.stereotype.Service

@Service
class AuthTokenIssuer(
    private val repository: TokenRepository
) {

    suspend fun issue(account: Account): AuthToken {
        val token = AuthToken.create(account.id, account.email, Duration.ofHours(1))
        repository.save(token)
        return token
    }
}
