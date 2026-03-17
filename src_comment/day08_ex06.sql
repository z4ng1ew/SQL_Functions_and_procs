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
      AND vis.visit_date = pdate;
END;
$$
LANGUAGE plpgsql;

SELECT * FROM fnc_person_visits_and_eats_on_date(pprice := 800);
SELECT * FROM fnc_person_visits_and_eats_on_date(pperson := 'Anna', pprice := 1300, pdate := '2022-01-01');