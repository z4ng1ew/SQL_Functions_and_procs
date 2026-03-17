UPDATE pizzeria
SET rating = 4
WHERE name = 'Pizza Hut';


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

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

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';

COMMIT;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

















/*
    Блок идемпотентности:
    Возвращаем рейтинг Pizza Hut к значению 4
    (состояние после Ex02), чтобы эксперимент
    можно было повторять сколько угодно раз.
*/
UPDATE pizzeria
SET rating = 4
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: READ COMMITTED
-- Роль: только ЧИТАЕТ данные (два SELECT-а)
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с уровнем READ COMMITTED.
    На этом уровне каждый SELECT видит данные, зафиксированные
    на момент НАЧАЛА ЭТОГО SELECT-а (а не на момент BEGIN).
    Поэтому два SELECT-а внутри одной транзакции могут
    вернуть разные результаты.
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 2: Первое чтение рейтинга Pizza Hut.
    Ожидаемый результат: rating = 4.
    Session #2 ещё ничего не менял.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 6: Второе чтение рейтинга Pizza Hut.
    Выполняется ПОСЛЕ того, как Session #2 обновил
    рейтинг до 3.6 и сделал COMMIT (шаги 3-5).
    Ожидаемый результат: rating = 3.6 (ИЗМЕНИЛОСЬ!).
    ВОТ АНОМАЛИЯ: тот же SELECT, та же транзакция,
    но результат другой. Это и есть Non-Repeatable Read —
    «неповторяющееся чтение».
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 7: Закрываем транзакцию.
*/
COMMIT;

/*
    Шаг 8: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.6.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: READ COMMITTED
-- Роль: ИЗМЕНЯЕТ данные между двумя SELECT-ами Session #1
-- ============================================================

/*
    Шаг 3: Открываем транзакцию во втором сеансе.
    Выполняется ПОСЛЕ шага 2 (первого SELECT в Session #1).
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 4: Обновляем рейтинг до 3.6.
    Это изменение «вклинивается» между двумя SELECT-ами
    Session #1, создавая аномалию.
*/
UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';

/*
    Шаг 5: Фиксируем изменения.
    После COMMIT значение 3.6 становится видимым
    для следующего SELECT в Session #1 (шаг 6).
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.6.
    Вывод: на уровне READ COMMITTED аномалия Non-Repeatable Read
    НЕ предотвращается. В Ex04 (SERIALIZABLE) оба SELECT-а
    вернут одинаковое значение — аномалия будет предотвращена.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';