-- ============================================================
-- PROJECT 1: E-Commerce Catalog Defect Detection System
-- File: 02_defect_detection.sql
-- Author: Nishit Patel
-- Description: Core defect mining queries — identifies bad SKUs,
--              low-rated categories, and repeat-defect sellers
-- ============================================================


-- ─────────────────────────────────────────────
-- QUERY 1: Defect rate by product category (weekly rollup)
-- Defect = review score <= 2
-- ─────────────────────────────────────────────
SELECT
    p.product_category_name,
    COUNT(oi.order_id)                                                      AS total_orders,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)                   AS defect_count,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(oi.order_id), 0), 2
    )                                                                        AS defect_rate_pct,
    DATE_TRUNC('week', o.order_purchase_timestamp)                          AS week_start
FROM orders o
JOIN order_items oi      ON o.order_id = oi.order_id
JOIN products p          ON oi.product_id = p.product_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY 1, 5
ORDER BY defect_rate_pct DESC;


-- ─────────────────────────────────────────────
-- QUERY 2: Top 20 defect SKUs (worst performing products)
-- ─────────────────────────────────────────────
WITH product_defects AS (
    SELECT
        oi.product_id,
        p.product_category_name,
        COUNT(DISTINCT oi.order_id)                                         AS total_orders,
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)               AS defect_orders,
        ROUND(AVG(r.review_score), 2)                                       AS avg_review_score,
        ROUND(
            100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(DISTINCT oi.order_id), 0), 2
        )                                                                    AS defect_rate_pct
    FROM order_items oi
    JOIN products p          ON oi.product_id = p.product_id
    JOIN orders o            ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY 1, 2
    HAVING COUNT(DISTINCT oi.order_id) >= 10  -- filter low-volume noise
)
SELECT *
FROM product_defects
ORDER BY defect_rate_pct DESC
LIMIT 20;


-- ─────────────────────────────────────────────
-- QUERY 3: Sellers with repeat defects (high-risk sellers)
-- ─────────────────────────────────────────────
WITH seller_defects AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                                         AS total_orders,
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)               AS defect_count,
        ROUND(
            100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(DISTINCT oi.order_id), 0), 2
        )                                                                    AS defect_rate_pct,
        ROUND(AVG(r.review_score), 2)                                       AS avg_score
    FROM order_items oi
    JOIN sellers s           ON oi.seller_id = s.seller_id
    JOIN orders o            ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY 1, 2
    HAVING COUNT(DISTINCT oi.order_id) >= 20
)
SELECT *,
    CASE
        WHEN defect_rate_pct >= 30 THEN 'Critical'
        WHEN defect_rate_pct >= 15 THEN 'High Risk'
        WHEN defect_rate_pct >= 5  THEN 'Monitor'
        ELSE 'Healthy'
    END AS risk_tier
FROM seller_defects
ORDER BY defect_rate_pct DESC;


-- ─────────────────────────────────────────────
-- QUERY 4: Late delivery impact on review scores
-- Measures correlation between delay and defect rate
-- ─────────────────────────────────────────────
SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On Time'
        WHEN o.order_delivered_customer_date IS NULL
            THEN 'Not Delivered'
        ELSE 'Late'
    END                                                         AS delivery_status,
    COUNT(o.order_id)                                           AS total_orders,
    ROUND(AVG(r.review_score), 2)                               AS avg_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)        AS defect_count,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(o.order_id), 0), 2
    )                                                           AS defect_rate_pct
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY defect_rate_pct DESC;
