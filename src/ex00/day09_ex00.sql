UPDATE pizzeria
SET rating = 4.6
WHERE name = 'Pizza Hut';


-- Session #1

BEGIN;

UPDATE pizzeria
SET rating = 5
WHERE name = 'Pizza Hut';

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

COMMIT;


-- Session #2

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';

SELECT *
FROM pizzeria
WHERE name = 'Pizza Hut';