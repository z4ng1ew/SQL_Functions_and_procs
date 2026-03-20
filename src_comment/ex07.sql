DROP FUNCTION IF EXISTS func_minimum(VARIADIC NUMERIC[]);

CREATE OR REPLACE FUNCTION func_minimum(VARIADIC arr NUMERIC[])
RETURNS NUMERIC AS
$$
    SELECT MIN(val) FROM UNNEST(arr) AS nums(val);
$$
LANGUAGE SQL;

SELECT func_minimum(VARIADIC arr => ARRAY[10.0, -1.0, 5.0, 4.4]);














## Суть задания

Нужно написать функцию `func_minimum`, которая принимает массив чисел и возвращает минимальное значение из него. Задание даёт выбор: SQL или PL/pgSQL. Ключевая новая концепция — `VARIADIC` (переменное число аргументов, как `va_list` в Си).

---

## Построчный комментарий


-- Удаляем старую версию функции, если она есть.
-- VARIADIC NUMERIC[] — указываем полную сигнатуру,
-- чтобы PostgreSQL точно знал, какую функцию удалять
-- (из-за перегрузки — overloading).
DROP FUNCTION IF EXISTS func_minimum(VARIADIC NUMERIC[]);

-- Создаём SQL-функцию (не PL/pgSQL — задание даёт выбор,
-- SQL проще и эффективнее для этой задачи).
-- VARIADIC — ключевое слово, позволяющее передавать
-- переменное число аргументов. PostgreSQL автоматически
-- собирает их в массив arr.
-- Аналог в Си: va_list / ... (многоточие в параметрах функции).
-- NUMERIC[] — тип «массив чисел». Квадратные скобки [] означают массив.
CREATE OR REPLACE FUNCTION func_minimum(VARIADIC arr NUMERIC[])

-- Функция возвращает одно число типа NUMERIC.
RETURNS NUMERIC AS
$$
    -- UNNEST(arr) — разворачивает массив в набор строк:
    --   [10.0, -1.0, 5.0, 4.4] → четыре отдельных строки.
    -- AS nums(val) — алиасы (псевдонимы):
    --   nums — имя виртуальной таблицы,
    --   val — имя столбца в ней.
    -- MIN(val) — агрегатная функция, находит минимальное значение
    --   среди всех строк.
    SELECT MIN(val) FROM UNNEST(arr) AS nums(val);
$$
-- LANGUAGE SQL — чистый SQL. Нет BEGIN/END, нет переменных.
-- PostgreSQL может встроить (inline) тело функции
-- в вызывающий запрос для оптимизации.
LANGUAGE SQL;

-- Проверка. VARIADIC arr => ARRAY[10.0, -1.0, 5.0, 4.4] —
-- передаём именованный аргумент ("МАСИИВ").
-- => — синтаксис именованного аргумента (альтернатива :=).
-- Ожидаем: -1.0
SELECT func_minimum(VARIADIC arr => ARRAY[10.0, -1.0, 5.0, 4.4]);
```

---

## Порядок выполнения

```
1. DROP FUNCTION IF EXISTS
   → Удаляет старую func_minimum (если была).

2. CREATE OR REPLACE FUNCTION
   → Регистрирует функцию в каталоге pg_proc.

3. SELECT func_minimum(VARIADIC arr => ARRAY[10.0, -1.0, 5.0, 4.4])
   → PostgreSQL берёт массив [10.0, -1.0, 5.0, 4.4]
   → UNNEST разворачивает его в 4 строки: 10.0, -1.0, 5.0, 4.4
   → MIN находит минимум: -1.0
   → Возвращает -1.0
```

---

## Альтернативные варианты написания

**1. PL/pgSQL вместо SQL**

```sql
CREATE FUNCTION func_minimum(VARIADIC arr NUMERIC[])
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT MIN(val) FROM UNNEST(arr) AS val);
END;
$$ LANGUAGE plpgsql;
-- Работает, но избыточно: BEGIN/END/RETURN не нужны
-- для одного SELECT. PostgreSQL не сможет встроить (inline)
-- PL/pgSQL-функцию в вызывающий запрос.
```

**2. Без UNNEST — через цикл PL/pgSQL**

```sql
CREATE FUNCTION func_minimum(VARIADIC arr NUMERIC[])
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
    element NUMERIC;
BEGIN
    result := arr[1];  -- первый элемент массива
    FOREACH element IN ARRAY arr LOOP
        IF element < result THEN
            result := element;
        END IF;
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;
-- Ручная реализация поиска минимума через цикл.
-- Как в Си: перебор массива с хранением текущего минимума.
-- Работает, но зачем, если есть MIN() + UNNEST()?
```

**3. Без VARIADIC — обычный массив**

```sql
CREATE FUNCTION func_minimum(arr NUMERIC[])
RETURNS NUMERIC AS $$
    SELECT MIN(val) FROM UNNEST(arr) AS nums(val);
$$ LANGUAGE SQL;

-- Вызов отличается:
SELECT func_minimum(ARRAY[10.0, -1.0, 5.0, 4.4]);
-- Без VARIADIC нельзя вызвать так:
-- SELECT func_minimum(10.0, -1.0, 5.0, 4.4);  -- ОШИБКА
```

**4. Другие алиасы для UNNEST**

```sql
-- Все три варианта дают одинаковый результат:
SELECT MIN(val) FROM UNNEST(arr) AS nums(val);    -- таблица nums, столбец val
SELECT MIN(val) FROM UNNEST(arr) AS val;           -- таблица и столбец — val
SELECT MIN(i)   FROM UNNEST(arr) AS g(i);          -- таблица g, столбец i (как в чеклисте)
```

**5. `=>` vs `:=` при вызове**

```sql
-- Два синтаксиса именованных аргументов — оба работают:
SELECT func_minimum(VARIADIC arr => ARRAY[10.0, -1.0, 5.0, 4.4]);
SELECT func_minimum(VARIADIC arr := ARRAY[10.0, -1.0, 5.0, 4.4]);
-- => — новый стиль (PostgreSQL 9.5+)
-- := — старый стиль (совместимость)
```

**6. Позиционный вызов без имени параметра**

```sql
SELECT func_minimum(VARIADIC ARRAY[10.0, -1.0, 5.0, 4.4]);
-- Без arr => — передаём массив по позиции.
-- Работает, но менее читабельно.
```

---

## Возможные вопросы на защите

**Q: Что такое VARIADIC?**
A: Ключевое слово, позволяющее функции принимать переменное число аргументов. PostgreSQL автоматически собирает их в массив. Аналог `...` (многоточие, ellipsis) и `va_list` в Си. Без VARIADIC можно передать только готовый массив, с VARIADIC — можно перечислять значения через запятую: `func_minimum(10.0, -1.0, 5.0)`.

**Q: Что такое UNNEST?**
A: Функция, которая разворачивает массив в набор строк. Название: UN (раз-) + NEST (вложенность) = «развернуть вложенную структуру». Нужна потому, что SQL-функции вроде MIN работают со строками, а не с массивами.

**Q: Почему SQL, а не PL/pgSQL?**
A: Задание даёт выбор. SQL проще (одна строка вместо BEGIN/END/RETURN) и эффективнее (PostgreSQL может встроить SQL-функцию в вызывающий запрос). Для одного SELECT нет смысла использовать процедурный язык.

**Q: Что будет, если передать пустой массив?**
A: `UNNEST` вернёт ноль строк. `MIN` от пустого набора вернёт `NULL`. Ошибки не будет.

**Q: Что будет, если в массиве есть NULL?**
A: `MIN` игнорирует NULL-значения. `ARRAY[10.0, NULL, 5.0]` вернёт `5.0`.

**Q: Можно ли вызвать без VARIADIC?**
A: Да, перечислив числа через запятую:
```sql
SELECT func_minimum(10.0, -1.0, 5.0, 4.4);
-- PostgreSQL сам соберёт их в массив благодаря VARIADIC.
```

**Q: Зачем `=>` в вызове?**
A: Это синтаксис именованного аргумента. `arr => ARRAY[...]` — передаём значение параметру `arr` по имени. Альтернатива — позиционная передача без имени.

**Q: Что значит `NUMERIC[]`?**
A: Массив чисел типа NUMERIC. Квадратные скобки `[]` обозначают массив в PostgreSQL. `NUMERIC` — числовой тип с произвольной точностью (может хранить как целые, так и дробные числа).