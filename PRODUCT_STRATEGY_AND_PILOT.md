# Product Strategy and Pilot Plan

## Product thesis

A small producer should be able to answer three questions before selling:
1. What does one unit actually cost me?
2. What is the minimum price that avoids a loss?
3. At the price I plan to charge, how much profit remains?

The product is not positioned as a generic notebook or bookkeeping app. Its primary job is product costing, pricing decisions, and detecting margin loss when input prices change.

## First customer segment to validate

Start with one narrow segment: home-based and micro food producers who make repeatable batches, such as cakes, sweets, baked goods, sauces, or packaged foods.

Why start here:
- Products are made from repeatable recipes.
- Ingredient purchase prices change.
- Packaging, labor, waste, and sales fees affect the real unit cost.
- Underpricing can directly erase the producer's margin.

This is a hypothesis, not a proven market conclusion. Do not expand to every kind of small business before validating this segment.

## Core user outcome

"Before I set or accept a price, I can see the real cost per unit, break-even price, target-profit price, and the profit or loss at the price I choose."

## MVP scope

Must work reliably:
- Raw materials, purchase pack size, and purchase price.
- Product recipes and batch yield.
- Packaging, labor, overhead, waste, and sales commission.
- Unit cost, break-even price, target price, and current-price profit.
- Price scenario simulation and saving a chosen selling price.
- Purchase-price history and recalculation of affected products.
- Backup and restore of all user-entered data.

Do not add yet:
- AI chat or generic AI features.
- Social feeds, community, or unrelated business tools.
- Forced account creation.
- Paid subscriptions before willingness-to-pay is tested.
- Cloud sync before the offline workflow and data integrity are proven.

## Pilot interview and task test

Recruit 5–10 producers from the same initial segment. Do not pitch first. Ask them to demonstrate their current costing process.

Ask:
1. Show how you currently calculate the cost of one product.
2. Which costs do you often forget to include?
3. What happens when an ingredient price changes?
4. How do you decide the selling price?
5. Tell me about the last time a price was wrong or profit was lower than expected.
6. What tool do you use now, and what is frustrating about it?
7. After trying this app, which decision did it help you make?
8. Would you pay for it? What would need to be true for the payment to feel worthwhile?

Then ask them to complete these tasks without coaching:
- Add two raw materials.
- Create one product recipe with a batch yield.
- Enter packaging, labor, overhead, and waste.
- Find the break-even and target-profit prices.
- Simulate a lower and a higher selling price.
- Update one ingredient's purchase price and explain what changed.
- Create a backup and restore it.

## Pilot success signals

Track actual behavior, not compliments:
- Can a new user complete their first product without help?
- How long does it take to create a product?
- Do users understand unit cost, break-even, and target price?
- Do they change a real selling-price decision because of the result?
- Do they return after the first session to update a purchase price or add another product?
- Do they independently ask to keep using it?
- Will at least some users commit to a real paid pilot, not just say "it's useful"?

A reasonable first validation target is 5–10 interviews, at least 5 observed task sessions, and 3 genuine paid-pilot commitments before building a subscription system. These are working thresholds, not industry benchmarks.

## Monetization hypothesis

Test a simple paid model only after the core value is demonstrated:
- Free trial or limited free tier to let users calculate a real product.
- Paid tier for multiple products, price-change monitoring, richer reports, and reliable cloud backup/sync once those features exist.
- One-time purchase can also be tested against subscription; do not assume recurring billing is preferred by this audience.

Never charge for a feature that is unreliable or not yet implemented. Account registration should remain optional until cloud features are ready.

## Trust and data safety

- Explain that calculations depend on the costs entered by the user.
- Do not imply tax, accounting, or legal certification.
- Keep backup and restore understandable and test them with real data.
- If cloud accounts are introduced, add secure authentication, account recovery, per-user data isolation, sync conflict handling, privacy terms, and account deletion before launch.

## Current release gate

Do not merge or publish as a production release until:
- Flutter analysis passes.
- Unit tests pass.
- Release APK builds and artifact is verified.
- Install, create/edit data, restart persistence, backup, restore, and calculation flows are tested on a real Android phone.
- A small pilot confirms the product solves a recurring problem.
