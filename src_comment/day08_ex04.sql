UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

COMMIT;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- Session #2

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

UPDATE pizzeria
SET rating = 3.0
WHERE name = 'Pizza Hut';

COMMIT;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';























/*
    Блок идемпотентности:
    Возвращаем рейтинг Pizza Hut к значению 3.6
    (состояние после Ex03), чтобы эксперимент
    можно было повторять сколько угодно раз.
*/
UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: SERIALIZABLE
-- Роль: только ЧИТАЕТ данные (два SELECT-а)
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с уровнем SERIALIZABLE.
    Это самый строгий уровень изоляции. Снимок (snapshot)
    данных фиксируется на момент BEGIN и НЕ МЕНЯЕТСЯ
    до конца транзакции. Никакие чужие COMMIT-ы не влияют
    на то, что видит эта транзакция.
*/
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

/*
    Шаг 3: Первое чтение рейтинга Pizza Hut.
    Ожидаемый результат: rating = 3.6.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 6: Второе чтение рейтинга Pizza Hut.
    Выполняется ПОСЛЕ того, как Session #2 обновил
    рейтинг до 3.0 и сделал COMMIT (шаги 3-5).
    Ожидаемый результат: rating = 3.6 (ТО ЖЕ САМОЕ!).
    АНОМАЛИЯ ПРЕДОТВРАЩЕНА: в отличие от Ex03 (READ COMMITTED),
    где второй SELECT вернул другое значение, здесь
    SERIALIZABLE гарантирует стабильный снимок данных.
    Чтение ПОВТОРЯЕМО — отсюда и название проблемы,
    которую этот уровень решает (Non-Repeatable Read).
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 7: Закрываем транзакцию.
    Только после COMMIT Session #1 «отпускает» свой снимок.
*/
COMMIT;

/*
    Шаг 8: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.0.
    Вне транзакции мы видим реальное состояние базы —
    значение, которое поставил Session #2.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: SERIALIZABLE
-- Роль: ИЗМЕНЯЕТ данные между двумя SELECT-ами Session #1
-- ============================================================

/*
    Шаг 2: Открываем транзакцию во втором сеансе.
*/
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

/*
    Шаг 4: Обновляем рейтинг до 3.0.
    Это изменение «вклинивается» между двумя SELECT-ами
    Session #1, но Session #1 его НЕ УВИДИТ благодаря
    уровню SERIALIZABLE.
*/
UPDATE pizzeria
SET rating = 3.0
WHERE name = 'Pizza Hut';

/*
    Шаг 5: Фиксируем изменения.
    В базе теперь rating = 3.0, но Session #1
    продолжает видеть свой снимок (rating = 3.6).
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.0.
    Вывод: на уровне SERIALIZABLE аномалия Non-Repeatable Read
    ПРЕДОТВРАЩЕНА — оба SELECT-а в Session #1 вернули
    одинаковое значение 3.6, в отличие от Ex03 (READ COMMITTED),
    где второй SELECT показал изменённое значение.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';