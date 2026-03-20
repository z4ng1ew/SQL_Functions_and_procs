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
SELECT * FROM fnc_fibonacci(20);