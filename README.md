# SQL Data Warehouse Project

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Data Engineering](https://img.shields.io/badge/Data%20Engineering-4CAF50?style=for-the-badge&logo=databricks&logoColor=white)
![ETL](https://img.shields.io/badge/ETL%20Pipeline-FF6F00?style=for-the-badge&logo=apache&logoColor=white)

An end-to-end data engineering project that builds a SQL Server data warehouse from raw source data to an analytics-ready star schema, connected to a Power BI dashboard.

---

## Problem Statement

Analytics teams working with siloed operational data face a common challenge: CRM and ERP systems each store fragments of the business picture — customer records, product catalogs, and sales transactions — in incompatible formats with inconsistent encodings, duplicate records, and missing values. Without a unified data model, building reliable sales reports or customer-level insights requires ad-hoc joins across raw tables, leading to slow queries, inconsistent metrics, and untrusted results.

This project solves that problem by building a **medallion-architecture data warehouse** that ingests raw data from both source systems, applies systematic data quality transformations, and delivers a clean star schema optimized for analytical queries and BI reporting.

---

## Architecture Overview

The pipeline follows a **Bronze → Silver → Gold** medallion architecture, implemented entirely in T-SQL stored procedures and views.

```
┌─────────────────────────────────────────────────────────────────┐
│                        SOURCE SYSTEMS                           │
│                                                                 │
│   CRM System                        ERP System                  │
│   ├── cust_info.csv                 ├── CUST_AZ12.csv           │
│   ├── prd_info.csv                  ├── LOC_A101.csv            │
│   └── sales_details.csv             └── PX_CAT_G1V2.csv        │
└──────────────────┬──────────────────────────┬───────────────────┘
                   │        BULK INSERT        │
                   ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  BRONZE LAYER  (Raw Ingestion — schema.bronze)                  │
│  6 tables, 115,000+ raw records, no transformations             │
│  Scripts: 01_bronze_ddl.sql, 02_bronze_procedure.sql            │
└───────────────────────────────┬─────────────────────────────────┘
                                │  silver.load_silver (stored proc)
                                │  Dedup · Standardize · Validate
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  SILVER LAYER  (Cleaned & Conformed — schema.silver)            │
│  6 tables, type-safe columns, dwh_create_date audit stamps      │
│  Scripts: 03_silver_ddl.sql, 04_silver_procedure.sql            │
└───────────────────────────────┬─────────────────────────────────┘
                                │  CREATE OR ALTER VIEW
                                │  Join · Enrich · Aggregate
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  GOLD LAYER  (Star Schema — schema.gold)                        │
│  gold.dim_customers  ·  gold.dim_products  ·  gold.fact_sales   │
│  79,177 transactions · 18,484 customers · 295 products          │
│  Script: 05_gold_views.sql                                      │
└───────────────────────────────┬─────────────────────────────────┘
                                │  DirectQuery / Import
                                ▼
                       ┌─────────────────┐
                       │  Power BI        │
                       │  Dashboard       │
                       └─────────────────┘
```

---

## Star Schema Design

The Gold layer exposes three views that form a classic star schema. Power BI connects directly to these views with no additional modeling required.

### `gold.fact_sales` — 79,177 Sales Transactions (2010–2014)

| Column | Type | Description |
|---|---|---|
| `order_number` | NVARCHAR(50) | Unique sales order identifier |
| `product_key` | INT | FK → `dim_products.product_key` |
| `customer_key` | INT | FK → `dim_customers.customer_key` |
| `order_date` | DATE | Date the order was placed |
| `ship_date` | DATE | Date the order was shipped |
| `due_date` | DATE | Expected delivery date |
| `sales_amount` | INT | Total revenue for the line item |
| `quantity` | INT | Units sold |
| `price` | INT | Unit price |

### `gold.dim_customers` — 18,484 Customers across 6 Countries

| Column | Type | Description |
|---|---|---|
| `customer_key` | INT | Surrogate key (ROW_NUMBER) |
| `customer_id` | INT | Source CRM identifier |
| `customer_number` | NVARCHAR(50) | Business customer code |
| `first_name` | NVARCHAR(50) | |
| `last_name` | NVARCHAR(50) | |
| `country` | NVARCHAR(50) | Resolved from ERP location data |
| `marital_status` | NVARCHAR(50) | Single / Married / n/a |
| `gender` | NVARCHAR(50) | CRM gender, ERP fallback |
| `birthdate` | DATE | From ERP; future dates set to NULL |
| `create_date` | DATE | Customer record creation date |

### `gold.dim_products` — 295 Active Products across 3 Categories

| Column | Type | Description |
|---|---|---|
| `product_key` | INT | Surrogate key (ROW_NUMBER) |
| `product_id` | INT | Source CRM identifier |
| `product_number` | NVARCHAR(50) | Business product code |
| `product_name` | NVARCHAR(50) | |
| `category_id` | NVARCHAR(50) | ERP category identifier |
| `category` | NVARCHAR(50) | Bikes / Components / Accessories |
| `subcategory` | NVARCHAR(50) | e.g., Road Bikes, Helmets |
| `maintenance` | NVARCHAR(50) | Maintenance flag from ERP |
| `cost` | INT | Standard unit cost |
| `product_line` | NVARCHAR(50) | Mountain / Road / Touring / Other Sale |
| `start_date` | DATE | Product active-from date (current products only) |

**Relationship**: `fact_sales.product_key` → `dim_products.product_key` and `fact_sales.customer_key` → `dim_customers.customer_key`.

---

## Data Quality

All cleaning and standardization occurs in the **Silver layer** (`04_silver_procedure.sql`). The following transformations are applied:

| Issue | Source | Fix Applied |
|---|---|---|
| Duplicate customer records | CRM | `ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)` — keeps latest record |
| Coded gender values (`F`, `M`) | CRM | Mapped to `Female` / `Male`; blanks set to `n/a` |
| Coded marital status (`S`, `M`) | CRM | Mapped to `Single` / `Married`; blanks set to `n/a` |
| Coded product line (`M`, `R`, `S`, `T`) | CRM | Mapped to Mountain / Road / Other Sale / Touring |
| Integer-encoded dates (e.g., `20130415`) | CRM | Validated (`LEN = 8` and non-zero), then cast to `DATE`; invalid values set to `NULL` |
| Negative or zero sales amounts | CRM | Recalculated as `quantity × ABS(price)` |
| Negative or zero unit prices | CRM | Recalculated as `sales / quantity` |
| `NAS`-prefixed customer IDs | ERP | `SUBSTRING(cid, 4, ...)` strips the prefix to align with CRM keys |
| Future birthdates | ERP | Set to `NULL` (data entry errors) |
| ISO country codes (`DE`, `US`, `GB`, etc.) | ERP | Expanded to full country names |
| Inconsistent whitespace in strings | Both | `TRIM()` applied to all text fields |
| NULL product costs | CRM | Defaulted to `0` via `ISNULL(prd_cost, 0)` |
| Product versioning (SCD) | CRM | `LEAD()` window function derives `prd_end_dt`; Gold layer filters `WHERE prd_end_dt IS NULL` for current products only |

All Silver tables include a `dwh_create_date DATETIME2 DEFAULT GETDATE()` audit column to track when each row was loaded.

---

## Power BI Dashboard

![Dashboard](images/dashboard.png)

The Power BI report connects to the three Gold views via **DirectQuery** (or Import mode) and provides:

- **Total Revenue KPI** — Sum of `sales_amount` across all periods
- **Sales Trend (2010–2014)** — Line chart of monthly `sales_amount` grouped by `order_date`
- **Revenue by Country** — Bar/map visual using `dim_customers.country`
- **Top Products by Revenue** — Ranked bar chart using `dim_products.product_name`
- **Sales by Product Category** — Donut chart segmented by `dim_products.category`
- **Customer Demographics** — Gender and marital status breakdowns using dimension attributes
- **Order Volume vs. Revenue** — Scatter plot comparing `quantity` to `sales_amount` per product

All visuals share cross-filtering so clicking a country, category, or product filters the entire report page.

---

## Setup Instructions

### Prerequisites

- **SQL Server Express** (free) — [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **SQL Server Management Studio (SSMS)** — [Download](https://aka.ms/ssmsfullsetup)
- **Power BI Desktop** (free) — [Download](https://powerbi.microsoft.com/desktop/)

### Step 1 — Create the Database and Schemas

Open SSMS, connect to your SQL Server instance, and run:

```sql
CREATE DATABASE DataWarehouse;
GO
USE DataWarehouse;
GO
CREATE SCHEMA bronze; GO
CREATE SCHEMA silver; GO
CREATE SCHEMA gold;   GO
```

### Step 2 — Create Bronze Tables

Run `SQL SCRIPTS/01_bronze_ddl.sql`. This creates the 6 raw staging tables.

### Step 3 — Update CSV File Paths

Open `SQL SCRIPTS/02_bronze_procedure.sql` and replace every occurrence of the hardcoded path:

```
C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\
```

with the absolute path to the `datasets/` folder on your machine, for example:

```
C:\Users\YourName\Downloads\sql-data-warehouse-project\datasets\
```

### Step 4 — Create and Execute the Bronze Load Procedure

Run `SQL SCRIPTS/02_bronze_procedure.sql`, then execute the procedure:

```sql
EXEC bronze.load_bronze;
```

### Step 5 — Create Silver Tables

Run `SQL SCRIPTS/03_silver_ddl.sql` to create the 6 cleaned staging tables.

### Step 6 — Create and Execute the Silver Load Procedure

Run `SQL SCRIPTS/04_silver_procedure.sql`, then execute:

```sql
EXEC silver.load_silver;
```

### Step 7 — Create Gold Views

Run `SQL SCRIPTS/05_gold_views.sql`. This creates `gold.dim_customers`, `gold.dim_products`, and `gold.fact_sales`.

### Step 8 — Connect Power BI

1. Open Power BI Desktop → **Get Data** → **SQL Server**
2. Enter your server name (e.g., `localhost\SQLEXPRESS`)
3. Enter `DataWarehouse` as the database
4. Select **Import** or **DirectQuery**
5. Load `gold.dim_customers`, `gold.dim_products`, and `gold.fact_sales`
6. Verify relationships are detected automatically (product_key, customer_key)

---

## File Structure

```
sql-data-warehouse-project/
│
├── SQL SCRIPTS/
│   ├── 01_bronze_ddl.sql        # CREATE TABLE for 6 raw staging tables
│   ├── 02_bronze_procedure.sql  # Stored proc: BULK INSERT from CSVs → bronze
│   ├── 03_silver_ddl.sql        # CREATE TABLE for 6 cleaned tables (+ audit column)
│   ├── 04_silver_procedure.sql  # Stored proc: transform & load bronze → silver
│   └── 05_gold_views.sql        # CREATE VIEW for dim_customers, dim_products, fact_sales
│
├── datasets/
│   ├── source_crm/
│   │   ├── cust_info.csv        # Customer master (CRM)
│   │   ├── prd_info.csv         # Product master (CRM)
│   │   └── sales_details.csv    # Transactional sales (CRM)
│   └── source_erp/
│       ├── CUST_AZ12.csv        # Customer demographics (ERP)
│       ├── LOC_A101.csv         # Customer country (ERP)
│       └── PX_CAT_G1V2.csv        # Product category hierarchy (ERP)
│
├── images/
│   └── dashboard.png            # Power BI dashboard screenshot
│
└── README.md
```

---

## Performance Considerations

- **Stored procedures with TRUNCATE + INSERT** — Full-refresh loads are simple and repeatable for datasets of this size; TRUNCATE is faster than DELETE as it does not log individual row deletions.
- **`TABLOCK` hint on BULK INSERT** — Minimizes lock overhead during initial data load by acquiring a table-level lock rather than row-level locks.
- **Surrogate keys via `ROW_NUMBER()`** — Integer surrogate keys on dimension views (`customer_key`, `product_key`) give the query optimizer efficient join paths compared to natural NVARCHAR keys.
- **Gold as views, not tables** — Views avoid storing redundant copies of data; Power BI Import mode materializes the result set in memory, making report interactions fast without index maintenance overhead on the warehouse side.
- **`WHERE prd_end_dt IS NULL` filter in `dim_products`** — Excludes historical product versions at view definition time, reducing the row count Power BI loads and preventing fan-out in sales aggregations.
- **`NULLIF(sls_quantity, 0)` guard** — Prevents divide-by-zero errors during price recalculation in the Silver transformation.

---

## Skills Demonstrated

| Area | Details |
|---|---|
| **Data Engineering** | Medallion architecture (Bronze/Silver/Gold), ETL pipeline design, data lake patterns |
| **ETL Development** | T-SQL stored procedures, BULK INSERT, incremental-style full-refresh loads |
| **SQL / T-SQL** | Window functions (`ROW_NUMBER`, `LEAD`), CASE expressions, multi-source JOINs, CTEs |
| **Data Modeling** | Star schema design, surrogate key generation, slowly-changing dimension (Type 1) handling |
| **Data Quality** | Deduplication, null handling, type coercion, standardization, referential integrity checks |
| **Business Intelligence** | Power BI report design, DAX-ready data model, cross-filter relationships |
| **Requirements Gathering** | Mapping source system fields to analytical dimensions (ITM-relevant: translating business needs to technical specs) |
| **Documentation** | End-to-end project documentation for reproducibility and team handoff |

---

## Tech Stack

- **SQL Server Express** — Database engine
- **SSMS** — Query development and schema management
- **T-SQL** — Stored procedures, views, window functions
- **Power BI Desktop** — Dashboard and reporting layer
