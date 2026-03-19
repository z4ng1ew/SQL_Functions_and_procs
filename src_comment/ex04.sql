DROP FUNCTION IF EXISTS fnc_persons_female();
DROP FUNCTION IF EXISTS fnc_persons_male();

CREATE FUNCTION fnc_persons_female()
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
    WHERE gender = 'female';
$$
LANGUAGE SQL;

CREATE FUNCTION fnc_persons_male()
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
    WHERE gender = 'male';
$$
LANGUAGE SQL;

SELECT * FROM fnc_persons_male();
SELECT * FROM fnc_persons_female();





## Суть задания

У тебя из предыдущих проектов уже есть два **VIEW** (представления — сохранённые SELECT-запросы, которые работают как виртуальные таблицы):


-- Примерно так они выглядят (созданы ранее):
CREATE VIEW v_persons_female AS
    SELECT * FROM person WHERE gender = 'female';

CREATE VIEW v_persons_male AS
    SELECT * FROM person WHERE gender = 'male';

-- Использование:
SELECT * FROM v_persons_female;
SELECT * FROM v_persons_male;
```

Задание просит: **сделай то же самое, но через функции вместо VIEW**.

```sql
-- Было (VIEW):
SELECT * FROM v_persons_male;

-- Стало (функция):
SELECT * FROM fnc_persons_male();
```

Результат **одинаковый** — список мужчин или женщин. Меняется только способ получения.

### Зачем это нужно

Задание учит тебя видеть, что **функция может работать как таблица**. Это ключевая идея:

```sql
-- Обычная таблица:
SELECT * FROM person;

-- VIEW (виртуальная таблица):
SELECT * FROM v_persons_male;

-- Функция (тоже виртуальная таблица!):
SELECT * FROM fnc_persons_male();


Все три вызываются одинаково — через `SELECT * FROM`. Но функция мощнее VIEW, потому что может принимать **параметры**. В ex04 параметров нет, но в ex05 задание скажет: «а теперь сделай одну функцию с параметром `gender`» — и ты поймёшь, зачем это было нужно.

### Цепочка заданий

```
ex04: две функции без параметров (fnc_persons_female, fnc_persons_male)
  ↓
ex05: одна функция С параметром (fnc_persons(pgender := 'male'))
```

Ex04 — это подготовительный шаг. Сначала учишься делать функцию-таблицу, потом делаешь её универсальной.



## Построчный комментарий


-- ============================================================
-- ЧАСТЬ 1: Очистка — удаляем старые функции если они есть
-- ============================================================

-- Удаляем функции из предыдущих запусков.
-- IF EXISTS — если функции нет, ошибки не будет.
DROP FUNCTION IF EXISTS fnc_persons_female();
DROP FUNCTION IF EXISTS fnc_persons_male();

-- ============================================================
-- ЧАСТЬ 2: Создание двух SQL-функций
-- ============================================================

-- Создаём SQL-функцию (НЕ PL/pgSQL!) для получения женщин.
-- SQL-функция — это обёртка над одним SELECT-запросом.
-- Внутри нельзя объявлять переменные, использовать IF/ELSE, циклы.
-- Нет BEGIN/END блока — только чистый SQL.
CREATE FUNCTION fnc_persons_female()

-- RETURNS TABLE — функция возвращает набор строк (как таблица).
-- Это позволяет вызывать её через SELECT * FROM fnc_persons_female().
-- person.id%TYPE — «такой же тип, как у столбца id в таблице person».
-- Если тип столбца изменится, функция автоматически подстроится.
RETURNS TABLE (
    id      person.id%TYPE,      -- тип как у person.id (сейчас BIGINT)
    name    person.name%TYPE,    -- тип как у person.name (сейчас VARCHAR)
    age     person.age%TYPE,     -- тип как у person.age (сейчас INTEGER)
    gender  person.gender%TYPE,  -- тип как у person.gender (сейчас VARCHAR)
    address person.address%TYPE  -- тип как у person.address (сейчас VARCHAR)
) AS
-- $$ — долларное квотирование, обрамление тела функции.
$$
    -- Тело функции — один SELECT-запрос.
    -- Явно перечисляем столбцы вместо SELECT * —
    -- безопаснее: если в таблицу добавят новый столбец,
    -- функция не сломается.
    SELECT id, name, age, gender, address
    FROM person
    WHERE gender = 'female';
$$
-- LANGUAGE SQL — указываем, что тело написано на чистом SQL.
-- НЕ plpgsql! Задание явно требует SQL-функцию.
LANGUAGE SQL;

-- Аналогичная функция для мужчин.
-- Единственное отличие — WHERE gender = 'male'.
CREATE FUNCTION fnc_persons_male()
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
    WHERE gender = 'male';
$$
LANGUAGE SQL;

-- ============================================================
-- ЧАСТЬ 3: Проверка — вызываем функции как виртуальные таблицы
-- ============================================================

-- Вызов функции в секции FROM — как будто это таблица.
-- Ожидаем: Andrey, Denis, Peter, Dmitriy
SELECT * FROM fnc_persons_male();

-- Ожидаем: Anna, Kate, Elvira, Irina, Nataly
SELECT * FROM fnc_persons_female();
```

---

## Порядок выполнения

```
1. DROP FUNCTION fnc_persons_female()  → Удалена (если была).
2. DROP FUNCTION fnc_persons_male()    → Удалена (если была).
3. CREATE FUNCTION fnc_persons_female  → Зарегистрирована в каталоге pg_proc.
4. CREATE FUNCTION fnc_persons_male    → Зарегистрирована в каталоге pg_proc.
5. SELECT * FROM fnc_persons_male()    → PostgreSQL выполняет SELECT
                                          внутри функции, возвращает мужчин.
6. SELECT * FROM fnc_persons_female()  → Аналогично, возвращает женщин.
```

---

## Альтернативные варианты написания

**1. `CREATE OR REPLACE` вместо `DROP` + `CREATE`**

```sql
CREATE OR REPLACE FUNCTION fnc_persons_female() ...
-- Одна команда вместо двух. Если функция уже есть — перезапишется.
-- Но CREATE OR REPLACE не может изменить тип возврата:
-- если старая функция возвращала INTEGER, а новая — TABLE,
-- будет ошибка. DROP + CREATE надёжнее в этом случае.
```

**2. Явные типы вместо `%TYPE`**

```sql
RETURNS TABLE (
    id      BIGINT,
    name    VARCHAR,
    age     INTEGER,
    gender  VARCHAR,
    address VARCHAR
) ...
-- Работает одинаково. Но если тип person.id когда-то изменится,
-- придётся обновлять функцию вручную.
-- %TYPE подстраивается автоматически.
```

**3. `SELECT *` вместо перечисления столбцов**

```sql
$$
    SELECT * FROM person WHERE gender = 'female';
$$
-- Короче, но хрупче: если в таблицу person добавят столбец,
-- SELECT * вернёт больше столбцов, чем объявлено в RETURNS TABLE,
-- и функция сломается с ошибкой.
```

**4. `SETOF person` вместо `RETURNS TABLE`**

```sql
CREATE FUNCTION fnc_persons_female()
RETURNS SETOF person AS
$$
    SELECT * FROM person WHERE gender = 'female';
$$
LANGUAGE SQL;
-- SETOF person — «набор строк с такой же структурой, как у таблицы person».
-- Короче, но менее гибко: привязывает функцию к точной структуре таблицы.
-- Если нужно вернуть только часть столбцов — не подойдёт.
```

**5. PL/pgSQL вместо SQL**

```sql
CREATE FUNCTION fnc_persons_female()
RETURNS TABLE (...) AS $$
BEGIN
    RETURN QUERY SELECT id, name, age, gender, address
    FROM person WHERE gender = 'female';
END;
$$ LANGUAGE plpgsql;
-- Работает, но задание ЯВНО требует SQL-функцию, НЕ PL/pgSQL.
-- SQL-функция проще и может быть оптимизирована PostgreSQL лучше:
-- планировщик запросов может «встроить» (inline) SQL-функцию
-- в вызывающий запрос, что невозможно с PL/pgSQL.
```

---

## Возможные вопросы на защите

**Q: Чем SQL-функция отличается от PL/pgSQL-функции?**
A: SQL-функция — это обёртка над одним (или несколькими) SQL-запросами. Нет переменных, нет IF/ELSE, нет циклов, нет BEGIN/END. PL/pgSQL — процедурный язык с переменными, условиями, циклами. SQL-функцию PostgreSQL может «встроить» (inline — подставить тело функции прямо в вызывающий запрос), что ускоряет выполнение. PL/pgSQL встроить нельзя.

**Q: Зачем `%TYPE`?**
A: `person.id%TYPE` означает «такой же тип данных, как у столбца id в таблице person». Если тип столбца изменится (например, с BIGINT на INTEGER), функция **автоматически** подстроится. Без `%TYPE` пришлось бы обновлять функцию вручную.

**Q: Почему функция, а не VIEW?**
A: Задание просит именно функцию. Но по сути `SELECT * FROM fnc_persons_male()` и `SELECT * FROM v_persons_male` (VIEW) дают одинаковый результат. Разница: функция может принимать параметры (что пригодится в ex05), а VIEW — нет.

**Q: Что значит `RETURNS TABLE`?**
A: Функция возвращает **набор строк** с определённой структурой. Это позволяет использовать функцию в секции FROM как виртуальную таблицу: `SELECT * FROM fnc_persons_male()`.

**Q: Можно ли добавить WHERE к вызову функции?**
A: Да, функция работает как таблица:
```sql
SELECT * FROM fnc_persons_male() WHERE age > 20;
-- Вернёт только мужчин старше 20.
```

**Q: Зачем две функции, если они почти одинаковые?**
A: Задание требует две. Но ты прав — это дублирование. В ex05 их заменят одной универсальной функцией с параметром.

**Q: Что будет если вызвать `SELECT name FROM fnc_persons_male()`?**
A: Сработает — можно выбирать отдельные столбцы, как из обычной таблицы. `RETURNS TABLE` определяет **все доступные** столбцы, но использовать можно любое подмножество.