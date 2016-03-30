Seeding the Plan table

p1 = Stripe::Plan.retrieve("plan-good")
p1 = Stripe::Plan.retrieve("plan-awesome")
p1 = Stripe::Plan.retrieve("plan-free")

Plan.create(stripe_id: p1.id, name: p1.name , price: p1.amount, interval: p1.interval )