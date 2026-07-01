SET search_path TO dw, source_oltp, public;

INSERT INTO dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d AS full_date,
    EXTRACT(ISODOW FROM d)::SMALLINT AS day_of_week,
    TRIM(TO_CHAR(d, 'Day')) AS day_name,
    EXTRACT(DAY FROM d)::SMALLINT AS day_of_month,
    EXTRACT(DOY FROM d)::SMALLINT AS day_of_year,
    EXTRACT(WEEK FROM d)::SMALLINT AS week_of_year,
    EXTRACT(MONTH FROM d)::SMALLINT AS month_number,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    TO_CHAR(d, 'Mon') AS month_short,
    EXTRACT(QUARTER FROM d)::SMALLINT AS quarter_number,
    'Q' || EXTRACT(QUARTER FROM d)::TEXT AS quarter_name,
    EXTRACT(YEAR FROM d)::INT AS year_number,
    TO_CHAR(d, 'YYYY-MM') AS year_month,
    EXTRACT(ISODOW FROM d) IN (6,7) AS is_weekend,
    FALSE AS is_us_holiday,
    NULL::VARCHAR(50) AS holiday_name
FROM GENERATE_SERIES('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS d
ON CONFLICT (date_key) DO NOTHING;

-- Mark major US holidays
UPDATE dim_date SET is_us_holiday = TRUE, holiday_name = 'New Years Day' WHERE month_number = 1 AND day_of_month = 1;
UPDATE dim_date SET is_us_holiday = TRUE, holiday_name = 'Independence Day' WHERE month_number = 7 AND day_of_month = 4;
UPDATE dim_date SET is_us_holiday = TRUE, holiday_name = 'Christmas' WHERE month_number = 12 AND day_of_month = 25;
