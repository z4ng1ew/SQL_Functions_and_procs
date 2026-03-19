DROP FUNCTION IF EXISTS fnc_persons_female();
DROP FUNCTION IF EXISTS fnc_persons_male();
DROP FUNCTION IF EXISTS fnc_persons(VARCHAR);

CREATE OR REPLACE FUNCTION fnc_persons(pgender VARCHAR DEFAULT 'female')
RETURNS TABLE (
    id      person.id%TYPE,
    name    person.name%TYPE,
    age     person.age%TYPE,
    gender  person.gender%TYPE,
    address person.address%TYPE
) AS
$$
    SELECT id, name, age, gender, address
    FROM person
    WHERE gender = pgender;
$$
LANGUAGE SQL;

SELECT * FROM fnc_persons(pgender := 'male');
SELECT * FROM fnc_persons();

















## Суть задания

В ex04 мы создали две одинаковые функции: одну для мужчин, другую для женщин. Это дублирование кода — отличается только значение `'male'`/`'female'` в WHERE. Задание ex05 просит заменить их **одной универсальной функцией** с параметром `pgender`, который определяет, кого возвращать. Если параметр не указан, по умолчанию возвращаются женщины (`DEFAULT 'female'`).

---

## Построчный комментарий


-- ============================================================
-- ЧАСТЬ 1: Очистка — удаляем старые функции из ex04
-- ============================================================

-- Удаляем две функции из ex04 (задание ЯВНО требует это сделать).
-- IF EXISTS — защита от ошибки при повторном запуске.
DROP FUNCTION IF EXISTS fnc_persons_female();
DROP FUNCTION IF EXISTS fnc_persons_male();

-- Удаляем саму fnc_persons, если она осталась от предыдущего запуска.
-- (VARCHAR) — указываем сигнатуру, потому что PostgreSQL различает
-- функции по имени И типам параметров (перегрузка функций).
-- Без указания типа PostgreSQL может не найти нужную функцию.
DROP FUNCTION IF EXISTS fnc_persons(VARCHAR);

-- ============================================================
-- ЧАСТЬ 2: Универсальная функция с параметром
-- ============================================================

-- CREATE OR REPLACE — если функция уже есть, перезаписать.
-- pgender VARCHAR DEFAULT 'female' — входной параметр:
--   pgender — имя параметра
--   VARCHAR — тип (строка переменной длины)
--   DEFAULT 'female' — если не передать значение, будет 'female'
CREATE OR REPLACE FUNCTION fnc_persons(pgender VARCHAR DEFAULT 'female')

-- RETURNS TABLE — функция возвращает набор строк.
-- %TYPE — «такой же тип, как у этого столбца в таблице person».
-- Автоматически подстроится, если типы столбцов изменятся.
RETURNS TABLE (
    id      person.id%TYPE,
    name    person.name%TYPE,
    age     person.age%TYPE,
    gender  person.gender%TYPE,
    address person.address%TYPE
) AS
$$
    -- Тело функции — один SELECT-запрос.
    -- pgender используется в WHERE как обычная переменная.
    -- PostgreSQL подставит значение параметра при вызове.
    SELECT id, name, age, gender, address
    FROM person
    WHERE gender = pgender;
$$
-- LANGUAGE SQL — чистый SQL, не PL/pgSQL.
-- Задание явно требует SQL-функцию.
LANGUAGE SQL;

-- ============================================================
-- ЧАСТЬ 3: Проверка
-- ============================================================

-- Вызов с явным параметром: pgender := 'male'
-- := — синтаксис именованного аргумента в PostgreSQL.
-- Ожидаем: Andrey, Denis, Peter, Dmitriy
SELECT * FROM fnc_persons(pgender := 'male');

-- Вызов без параметра: сработает DEFAULT 'female'.
-- Ожидаем: Anna, Kate, Elvira, Irina, Nataly
SELECT * FROM fnc_persons();
```

---

## Порядок выполнения

```
1. DROP fnc_persons_female  → Удалена (если была).
2. DROP fnc_persons_male    → Удалена (если была).
3. DROP fnc_persons         → Удалена (если была от прошлого запуска).
4. CREATE fnc_persons       → Зарегистрирована в каталоге pg_proc.
5. SELECT * FROM fnc_persons(pgender := 'male')
   → PostgreSQL подставляет pgender = 'male' в WHERE
   → Возвращает мужчин.
6. SELECT * FROM fnc_persons()
   → pgender не передан → используется DEFAULT 'female'
   → Возвращает женщин.
```

---

## Альтернативные варианты написания

**1. Явные типы вместо `%TYPE`**

```sql
RETURNS TABLE (
    id      BIGINT,
    name    VARCHAR,
    age     INTEGER,
    gender  VARCHAR,
    address VARCHAR
) ...
-- Работает, но если типы в person изменятся,
-- придётся обновлять функцию вручную.
```

**2. `SELECT *` вместо перечисления столбцов**

```sql
$$
    SELECT * FROM person WHERE gender = pgender;
$$
-- Короче, но если в person добавят столбец,
-- SELECT * вернёт больше столбцов, чем в RETURNS TABLE → ошибка.
```

**3. `SETOF person` вместо `RETURNS TABLE`**

```sql
CREATE FUNCTION fnc_persons(pgender VARCHAR DEFAULT 'female')
RETURNS SETOF person AS
$$
    SELECT * FROM person WHERE gender = pgender;
$$
LANGUAGE SQL;
-- SETOF person — «набор строк с такой же структурой, как таблица person».
-- Проще написать, но привязывает функцию к точной структуре person.
```

**4. PL/pgSQL вместо SQL**

```sql
CREATE FUNCTION fnc_persons(pgender VARCHAR DEFAULT 'female')
RETURNS TABLE (...) AS $$
BEGIN
    RETURN QUERY
        SELECT id, name, age, gender, address
        FROM person WHERE gender = pgender;
END;
$$ LANGUAGE plpgsql;
-- Работает, но задание ЯВНО требует SQL-функцию.
-- SQL-функция ещё и быстрее: PostgreSQL может «встроить» (inline)
-- её в вызывающий запрос при оптимизации.
```

**5. Позиционный аргумент вместо именованного**

```sql
-- Именованный (как в задании):
SELECT * FROM fnc_persons(pgender := 'male');

-- Позиционный (по порядку параметров):
SELECT * FROM fnc_persons('male');

-- Оба работают. Именованный — читабельнее,
-- особенно когда параметров несколько.
```

---

## Возможные вопросы на защите

**Q: Чем эта функция лучше двух из ex04?**
A: Нет дублирования. Одна функция вместо двух. Если нужно изменить логику (например, добавить столбец) — правишь в одном месте. Если появится `gender = 'other'`, не нужно создавать третью функцию — просто вызываешь `fnc_persons(pgender := 'other')`.

**Q: Что такое `DEFAULT 'female'`?**
A: Значение по умолчанию. Если при вызове не передать параметр (`fnc_persons()`), PostgreSQL подставит `'female'` автоматически. Аналог в Си (C++ на самом деле, в чистом Си нет значений по умолчанию): `void func(int x = 10)`.

**Q: Что такое `pgender := 'male'`?**
A: Именованный аргумент. `:=` — синтаксис передачи аргумента по имени в PostgreSQL. Альтернатива — позиционный вызов: `fnc_persons('male')`. Именованный удобнее, когда параметров несколько — не нужно помнить их порядок.

**Q: Почему `DROP FUNCTION fnc_persons(VARCHAR)` с указанием типа?**
A: PostgreSQL поддерживает перегрузку функций (overloading — несколько функций с одним именем, но разными параметрами). Может существовать `fnc_persons(VARCHAR)` и `fnc_persons(INTEGER)`. Указание типа однозначно определяет, какую именно удалить.

**Q: Что если передать `pgender := 'unknown'`?**
A: Функция вернёт **пустой набор строк** — ни одна строка в `person` не имеет `gender = 'unknown'`. Ошибки не будет.

**Q: Почему SQL-функция, а не PL/pgSQL?**
A: Задание явно требует SQL. Кроме того, SQL-функции PostgreSQL может встроить (inline) в вызывающий запрос — оптимизатор работает с ней как с подзапросом, а не как с «чёрным ящиком». PL/pgSQL-функции всегда выполняются отдельно.

**Q: Можно ли использовать эту функцию в JOIN?**
A: Да, как обычную таблицу:
```sql
SELECT p.name, m.pizza_name
FROM fnc_persons(pgender := 'male') p
JOIN person_order po ON p.id = po.person_id
JOIN menu m ON po.menu_id = m.id;
```