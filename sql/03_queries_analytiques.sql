-- ============================================================
-- REVOLUT BANKING DATABASE
-- Fichier 3 : Requêtes analytiques + Index + Transactions
-- Projet Final — Système Bancaire Digital
-- MySQL 8.0+ requis (window functions, CTE)
-- ============================================================

USE Revolut;

-- ============================================================
-- SECTION 1 : INDEX STRATÉGIQUES (Optimisation)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_transactions_account
    ON Transactions(account_id);

CREATE INDEX IF NOT EXISTS idx_transactions_type
    ON Transactions(type_id);

CREATE INDEX IF NOT EXISTS idx_transactions_date
    ON Transactions(transaction_date);

CREATE INDEX IF NOT EXISTS idx_account_owner
    ON Account(owner);

-- Vérifier les index créés
SHOW INDEX FROM Transactions;
SHOW INDEX FROM Account;


-- ============================================================
-- SECTION 2 : EXPLAIN (plan d'exécution avant/après index)
-- ============================================================

EXPLAIN
SELECT t.*, u.name
FROM Transactions t
JOIN Account a ON a.id = t.account_id
JOIN Users u   ON u.id = a.owner
WHERE t.type_id = 1;


-- ============================================================
-- SECTION 3 : TOP 10 CLIENTS PAR VOLUME DE TRANSACTIONS
-- Concepts : CTE + RANK() + window function
-- ============================================================

WITH stats AS (
    SELECT
        u.id,
        u.name,
        u.email,
        COUNT(t.id)             AS nb_transactions,
        SUM(t.amount)           AS total_transactions,
        ROUND(AVG(t.amount), 2) AS montant_moyen
    FROM Users u
    JOIN Account a      ON a.owner = u.id
    JOIN Transactions t ON t.account_id = a.id
    GROUP BY u.id, u.name, u.email
)
SELECT
    *,
    RANK() OVER (ORDER BY total_transactions DESC) AS rang
FROM stats
ORDER BY rang
LIMIT 10;


-- ============================================================
-- SECTION 4 : TOP 10 CLIENTS PAR DÉPÔTS
-- Concepts : JOIN multiple + agrégation + filtre sur type
-- ============================================================

SELECT
    u.id,
    u.name,
    u.email,
    COUNT(t.id)      AS nb_depots,
    SUM(t.amount)    AS total_depose,
    MAX(t.amount)    AS plus_gros_depot
FROM Users u
JOIN Account a      ON a.owner = u.id
JOIN Transactions t ON t.account_id = a.id
JOIN TransactionType tt ON tt.id = t.type_id
WHERE tt.name = 'Deposit'
GROUP BY u.id, u.name, u.email
ORDER BY total_depose DESC
LIMIT 10;


-- ============================================================
-- SECTION 5 : ÉVOLUTION MENSUELLE DES DÉPÔTS
-- Concepts : CTE + LAG() + DATE_FORMAT + variation %
-- ============================================================

WITH stats_mensuelles AS (
    SELECT
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS mois_annee,
        COUNT(t.id)             AS nb_depots,
        SUM(t.amount)           AS volume_total,
        ROUND(AVG(t.amount), 2) AS montant_moyen,
        MIN(t.amount)           AS min_depot,
        MAX(t.amount)           AS max_depot,
        COUNT(DISTINCT a.owner) AS nb_clients_actifs
    FROM Transactions t
    JOIN Account a ON a.id = t.account_id
    JOIN TransactionType tt ON tt.id = t.type_id
    WHERE tt.name = 'Deposit'
    GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m')
)
SELECT
    mois_annee,
    nb_depots,
    volume_total,
    montant_moyen,
    min_depot,
    max_depot,
    nb_clients_actifs,
    LAG(volume_total) OVER (ORDER BY mois_annee) AS volume_mois_precedent,
    ROUND(
        (volume_total - LAG(volume_total) OVER (ORDER BY mois_annee))
        / LAG(volume_total) OVER (ORDER BY mois_annee) * 100,
    2) AS variation_pct
FROM stats_mensuelles
ORDER BY mois_annee DESC;


-- ============================================================
-- SECTION 6 : CLASSEMENT DES COMPTES PAR ACTIVITÉ ET PATRIMOINE
-- Concepts : RANK() + LEFT JOIN + agrégation + calcul patrimoine
-- ============================================================

SELECT
    a.id                                               AS account_id,
    u.name                                             AS proprietaire,
    a.IBAN,
    a.balance                                          AS solde,
    a.stockValue                                       AS valeur_actions,
    (a.balance + a.stockValue)                         AS patrimoine_total,
    COUNT(t.id)                                        AS nb_transactions,
    RANK() OVER (ORDER BY (a.balance + a.stockValue) DESC) AS rang_patrimoine,
    RANK() OVER (ORDER BY COUNT(t.id) DESC)            AS rang_activite
FROM Account a
JOIN Users u ON u.id = a.owner
LEFT JOIN Transactions t ON t.account_id = a.id
GROUP BY a.id, u.name, a.IBAN, a.balance, a.stockValue
ORDER BY patrimoine_total DESC
LIMIT 10;


-- ============================================================
-- SECTION 7 : TRANSACTIONS SUSPECTES (détection fraude)
-- Concepts : CASE WHEN + seuils métier + jointures multiples
-- ============================================================

SELECT
    t.id                    AS transaction_id,
    u.name                  AS utilisateur,
    u.email,
    a.IBAN,
    tt.name                 AS type_transaction,
    t.amount,
    t.transaction_date,
    CASE
        WHEN t.amount > 5000
            THEN 'Montant élevé (> 5000 €)'
        WHEN tt.name = 'Withdrawal' AND t.amount > a.withdrawalLimit * 0.8
            THEN 'Proche limite retrait (> 80%)'
        WHEN tt.name = 'Transfer'   AND t.amount > a.transferLimit   * 0.8
            THEN 'Proche limite virement (> 80%)'
        ELSE 'Autre'
    END AS raison_suspicion
FROM Transactions t
JOIN Account a      ON a.id = t.account_id
JOIN Users u        ON u.id = a.owner
JOIN TransactionType tt ON tt.id = t.type_id
WHERE
    t.amount > 5000
    OR (tt.name = 'Withdrawal' AND t.amount > a.withdrawalLimit * 0.8)
    OR (tt.name = 'Transfer'   AND t.amount > a.transferLimit   * 0.8)
ORDER BY t.amount DESC;


-- ============================================================
-- SECTION 8 : ANOMALIES STATISTIQUES (z-score)
-- Concepts : CTE + STDDEV() + PARTITION BY + z-score
-- ============================================================

WITH stats_retraits AS (
    SELECT
        u.id   AS user_id,
        u.name,
        t.amount,
        t.transaction_date,
        AVG(t.amount)    OVER (PARTITION BY u.id) AS moyenne_user,
        STDDEV(t.amount) OVER (PARTITION BY u.id) AS ecart_type_user
    FROM Users u
    JOIN Account a      ON a.owner = u.id
    JOIN Transactions t ON t.account_id = a.id
    JOIN TransactionType tt ON tt.id = t.type_id
    WHERE tt.name = 'Withdrawal'
)
SELECT
    user_id,
    name,
    amount                    AS montant_retrait,
    transaction_date,
    ROUND(moyenne_user, 2)    AS moyenne_habituelle,
    ROUND(ecart_type_user, 2) AS ecart_type,
    CASE
        WHEN ecart_type_user = 0 THEN NULL
        ELSE ROUND((amount - moyenne_user) / ecart_type_user, 2)
    END AS z_score,
    CASE
        WHEN ecart_type_user = 0                             THEN 'Indéterminé (écart-type nul)'
        WHEN (amount - moyenne_user) / ecart_type_user > 3  THEN 'Critique (> 3 écarts-type)'
        WHEN (amount - moyenne_user) / ecart_type_user > 2  THEN 'Anormal (> 2 écarts-type)'
        ELSE 'Normal'
    END AS alerte
FROM stats_retraits
WHERE ecart_type_user = 0
   OR (amount - moyenne_user) / ecart_type_user > 2
ORDER BY z_score DESC;


-- ============================================================
-- SECTION 9 : ANOMALIES COMPORTEMENTALES MENSUELLES
-- Concepts : double CTE + LAG() + PARTITION BY user + HAVING
-- ============================================================

WITH stats_clients AS (
    SELECT
        u.id              AS user_id,
        u.name,
        YEAR(t.transaction_date)  AS annee,
        MONTH(t.transaction_date) AS mois,
        tt.name                   AS type_transaction,
        COUNT(t.id)               AS nb_transactions,
        SUM(t.amount)             AS volume_total
    FROM Users u
    JOIN Account a      ON a.owner = u.id
    JOIN Transactions t ON t.account_id = a.id
    JOIN TransactionType tt ON tt.id = t.type_id
    GROUP BY u.id, u.name, annee, mois, tt.name
),
variations AS (
    SELECT
        user_id, name, annee, mois, type_transaction,
        nb_transactions, volume_total,
        LAG(nb_transactions) OVER (
            PARTITION BY user_id, type_transaction ORDER BY annee, mois
        ) AS nb_precedent,
        CASE
            WHEN LAG(nb_transactions) OVER (
                PARTITION BY user_id, type_transaction ORDER BY annee, mois
            ) > 0
            THEN ROUND(
                (nb_transactions - LAG(nb_transactions) OVER (
                    PARTITION BY user_id, type_transaction ORDER BY annee, mois
                )) * 100.0
                / LAG(nb_transactions) OVER (
                    PARTITION BY user_id, type_transaction ORDER BY annee, mois
                ), 2)
            ELSE NULL
        END AS variation_nb_pct,
        CASE
            WHEN LAG(volume_total) OVER (
                PARTITION BY user_id, type_transaction ORDER BY annee, mois
            ) > 0
            THEN ROUND(
                (volume_total - LAG(volume_total) OVER (
                    PARTITION BY user_id, type_transaction ORDER BY annee, mois
                )) * 100.0
                / LAG(volume_total) OVER (
                    PARTITION BY user_id, type_transaction ORDER BY annee, mois
                ), 2)
            ELSE NULL
        END AS variation_volume_pct
    FROM stats_clients
)
SELECT
    user_id, name, annee, mois, type_transaction,
    nb_transactions, volume_total,
    variation_nb_pct, variation_volume_pct,
    CASE
        WHEN ABS(variation_nb_pct)     > 200 THEN 'Anomalie critique : explosion/chute transactions'
        WHEN ABS(variation_volume_pct) > 300 THEN 'Anomalie critique : explosion/chute volume'
        WHEN ABS(variation_nb_pct)     > 100 THEN 'Alerte : variation importante transactions'
        WHEN ABS(variation_volume_pct) > 150 THEN 'Alerte : variation importante volume'
        ELSE 'Normal'
    END AS niveau_alerte
FROM variations
WHERE ABS(variation_nb_pct) > 100
   OR ABS(variation_volume_pct) > 150
ORDER BY ABS(variation_volume_pct) DESC;


-- ============================================================
-- SECTION 10 : TABLEAU DE BORD GLOBAL
-- Concepts : UNION ALL + agrégations + CAST
-- ============================================================

SELECT 'Nombre total utilisateurs'        AS indicateur, CAST(COUNT(*) AS CHAR) AS valeur FROM Users
UNION ALL
SELECT 'Nombre total comptes',             CAST(COUNT(*) AS CHAR) FROM Account
UNION ALL
SELECT 'Nombre total transactions',        CAST(COUNT(*) AS CHAR) FROM Transactions
UNION ALL
SELECT 'Volume total transactions (€)',    CAST(ROUND(SUM(amount), 2) AS CHAR) FROM Transactions
UNION ALL
SELECT 'Transaction moyenne (€)',          CAST(ROUND(AVG(amount), 2) AS CHAR) FROM Transactions
UNION ALL
SELECT 'Total dépôts (€)',
    CAST(ROUND(SUM(CASE WHEN tt.name = 'Deposit'    THEN t.amount ELSE 0 END), 2) AS CHAR)
FROM Transactions t JOIN TransactionType tt ON tt.id = t.type_id
UNION ALL
SELECT 'Total retraits (€)',
    CAST(ROUND(SUM(CASE WHEN tt.name = 'Withdrawal' THEN t.amount ELSE 0 END), 2) AS CHAR)
FROM Transactions t JOIN TransactionType tt ON tt.id = t.type_id
UNION ALL
SELECT 'Total virements (€)',
    CAST(ROUND(SUM(CASE WHEN tt.name = 'Transfer'   THEN t.amount ELSE 0 END), 2) AS CHAR)
FROM Transactions t JOIN TransactionType tt ON tt.id = t.type_id
UNION ALL
SELECT 'Transactions suspectes (> 5000 €)', CAST(COUNT(*) AS CHAR) FROM Transactions WHERE amount > 5000;


-- ============================================================
-- SECTION 11 : VIREMENT SÉCURISÉ (Transaction ACID)
-- Concepts : START TRANSACTION + COMMIT + ROLLBACK
-- Exemple : virement de 250 € du compte 1 vers le compte 3
-- ============================================================

START TRANSACTION;

    UPDATE Account
    SET balance = balance - 250.00
    WHERE id = 1;

    UPDATE Account
    SET balance = balance + 250.00
    WHERE id = 3;

    INSERT INTO Transactions (account_id, type_id, amount, transaction_date)
    VALUES (1, 3, 250.00, NOW());

    INSERT INTO AuditLogs (user_id, type, amount, transaction_date)
    VALUES (1, 'TRANSFER', 250.00, NOW());

COMMIT;

-- Vérification après virement
SELECT id, IBAN, balance FROM Account WHERE id IN (1, 3);


-- ============================================================
-- SECTION 12 : DÉMONSTRATION ROLLBACK
-- Tentative de virement impossible → annulation complète
-- ============================================================

START TRANSACTION;

    UPDATE Account SET balance = balance - 9999999.00 WHERE id = 1;

    SELECT balance FROM Account WHERE id = 1;

ROLLBACK;

SELECT id, balance AS balance_apres_rollback FROM Account WHERE id = 1;
