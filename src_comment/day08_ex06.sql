DELETE FROM pizzeria
WHERE id = 11;


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT SUM(rating)
FROM pizzeria;

SELECT SUM(rating)
FROM pizzeria;

COMMIT;

SELECT SUM(rating)
FROM pizzeria;


-- Session #2

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

INSERT INTO pizzeria (id, name, rating)
VALUES (11, 'Kazan Pizza 2', 4);

COMMIT;

SELECT SUM(rating)
FROM pizzeria;


















/*
    Блок идемпотентности:
    Удаляем строку с id=11, если она существует,
    чтобы INSERT не упал с ошибкой дублирования
    первичного ключа при повторном запуске.
*/
DELETE FROM pizzeria
WHERE id = 11;


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: REPEATABLE READ
-- Роль: только ЧИТАЕТ (два SELECT SUM)
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с уровнем REPEATABLE READ.
    В отличие от READ COMMITTED (Ex05), здесь снимок (snapshot)
    данных фиксируется на момент BEGIN. Все SELECT-ы внутри
    транзакции будут видеть один и тот же набор строк,
    даже если другие сеансы вставят новые строки и закоммитят.
*/
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

/*
    Шаг 3: Первое суммирование рейтингов всех пиццерий.
    Ожидаемый результат: 26.9 (сумма с Kazan Pizza из Ex05,
    но без Kazan Pizza 2, которую Session #2 ещё не вставил).
*/
SELECT SUM(rating)
FROM pizzeria;

/*
    Шаг 6: Второе суммирование рейтингов.
    Выполняется ПОСЛЕ того, как Session #2 вставил
    'Kazan Pizza 2' (rating=4) и сделал COMMIT (шаги 3-5).
    Ожидаемый результат: 26.9 (ТО ЖЕ САМОЕ!).
    ФАНТОМ ЗАБЛОКИРОВАН: REPEATABLE READ работает
    со снимком на момент BEGIN. Новая строка, вставленная
    Session #2, для этой транзакции НЕ СУЩЕСТВУЕТ.
    В отличие от Ex05 (READ COMMITTED), где сумма изменилась.
*/
SELECT SUM(rating)
FROM pizzeria;

/*
    Шаг 7: Закрываем транзакцию.
    Только после COMMIT Session #1 «отпускает» свой снимок.
*/
COMMIT;

/*
    Шаг 8: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: 30.9 (26.9 + 4).
    Вне транзакции видим реальное состояние базы —
    с новой строкой Kazan Pizza 2.
*/
SELECT SUM(rating)
FROM pizzeria;


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: REPEATABLE READ
-- Роль: ВСТАВЛЯЕТ новую строку между двумя SELECT-ами Session #1
-- ============================================================

/*
    Шаг 2: Открываем транзакцию во втором сеансе.
*/
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

/*
    Шаг 4: Вставляем новый ресторан 'Kazan Pizza 2'.
    Эта строка — потенциальный «фантом», но REPEATABLE READ
    в Session #1 её НЕ УВИДИТ, потому что работает
    со снимком данных на момент своего BEGIN.
*/
INSERT INTO pizzeria (id, name, rating)
VALUES (11, 'Kazan Pizza 2', 4);

/*
    Шаг 5: Фиксируем изменения.
    Строка теперь в базе, но Session #1 её не видит
    до завершения своей транзакции.
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: 30.9.
    Вывод: на уровне REPEATABLE READ аномалия Phantom Read
    ПРЕДОТВРАЩЕНА — оба SELECT SUM в Session #1 вернули
    одинаковую сумму 26.9, в отличие от Ex05 (READ COMMITTED),
    где сумма изменилась с 21.9 на 26.9.
*/
SELECT SUM(rating)
FROM pizzeria;