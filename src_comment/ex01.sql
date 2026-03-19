CREATE OR REPLACE FUNCTION fnc_trg_person_update_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'U', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_person_update_audit ON person;

CREATE TRIGGER trg_person_update_audit
AFTER UPDATE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_update_audit();

UPDATE person SET name = 'Bulat' WHERE id = 10;
UPDATE person SET name = 'Damir' WHERE id = 10;

SELECT * FROM person_audit;










## Построчный комментарий


-- Создаём (или заменяем) триггерную функцию для аудита UPDATE-операций.
-- OR REPLACE — если функция уже существует, она будет перезаписана
-- без необходимости предварительного DROP.
CREATE OR REPLACE FUNCTION fnc_trg_person_update_audit()
RETURNS TRIGGER AS
$BODY$
BEGIN
    -- При каждом UPDATE в person эта функция записывает
    -- СТАРОЕ состояние строки (OLD) в person_audit.
    -- OLD — псевдозапись, содержащая данные строки ДО изменения.
    -- 'U' — тип события (Update).
    -- Именно OLD, а не NEW, потому что задание требует сохранять
    -- ПРЕДЫДУЩЕЕ состояние — то, что было до обновления.
    INSERT INTO person_audit(created, type_event, row_id, name, age, gender, address)
    VALUES (CURRENT_TIMESTAMP, 'U', OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);

    -- RETURN NULL — для AFTER-триггеров возвращаемое значение
    -- игнорируется PostgreSQL. Это просто синтаксическая формальность.
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;

-- Удаляем старый триггер на UPDATE, если он остался от предыдущего запуска.
-- IF EXISTS — защита от ошибки, если триггера ещё нет.
DROP TRIGGER IF EXISTS trg_person_update_audit ON person;

-- Создаём триггер-наблюдатель на таблице person.
-- AFTER UPDATE — срабатывает ПОСЛЕ обновления строки.
-- FOR EACH ROW — вызывается для КАЖДОЙ обновлённой строки.
CREATE TRIGGER trg_person_update_audit
AFTER UPDATE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_update_audit();

-- Первый UPDATE: меняем имя Дамира на Булат.
-- Триггер срабатывает → в person_audit записывается OLD-состояние:
-- name = 'Damir' (то, что БЫЛО до изменения).
UPDATE person SET name = 'Bulat' WHERE id = 10;

-- Второй UPDATE: меняем имя обратно на Дамир.
-- Триггер срабатывает → в person_audit записывается OLD-состояние:
-- name = 'Bulat' (то, что БЫЛО до этого изменения).
UPDATE person SET name = 'Damir' WHERE id = 10;

-- Проверяем person_audit. Ожидаем увидеть ТРИ строки:
-- 1) type_event='I', name='Damir'  (из ex00 — вставка)
-- 2) type_event='U', name='Damir'  (первый UPDATE — старое значение)
-- 3) type_event='U', name='Bulat'  (второй UPDATE — старое значение)
SELECT * FROM person_audit;
```

---

## Что происходит пошагово

```
Состояние person:  name = 'Damir'
        ↓
UPDATE SET name = 'Bulat'
        ↓
Триггер: записать OLD (name='Damir') в аудит с type_event='U'
        ↓
Состояние person:  name = 'Bulat'
        ↓
UPDATE SET name = 'Damir'
        ↓
Триггер: записать OLD (name='Bulat') в аудит с type_event='U'
        ↓
Состояние person:  name = 'Damir'
```

---

## Альтернативные варианты написания

**1. Сохранять NEW вместо OLD**

```sql
-- Можно записывать НОВОЕ состояние вместо старого:
VALUES (CURRENT_TIMESTAMP, 'U', NEW.id, NEW.name, NEW.age, NEW.gender, NEW.address);
-- Но задание ЯВНО требует "предыдущие состояния (OLD)".
-- К тому же OLD ценнее: новое состояние и так видно в самой таблице person,
-- а вот старое — безвозвратно теряется без аудита.
```

**2. Сохранять и OLD, и NEW**

```sql
-- Можно записывать две строки за раз — и до, и после:
INSERT INTO person_audit(...) VALUES (CURRENT_TIMESTAMP, 'U', OLD.id, OLD.name, ...);
INSERT INTO person_audit(...) VALUES (CURRENT_TIMESTAMP, 'U', NEW.id, NEW.name, ...);
-- Избыточно для этого задания, но встречается в реальных системах.
```

**3. Без явной передачи `created` и `type_event`**

```sql
-- Полагаемся на DEFAULT-значения таблицы:
INSERT INTO person_audit(row_id, name, age, gender, address)
VALUES (OLD.id, OLD.name, OLD.age, OLD.gender, OLD.address);
-- ПРОБЛЕМА: DEFAULT для type_event = 'I', а нам нужен 'U'.
-- Поэтому здесь type_event ОБЯЗАТЕЛЬНО передавать явно!
-- Это важное отличие от ex00, где DEFAULT 'I' совпадал с нужным значением.
```

**4. Один триггер на INSERT и UPDATE сразу**

```sql
-- Можно было объединить уже сейчас:
CREATE TRIGGER trg_person_audit
AFTER INSERT OR UPDATE ON person
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_person_audit();
-- Но задание требует отдельные триггеры в ex00 и ex01.
-- Объединение будет в ex03.
```

---

## Возможные вопросы на защите

**Q: Почему OLD, а не NEW?**
A: Задание требует сохранять **предыдущие** состояния. NEW — это то, что уже записано в таблице `person`, его можно посмотреть в любой момент. А OLD — данные до изменения — без аудита пропадут безвозвратно.

**Q: Что содержит OLD при INSERT?**
A: Ничего — при INSERT строки до операции не существовало, поэтому `OLD` **недоступен**. Попытка обратиться к `OLD` в INSERT-триггере вызовет ошибку. Аналогично, `NEW` недоступен при DELETE.

**Q: Что будет, если UPDATE не изменит ни одной строки?**
A: Триггер **не сработает**. `FOR EACH ROW` означает «для каждой затронутой строки». Если `WHERE id = 10` не найдёт строку (например, Дамир уже удалён), то затронутых строк — ноль, и функция не вызовется.

**Q: Что будет, если UPDATE изменит 1000 строк одним запросом?**
A: Триггер сработает **1000 раз** — по одному разу на каждую строку, потому что указано `FOR EACH ROW`. В `person_audit` появится 1000 новых записей.

**Q: Почему два отдельных триггера (insert + update), а не один?**
A: Потому что задания ex00 и ex01 идут последовательно — сначала учишься делать по частям, потом объединяешь в ex03. Это методический приём: от простого к сложному.

**Q: Можно ли определить, какие именно столбцы изменились при UPDATE?**
A: Да, можно сравнить `OLD` и `NEW` поле за полем: `IF OLD.name != NEW.name THEN ...`. В нашем задании это не требуется — мы записываем всю строку целиком.

**Q: Зачем `DROP TRIGGER IF EXISTS` перед `CREATE TRIGGER`?**
A: В отличие от функций, для триггеров **нет** синтаксиса `CREATE OR REPLACE TRIGGER` (он появился только в PostgreSQL 14+). Поэтому нужно сначала удалить старый, потом создать новый.