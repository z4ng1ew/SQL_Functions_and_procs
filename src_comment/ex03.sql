DROP TRIGGER IF EXISTS trg_person_insert_audit ON person;
DROP TRIGGER IF EXISTS trg_person_update_audit ON person;
DROP TRIGGER IF EXISTS trg_person_delete_audit ON person;

DROP FUNCTION IF EXISTS fnc_trg_person_insert_audit();
DROP FUNCTION IF EXISTS fnc_trg_person_update_audit();
DROP FUNCTION IF EXISTS fnc_trg_person_delete_audit();

TRUNCATE person_audit;

CREATE OR REPLACE FUNCTION fnc_trg_person_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'I', NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);
    ELSEIF (TG_OP = 'UPDATE') THEN
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'U', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);
    ELSE
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'D', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);
    END IF;

    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_person_audit ON person;

CREATE TRIGGER trg_person_audit
AFTER INSERT OR UPDATE OR DELETE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_audit();

INSERT INTO person(id, name, age, gender, address)
VALUES (10, 'Damir', 22, 'male', 'Irkutsk');

UPDATE person SET name = 'Bulat' WHERE id = 10;
UPDATE person SET name = 'Damir' WHERE id = 10;

DELETE FROM person WHERE id = 10;

SELECT * FROM person_audit ORDER BY created;









## Построчный комментарий


-- ============================================================
-- ЧАСТЬ 1: Очистка старых объектов из ex00, ex01, ex02
-- ============================================================

-- Удаляем три отдельных триггера с таблицы person.
-- Сначала триггеры, потом функции — потому что триггер
-- ссылается на функцию, и PostgreSQL не даст удалить функцию,
-- пока на неё есть зависимость.
DROP TRIGGER IF EXISTS trg_person_insert_audit ON person;
DROP TRIGGER IF EXISTS trg_person_update_audit ON person;
DROP TRIGGER IF EXISTS trg_person_delete_audit ON person;

-- Теперь безопасно удаляем три старые триггерные функции.
DROP FUNCTION IF EXISTS fnc_trg_person_insert_audit();
DROP FUNCTION IF EXISTS fnc_trg_person_update_audit();
DROP FUNCTION IF EXISTS fnc_trg_person_delete_audit();

-- Очищаем таблицу аудита.
-- TRUNCATE — мгновенная очистка всей таблицы.
-- Не обрабатывает строки по одной (в отличие от DELETE),
-- не пишет каждую строку в WAL (Write-Ahead Log — журнал предзаписи),
-- не вызывает триггеры на DELETE.
TRUNCATE person_audit;

-- ============================================================
-- ЧАСТЬ 2: Универсальная функция и триггер
-- ============================================================

-- Одна функция заменяет три из ex00–ex02.
-- OR REPLACE — перезаписывает функцию, если она уже существует.
CREATE OR REPLACE FUNCTION fnc_trg_person_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    -- TG_OP — специальная переменная PostgreSQL, доступная
    -- только внутри триггерных функций. Содержит строку:
    -- 'INSERT', 'UPDATE' или 'DELETE'.

    IF (TG_OP = 'INSERT') THEN
        -- INSERT: используем NEW — данные новой строки.
        -- OLD при INSERT не существует (строки до вставки не было).
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'I', NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);

    ELSEIF (TG_OP = 'UPDATE') THEN
        -- UPDATE: используем OLD — данные строки ДО изменения.
        -- Задание требует сохранять именно предыдущее состояние.
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'U', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    ELSEIF (TG_OP = 'DELETE') THEN
        -- DELETE: используем OLD — данные удаляемой строки.
        -- NEW при DELETE не существует (строка уничтожена).
        -- Явная проверка TG_OP = 'DELETE' вместо ELSE —
        -- задание требует «явно определить блоки для каждого события».
        INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
        VALUES (CURRENT_TIMESTAMP, 'D', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    END IF;

    -- RETURN NULL — AFTER-триггер, возвращаемое значение игнорируется.
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

-- Защита от повторного запуска.
DROP TRIGGER IF EXISTS trg_person_audit ON person;

-- Один триггер на все три события.
-- AFTER — срабатывает после выполнения операции.
-- INSERT OR UPDATE OR DELETE — реагирует на любую из трёх.
-- FOR EACH ROW — вызывается для каждой затронутой строки.
CREATE TRIGGER trg_person_audit
AFTER INSERT OR UPDATE OR DELETE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_audit();

-- ============================================================
-- ЧАСТЬ 3: Тестовые DML-операции
-- ============================================================

-- INSERT: вставляем Дамира → триггер → TG_OP='INSERT'
-- → person_audit: 'I', Damir
INSERT INTO person(id, name, age, gender, address)
VALUES (10, 'Damir', 22, 'male', 'Irkutsk');

-- UPDATE #1: Damir→Bulat → триггер → TG_OP='UPDATE'
-- → person_audit: 'U', Damir (OLD — то что БЫЛО)
UPDATE person SET name = 'Bulat' WHERE id = 10;

-- UPDATE #2: Bulat→Damir → триггер → TG_OP='UPDATE'
-- → person_audit: 'U', Bulat (OLD — то что БЫЛО)
UPDATE person SET name = 'Damir' WHERE id = 10;

-- DELETE: удаляем Дамира → триггер → TG_OP='DELETE'
-- → person_audit: 'D', Damir (OLD — данные перед удалением)
DELETE FROM person WHERE id = 10;

-- Проверяем: 4 строки в хронологическом порядке.
-- ORDER BY created — гарантирует порядок по времени.
SELECT * FROM person_audit ORDER BY created;
```

---

## Порядок выполнения

```
 1. DROP TRIGGER (×3)      → Старые триггеры удалены с person.
 2. DROP FUNCTION (×3)     → Старые функции удалены из каталога.
 3. TRUNCATE person_audit  → Таблица аудита пуста.
 4. CREATE FUNCTION        → Универсальная функция зарегистрирована в pg_proc.
 5. DROP TRIGGER IF EXISTS → Страховка: удаляем trg_person_audit если есть.
 6. CREATE TRIGGER         → Один триггер повешен на person.
 7. INSERT (Damir)         → person: +Damir  → audit: 'I', Damir
 8. UPDATE (→Bulat)        → person: Damir→Bulat → audit: 'U', Damir
 9. UPDATE (→Damir)        → person: Bulat→Damir → audit: 'U', Bulat
10. DELETE                  → person: -Damir → audit: 'D', Damir
11. SELECT                  → Показывает 4 строки из person_audit.
```

---

## Альтернативные варианты написания

**1. `ELSE` вместо `ELSEIF (TG_OP = 'DELETE')`**

```sql
ELSE
    INSERT INTO person_audit(...) VALUES (..., 'D', OLD...);
END IF;
-- Логически эквивалентно: других событий кроме DELETE быть не может.
-- Но задание просит явные блоки для каждого события —
-- поэтому ELSEIF с проверкой точнее соответствует требованию.
```

**2. Три отдельных IF вместо IF-ELSEIF**

```sql
IF (TG_OP = 'INSERT') THEN ... END IF;
IF (TG_OP = 'UPDATE') THEN ... END IF;
IF (TG_OP = 'DELETE') THEN ... END IF;
-- Работает, но неэффективно: проверяет ВСЕ три условия каждый раз,
-- даже когда первое уже сработало. ELSEIF останавливается
-- на первом совпадении.
```

**3. CASE вместо IF-ELSEIF**

```sql
CASE TG_OP
    WHEN 'INSERT' THEN ...
    WHEN 'UPDATE' THEN ...
    WHEN 'DELETE' THEN ...
END CASE;
-- В PL/pgSQL CASE не может содержать INSERT-операторы напрямую.
-- Пришлось бы оборачивать в EXECUTE — усложняет без пользы.
-- Задание просит IF-ELSE, поэтому CASE здесь неуместен.
```

**4. `DELETE FROM person_audit` вместо `TRUNCATE`**

```sql
DELETE FROM person_audit;
-- Работает, но медленнее: построчная обработка + запись в WAL.
-- Также DELETE вызвал бы триггеры на person_audit (если бы они были).
-- Задание предлагает TRUNCATE — лучше следовать рекомендации.
```

**5. `CASCADE` при удалении функций**

```sql
DROP FUNCTION fnc_trg_person_insert_audit() CASCADE;
-- CASCADE автоматически удалит зависимые триггеры.
-- Тогда отдельные DROP TRIGGER не нужны.
-- Но опасно: можно случайно удалить что-то лишнее.
-- Явное удаление триггеров → функций безопаснее и читабельнее.
```

---

## Возможные вопросы на защите

**Q: Почему один триггер лучше трёх?**
A: Меньше объектов в базе — проще поддерживать. Изменение логики аудита требует правки одной функции вместо трёх. Меньше риск рассинхронизации: если обновить две функции из трёх, третья останется с устаревшей логикой.

**Q: Что такое `TG_OP` и какие ещё специальные переменные доступны в триггерах?**
A: `TG_OP` — тип операции (`'INSERT'`, `'UPDATE'`, `'DELETE'`). Другие: `TG_NAME` — имя триггера, `TG_TABLE_NAME` — имя таблицы, `TG_WHEN` — `'BEFORE'` или `'AFTER'`, `TG_LEVEL` — `'ROW'` или `'STATEMENT'`. Все заполняются PostgreSQL автоматически.

**Q: Почему `ELSEIF`, а не `ELSE` для DELETE?**
A: Задание требует «явно определить отдельные блоки IF-ELSE для каждого события». ELSEIF с явной проверкой `TG_OP = 'DELETE'` соответствует этому требованию точнее. ELSE тоже работает, но DELETE не проверяется явно.

**Q: Что если в IF не сработает ни одна ветка?**
A: Если TG_OP не совпадёт ни с одной проверкой, ни один INSERT в аудит не выполнится. Функция просто вернёт NULL. На практике это невозможно — триггер привязан к INSERT/UPDATE/DELETE, других значений TG_OP не бывает.

**Q: Зачем `TRUNCATE`, а не `DELETE`?**
A: TRUNCATE быстрее (не обрабатывает строки по одной), не пишет в WAL построчно, не вызывает триггеры. Задание явно предлагает TRUNCATE.

**Q: Порядок удаления важен? Можно сначала функции, потом триггеры?**
A: Нет. Триггер ссылается на функцию. PostgreSQL не даст удалить функцию, пока существует зависимый триггер (без CASCADE). Правильный порядок: сначала триггеры, потом функции.

**Q: `TRUNCATE person` сработает через этот триггер?**
A: Нет. Триггер привязан к INSERT/UPDATE/DELETE. TRUNCATE — отдельное событие, требует отдельного `AFTER TRUNCATE` триггера (и только `FOR EACH STATEMENT`, не `FOR EACH ROW`).

**Q: Что произойдёт при `UPDATE person SET age = 23 WHERE id > 5`?**
A: Триггер сработает **для каждой** строки с id > 5 (из-за `FOR EACH ROW`). Если UPDATE затронет 3 строки — в person_audit появится 3 записи с type_event = 'U'.