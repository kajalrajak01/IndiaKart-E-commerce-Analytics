/*
=====================================================================================================
IndiaKart E-Commerce Data Analytics
Phase 3 — SQL KPI Analysis
=====================================================================================================

Analyst: Kajal Rajak
Database: indiakart
Tool: PostgreSQL

Purpose: Calculate the 10 business KPIs defined in the Phase 3 PRD using PostgreSQL and prepare live 
KPI outputs for the Power BI dashboard.
=====================================================================================================
*/

-- ===================================================================================================
-- KPI 1 Gross Merchandise Value (GMV) 
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_gmv AS
SELECT ROUND(SUM("final_amount")::numeric, 2) AS gross_merchandise_value
FROM "orders DA";

SELECT *
FROM kpi_gmv;

-- ===================================================================================================
-- KPI 2 Net Revenue
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_net_revenue AS
SELECT ROUND(SUM(final_amount)::numeric, 2) AS net_revenue
FROM "orders DA"
WHERE status = 'Delivered';

SELECT *
FROM kpi_net_revenue;

-- ===================================================================================================
-- KPI 3 Average Order Value (AOV)
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_average_order_value AS
SELECT ROUND(AVG(final_amount)::numeric, 2) AS average_order_value
FROM "orders DA"
WHERE status = 'Delivered';

SELECT *
FROM kpi_average_order_value;

-- ===================================================================================================
-- KPI 4 Cancellation Rate
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_cancellation_rate AS
SELECT
    ROUND(
        COUNT(*) FILTER (WHERE status = 'Cancelled') * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_percentage
FROM "orders DA";

SELECT *
FROM kpi_cancellation_rate;

-- ===================================================================================================
-- KPI 5 Return Rate
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_return_rate AS
SELECT ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*)
FROM "orders DA" WHERE status = 'Delivered'), 0), 2) 
AS return_rate_percentage
FROM "returns DA" r
JOIN "orders DA" o
    ON r.order_id = o.order_id
WHERE o.status = 'Delivered';

SELECT *
FROM kpi_return_rate;

-- ===================================================================================================
-- KPI 6 Customer Lifetime Value (CLV)
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_clv_by_segment AS
SELECT
    c.segment,
    ROUND(AVG(c.total_spent)::numeric, 2) AS average_customer_lifetime_value
FROM "customers DA" c
GROUP BY c.segment
ORDER BY average_customer_lifetime_value DESC;

SELECT *
FROM kpi_clv_by_segment;

-- ===================================================================================================
-- KPI 7 Month-over-Month Growth
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_mom_growth AS
WITH monthly_gmv AS (
    SELECT
        DATE_TRUNC('month', order_date_dt)::date AS month,
        SUM(final_amount) AS gmv
    FROM "orders DA"
    GROUP BY DATE_TRUNC('month', order_date_dt)
),
monthly_growth AS (
    SELECT
        month,
        gmv,
        LAG(gmv) OVER (ORDER BY month) AS previous_month_gmv
    FROM monthly_gmv
)
SELECT
    month,
    ROUND(gmv::numeric, 2) AS monthly_gmv,
    ROUND(previous_month_gmv::numeric, 2) AS previous_month_gmv,
    ROUND(
        ((gmv - previous_month_gmv) / NULLIF(previous_month_gmv, 0) * 100)::numeric,
        2
    ) AS mom_growth_percentage
FROM monthly_growth
ORDER BY month;

SELECT *
FROM kpi_mom_growth;

-- ===================================================================================================
-- KPI 8 Top Category Revenue Share
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_category_revenue_share AS
SELECT category, ROUND(SUM(total_price)::numeric, 2) AS category_revenue,
    ROUND(
        (SUM(total_price) * 100.0 / NULLIF(SUM(SUM(total_price)) OVER (), 0)
        )::numeric, 2) AS revenue_share_percentage
FROM "order_items DA"
GROUP BY category
ORDER BY category_revenue DESC;

SELECT *
FROM kpi_category_revenue_share;

-- ===================================================================================================
-- KPI 9 Payment Failure Rate
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_payment_failure_rate AS
SELECT
    ROUND(
        (
            COUNT(*) FILTER (WHERE status = 'Failed') * 100.0
            / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS payment_failure_rate_percentage
FROM "payments DA";

SELECT *
FROM kpi_payment_failure_rate;

-- ===================================================================================================
-- KPI 10 Inventory Fill Rate
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_inventory_fill_rate AS
SELECT
    ROUND(
        COUNT(*) FILTER (WHERE status = 'In Stock') * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS inventory_fill_rate_percentage
FROM "inventory DA";

SELECT *
FROM kpi_inventory_fill_rate;

SELECT *
FROM kpi_inventory_fill_rate;

-- ===================================================================================================
-- KPI 11: Cohort Analysis
-- ===================================================================================================
CREATE OR REPLACE VIEW kpi_cohort_retention AS
WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC(
            'month',
            TO_DATE(registration_date, 'DD-MM-YYYY')
        )::date AS cohort_month
    FROM "customers DA"
),
customer_orders AS (
    SELECT
        order_id,
        customer_id,
        DATE_TRUNC('month', order_date_dt)::date AS order_month
    FROM "orders DA"
),
cohort_activity AS (
    SELECT
        c.cohort_month,
        (
            (EXTRACT(YEAR FROM o.order_month) -
             EXTRACT(YEAR FROM c.cohort_month)) * 12
            +
            (EXTRACT(MONTH FROM o.order_month) -
             EXTRACT(MONTH FROM c.cohort_month))
        )::integer AS month_number,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT o.customer_id) AS active_customers
    FROM customer_cohorts c
    JOIN customer_orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_month >= c.cohort_month
    GROUP BY c.cohort_month, month_number
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_customers
    FROM customer_cohorts
    GROUP BY cohort_month
)
SELECT
    a.cohort_month,
    s.total_customers,
    a.month_number,
    a.total_orders,
    a.active_customers,
    ROUND(
        a.active_customers * 100.0 /
        NULLIF(s.total_customers, 0),
        2
    ) AS retention_percentage
FROM cohort_activity a
JOIN cohort_sizes s
    ON a.cohort_month = s.cohort_month
ORDER BY a.cohort_month, a.month_number;

SELECT *
FROM kpi_cohort_retention;