package com.example.order.application

import com.example.order.domain.Order
import com.example.order.domain.OrderRepository
import org.springframework.stereotype.Service

@Service
class CreateOrderService(
    private val repository: OrderRepository
) : CreateOrderUseCase {

    override suspend fun createOrder(command: CreateOrderCommand): Order {
        if (command.items.isEmpty()) {
            throw EmptyOrderException(command.userId)
        }
        if (command.items.size > 100) {
            throw TooManyItemsException(command.userId, command.items.size)
        }
        if (command.totalAmount <= 0) {
            throw InvalidAmountException(command.totalAmount)
        }
        if (command.shippingAddress.isBlank()) {
            throw MissingAddressException(command.userId)
        }

        val order = Order(
            userId = command.userId,
            items = command.items,
            totalAmount = command.totalAmount,
            shippingAddress = command.shippingAddress
        )
        return repository.save(order)
    }
}
