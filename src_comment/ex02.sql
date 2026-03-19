CREATE OR REPLACE FUNCTION fnc_trg_person_delete_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'D', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_person_delete_audit ON person;

CREATE TRIGGER trg_person_delete_audit
AFTER DELETE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_delete_audit();

DELETE FROM person WHERE id = 10;

SELECT * FROM person_audit ORDER BY created;













## Построчный комментарий


-- Создаём (или заменяем) триггерную функцию для аудита DELETE-операций.
-- OR REPLACE — если функция уже есть, перезаписываем без DROP.
CREATE OR REPLACE FUNCTION fnc_trg_person_delete_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    -- При DELETE из person записываем СТАРОЕ состояние строки (OLD)
    -- в таблицу аудита. OLD — единственный доступный вариант при DELETE,
    -- потому что NEW не существует (строка удалена, «нового» состояния нет).
    -- 'D' — тип события (Delete).
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'D', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    -- RETURN NULL — AFTER-триггер, возвращаемое значение игнорируется.
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

-- Удаляем старый триггер на DELETE, если остался от прошлого запуска.
DROP TRIGGER IF EXISTS trg_person_delete_audit ON person;

-- Создаём триггер-наблюдатель: после каждого DELETE из person
-- вызывать функцию fnc_trg_person_delete_audit.
CREATE TRIGGER trg_person_delete_audit
AFTER DELETE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_delete_audit();

-- Удаляем Дамира из person.
-- Триггер срабатывает → OLD-состояние (Дамир, 22, male, Irkutsk)
-- автоматически записывается в person_audit с type_event = 'D'.
DELETE FROM person WHERE id = 10;

-- Проверяем всю историю аудита, отсортированную по времени.
-- ORDER BY created — чтобы события шли в хронологическом порядке.
-- Ожидаем 4 строки (если ex00 и ex01 были выполнены ранее):
--   1) 'I' — Damir  (вставка из ex00)
--   2) 'U' — Damir  (первый UPDATE из ex01, OLD-состояние)
--   3) 'U' — Bulat  (второй UPDATE из ex01, OLD-состояние)
--   4) 'D' — Damir  (удаление из ex02, OLD-состояние)
SELECT * FROM person_audit ORDER BY created;
```

---

## Порядок выполнения

```
1. CREATE OR REPLACE FUNCTION fnc_trg_person_delete_audit()
   → Функция зарегистрирована в каталоге pg_proc. Ждёт вызова.

2. DROP TRIGGER IF EXISTS trg_person_delete_audit ON person
   → Если старый триггер был — удалён. Если нет — ничего не происходит.

3. CREATE TRIGGER trg_person_delete_audit AFTER DELETE ON person
   → Наблюдатель повешен на таблицу person.
     Теперь любой DELETE из person вызовет функцию из шага 1.

4. DELETE FROM person WHERE id = 10
   → PostgreSQL удаляет строку Дамира из person.
   → Видит триггер на DELETE → вызывает функцию.
   → Функция берёт OLD (Damir, 22, male, Irkutsk)
     и вставляет копию в person_audit с type_event = 'D'.
   → Дамира в person больше нет, но его данные сохранены в аудите.

5. SELECT * FROM person_audit ORDER BY created
   → Выводим всю историю изменений в хронологическом порядке.
```

---

## Альтернативные варианты написания

**1. Без явной передачи `created` и `type_event`**

```sql
INSERT INTO person_audit(type_event, row_id, name, age, gender, address)
VALUES ('D', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);
-- created заполнится через DEFAULT. Работает, но менее явно.
-- type_event передавать ОБЯЗАТЕЛЬНО, потому что DEFAULT = 'I', а нам нужен 'D'.
```

**2. `RETURN OLD` вместо `RETURN NULL`**

```sql
RETURN OLD;
-- Для AFTER-триггера разницы нет — значение игнорируется.
-- Но RETURN NULL семантически точнее: явно показывает,
-- что возвращать здесь нечего.
```

**3. Без `ORDER BY created`**

```sql
SELECT * FROM person_audit;
-- Без ORDER BY PostgreSQL НЕ гарантирует порядок строк.
-- Может показать в любой последовательности.
-- ORDER BY created гарантирует хронологический порядок.
```

**4. `BEFORE DELETE` вместо `AFTER DELETE`**

```sql
CREATE TRIGGER trg_person_delete_audit
BEFORE DELETE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_delete_audit();
-- Технически тоже сработает — OLD доступен и в BEFORE.
-- НО: если функция вернёт NULL в BEFORE-триггере,
-- DELETE будет ОТМЕНЁН — строка останется в person.
-- Поэтому AFTER безопаснее для аудита.
```

---

## Возможные вопросы на защите

**Q: Почему OLD, а не NEW?**
A: При DELETE строка **уничтожается**. `NEW` не существует — нет «нового состояния» удалённой строки. Доступен только `OLD` — данные, которые были до удаления.

**Q: Что будет, если `DELETE FROM person WHERE id = 10` не найдёт строку?**
A: Триггер **не сработает**. `FOR EACH ROW` — для каждой **затронутой** строки. Если ни одна строка не удалена, функция не вызовется, в `person_audit` ничего не добавится.

**Q: Сейчас на таблице `person` висят три триггера (insert, update, delete). В каком порядке они срабатывают?**
A: Каждый срабатывает только на **своё** событие. INSERT-триггер не реагирует на DELETE, и наоборот. Они не конфликтуют. Если бы на одно событие висело несколько триггеров, PostgreSQL выполнял бы их в алфавитном порядке по имени.

**Q: Зачем `ORDER BY created` в финальном SELECT?**
A: Без ORDER BY реляционная СУБД (РСУБД — система управления реляционными базами данных) **не гарантирует** порядок строк. Даже если сейчас строки идут хронологически, при другом плане запроса или после VACUUM (процесс очистки «мёртвых» строк в PostgreSQL) порядок может измениться.

**Q: Можно ли восстановить удалённого Дамира из `person_audit`?**
A: Да, именно для этого аудит и нужен:
```sql
INSERT INTO person(id, name, age, gender, address)
SELECT row_id, name, age, gender, address
FROM person_audit
WHERE row_id = 10 AND type_event = 'D'
ORDER BY created DESC
LIMIT 1;
```

**Q: Что будет в ex03?**
A: Все три триггера и функции будут удалены и заменены одним универсальным триггером с `IF-ELSE` по `TG_OP`. Это рефакторинг — устранение дублирования кода.









