# Nawy Proptech Platform — Dimensional Model Documentation

> **Complete reference for the Kimball star schema powering Nawy's analytics**



## 📖 Table of Contents

- [Introduction](#-introduction)
- [Modeling Approach](#-modeling-approach)
- [The Bus Matrix](#-the-bus-matrix)
- [Dimension Design Standards](#-dimension-design-standards)
- [Fact Table Design Standards](#-fact-table-design-standards)
- [Conformed Dimensions in Detail](#-conformed-dimensions-in-detail)
- [Fact Tables in Detail](#-fact-tables-in-detail)
- [Grain Declaration Reference](#-grain-declaration-reference)
- [Additive, Semi-Additive, Non-Additive Measures](#-additive-semi-additive-non-additive-measures)
- [Slowly Changing Dimensions](#-slowly-changing-dimensions)
- [Special Members and Null Handling](#-special-members-and-null-handling)
- [Degenerate Dimensions](#-degenerate-dimensions)
- [Junk Dimensions](#-junk-dimensions)
- [Role-Playing Dimensions](#-role-playing-dimensions)
- [Snowflaking Decisions](#-snowflaking-decisions)
- [Aggregate Design](#-aggregate-design)
- [Modeling Anti-Patterns Avoided](#-modeling-anti-patterns-avoided)
- [Query Examples](#-query-examples)






## 🎯 Introduction

### What Is This Document?

This is the **authoritative dimensional modeling reference** for the Nawy Proptech data warehouse. It documents:

- Every dimension table (structure, grain, attributes)
- Every fact table (grain, measures, dimensions)
- The relationships between them (the bus matrix)
- Design decisions and why they were made
- Standards for extending the model

### Who Should Read This?

| Role | What You'll Get |
|------|-----------------|
| **Data Analysts** | How to join tables correctly, which grain to use |
| **BI Developers** | Dimension hierarchies, measure semantics |
| **Data Engineers** | ETL design, SCD strategy, late-arriving handling |
| **Data Architects** | Design rationale, extension guidelines |
| **Business Stakeholders** | What questions the model can answer |

### Where This Fits

This document assumes the warehouse follows the **three-layer Medallion architecture**:

- **Bronze** — Raw ingestion (append-only)
- **Silver** — Cleansed, deduplicated, historized
- **Gold** — Dimensional model (this document)

The Gold layer contains **8 dimensions** and **15 fact tables**, all sharing **conformed dimensions**.

