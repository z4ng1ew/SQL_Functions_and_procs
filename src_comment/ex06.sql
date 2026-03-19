DROP FUNCTION IF EXISTS fnc_person_visits_and_eats_on_date(VARCHAR, NUMERIC, DATE);

CREATE OR REPLACE FUNCTION fnc_person_visits_and_eats_on_date(
    pperson VARCHAR DEFAULT 'Dmitriy',
    pprice  NUMERIC DEFAULT 500,
    pdate   DATE DEFAULT '2022-01-08'
)
RETURNS TABLE (name VARCHAR) AS
$$
BEGIN
    RETURN QUERY
    SELECT piz.name AS pizzeria_name
    FROM menu AS mn
        INNER JOIN pizzeria AS piz ON piz.id = mn.pizzeria_id
        INNER JOIN person_visits AS vis ON mn.pizzeria_id = vis.pizzeria_id
        INNER JOIN person AS pr ON pr.id = vis.person_id
    WHERE mn.price < pprice
      AND pr.name = pperson
      AND vis.visit_date = pdate
    ORDER BY piz.name DESC;  
END;
$$
LANGUAGE plpgsql;

SELECT * FROM fnc_person_visits_and_eats_on_date(pprice := 800);
SELECT * FROM fnc_person_visits_and_eats_on_date(pperson := 'Anna', pprice := 1300, pdate := '2022-01-01');





## Суть задания

Нужно создать PL/pgSQL-функцию, которая принимает три параметра (имя человека, максимальная цена, дата) и возвращает названия пиццерий, где этот человек побывал в указанный день и где есть пицца дешевле указанной суммы. Это первая функция в проекте, которая объединяет данные из **четырёх таблиц** и использует PL/pgSQL вместо чистого SQL.

---

## Построчный комментарий


-- Удаляем старую версию функции, если она есть.
-- (VARCHAR, NUMERIC, DATE) — указываем сигнатуру,
-- чтобы PostgreSQL точно знал, какую функцию удалять
-- (из-за перегрузки функций — overloading).
DROP FUNCTION IF EXISTS fnc_person_visits_and_eats_on_date(VARCHAR, NUMERIC, DATE);

-- Создаём PL/pgSQL-функцию с тремя входными параметрами.
-- OR REPLACE — если функция уже есть, перезаписать.
CREATE OR REPLACE FUNCTION fnc_person_visits_and_eats_on_date(
    -- pperson — имя человека. По умолчанию 'Dmitriy'.
    pperson VARCHAR DEFAULT 'Dmitriy',
    -- pprice — максимальная цена пиццы. По умолчанию 500.
    -- NUMERIC — числовой тип с произвольной точностью (в отличие от
    -- INTEGER, может хранить дробные значения вроде 499.99).
    pprice  NUMERIC DEFAULT 500,
    -- pdate — дата посещения. По умолчанию 8 января 2022.
    pdate   DATE DEFAULT '2022-01-08'
)
-- Функция возвращает набор строк с одним столбцом name типа VARCHAR.
RETURNS TABLE (name VARCHAR) AS
$$
BEGIN
    -- RETURN QUERY — конструкция PL/pgSQL, которая говорит:
    -- «выполни этот SELECT и верни результат как набор строк».
    -- В SQL-функции (LANGUAGE SQL) этого не нужно — там SELECT
    -- возвращает результат сам. В PL/pgSQL — нужно явно.
    RETURN QUERY

    -- Основной запрос: соединяем 4 таблицы.
    SELECT piz.name AS pizzeria_name
    -- menu — таблица с пиццами и ценами.
    FROM menu AS mn
        -- Соединяем с pizzeria, чтобы получить название пиццерии.
        -- mn.pizzeria_id → piz.id
        INNER JOIN pizzeria AS piz ON piz.id = mn.pizzeria_id
        -- Соединяем с person_visits, чтобы узнать, кто посещал эту пиццерию.
        -- Связь через pizzeria_id: пиццерия из меню = пиццерия из визита.
        INNER JOIN person_visits AS vis ON mn.pizzeria_id = vis.pizzeria_id
        -- Соединяем с person, чтобы узнать имя посетителя.
        -- vis.person_id → pr.id
        INNER JOIN person AS pr ON pr.id = vis.person_id
    -- Три условия фильтрации:
    WHERE mn.price < pprice       -- цена пиццы строго меньше указанной
      AND pr.name = pperson       -- имя посетителя совпадает с параметром
      AND vis.visit_date = pdate; -- дата визита совпадает с параметром
    ORDER BY piz.name DESC;    -- СОРТИРОВКА ПО УБЫВАНИЮ
END;
$$
-- LANGUAGE plpgsql — задание явно требует PL/pgSQL, не SQL.
-- В отличие от ex04/ex05, здесь нужен BEGIN/END и RETURN QUERY.
LANGUAGE plpgsql;

-- ============================================================
-- Проверка
-- ============================================================

-- Вызов с одним параметром. Остальные берутся из DEFAULT:
-- pperson = 'Dmitriy' (DEFAULT), pprice = 800, pdate = '2022-01-08' (DEFAULT).
-- Ожидаем: "Papa Johns", "DoDo Pizza"
SELECT * FROM fnc_person_visits_and_eats_on_date(pprice := 800);

-- Вызов со всеми тремя параметрами.
-- Ожидаем: четыре строки "Pizza Hut"
-- (дубликаты из-за нескольких пунктов меню дешевле 1300 в Pizza Hut).
SELECT * FROM fnc_person_visits_and_eats_on_date(pperson := 'Anna', pprice := 1300, pdate := '2022-01-01');
```

---

## Порядок выполнения

```
1. DROP FUNCTION IF EXISTS
   → Удаляет старую версию функции (если была).

2. CREATE OR REPLACE FUNCTION
   → Регистрирует функцию в каталоге pg_proc.
     Функция ждёт вызова.

3. SELECT * FROM fnc_person_visits_and_eats_on_date(pprice := 800)
   → PostgreSQL подставляет параметры:
     pperson = 'Dmitriy' (DEFAULT)
     pprice = 800
     pdate = '2022-01-08' (DEFAULT)
   → Выполняет JOIN четырёх таблиц с этими фильтрами.
   → Возвращает: Papa Johns, DoDo Pizza.

4. SELECT * FROM fnc_person_visits_and_eats_on_date(
       pperson := 'Anna', pprice := 1300, pdate := '2022-01-01')
   → Все три параметра переданы явно.
   → Возвращает: Pizza Hut (×4).
```

---

## Альтернативные варианты написания

**1. SQL-функция вместо PL/pgSQL**

```sql
CREATE FUNCTION fnc_person_visits_and_eats_on_date(...)
RETURNS TABLE (name VARCHAR) AS
$$
    SELECT piz.name
    FROM menu AS mn
        INNER JOIN pizzeria AS piz ON piz.id = mn.pizzeria_id
        INNER JOIN person_visits AS vis ON mn.pizzeria_id = vis.pizzeria_id
        INNER JOIN person AS pr ON pr.id = vis.person_id
    WHERE mn.price < pprice
      AND pr.name = pperson
      AND vis.visit_date = pdate;
$$
LANGUAGE SQL;
-- Работает, но задание ЯВНО требует PL/pgSQL.
-- Нет BEGIN/END и RETURN QUERY — просто голый SELECT.
```

**2. С DISTINCT**

```sql
RETURN QUERY
SELECT DISTINCT piz.name AS pizzeria_name
FROM ...
-- Уберёт дубликаты. Но чеклист ожидает дубликаты
-- (четыре "Pizza Hut"), поэтому DISTINCT не нужен.
```

**3. Другой порядок JOIN**

```sql
-- Можно начать с person, а не с menu:
FROM person AS pr
    INNER JOIN person_visits AS vis ON pr.id = vis.person_id
    INNER JOIN pizzeria AS piz ON vis.pizzeria_id = piz.id
    INNER JOIN menu AS mn ON piz.id = mn.pizzeria_id
-- Результат тот же — оптимизатор PostgreSQL сам выберет
-- оптимальный порядок соединения, независимо от того,
-- как ты написал JOIN.
```

**4. С использованием OUT-параметров вместо RETURNS TABLE**

```sql
CREATE FUNCTION fnc_person_visits_and_eats_on_date(
    pperson VARCHAR DEFAULT 'Dmitriy',
    pprice  NUMERIC DEFAULT 500,
    pdate   DATE DEFAULT '2022-01-08',
    OUT name VARCHAR  -- выходной параметр вместо RETURNS TABLE
)
RETURNS SETOF VARCHAR AS ...
-- Другой синтаксис, тот же результат.
-- RETURNS TABLE читабельнее.
```

---

## Возможные вопросы на защите

**Q: Почему PL/pgSQL, а не SQL-функция?**
A: Задание явно требует PL/pgSQL. Кроме того, PL/pgSQL позволяет добавлять логику — переменные, условия, циклы. В ex04/ex05 хватало чистого SQL, здесь задание намеренно переводит на PL/pgSQL для практики.

**Q: Что такое `RETURN QUERY`?**
A: Конструкция PL/pgSQL, которая выполняет SELECT и добавляет его результат к выходу функции. В SQL-функции SELECT сам возвращает результат, а в PL/pgSQL нужно явно сказать «верни результат этого запроса».

**Q: Почему четыре строки Pizza Hut для Анны?**
A: Потому что JOIN без DISTINCT даёт декартово произведение (Cartesian product — комбинация каждой строки одной таблицы с каждой строкой другой). Анна посетила Pizza Hut один раз, но в меню Pizza Hut четыре пиццы дешевле 1300. Каждая пицца даёт отдельную строку в результате.

**Q: Можно ли добавить DISTINCT?**
A: Можно, но чеклист ожидает дубликаты. Вопрос о DISTINCT — это вопрос бизнес-логики: иногда дубликаты нужны (показывают, сколько вариантов есть), иногда нет.

**Q: Зачем `AS pizzeria_name` в SELECT, если столбец называется `name`?**
A: Это алиас (alias — псевдоним) для читабельности. На результат не влияет — столбец в выводе всё равно называется `name`, как указано в `RETURNS TABLE (name VARCHAR)`. RETURNS TABLE определяет имя столбца в результате, а не алиас внутри запроса.

**Q: Что если передать несуществующее имя?**
A: Функция вернёт **пустой** набор строк. Ошибки не будет — WHERE просто не найдёт совпадений.

**Q: Почему `price < pprice`, а не `price <= pprice`?**
A: Задание говорит «дешевле указанной суммы» — строго меньше. `<=` означало бы «дешевле или равно», что не соответствует формулировке.

**Q: Можно ли вызвать функцию в JOIN?**
A: Да:
```sql
SELECT pr.name, f.name AS pizzeria
FROM person pr
CROSS JOIN LATERAL fnc_person_visits_and_eats_on_date(
    pperson := pr.name, pprice := 500
) f;
-- LATERAL позволяет передавать значения из внешнего запроса
-- в функцию для каждой строки.
```






