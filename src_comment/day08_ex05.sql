DELETE FROM pizzeria
WHERE id = 10;


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT SUM(rating)
FROM pizzeria;

SELECT SUM(rating)
FROM pizzeria;

COMMIT;

SELECT SUM(rating)
FROM pizzeria;


-- Session #2

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

INSERT INTO pizzeria (id, name, rating)
VALUES (10, 'Kazan Pizza', 5);

COMMIT;

SELECT SUM(rating)
FROM pizzeria;



































/*
    Блок идемпотентности:
    Удаляем строку с id=10, если она существует,
    чтобы INSERT не упал с ошибкой дублирования
    первичного ключа при повторном запуске.
*/
DELETE FROM pizzeria
WHERE id = 10;


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: READ COMMITTED
-- Роль: только ЧИТАЕТ (два SELECT SUM)
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с уровнем READ COMMITTED.
    На этом уровне каждый SELECT видит данные,
    зафиксированные на момент начала ЭТОГО SELECT-а.
    Поэтому два SELECT SUM внутри одной транзакции
    могут вернуть разные суммы.
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 3: Первое суммирование рейтингов всех пиццерий.
    Ожидаемый результат: 21.9 (сумма без Kazan Pizza).
    Session #2 ещё не вставил новую строку.
*/
SELECT SUM(rating)
FROM pizzeria;

/*
    Шаг 6: Второе суммирование рейтингов.
    Выполняется ПОСЛЕ того, как Session #2 вставил
    'Kazan Pizza' (rating=5) и сделал COMMIT (шаги 3-5).
    Ожидаемый результат: 26.9 (21.9 + 5 = 26.9).
    СУММА ИЗМЕНИЛАСЬ! Появилась строка, которой не было
    при первом SELECT — это и есть ФАНТОМ (phantom).
    В отличие от Non-Repeatable Read (Ex03), где менялось
    ЗНАЧЕНИЕ существующей строки, здесь появилась
    НОВАЯ строка, которой раньше не существовало.
*/
SELECT SUM(rating)
FROM pizzeria;

/*
    Шаг 7: Закрываем транзакцию.
*/
COMMIT;

/*
    Шаг 8: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: 26.9.
*/
SELECT SUM(rating)
FROM pizzeria;


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: READ COMMITTED
-- Роль: ВСТАВЛЯЕТ новую строку между двумя SELECT-ами Session #1
-- ============================================================

/*
    Шаг 2: Открываем транзакцию во втором сеансе.
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 4: Вставляем новый ресторан 'Kazan Pizza'.
    Эта строка — «фантом»: её не было при первом SELECT
    в Session #1, но она появится при втором.
    Именно INSERT (а не UPDATE) создаёт настоящий
    Phantom Read — появление строки из ниоткуда.
*/
INSERT INTO pizzeria (id, name, rating)
VALUES (10, 'Kazan Pizza', 5);

/*
    Шаг 5: Фиксируем изменения.
    После COMMIT новая строка становится видимой
    для следующего SELECT в Session #1 (шаг 6).
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: 26.9.
    Вывод: на уровне READ COMMITTED аномалия Phantom Read
    НЕ предотвращается. В Ex06 (REPEATABLE READ) оба SELECT SUM
    вернут одинаковую сумму — фантом будет заблокирован.
*/
SELECT SUM(rating)
FROM pizzeria;