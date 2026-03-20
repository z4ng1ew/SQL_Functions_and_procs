DROP FUNCTION IF EXISTS fnc_fibonacci(INTEGER);

CREATE OR REPLACE FUNCTION fnc_fibonacci(pstop INTEGER DEFAULT 10)
RETURNS TABLE (fib_number_column_name BIGINT) AS
$$
    WITH RECURSIVE fib(cur, nxt) AS (
        SELECT 0::BIGINT AS cur, 1::BIGINT AS nxt
        UNION ALL
        SELECT nxt, cur + nxt FROM fib WHERE nxt < pstop
    )
    SELECT cur FROM fib;
$$
LANGUAGE SQL;

SELECT * FROM fnc_fibonacci(100);
SELECT * FROM fnc_fibonacci();



У тебя в загруженном документе уже есть полный разбор этого задания — суть, построчный комментарий, порядок выполнения, альтернативы и вопросы на защите. Но в самом коде стоит `fib_number_column_name` вместо `a`. Исправь на `a`, чтобы совпадало с чеклистом:

```sql
RETURNS TABLE (a BIGINT) AS
```

Всё остальное в разборе из документа полностью актуально для твоего решения. Хочешь, чтобы я разобрал что-то конкретное подробнее?