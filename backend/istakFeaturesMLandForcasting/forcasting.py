import pandas as pd
from prophet import Prophet

def forecast_featured_items(month_num):
    """
    month_num: string or int ("01" for January, "04" for April, etc.)
    Returns top 5 items predicted for that month.
    """
    df = pd.read_csv("dataset.csv")
    df["ds"] = pd.to_datetime(df["ds"])
    predictions = {}

    # Convert month number to int
    target_month_num = int(month_num)

    for item_name, group in df.groupby("item"):
        if len(group) < 5:
            continue

        # Aggregate monthly
        monthly = group.groupby(group["ds"].dt.to_period("M"))["y"].sum().reset_index()
        monthly.rename(columns={"ds": "month"}, inplace=True)
        monthly["ds"] = monthly["month"].dt.to_timestamp()
        monthly = monthly[["ds", "y"]]

        # Train Prophet
        model = Prophet()
        model.fit(monthly)

        # Forecast 12 months ahead (1 year)
        future = model.make_future_dataframe(periods=12, freq="ME")
        forecast = model.predict(future)

        # Pick only rows with the target month number
        forecast["month_num"] = forecast["ds"].dt.month
        target_forecast = forecast[forecast["month_num"] == target_month_num]

        if not target_forecast.empty:
            # Take the closest upcoming month
            next_pred = target_forecast.iloc[0]["yhat"]
            predictions[item_name] = next_pred

    # Sort and pick top 5
    top_items = sorted(predictions, key=predictions.get, reverse=True)[:5]

    print(f"🌟 Featured items for month {month_num} (Top 5):")
    for idx, item in enumerate(top_items, start=1):
        print(f"{idx}. {item}")

    return top_items

# Example usage:
# forecast_featured_items("01")  # January
# forecast_featured_items("04")  # April
