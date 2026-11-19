import csv

from db import SessionLocal, init_db
from models import FoodCookingMethod, FoodItem


def seed_food_items(csv_path="food_items.csv"):
    init_db()
    session = SessionLocal()
    try:
        foods = {(fi.category, fi.name): fi for fi in session.query(FoodItem).all()}
        added = updated = 0
        wanted = []  # (FoodItem, [cooking methods])
        with open(csv_path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                key = (row["category"], row["name"])
                portion = row["portion_description"] or ""
                fi = foods.get(key)
                if fi is None:
                    fi = FoodItem(category=row["category"], name=row["name"], portion_description=portion)
                    session.add(fi)
                    foods[key] = fi
                    added += 1
                elif (fi.portion_description or "") != portion:
                    fi.portion_description = portion
                    updated += 1
                methods = [m.strip() for m in (row.get("cooking_methods") or "").split("|") if m.strip()]
                wanted.append((fi, methods))
        session.flush()  # gives the new foods their food_item_id

        have = {(cm.food_item_id, cm.name) for cm in session.query(FoodCookingMethod).all()}
        methods_added = 0
        for fi, methods in wanted:
            for name in methods:
                if (fi.food_item_id, name) not in have:
                    session.add(FoodCookingMethod(food_item_id=fi.food_item_id, name=name))
                    have.add((fi.food_item_id, name))
                    methods_added += 1
        session.commit()
        print(f"Food items: {added} added, {updated} updated. Cooking methods: {methods_added} added.")
    finally:
        session.close()


if __name__ == "__main__":
    seed_food_items()
