# Justification des choix de conception

## Contexte

Base de données bancaire inspirée de Revolut, conçue pour répondre aux exigences du projet final :
cohérence, performance, traçabilité et gestion des accès concurrents.

---

## Choix du moteur de stockage : InnoDB

**Pourquoi InnoDB et pas MyISAM ?**

InnoDB est le seul moteur MySQL supportant les clés étrangères et les transactions ACID.
MyISAM est plus rapide sur les lectures pures mais ne garantit aucune intégrité référentielle.
Dans un contexte bancaire où chaque centime doit être traçable, InnoDB s'impose.

---

## Modélisation des transactions : pattern héritage

Les transactions sont modélisées en deux niveaux :

- `Transactions` : table centrale avec les informations communes (montant, date, compte, type)
- `Withdrawal`, `Deposit`, `Transfer` : tables de détail liées par une relation 1,1

**Pourquoi ce choix ?**

Chaque type de transaction a des attributs spécifiques :
- `Withdrawal` → taux de change (`rate`)
- `Transfer` → référence unique + utilisateur destinataire
- `Deposit` → aucun attribut supplémentaire

Fusionner tout dans une seule table aurait créé de nombreuses colonnes nullable, ce qui viole la 3ème forme normale (3NF).

---

## Clé étrangère BankCard → Country

La table `BankCard` possède un `country_id` (clé étrangère vers `Country`) plutôt qu'une colonne `transaction_country_rate` en dur.

**Pourquoi ?**

Une clé étrangère vers `Country` permet de :
- Récupérer le taux à jour via `JOIN` (pas de dénormalisation)
- Changer un taux dans `Country` sans mettre à jour toutes les cartes

La colonne `transaction_country_rate` est conservée pour l'historique du taux au moment de la transaction.

---

## Index stratégiques

| Index | Colonne | Justification |
|---|---|---|
| `idx_transactions_account` | `Transactions.account_id` | Jointure très fréquente avec `Account` |
| `idx_transactions_type` | `Transactions.type_id` | Filtrage par type (Deposit, Withdrawal...) |
| `idx_transactions_date` | `Transactions.transaction_date` | Tri et regroupement mensuel |
| `idx_account_owner` | `Account.owner` | Jointure fréquente avec `Users` |

**Colonnes non indexées :**

- `Users.sex` : faible sélectivité (seulement 3 valeurs)
- `Account.status` : faible sélectivité (presque toujours 'active')
- `Transactions.amount` : les requêtes sur amount utilisent des plages, pas des égalités exactes

---

## Transactions ACID : niveau d'isolation choisi

Niveau : **REPEATABLE READ** (défaut MySQL InnoDB)

**Pourquoi pas SERIALIZABLE ?**

SERIALIZABLE garantit l'absence de phantom reads mais génère beaucoup de verrous et ralentit les accès concurrents.
REPEATABLE READ est suffisant pour les virements bancaires dans notre contexte car :
- On verrouille la ligne du compte source avec `FOR UPDATE` avant de débiter
- Les phantom reads ne sont pas un risque sur des soldes individuels

---

## Gestion du solde négatif

Le solde ne peut pas être négatif dans nos contraintes métier.
La vérification est faite au niveau applicatif (dans la transaction) plutôt qu'avec une contrainte `CHECK (balance >= 0)`.

**Pourquoi ?**

La contrainte `CHECK` est supportée depuis MySQL 8.0.16 seulement.
De plus, `overdrawnLimit` permet un découvert autorisé, donc le solde peut légalement descendre en dessous de 0 jusqu'à `-overdrawnLimit`.
Une contrainte `CHECK` fixe ne pourrait pas gérer ce cas dynamiquement.

---

## AuditLogs : journalisation complète

Chaque opération (dépôt, retrait, virement) est inscrite dans `AuditLogs` **en plus** de la table `Transactions`.

**Pourquoi deux tables ?**

`Transactions` est la source de vérité métier, optimisée pour les jointures et le reporting.
`AuditLogs` est la trace légale, immuable, qui conserve l'utilisateur ayant initié l'opération — ce qui peut différer du propriétaire du compte (ex: virement initié par un conseiller).
