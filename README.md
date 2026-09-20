# Olist E-Commerce Analysis

An end-to-end data analyst project on the Olist Brazilian e-commerce dataset, covering database design, SQL business analysis, Python data cleaning, and a Power BI dashboard.

![Dashboard Screenshot](Screenshot%202026-09-19%20231151.png)

## Project Overview

This project analyzes ~99,000 orders from Olist, a Brazilian e-commerce marketplace, to answer core business questions around revenue trends, product performance, geographic distribution, and delivery reliability. The pipeline moves data through four stages: MySQL (storage) → SQL (analysis) → Python/pandas (cleaning + feature engineering) → Power BI (visualization).

**Dataset source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)

## Tech Stack

- **MySQL** — database storage and initial querying
- **Python (pandas)** — data cleaning, feature engineering
- **Power BI** — dashboard and visualization
- **Git/GitHub** — version control

## Repository Structure

```
├── phase2_analysis.sql       # SQL business analysis queries (5 queries, commented)
├── phase3_cleaning.ipynb     # Python data cleaning + feature engineering notebook
├── orders_cleaned.csv        # Cleaned dataset output from Phase 3
├── olist_dashboard.pbix      # Power BI dashboard file
└── README.md
```

## Phase 1: Database Setup

Created a MySQL database (`olist_ecommerce`) and imported four core tables from the raw Kaggle CSVs: `orders`, `order_items`, `products`, `customers`. Handled empty date fields and numeric fields during import using `NULLIF()` on staged variables, since MySQL's `LOAD DATA INFILE` rejects blank strings for typed columns.

## Phase 2: SQL Business Analysis

Five queries answering core business questions, including two window-function queries (`RANK() OVER (PARTITION BY ...)` for top products per category, and `LAG()` for month-over-month revenue growth). Full queries and explanations in [`phase2_analysis.sql`](phase2_analysis.sql).

**Key findings:**
- Revenue grew steadily through 2017, with a **52% month-over-month spike in November 2017** (Black Friday).
- **São Paulo (SP) alone accounts for ~38% of total revenue** — by far the largest state, consistent with it being Brazil's economic center.
- Counterintuitively, **Northeast states (Alagoas, Maranhão, Piauí, Ceará) had the highest late-delivery rates (15–24%)**, not the more remote northern states as initially expected — a finding the data corrected rather than confirmed.

## Phase 3: Python Data Cleaning & Feature Engineering

Used pandas (connected directly to the MySQL database via `mysql-connector-python`) to clean the `orders` table and engineer new features. Full process and reasoning in [`phase3_cleaning.ipynb`](phase3_cleaning.ipynb).

**Data quality findings:**
- 14 orders (0.014%) had a status/delivery-date mismatch — 6 were corrected (date evidence outweighed a stale "canceled" label), 8 were left as a documented gap (no reliable date to assign).
- 2,965 orders (~3%) have no delivery date — these are legitimately canceled/unavailable orders, not data errors.
- 775 orders have no associated line items; 767 are explained by cancellation/unavailability, 6 remain unexplained anomalies.

**Features engineered:**
- `delivery_delay_days` — actual vs. estimated delivery date (negative = early)
- `fulfillment_days` — total days from purchase to delivery
- `is_late` — nullable boolean flag (avoids the pandas pitfall where `NaN > 0` silently evaluates to `False`)
- `total_price`, `total_freight`, `item_count` — aggregated from `order_items` per order

**Key stat:** Of orders with a known outcome, ~6.8% were delivered later than their estimated date; on average, orders arrive **~12 days earlier** than estimated.

## Phase 4: Power BI Dashboard

Built a dashboard connecting to both the cleaned CSV output and the live MySQL database, with a star-schema data model (`orders_cleaned` as the fact table, linked to `customers`, `products`, and `order_items`).

**Dashboard includes:**
- KPI cards: Total Revenue, Total Orders, Average Delivery Delay
- Monthly revenue trend
- Revenue by state
- Average delivery delay by state

**Note on geography:** An initial attempt to use a filled/bubble map failed due to a known limitation in Power BI's default geocoding service (Bing Maps struggles with two-letter Brazilian state abbreviations, e.g. misreading `PR` as Puerto Rico). Rather than force an unreliable visual, the dashboard uses sorted bar charts instead — a deliberate choice that also reads more clearly for precise state-by-state comparison.

## Key Takeaways

1. Revenue is heavily concentrated in São Paulo and the Southeast, consistent with Brazil's economic geography.
2. Delivery performance is strongest in the South/Southeast and weakest in the Northeast — a pattern that only emerged from the data, not from the initial hypothesis.
3. Olist's delivery estimates are conservative by design — most orders arrive well before the promised date, which likely supports customer satisfaction at the cost of a less "efficient-looking" estimate.

## How to Reproduce

1. Download the Olist dataset from Kaggle (link above) — you'll get 9 CSVs.
2. Set up a MySQL database and import the 4 core CSVs (orders, order_items, products, customers) — see Phase 1 above for the table schemas and how I handled blank date fields.
3. Run the queries in `phase2_analysis.sql` against your database.
4. Open `phase3_cleaning.ipynb`, put in your own MySQL password, and run the notebook top to bottom.
5. Open `olist_dashboard.pbix` in Power BI Desktop — you'll need to point the data source at your own local MySQL setup since mine's obviously not accessible to you.
   
