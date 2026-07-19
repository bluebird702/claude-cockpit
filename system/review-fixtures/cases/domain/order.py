from fastapi import Depends


class Order:
    def __init__(self, total: int, discount: "Depends" = None) -> None:
        self.total = total
        self.discount = discount
