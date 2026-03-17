DELETE FROM person WHERE id = 10;

DROP TABLE IF EXISTS person_audit;

CREATE TABLE person_audit (
    created     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    type_event  CHAR(1) NOT NULL DEFAULT 'I',
    row_id      BIGINT NOT NULL,
    name        VARCHAR,
    age         INTEGER,
    gender      VARCHAR,
    address     VARCHAR,
    CONSTRAINT ch_type_event CHECK (type_event IN ('I', 'U', 'D'))
);

CREATE OR REPLACE FUNCTION fnc_trg_person_insert_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'I', NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);

    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_person_insert_audit ON person;

CREATE TRIGGER trg_person_insert_audit
AFTER INSERT ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_insert_audit();

INSERT INTO person(id, name, age, gender, address)
VALUES (10, 'Damir', 22, 'male', 'Irkutsk');

SELECT * FROM person_audit;





---
CONSTRAINT ch_type_event CHECK (type_event IN ('I', 'U', 'D'))
```

Здесь три части:

**`CONSTRAINT ch_type_event`** — задаёт **имя** ограничению. `ch_type_event` — это просто название, которое ты (или задание) выбрал. Оно нужно, чтобы потом можно было сослаться на это ограничение, например, удалить его: `ALTER TABLE person_audit DROP CONSTRAINT ch_type_event;`. Если имя не задать, PostgreSQL сгенерирует его автоматически (что-то вроде `person_audit_type_event_check`).

**`CHECK (...)`** — это тип ограничения. CHECK-ограничение (проверочное ограничение) — это условие, которое **каждая строка обязана выполнять**. Если при INSERT или UPDATE условие нарушается, PostgreSQL выдаст ошибку и откажет в операции.

**`type_event IN ('I', 'U', 'D')`** — само условие. Столбец `type_event` может содержать **только** одно из трёх значений: `'I'` (Insert), `'U'` (Update), `'D'` (Delete). Попытка записать, например, `'X'` приведёт к ошибке вроде:
```
ERROR: new row for relation "person_audit" violates check constraint "ch_type_event"

















## Построчный комментарий

```sql
-- Удаляем строку с id=10 из person, если она осталась от предыдущего запуска.
-- Без этого повторный INSERT выдаст ошибку "нарушение уникальности person_pkey".
DELETE FROM person WHERE id = 10;

-- Удаляем старую таблицу аудита, если она существует.
-- IF EXISTS — защита от ошибки при первом запуске, когда таблицы ещё нет.
DROP TABLE IF EXISTS person_audit;

-- Создаём таблицу аудита. Структура повторяет person,
-- но добавлены служебные столбцы: created, type_event.
CREATE TABLE person_audit (
    -- Метка времени события. NOT NULL — обязательно к заполнению.
    -- DEFAULT CURRENT_TIMESTAMP — если не передать значение явно,
    -- PostgreSQL подставит текущее время сервера.
    created     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Тип события: 'I' = Insert, 'U' = Update, 'D' = Delete.
    -- CHAR(1) — строка фиксированной длины в 1 символ.
    -- DEFAULT 'I' — если не указать, по умолчанию будет 'I'.
    type_event  CHAR(1) NOT NULL DEFAULT 'I',

    -- Копия person.id. BIGINT — целое число до ~9.2 * 10^18.
    row_id      BIGINT NOT NULL,

    -- Остальные поля — копии столбцов из person, без ограничений.
    name        VARCHAR,
    age         INTEGER,
    gender      VARCHAR,
    address     VARCHAR,

    -- Проверочное ограничение: type_event может быть ТОЛЬКО 'I', 'U' или 'D'.
    -- Имя ch_type_event нужно, чтобы потом можно было обращаться к этому
    -- ограничению по имени (например, при удалении).
    CONSTRAINT ch_type_event CHECK (type_event IN ('I', 'U', 'D'))
);

-- Создаём (или заменяем) триггерную функцию.
-- CREATE OR REPLACE — если функция уже существует, она будет перезаписана.
-- RETURNS TRIGGER — специальный тип возврата для триггерных функций.
CREATE OR REPLACE FUNCTION fnc_trg_person_insert_audit()
RETURNS TRIGGER AS
$BODY$
    -- $BODY$ — это долларное квотирование (dollar quoting).
    -- Замена обычным кавычкам, чтобы внутри тела функции
    -- можно было свободно использовать апострофы.
BEGIN
    -- При каждом INSERT в person эта функция автоматически
    -- вставит копию новой строки (NEW) в person_audit.
    -- NEW — псевдозапись, содержащая данные НОВОЙ строки.
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'I', NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);

    -- RETURN NULL — для AFTER-триггеров возвращаемое значение игнорируется.
    -- NULL здесь — просто формальность, обязательная синтаксически.
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;
    -- LANGUAGE plpgsql — указываем, что тело написано на PL/pgSQL
    -- (процедурном расширении SQL для PostgreSQL).

-- Удаляем старый триггер, если он есть (защита от повторного запуска).
DROP TRIGGER IF EXISTS trg_person_insert_audit ON person;

-- Создаём триггер на таблице person.
-- AFTER INSERT — срабатывает ПОСЛЕ вставки строки.
-- FOR EACH ROW — срабатывает для КАЖДОЙ вставленной строки
--   (а не один раз на весь оператор INSERT).
-- EXECUTE FUNCTION — указывает, какую функцию вызвать.
CREATE TRIGGER trg_person_insert_audit
AFTER INSERT ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_insert_audit();

-- Тестовая вставка. Триггер автоматически запишет копию в person_audit.
INSERT INTO person(id, name, age, gender, address)
VALUES (10, 'Damir', 22, 'male', 'Irkutsk');

-- Проверяем: в person_audit должна появиться одна строка
-- с type_event = 'I' и данными Дамира.
SELECT * FROM person_audit;
```

---

## Альтернативные варианты написания

**1. `RETURN NULL` vs `RETURN NEW`**

```sql
-- Оба варианта работают одинаково для AFTER-триггера:
RETURN NULL;  -- каноничный вариант: честно показывает, что значение не используется
RETURN NEW;   -- тоже работает, но вводит в заблуждение — будто значение важно
```

**2. Без явной передачи `created` и `type_event`**

```sql
-- Можно положиться на DEFAULT-значения:
INSERT INTO person_audit(row_id, name, age, gender, address)
VALUES (NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);
-- Результат тот же, но менее очевидно, ЧТО записывается.
```

**3. `$$` вместо `$BODY$`**

```sql
-- Оба варианта — долларное квотирование, разницы нет:
CREATE FUNCTION ... AS $BODY$ ... $BODY$ LANGUAGE plpgsql;
CREATE FUNCTION ... AS $$ ... $$ LANGUAGE plpgsql;
-- $BODY$ читабельнее, $$ — короче. Дело вкуса.
```

**4. `EXECUTE FUNCTION` vs `EXECUTE PROCEDURE`**

```sql
-- В PostgreSQL 11+ правильно:
EXECUTE FUNCTION fnc_trg_person_insert_audit();
-- В старых версиях (до 11) использовалось:
EXECUTE PROCEDURE fnc_trg_person_insert_audit();
-- Оба работают в современном PostgreSQL, но FUNCTION — актуальный вариант.
```

**5. Таблица без именованного CONSTRAINT**

```sql
-- Можно без имени — PostgreSQL сгенерирует имя сам:
CHECK (type_event IN ('I', 'U', 'D'))
-- Но задание ЯВНО требует имя ch_type_event, поэтому так делать не стоит.
```

---

## Возможные вопросы на защите

**Q: Зачем нужен аудит на уровне БД, если можно логировать в приложении?**
A: Потому что к базе могут подключаться напрямую (через IDE, скрипты, другие сервисы) в обход приложения. Триггер сработает **всегда**, независимо от источника запроса.

**Q: Что такое `NEW` и `OLD`?**
A: Псевдозаписи (pseudo-records). `NEW` — строка после операции (доступна в INSERT/UPDATE). `OLD` — строка до операции (доступна в UPDATE/DELETE). В INSERT нет `OLD` (строки до вставки не существовало), в DELETE нет `NEW` (строка удалена).

**Q: Почему `RETURN NULL`, а не `RETURN NEW`?**
A: Для AFTER-триггеров возвращаемое значение игнорируется PostgreSQL. `RETURN NULL` — семантически честнее. Но `RETURN NEW` тоже сработает без ошибок.

**Q: Что будет, если написать `BEFORE INSERT` вместо `AFTER INSERT`?**
A: Функционально — аудит всё равно запишется. Но при `BEFORE` с `RETURN NULL` триггер **отменит** саму вставку в `person` — строка туда не попадёт. Это критическое отличие.

**Q: Зачем `FOR EACH ROW`? Что будет с `FOR EACH STATEMENT`?**
A: `FOR EACH ROW` — функция вызывается на **каждую** строку. `FOR EACH STATEMENT` — один раз на весь оператор, и в этом случае `NEW`/`OLD` **недоступны** (нельзя узнать, какие конкретно строки затронуты).

**Q: Что такое `$BODY$`?**
A: Долларное квотирование (dollar quoting) — способ обрамления тела функции. Альтернатива обычным кавычкам `'...'`. Внутри `$BODY$...$BODY$` можно свободно использовать апострофы без экранирования.

**Q: Зачем `DROP TABLE IF EXISTS` и `DROP TRIGGER IF EXISTS`?**
A: Идемпотентность — скрипт можно запускать повторно без ошибок. Без них второй запуск упадёт с ошибкой «таблица/триггер уже существует».

**Q: Почему `row_id` типа `BIGINT`, а не `INTEGER`?**
A: Задание явно требует `BIGINT`. На практике это запас на будущее — `INTEGER` вмещает до ~2.1 миллиарда, `BIGINT` — до ~9.2 квинтиллиона (9.2 * 10^18).