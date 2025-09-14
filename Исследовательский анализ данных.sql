

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT count(id) AS kol_vo,-------общее количество игроков, зарегистрированных в игре
sum(payer) AS donaters,----------количество платящих игроков
round(sum(payer) * 1.0/count(id),2) AS dolya_donaters--------доля платящих игроков от общего количества пользователей
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT r.race,
       SUM(u.payer) AS donaters,---------количество платящих игроков
       COUNT(u.id) AS kol_vo,-----------общее количество игроков
       ROUND(SUM(u.payer) * 1.0 / COUNT(u.id), 2) AS dolya--------- доля платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY dolya DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT count(amount), -------общее количество покупок
sum(amount),-------суммарную стоимость всех покупок
min(amount),-------минимальную стоимость покупки
max(amount),-------максимальную стоимость покупки
avg(amount),-------среднее значение покупки
percentile_disc(0.5) WITHIN GROUP(ORDER BY amount),-------медиана покупок
stddev(amount) AS stand_dev -------стандартное отклонение
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:

SELECT count(amount),-----количество нулевых покупок
count(amount)*1.0 / (SELECT count(id) FROM fantasy.events)-------доля нулевых покупок
FROM fantasy.events
WHERE amount = 0;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

SELECT CASE 
WHEN u.payer = 1
THEN 'payer'
WHEN u.payer = 0
THEN 'non-payer'
END,------платящие и не платящие игроки
count(DISTINCT u.id),------общее кол-во игроков
count(e.transaction_id)/count(DISTINCT u.id) AS avg_tr,-------среднее кол-во транзакций
sum(e.amount)/count(DISTINCT u.id) AS avg_amount----------- средняя сумма транзакций
FROM fantasy.users AS u
JOIN fantasy.events AS e ON u.id = e.id
WHERE e.amount <> 0
GROUP BY u.payer;

-- 2.4: Популярные эпические предметы:

WITH total_sales AS (
    SELECT 
        e.item_code,
        COUNT(*) AS total_sales_count,
        COUNT(DISTINCT e.id) AS players_count
    FROM fantasy.events AS e
    WHERE e.amount <> 0 -------------так вот же мы отсекаем все нулевые значения
    GROUP BY e.item_code
),
relative_sales AS (
    SELECT 
        ts.item_code,
        ts.total_sales_count,
        ts.players_count,
        (ts.total_sales_count * 1.0 / SUM(ts.total_sales_count) OVER ()) AS sales_ratio,
        (ts.players_count * 1.0 / (SELECT COUNT(DISTINCT id) FROM fantasy.events)) AS player_ratio
    FROM total_sales ts
)
SELECT 
    i.game_items,
    rs.total_sales_count,
    rs.sales_ratio,
    rs.player_ratio
FROM relative_sales AS rs
JOIN fantasy.items AS i ON rs.item_code = i.item_code
ORDER BY rs.player_ratio DESC;

-- Решение ad hoc-задач
-- Зависимость активности игроков от расы персонажа:

WITH total_players AS (
    SELECT r.race,
        COUNT(u.id) AS total_players
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY r.race
),
paying_players AS (
    SELECT r.race,
    SUM(u.payer) AS cheto,
        COUNT(DISTINCT e.id) AS paying_players_count
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount <> 0
    GROUP BY r.race
),
player_activity AS (
    SELECT r.race,
        COUNT(e.transaction_id) AS total_transactions,
        SUM(e.amount) AS total_amount_spent
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount <> 0
    GROUP BY r.race
),
total_payers AS (SELECT r.race,
        COUNT(DISTINCT e.id) AS total_payers
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    WHERE payer = 1
    GROUP BY r.race
    )
SELECT tp.race,
    tp.total_players,
    pp.paying_players_count,
    ROUND(pp.paying_players_count * 1.0 / tp.total_players, 4) AS paying_players_ratio,
    ROUND(tpa.total_payers * 1.0 / pp.paying_players_count, 4) AS paying_ratio_among_buyers,
    ROUND(pa.total_transactions * 1.0 / pp.paying_players_count, 4) AS avg_transactions_per_player,
    pa.total_amount_spent * 1.0 / pa.total_transactions AS avg_amount_per_transaction,
    pa.total_amount_spent * 1.0 / pp.paying_players_count AS avg_total_amount_per_player
FROM total_players AS tp
JOIN paying_players AS pp ON tp.race = pp.race
JOIN player_activity AS pa ON tp.race = pa.race
JOIN total_payers AS tpa ON tp.race = tpa.race
ORDER BY tp.race;
