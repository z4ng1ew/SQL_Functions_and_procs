UPDATE pizzeria
SET rating = 5
WHERE name = 'Pizza Hut';


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

UPDATE pizzeria
SET rating = 4
WHERE name = 'Pizza Hut';

COMMIT;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- Session #2

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';

COMMIT;

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

























/*
    Блок идемпотентности:
    Возвращаем рейтинг Pizza Hut к значению 5,
    чтобы эксперимент можно было повторять сколько угодно раз.
*/
UPDATE pizzeria
SET rating = 5
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: READ COMMITTED (дефолт PostgreSQL)
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с явным указанием уровня изоляции.
    READ COMMITTED — каждый оператор внутри транзакции видит
    только те данные, которые были зафиксированы (COMMIT)
    до начала выполнения этого оператора.
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 3: Читаем текущий рейтинг Pizza Hut.
    Ожидаемый результат: rating = 5.
    Оба сеанса видят одно и то же стартовое значение.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 5: Обновляем рейтинг до 4.
    UPDATE выполняется сразу, строка блокируется.
    Session #2 в этот момент ЗАВИСНЕТ на своём UPDATE,
    ожидая освобождения блокировки.
*/
UPDATE pizzeria
SET rating = 4
WHERE name = 'Pizza Hut';

/*
    Шаг 7: Фиксируем изменения.
    После COMMIT блокировка снимается,
    и Session #2 наконец выполнит свой UPDATE,
    перезаписав значение 4 на 3.6.
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.6 (а не 4!).
    Обновление Session #1 ПОТЕРЯНО — это и есть
    аномалия Lost Update.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: READ COMMITTED
-- ============================================================

/*
    Шаг 2: Открываем транзакцию во втором сеансе.
*/
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
    Шаг 4: Читаем текущий рейтинг Pizza Hut.
    Ожидаемый результат: rating = 5.
    Session #1 ещё не закоммитил свой UPDATE,
    поэтому Session #2 видит старое значение.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 6: Обновляем рейтинг до 3.6.
    Эта команда ЗАВИСНЕТ до тех пор, пока Session #1
    не сделает COMMIT. После разблокировки UPDATE выполнится
    и ЗАТРЁТ значение 4, которое поставил Session #1.
*/
UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';

/*
    Шаг 8: Фиксируем изменения.
    Теперь в базе rating = 3.6.
*/
COMMIT;

/*
    Шаг 10: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 3.6.
    Вывод: на уровне READ COMMITTED аномалия Lost Update
    НЕ предотвращается — обновление Session #1 потеряно.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';