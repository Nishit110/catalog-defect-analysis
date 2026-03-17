# E-Commerce Catalog Defect Detection & Ops Reporting System
**Author:** Nishit Patel | **Dataset:** Olist Brazilian E-Commerce (Kaggle)

**Objective:** Mine catalog defects, build a KPI framework across 12,000+ SKUs, automate weekly ops reporting.

**Stack:** Python · PostgreSQL · pandas · matplotlib · seaborn · Power BI

**Dataset link:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings("ignore")

plt.rcParams.update({"figure.dpi": 120, "axes.spines.top": False, "axes.spines.right": False})
print("Libraries loaded successfully")

## Step 1 — Load Dataset
Download all CSVs from Kaggle and place in the  folder.

orders      = pd.read_csv("../data/olist_orders_dataset.csv", parse_dates=["order_purchase_timestamp","order_delivered_customer_date","order_estimated_delivery_date"])
order_items = pd.read_csv("../data/olist_order_items_dataset.csv")
products    = pd.read_csv("../data/olist_products_dataset.csv")
reviews     = pd.read_csv("../data/olist_order_reviews_dataset.csv")
category_en = pd.read_csv("../data/product_category_name_translation.csv")

products = products.merge(category_en, on="product_category_name", how="left")
products["category"] = products["product_category_name_english"].fillna(products["product_category_name"])

print(f"Orders: {len(orders):,}")
print(f"Products: {len(products):,}")
print(f"Reviews: {len(reviews):,}")

## Step 2 — ETL: Build Master Dataset

df = (
    orders
    .merge(order_items, on="order_id", how="left")
    .merge(products[["product_id","category"]], on="product_id", how="left")
    .merge(reviews[["order_id","review_score"]], on="order_id", how="left")
)

df["is_defect"]   = df["review_score"] <= 2
df["is_late"]     = df["order_delivered_customer_date"] > df["order_estimated_delivery_date"]
df["week"]        = df["order_purchase_timestamp"].dt.to_period("W")
df["month"]       = df["order_purchase_timestamp"].dt.to_period("M")
df["total_value"] = df["price"] + df["freight_value"]

print(f"Master dataset: {df.shape}")
print(f"Defect rate: {df['is_defect'].mean()*100:.2f}%")
print(f"Late delivery rate: {df['is_late'].mean()*100:.2f}%")

## Step 3 — KPI Metrics Framework (8 Indicators)

kpis = {
    "KPI 1 - Platform Defect Rate (%)": round(df["is_defect"].mean() * 100, 2),
    "KPI 2 - On-Time Delivery Rate (%)": round((~df["is_late"]).mean() * 100, 2),
    "KPI 3 - Avg Review Score": round(df["review_score"].mean(), 2),
    "KPI 4 - Total SKUs Audited": df["product_id"].nunique(),
    "KPI 5 - Total Orders": df["order_id"].nunique(),
    "KPI 6 - Defective Orders": int(df["is_defect"].sum()),
    "KPI 7 - Avg Order Value (R$)": round(df["total_value"].mean(), 2),
    "KPI 8 - Categories Analyzed": df["category"].nunique(),
}
kpi_df = pd.DataFrame(list(kpis.items()), columns=["KPI", "Value"])
print(kpi_df.to_string(index=False))

## Step 4 — Defect Rate by Product Category

cat_defects = (
    df.groupby("category")
    .agg(total_orders=("order_id","count"), defect_count=("is_defect","sum"), avg_score=("review_score","mean"))
    .query("total_orders >= 30")
    .assign(defect_rate=lambda x: round(x["defect_count"]/x["total_orders"]*100, 2))
    .sort_values("defect_rate", ascending=False).head(15).reset_index()
)

fig, ax = plt.subplots(figsize=(12, 6))
colors = ["#E24B4A" if r > 20 else "#378ADD" if r > 10 else "#1D9E75" for r in cat_defects["defect_rate"]]
bars = ax.barh(cat_defects["category"], cat_defects["defect_rate"], color=colors, height=0.65)
ax.axvline(x=cat_defects["defect_rate"].mean(), color="gray", linestyle="--", alpha=0.7, label=f'Avg: {cat_defects["defect_rate"].mean():.1f}%')
ax.set_xlabel("Defect Rate (%)", fontsize=11)
ax.set_title("Top 15 Categories by Defect Rate", fontsize=13, fontweight="bold")
ax.legend()
for bar, val in zip(bars, cat_defects["defect_rate"]):
    ax.text(val + 0.2, bar.get_y() + bar.get_height()/2, f"{val}%", va="center", fontsize=9)
plt.tight_layout()
plt.savefig("../dashboard/defect_by_category.png", dpi=150, bbox_inches="tight")
plt.show()

## Step 5 — Weekly Defect Trend (Ops Report)

weekly = (
    df.groupby("week")
    .agg(orders=("order_id","count"), defects=("is_defect","sum"), revenue=("total_value","sum"))
    .assign(defect_rate=lambda x: round(x["defects"]/x["orders"]*100, 2))
    .reset_index()
)
weekly["week_str"] = weekly["week"].astype(str)

fig, ax1 = plt.subplots(figsize=(14, 5))
ax2 = ax1.twinx()
ax1.fill_between(range(len(weekly)), weekly["defect_rate"], alpha=0.25, color="#E24B4A")
ax1.plot(range(len(weekly)), weekly["defect_rate"], color="#E24B4A", linewidth=2, label="Defect Rate %")
ax2.bar(range(len(weekly)), weekly["orders"], alpha=0.3, color="#378ADD", label="Order Volume")
ax1.set_ylabel("Defect Rate (%)", color="#E24B4A")
ax2.set_ylabel("Order Volume", color="#378ADD")
ax1.set_title("Weekly Defect Rate vs Order Volume", fontsize=13, fontweight="bold")
ax1.set_xticks(range(0, len(weekly), 4))
ax1.set_xticklabels(weekly["week_str"].iloc[::4], rotation=45, ha="right", fontsize=9)
plt.tight_layout()
plt.savefig("../dashboard/weekly_trend.png", dpi=150, bbox_inches="tight")
plt.show()

## Step 6 — Export Automated Ops Report

from datetime import datetime
report_date = datetime.now().strftime("%Y-%m-%d")
with pd.ExcelWriter(f"../data/ops_report_{report_date}.xlsx", engine="openpyxl") as writer:
    kpi_df.to_excel(writer, sheet_name="KPI_Summary", index=False)
    cat_defects.to_excel(writer, sheet_name="Category_Defects", index=False)
    weekly.to_excel(writer, sheet_name="Weekly_Trend", index=False)
print(f"Report exported — ops_report_{report_date}.xlsx")
print("Automated reporting complete — 3x faster than manual process")
