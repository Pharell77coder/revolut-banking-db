# Revolut Banking Database

> Projet final — Conception & Optimisation d'un Système Bancaire Digital  
> Cours Introduction à SQL — 2 jours

---

## Description

Base de données relationnelle complète inspirée de Revolut.  
Conçue pour couvrir toutes les exigences du projet final : modélisation, intégrité référentielle, requêtes analytiques avancées, transactions ACID et optimisation par index.

---

## Structure du repository

```
revolut-banking-db/
├── README.md
├── schema/
│   └── diagramme.png              ← schéma ER (draw.io)
├── sql/
│   ├── 01_create_tables.sql       ← DDL : création des tables
│   ├── 02_insert_data.sql         ← DML : données de test
│   └── 03_queries_analytiques.sql ← requêtes avancées + index
└── docs/
    └── justification.md           ← choix de conception
```

---

## Schéma de la base

![Diagramme ER](schema/diagramme.png)

---

## Tables (13 au total)

| Table | Rôle |
|---|---|
| `Country` | Pays avec devise et taux de retrait |
| `Bank` | Banques liées à un pays |
| `Users` | Utilisateurs / clients |
| `Account` | Comptes bancaires (liés à un user et une banque) |
| `BankCard` | Cartes bancaires liées à un compte |
| `StockMarket` | Données boursières |
| `Portfolio` | Portefeuille boursier par compte |
| `TransactionType` | Types : Withdrawal, Deposit, Transfer |
| `Transactions` | Table centrale de toutes les transactions |
| `Withdrawal` | Détails d'un retrait (avec taux de change) |
| `Deposit` | Détails d'un dépôt |
| `Transfer` | Détails d'un virement (destinataire + référence) |
| `AuditLogs` | Journal d'audit complet |

---

## Données de test

| Entité | Quantité |
|---|---|
| Pays | 10 |
| Banques | 15 |
| Utilisateurs | 15 |
| Comptes | 17 |
| Cartes bancaires | 17 |
| Actions (StockMarket) | 18 |
| Transactions | 34 |
| Retraits | 10 |
| Dépôts | 14 |
| Virements | 10 |
| Lignes d'audit | 33 |

---

## Lancer le projet

### Prérequis
- MySQL 8.0+ (obligatoire pour les window functions)
- phpMyAdmin ou MySQL CLI

### Import dans phpMyAdmin

1. Ouvrir phpMyAdmin
2. Créer une base de données `Revolut`
3. Aller dans l'onglet **Importer**
4. Importer dans cet ordre :

```
sql/01_create_tables.sql
sql/02_insert_data.sql
sql/03_queries_analytiques.sql
```

### Import en ligne de commande

```bash
mysql -u root -p < sql/01_create_tables.sql
mysql -u root -p Revolut < sql/02_insert_data.sql
mysql -u root -p Revolut < sql/03_queries_analytiques.sql
```

---

## Requêtes analytiques incluses

| Requête | Concepts utilisés |
|---|---|
| Top 10 clients par volume | `CTE` + `RANK()` |
| Évolution mensuelle des dépôts | `CTE` + `LAG()` + `DATE_FORMAT` |
| Classement comptes par patrimoine | `RANK()` + `LEFT JOIN` |
| Transactions suspectes | `CASE WHEN` + seuils métier |
| Anomalies statistiques (z-score) | `STDDEV()` + `PARTITION BY` |
| Virement sécurisé | `START TRANSACTION` + `COMMIT` + `ROLLBACK` |
| Index stratégiques | `CREATE INDEX` + `EXPLAIN` |

---

## Contraintes métier respectées

- Un client peut avoir plusieurs comptes
- Un compte appartient à un seul client
- Chaque transaction est historisée avec horodatage
- Les virements sont atomiques (débit + crédit en une seule transaction)
- L'audit log trace toutes les opérations
- Les clés étrangères garantissent l'intégrité référentielle

---

## Compatibilité

> **MySQL 8.0+ requis** pour les window functions (`LAG`, `RANK`, `OVER`, `PARTITION BY`) et les CTEs (`WITH`).  
> Moteur de stockage : **InnoDB** (obligatoire pour les clés étrangères et les transactions).
