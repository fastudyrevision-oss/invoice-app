# 🛡️ Quality Assurance & Financial Audit Roadmap

This document serves as the master strategy for verifying the technical and financial integrity of the Invoice Application. It focuses on robust protection against data corruption, calculation drift, and system crashes.

---

## 🛑 1. CRITICAL: System Stability & Integrity
*These scenarios test for catastrophic failure, data loss, or corruption. If these fail, the app is considered unsafe for production.*

| Category | Scenario | Expected Robustness |
| :--- | :--- | :--- |
| **Data Atomicity** | **Partial Save Crash**: Force-quit or crash the app exactly when clicking "Save Order". | **Database Transaction**: Either 100% of the invoice and its batches are saved, or 0% are. No "phantom" invoices with missing items. |
| **Concurrency** | **Race Condition**: Try to sell the same batch from two different UI tabs/windows at the exact same millisecond. | **Row Locking**: The first transaction succeeds; the second must fail with a "Stock no longer available" error. |
| **Schema Drift** | **Migration Failure**: Manually delete a required column (like `category`) and restart the app. | **Auto-Healing**: `DatabaseHelper` must detect the missing column and re-add it without losing existing data. |

---

## 🏛️ 2. MoSCoW Testing Strategy

### ✅ MUST HAVE: Core Financial Accuracy
*Financial non-negotiables. Any discrepancy here is a high-priority bug.*

- [ ] **Accrual vs. Cash Consistency**: Verify "Net Profit" matches `(Sales + Manual Income) - (COGS + Expenses + Losses)`.
- [ ] **FIFO Batch Depletion**: Ensure older/expiring stock is ALWAYS depleted before newer stock to prevent financial leakage.
- [ ] **immutable Posted Orders**: Ensure once an invoice is "Posted", no field (price, qty, customer) can be changed via the UI.
- [ ] **Weighted Average Stocking**: When buying new stock at RM 10.50 after buying at RM 10.00, the `product.cost_price` must update to reflect the weighted average.

### 📈 SHOULD HAVE: Complex Edge Cases
*Scenarios that occur in real business environments but are often overlooked.*

- [ ] **The "Zero-Value" Transaction**: Add RM 0.00 items or 0 quantity items to an invoice. (Should be blocked or handled gracefully).
- [ ] **Extreme Precision**: Sell an item for RM 0.9999 (should round correctly to 2 decimal places to avoid RM 0.01 drift).
- [ ] **Negative Pending**: Pay RM 110 on a RM 100 invoice. (Should result in RM 10 credit for customer or be blocked).
- [ ] **Multi-Year Pivot**: Query P&L for a range spanning 3 years. (Check for query performance and memory overflow).

### ✨ COULD HAVE: Enhanced Robustness
*Nice-to-have tests that improve long-term developer confidence.*

- [ ] **Emoji & RTL Support**: Product names in Arabic, Urdu, or with 🚀 emojis. (PDF export should not break).
- [ ] **Large Dataset Stress**: Create 10,000 invoices and run a "Product Profit Report". (Check for UI freeze).
- [ ] **Deep Link Sync**: Delete a Category and check if all linked Products correctly move to "Uncategorized".

### 🚫 WON'T HAVE (Current Scope)
- Cloud-sync conflict resolution (handled by single-local-db model).
- Real-time multi-user concurrent editing (App is designed for single-user desktop/mobile use).

---

## 🧪 Critical Condition Matrix

| Scenario | Critical Condition | Expected Behavior |
| :--- | :--- | :--- |
| **Return of Expired Item** | Sales Return of an item that has now officially expired in the warehouse. | System should allow the return but mark it as "Quarantined" or "Wasted" immediately. |
| **Reverse Date Entry** | Adding a Manual Entry for year 2020 while today is 2026. | P&L must correctly recalculate historically without affecting "Today's" balance. |
| **Database Max Size** | SQLite file reaches 2GB. | App should provide a "Cleanup/Archive" or "Backup" prompt before hitting system limits. |

---

## 🛠️ Audit Checklist for Developers
- [ ] Run `recalculateProductFromBatches()` after any direct DB manipulation.
- [ ] Verify `AuditLogger` presence for every "Delete" action.
- [ ] Check if `is_synced` flags are updated if moving to a cloud-hybrid model.
- [ ] Test PDF layout on "Portrait" vs "Landscape" settings.
