import random
from datetime import datetime, timedelta
import pandas as pd

items_clothing = ["barot_saya", "barong_tagalog", "patadyong", "dance_uniform", "headdress_kapasti"]
items_instruments = ["kulintang", "glasses_for_binasuan"]
items_tools = ["bamboo_poles", "coconut_shells", "fan_abaniko", "oil_lamps"]
items_misc = ["mirror_panel", "speaker_system", "props_storage_rack"]

all_items = items_clothing + items_instruments + items_tools + items_misc

def generate_mock_data(start_year=2023, end_year=2024, target_count=700):
    records = []

    # date range across 2 years
    start_date = datetime(start_year, 1, 1)
    end_date = datetime(end_year, 12, 31)
    total_days = (end_date - start_date).days

    while len(records) < target_count:
        # random date
        date_obj = start_date + timedelta(days=random.randint(0, total_days))
        month = date_obj.month

        # Decide item category based on month
        if month in [12, 7]:
            item = random.choice(items_instruments + items_clothing)
        elif month in [1, 6, 10, 5]:
            item = random.choice(items_tools + items_clothing)
        elif month in [3, 4, 8]:  # rare months
            if random.random() < 0.2:  # ~20% chance no borrow
                y = 0
                records.append({"ds": date_obj.strftime("%Y-%m-%d"), "y": y, "item": random.choice(all_items)})
                continue
            else:
                item = random.choice(all_items)
        else:
            item = random.choice(all_items)

        # Borrow count logic
        if item in items_clothing:
            y = random.randint(2, 8)
        elif item in items_instruments:
            y = random.randint(1, 5)
        elif item in items_tools:
            y = random.randint(1, 4)
        else:  # misc
            y = random.randint(1, 2)

        records.append({
            "ds": date_obj.strftime("%Y-%m-%d"),
            "y": y,
            "item": item
        })

    # Convert to DataFrame and sort
    df = pd.DataFrame(records)
    df = df[df["y"] > 0]  # skip 0s
    df["ds"] = pd.to_datetime(df["ds"])
    df = df.sort_values("ds").reset_index(drop=True)
    df["ds"] = df["ds"].dt.strftime("%Y-%m-%d")

    return df


if __name__ == "__main__":
    df = generate_mock_data()
    print(f"Total records: {len(df)}")

    # Print entire DataFrame
    print(df)
    

    df.to_csv("mock_data.csv", index=False)
    
    # Export as list of dictionaries (all records, not just 10)
    data_list = df.to_dict(orient="records")
    print(data_list)
    

