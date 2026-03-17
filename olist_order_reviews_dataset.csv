-- ============================================================
-- PROJECT 1: E-Commerce Catalog Defect Detection System
-- File: 03_kpi_metrics_reporting.sql
-- Author: Nishit Patel
-- Description: Defines 8 KPIs + daily/weekly/monthly report views
-- ============================================================


-- ─────────────────────────────────────────────
-- KPI FRAMEWORK — 8 Core Metrics
-- ─────────────────────────────────────────────

-- KPI 1: Overall defect rate (platform-wide)
CREATE OR REPLACE VIEW vw_kpi_overall_defect_rate AS
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(o.order_id), 0), 2
    ) AS platform_defect_rate_pct
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id;


-- KPI 2: On-time delivery rate
CREATE OR REPLACE VIEW vw_kpi_on_time_delivery AS
SELECT
    ROUND(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1
            ELSE 0 END)
        / NULLIF(COUNT(order_id), 0), 2
    ) AS on_time_delivery_rate_pct
FROM orders
WHERE order_status = 'delivered';


-- KPI 3: Average review score by category (monthly)
CREATE OR REPLACE VIEW vw_kpi_monthly_review_score AS
SELECT
    p.product_category_name,
    DATE_TRUNC('month', o.order_purchase_timestamp)     AS month,
    ROUND(AVG(r.review_score), 2)                       AS avg_review_score,
    COUNT(r.review_id)                                  AS review_count
FROM orders o
JOIN order_items oi       ON o.order_id = oi.order_id
JOIN products p           ON oi.product_id = p.product_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY 1, 2;


-- KPI 4: Seller fill rate (orders fulfilled vs total placed)
CREATE OR REPLACE VIEW vw_kpi_seller_fill_rate AS
SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id)                                          AS total_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END) AS delivered_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                                    AS fill_rate_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 1;


-- KPI 5: Repeat purchase rate by customer
CREATE OR REPLACE VIEW vw_kpi_repeat_purchase_rate AS
WITH customer_orders AS (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY 1
)
SELECT
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)    AS repeat_customers,
    COUNT(*)                                             AS total_customers,
    ROUND(
        100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                    AS repeat_purchase_rate_pct
FROM customer_orders;


-- KPI 6: Average order value (AOV) by category
CREATE OR REPLACE VIEW vw_kpi_aov_by_category AS
SELECT
    p.product_category_name,
    ROUND(AVG(oi.price + oi.freight_value), 2)  AS avg_order_value,
    COUNT(DISTINCT o.order_id)                  AS order_count
FROM orders o
JOIN order_items oi  ON o.order_id = oi.order_id
JOIN products p      ON oi.product_id = p.product_id
GROUP BY 1
ORDER BY avg_order_value DESC;


-- KPI 7: Review score trend (month-over-month delta)
CREATE OR REPLACE VIEW vw_kpi_review_score_trend AS
WITH monthly_scores AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        ROUND(AVG(r.review_score), 3)                   AS avg_score
    FROM orders o
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY 1
)
SELECT
    month,
    avg_score,
    LAG(avg_score) OVER (ORDER BY month)                        AS prev_month_score,
    ROUND(avg_score - LAG(avg_score) OVER (ORDER BY month), 3) AS score_delta
FROM monthly_scores
ORDER BY month;


-- KPI 8: Cancellation rate (operational health)
CREATE OR REPLACE VIEW vw_kpi_cancellation_rate AS
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)   AS month,
    COUNT(order_id)                                  AS total_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(
        100.0 * SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(order_id), 0), 2
    )                                                AS cancellation_rate_pct
FROM orders
GROUP BY 1
ORDER BY month;


-- ─────────────────────────────────────────────
-- AUTOMATED REPORTING VIEWS
-- ─────────────────────────────────────────────

-- Daily Ops Snapshot
CREATE OR REPLACE VIEW vw_daily_ops_report AS
SELECT
    DATE(o.order_purchase_timestamp)                                    AS report_date,
    COUNT(DISTINCT o.order_id)                                          AS orders_placed,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END) AS orders_delivered,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)               AS defects_flagged,
    ROUND(AVG(r.review_score), 2)                                       AS avg_daily_score,
    ROUND(SUM(oi.price + oi.freight_value), 2)                         AS total_revenue
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id
LEFT JOIN order_items oi  ON o.order_id = oi.order_id
GROUP BY 1
ORDER BY report_date DESC;


-- Weekly Trend Report
CREATE OR REPLACE VIEW vw_weekly_ops_report AS
SELECT
    DATE_TRUNC('week', o.order_purchase_timestamp)                      AS week_start,
    COUNT(DISTINCT o.order_id)                                          AS weekly_orders,
    ROUND(AVG(r.review_score), 2)                                       AS avg_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)               AS defects,
    ROUND(
        100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                                    AS defect_rate_pct,
    ROUND(SUM(oi.price + oi.freight_value), 2)                         AS weekly_revenue
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id
LEFT JOIN order_items oi  ON o.order_id = oi.order_id
GROUP BY 1
ORDER BY week_start DESC;
