# Product direction: narrow paid utility MVP

## Decision under test
Do not expand the generic customer / order / income ledger. Test a narrow tool for small-batch and home-based product makers: **true unit-cost and price simulator**.

Working concept name: **قیمت‌یار** (keep repository/app identity unchanged until validation).

## Why this hypothesis
- Generic note-taking, reminders, customer lists and cash ledgers have easy paper and free-app substitutes.
- Local market research surfaced existing home-business order-management offers and product-cost calculators. This confirms demand categories exist, but also means we must not clone them.
- The testable wedge is not “a calculator”; it is a live cost model where one raw-material price change recalculates every affected product, batch, margin and recommended selling price, with a clear warning when current prices erase the target margin.

## Initial customer segment
One-person and very small home-based makers who repeatedly produce items from recipes or bills of materials (for example: cakes / baked goods, candles, soaps, crafts). Do not target all small businesses in the first release.

## Core customer job
“Before I accept an order or change my price, tell me what this product really costs today, what I earn after all costs, and what selling price protects my margin.”

## MVP scope
1. Create raw materials with unit, pack size, purchase price and date.
2. Create a product recipe/BOM with quantities of each material.
3. Include non-material costs: packaging, labor, energy/overhead, waste and sales commission as explicit optional fields.
4. Calculate batch cost, unit cost, gross profit, margin and break-even price.
5. Recalculate all affected products when a material price changes; show which products are impacted and by how much.
6. Simulate a proposed selling price and show the resulting profit/margin before saving it.
7. Keep all data offline on device; support backup/restore using the existing JSON backup mechanism, with schema versioning.

## Not in MVP
- AI chat or generic AI assistant.
- Customer CRM, order pipeline, inventory, accounting, tax, payment gateway or cloud sync.
- Automatic market-price scraping or claims of “best price”.
- Multi-user/team features.
- Subscription/paywall implementation before willingness-to-pay validation.

## Differentiation hypothesis
The paid value is **cost-change impact + margin protection**, not data entry. A user changes one ingredient cost and immediately sees every product whose margin has fallen below their target, the amount of price change needed, and a shareable cost breakdown.

This is a hypothesis, not a proven moat. Competitor research and user tests must challenge it.

## Validation gate before public release
Interview 10–15 real makers. Ask them to show their current costing method and a recent example where a price change affected profit. Do not ask only “would you pay?”. Run a clickable or working prototype with at least 5 testers. Continue only if users repeatedly use the material-price update and product-impact flow, and at least 3 agree to a paid pilot or place a real refundable/clearly disclosed reservation where legally and operationally appropriate.

## Product success metrics
- Time to cost the first product: under 5 minutes.
- Time to update all affected product costs after a supplier price change: under 30 seconds.
- At least 4 of 5 pilot users correctly understand the unit cost and margin.
- Evidence of repeated use after a real material-price change.
- Explicit paid-pilot commitment, not compliments or downloads.

## Technical constraints
- Android-first, Persian RTL, local/offline-first.
- User has phone-only access; build and QA through GitHub Actions.
- Preserve existing customer/order/ledger data. Database migration must be additive and backup compatibility must be tested.
- No destructive schema changes or broad refactors during the MVP.
- Do not claim a feature is tested on the user's phone until the user has actually tested it.

## Immediate implementation sequence
1. Add materials and product recipes tables with an additive SQLite migration.
2. Add a focused “قیمت‌گذاری” area with material and product creation.
3. Implement deterministic cost, margin and price-simulation calculations with unit tests.
4. Add material-price impact screen.
5. Verify backup/restore includes the new tables.
6. Build APK with existing GitHub Actions workflow.
7. Conduct customer validation before adding monetization or more features.
