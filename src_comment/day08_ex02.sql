UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';


-- Session #1

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

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

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

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
    Возвращаем рейтинг Pizza Hut к значению 3.6
    (состояние после Ex01), чтобы эксперимент
    можно было повторять сколько угодно раз.
*/
UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #1 (первое окно терминала с psql)
-- Уровень изоляции: REPEATABLE READ
-- ============================================================

/*
    Шаг 1: Открываем транзакцию с уровнем REPEATABLE READ.
    В отличие от READ COMMITTED (Ex01), здесь транзакция
    фиксирует «снимок» (snapshot) данных на момент BEGIN.
    Все SELECT-ы внутри транзакции будут видеть этот снимок,
    а PostgreSQL дополнительно защищает от потери обновлений.
*/
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

/*
    Шаг 3: Читаем текущий рейтинг Pizza Hut.
    Ожидаемый результат: rating = 3.6.
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
    После COMMIT блокировка снимается.
    Но Session #2 НЕ сможет выполнить свой UPDATE —
    PostgreSQL обнаружит, что строка была изменена
    после начала транзакции Session #2, и выбросит ошибку:
    ERROR: could not serialize access due to concurrent update
    (не удалось сериализовать доступ из-за параллельного изменения)
*/
COMMIT;

/*
    Шаг 9: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 4.
    Обновление Session #1 СОХРАНЕНО — аномалия Lost Update
    ПРЕДОТВРАЩЕНА уровнем REPEATABLE READ.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';


-- ============================================================
-- Session #2 (второе окно терминала с psql)
-- Уровень изоляции: REPEATABLE READ
-- ============================================================

/*
    Шаг 2: Открываем транзакцию во втором сеансе.
    Снимок данных зафиксирован: rating = 3.6.
*/
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

/*
    Шаг 4: Читаем текущий рейтинг Pizza Hut.
    Ожидаемый результат: rating = 3.6.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

/*
    Шаг 6: Пытаемся обновить рейтинг до 3.6.
    Команда ЗАВИСНЕТ, ожидая COMMIT от Session #1.
    После разблокировки PostgreSQL выдаст ОШИБКУ:
    ERROR: could not serialize access due to concurrent update
    Потому что строка уже была изменена Session #1
    после того, как Session #2 сделал свой BEGIN.
    REPEATABLE READ не позволяет затереть чужое изменение.
*/
UPDATE pizzeria
SET rating = 3.6
WHERE name = 'Pizza Hut';

/*
    Шаг 8: Пытаемся зафиксировать.
    Результат: ROLLBACK — транзакция уже сломана ошибкой,
    PostgreSQL автоматически откатывает её.
*/
COMMIT;

/*
    Шаг 10: Проверяем итоговый результат (ниже красной линии).
    Ожидаемый результат: rating = 4.
    Вывод: на уровне REPEATABLE READ аномалия Lost Update
    ПРЕДОТВРАЩЕНА — в отличие от Ex01 (READ COMMITTED),
    где обновление Session #1 было потеряно.
*/
SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';