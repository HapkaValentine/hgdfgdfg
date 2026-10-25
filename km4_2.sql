-- =====================================================================
-- КМ№4.2. Хранимые процедуры и функции. Вариант «Генератор ID».
-- =====================================================================
-- 0. Очистка (удаление, если существует)
DROP FUNCTION IF EXISTS GET_NEXT_ID (VARCHAR, VARCHAR);

DROP TABLE IF EXISTS TEST2 CASCADE;

DROP TABLE IF EXISTS TEST CASCADE;

DROP TABLE IF EXISTS SPEC CASCADE;

-- 1. Создание спец. таблицы
CREATE TABLE SPEC (
	ID INTEGER PRIMARY KEY,
	TABLE_NAME VARCHAR(100) NOT NULL,
	COLUMN_NAME VARCHAR(100) NOT NULL,
	CURRENT_MAX INTEGER NOT NULL,
	UNIQUE (TABLE_NAME, COLUMN_NAME) -- защита от дублей пар таблица+столбец
);

-- 2. Добавление в спец. таблицу записи (1, spec, id, 1)
INSERT INTO
	SPEC (ID, TABLE_NAME, COLUMN_NAME, CURRENT_MAX)
VALUES
	(1, 'spec', 'id', 1);

-- 3. Создание хранимой функции (ХП)
CREATE OR REPLACE FUNCTION GET_NEXT_ID (P_TABLE_NAME VARCHAR, P_COLUMN_NAME VARCHAR) RETURNS INTEGER AS $$
DECLARE
    v_current_max integer;
    v_new_max integer;
    v_new_id integer;
    v_max_in_target integer;
BEGIN
    -- Ищем запись в спец. таблице и блокируем её (FOR UPDATE) от параллельных изменений
    SELECT current_max INTO v_current_max
    FROM spec
    WHERE table_name = p_table_name AND column_name = p_column_name
    FOR UPDATE;

    IF FOUND THEN
        -- Если запись есть, инкрементируем
        v_new_max := v_current_max + 1;
        UPDATE spec
        SET current_max = v_new_max
        WHERE table_name = p_table_name AND column_name = p_column_name;
    ELSE
        -- Если записи нет, ищем максимум в целевой таблице через динамический SQL
        -- %I экранирует имена таблиц и столбцов, защищая от SQL-инъекций
        EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM %I', p_column_name, p_table_name)
        INTO v_max_in_target;

        v_new_max := v_max_in_target + 1;

        -- РЕКУРСИВНЫЙ ВЫЗОВ: получаем ID для новой записи в таблице spec
        v_new_id := get_next_id('spec', 'id');

        -- Вставляем новую запись в спец. таблицу
        INSERT INTO spec (id, table_name, column_name, current_max)
        VALUES (v_new_id, p_table_name, p_column_name, v_new_max);
    END IF;

    RETURN v_new_max;
END;
$$ LANGUAGE PLPGSQL;

-- =====================================================================
-- ТЕСТИРОВАНИЕ (Шаги 4 - 23)
-- =====================================================================
-- 4. Вызов ХП с параметрами 'spec', 'id'. Должна вернуть 2.
SELECT
	GET_NEXT_ID ('spec', 'id') AS STEP_4;

-- 5. Распечатка содержимого спец. таблицы. Должна быть 1 строка "(1, spec, id, 2)".
SELECT
	*
FROM
	SPEC;

-- 6. Вызов ХП с параметрами 'spec', 'id'. Должна вернуть 3.
SELECT
	GET_NEXT_ID ('spec', 'id') AS STEP_6;

-- 7. Распечатка содержимого спец. таблицы. Должна быть 1 строка "(1, spec, id, 3)".
SELECT
	*
FROM
	SPEC;

-- 8. Создание новой таблицы test с одним столбцом 'id'.
CREATE TABLE TEST (ID INTEGER);

-- 9. Добавление в таблицу test записи (10).
INSERT INTO
	TEST (ID)
VALUES
	(10);

-- 10. Вызов ХП с параметрами 'test', 'id'. Должна вернуть 11.
SELECT
	GET_NEXT_ID ('test', 'id') AS STEP_10;

-- 11. Распечатка спец. таблицы. Должно быть 2 строки: (1, spec, id, 4) и (4, test, id, 11).
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;

-- 12. Вызов ХП с параметрами 'test', 'id'. Должна вернуть 12.
SELECT
	GET_NEXT_ID ('test', 'id') AS STEP_12;

-- 13. Распечатка спец. таблицы. (1, spec, id, 4) и (4, test, id, 12).
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;

-- 14. Создание таблицы test2 со столбцами 'num_value1', 'num_value2'.
CREATE TABLE TEST2 (NUM_VALUE1 INTEGER, NUM_VALUE2 INTEGER);

-- 15. Вызов ХП с параметрами 'test2', 'num_value1'. Должна вернуть 1.
SELECT
	GET_NEXT_ID ('test2', 'num_value1') AS STEP_15;

-- 16. Распечатка спец. таблицы. 3 строки: (1, spec, id, 5) (4, test, id, 12) (5, test2, num_value1, 1).
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;

-- 17. Вызов ХП с параметрами 'test2', 'num_value1'. Должна вернуть 2.
SELECT
	GET_NEXT_ID ('test2', 'num_value1') AS STEP_17;

-- 18. Распечатка спец. таблицы. (1, spec, id, 5) (4, test, id, 12) (5, test2, num_value1, 2).
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;

-- 19. Добавление в test2 записи (2, 13).
INSERT INTO
	TEST2 (NUM_VALUE1, NUM_VALUE2)
VALUES
	(2, 13);

-- 20. Вызов ХП с параметрами 'test2', 'num_value2'. Должна вернуть 14.
SELECT
	GET_NEXT_ID ('test2', 'num_value2') AS STEP_20;

-- 21. Распечатка спец. таблицы. 4 строки.
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;

-- 22. Вызов ХП с параметрами 'test2', 'num_value1' 5 раз.
SELECT
	GET_NEXT_ID ('test2', 'num_value1')
FROM
	GENERATE_SERIES(1, 5);

-- 23. Распечатка спец. таблицы. Значение для test2/num_value1 должно стать 7.
SELECT
	*
FROM
	SPEC
ORDER BY
	ID;