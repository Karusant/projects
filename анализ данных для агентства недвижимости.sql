/* Проект : анализ данных для агентства недвижимости
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


--Время активности объявлений

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_flats AS (
    SELECT id
    FROM real_estate.flats
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
filtered_ads AS (
    SELECT
        a.id AS ad_id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.id AS flat_id,
        f.city_id,
        f.type_id,
        f.total_area,
        f.rooms,
        f.ceiling_height,
        f.floors_total,
        f.living_area,
        f.floor,
        f.is_apartment,
        f.balcony,
        c.city,
        t.type
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE f.id IN (SELECT id FROM filtered_flats)  -- Фильтрация аномальных значений
),
categorized_ads AS (
    SELECT
        ad_id,
        flat_id,
        last_price,
        total_area,
        rooms,
        balcony,
        CASE
            WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        CASE
            WHEN days_exposition BETWEEN 1 AND 30 THEN '1 месяц'
            WHEN days_exposition BETWEEN 31 AND 90 THEN '3 месяца'
            WHEN days_exposition BETWEEN 91 AND 180 THEN '6 месяцев'
            ELSE 'более 6 месяцев'
        END AS activity_category
    FROM filtered_ads
    WHERE TYPE='город' AND days_exposition IS NOT NULL -----фильтр только для городов лен-обл и исключение не снятых объявлений
),
final_analysis AS (
    SELECT
        region,
        activity_category,
        COUNT(*) AS ad_count,
        AVG(last_price / total_area) AS avg_price_per_sqm,
        AVG(total_area) AS avg_total_area,
        AVG(rooms) AS avg_rooms,
        AVG(balcony) AS avg_balcony
    FROM categorized_ads
    GROUP BY
        region,
        activity_category
)
SELECT
    region,
    activity_category,
    ad_count,
    ROUND(avg_price_per_sqm::numeric, 2) AS avg_price_per_sqm,
    ROUND(avg_total_area::numeric, 2) AS avg_total_area,
    ROUND(avg_rooms::numeric, 2) AS avg_rooms,
    ROUND(avg_balcony::numeric, 2) AS avg_balcony
FROM final_analysis
ORDER BY region, activity_category;


-- Сезонность объявлений

WITH ad_dat AS (
    SELECT
        f.id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS removal_month,
        a.last_price,
        f.total_area
    FROM real_estate.advertisement AS a
    FULL JOIN real_estate.flats AS f ON a.id = f.id
    FULL JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE type='город'
),
limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
-- Анализ публикаций
SELECT
    publication_month,
    COUNT(*) AS publication_count
FROM ad_dat
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY publication_month
ORDER BY publication_count DESC;
-- Анализ снятия объявлений
SELECT
    removal_month,
    COUNT(*) AS removal_count
FROM ad_dat
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY removal_month
ORDER BY removal_count DESC;



-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- Извлечение месяцев публикации и снятия объявлений
WITH ad_dat AS (
    SELECT
        f.id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS removal_month,
        a.last_price,
        f.total_area
    FROM real_estate.advertisement AS a
    FULL JOIN real_estate.flats AS f ON a.id = f.id
    FULL JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE type='город'
),
limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
            )
-- Сравнение активности публикации и снятия
SELECT
    publication_month,
    removal_month,
    COUNT(*) AS activity_count
FROM ad_dat
WHERE publication_month = removal_month AND id IN (SELECT * FROM filtered_id)
GROUP BY publication_month, removal_month
ORDER BY activity_count DESC;



-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Извлечение месяцев публикации и снятия объявлений

WITH ad_dat AS (
    SELECT
        f.id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS removal_month,
        a.last_price,
        f.total_area,
        a.days_exposition
    FROM real_estate.advertisement AS a
    FULL JOIN real_estate.flats AS f ON a.id = f.id
    FULL JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE type='город'
),
limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
            )
-- Анализ влияния сезонности на стоимость и площадь для поданых объявлений
SELECT
    publication_month,
    AVG(last_price / total_area) AS avg_price_per_sqm,
    AVG(total_area) AS avg_area,
    count(id)
FROM ad_dat
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY publication_month
ORDER BY publication_month; 
-- Анализ влияния сезонности на стоимость и площадь для снятых объявлений
SELECT
    publication_month,
    AVG(last_price / total_area) AS avg_price_per_sqm,
    AVG(total_area) AS avg_area,
    count(id)
FROM ad_dat
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL--------- так вот он 
GROUP BY publication_month
ORDER BY publication_month;

-- Анализ рынка недвижимости Ленобласти

WITH leningrad_ads AS (
    SELECT
        a.id,
        c.city,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE c.city <> 'Санкт-Петербург'
),
limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
            )

SELECT
  city,
  count(days_exposition) * 1.0 / count(first_day_exposition),
  COUNT(*) AS ad_count,
  AVG(last_price / total_area) AS avg_price_per_sqm,
  AVG(total_area) AS avg_area,
  AVG(days_exposition) AS avg_days_on_market
FROM leningrad_ads
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY city
ORDER BY ad_count DESC
LIMIT 15;
