"use client";

import * as React from "react";
import { Area, AreaChart, CartesianGrid, XAxis } from "recharts";
import { useRouter } from "next/navigation";
import { useIsMobile } from "@/hooks/use-mobile";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  ToggleGroup,
  ToggleGroupItem,
} from "@/components/ui/toggle-group";

export const description = "An interactive area chart for total transactions";

interface ChartItemCount {
  item: string;
  count: number;
}

interface ChartDataPoint {
  period: string;            // date (YYYY-MM-DD), week_start (YYYY-MM-DD), or month (YYYY-MM)
  count: number;
  items: ChartItemCount[];   // top items for the period
}

const chartConfig = {
  transactions: {
    label: "Total Transactions",
    color: "#22c55e",
  },
} satisfies ChartConfig;


function getWeek(date: Date): number {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000; // Convert to days
  return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
}


export function ChartAreaInteractive() {
  const router = useRouter();
  const isMobile = useIsMobile();
  const [timeRange, setTimeRange] = React.useState<"12m" | "8w" | "7d">("12m");  // REVISED: Updated options
  const [chartData, setChartData] = React.useState<ChartDataPoint[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

  const handleTimeRangeChange = (value: string) => {
    if (value === "12m" || value === "8w" || value === "7d") {
      setTimeRange(value);
    }
  };

  React.useEffect(() => {
    const fetchAnalytics = async () => {
      setLoading(true);
      setError(null);
      try {
        const token =
          localStorage.getItem("access_token") ||
          localStorage.getItem("token");
        if (!token) {
          setError("Not authenticated. Please login.");
          router.push("/login");
          setLoading(false);
          return;
        }

        const response = await fetch(
          `${API_BASE_URL}/api/analytics/transactions/`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
          }
        );

        if (!response.ok) {
          if (response.status === 401 || response.status === 403) {
            localStorage.removeItem("access_token");
            localStorage.removeItem("token");
            router.push("/login");
          } else {
            setError(`Failed to fetch analytics: ${response.statusText}`);
          }
          setLoading(false);
          return;
        }

        const data = await response.json();
        console.log("Fetched analytics:", data);

        // REVISED: Map based on new ranges
        let selectedData: ChartDataPoint[] = [];
        if (timeRange === "7d") {
          selectedData = (data.daily_7 || []).map((item: any) => ({
            period: item.date,  // YYYY-MM-DD
            count: item.count,
            items: item.top_items || [],
          }));
        } else if (timeRange === "8w") {
          selectedData = (data.weekly_8 || []).map((item: any) => ({
            period: item.week_start,  // YYYY-MM-DD (week start)
            count: item.count,
            items: item.top_items || [],
          }));
        } else if (timeRange === "12m") {
          selectedData = (data.monthly_12 || []).map((item: any) => ({
            period: item.month,  // YYYY-MM
            count: item.count,
            items: item.top_items || [],
          }));
        }

        // Sort ascending (past to present) for chart flow
        selectedData.sort((a, b) => new Date(a.period).getTime() - new Date(b.period).getTime());

        setChartData(selectedData);
        setLoading(false);
      } catch (err) {
        console.error("Fetch error:", err);
        setError(err instanceof Error ? err.message : "An error occurred");
        setLoading(false);
      }
    };

    fetchAnalytics();
  }, [router, timeRange, API_BASE_URL]);

  React.useEffect(() => {
    if (isMobile) {
      setTimeRange("7d");
    }
  }, [isMobile]);

  // REVISED: Filter window using range-specific logic
  const filteredData = chartData.filter((item) => {
    const date = new Date(item.period);
    const referenceDate = new Date(); // current time
    let startDate: Date;
    if (timeRange === "7d") {
      startDate = new Date(referenceDate);
      startDate.setDate(startDate.getDate() - 7);
    } else if (timeRange === "8w") {
      startDate = new Date(referenceDate);
      startDate.setDate(startDate.getDate() - (8 * 7));  // 56 days
    } else {  // 12m
      startDate = new Date(referenceDate);
      startDate.setMonth(startDate.getMonth() - 12);
    }
    return date >= startDate;
  });

  return (
    <Card className="@container/card">
      <CardHeader>
        <CardTitle>Total Transactions</CardTitle>
        <CardDescription>
          <span className="hidden @[540px]/card:block">
            {timeRange === "7d" ? "Total transactions by day" : 
             timeRange === "8w" ? "Total transactions by week" : 
             "Total transactions by month"}
          </span>
          <span className="@[540px]/card:hidden">
            {timeRange === "7d" ? "Last 7 days" : 
             timeRange === "8w" ? "Last 8 weeks" : 
             "Last 12 months"}
          </span>
        </CardDescription>
        <CardAction>
          <ToggleGroup
            type="single"
            value={timeRange}
            onValueChange={(value) =>
              value && setTimeRange(value as "12m" | "8w" | "7d")
            }
            variant="outline"
            className="hidden *:data-[slot=toggle-group-item]:!px-4 @[767px]/card:flex"
          >
            <ToggleGroupItem value="12m">Last 12 months</ToggleGroupItem>
            <ToggleGroupItem value="8w">Last 8 weeks</ToggleGroupItem>
            <ToggleGroupItem value="7d">Last 7 days</ToggleGroupItem>
          </ToggleGroup>
          <Select value={timeRange} onValueChange={handleTimeRangeChange}>
            <SelectTrigger
              className="flex w-40 **:data-[slot=select-value]:block **:data-[slot=select-value]:truncate @[767px]/card:hidden"
              size="sm"
              aria-label="Select a time range"
            >
              <SelectValue placeholder="Last 12 months" />
            </SelectTrigger>
            <SelectContent className="rounded-xl">
              <SelectItem value="12m" className="rounded-lg">
                Last 12 months
              </SelectItem>
              <SelectItem value="8w" className="rounded-lg">
                Last 8 weeks
              </SelectItem>
              <SelectItem value="7d" className="rounded-lg">
                Last 7 days
              </SelectItem>
            </SelectContent>
          </Select>
        </CardAction>
      </CardHeader>

      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        {loading ? (
          <div className="text-center">Loading...</div>
        ) : error ? (
          <div className="text-center text-red-600">{error}</div>
        ) : filteredData.length === 0 ? (
          <div className="text-center text-muted-foreground">
            No data available for the selected range.
          </div>
        ) : (
          <ChartContainer
            config={chartConfig}
            className="aspect-auto h-[250px] w-full"
          >
            <AreaChart data={filteredData}>
              <defs>
                <linearGradient id="fillTransactions" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#22c55e" stopOpacity={0.8} />
                  <stop offset="95%" stopColor="#22c55e" stopOpacity={0.1} />
                </linearGradient>
              </defs>

              <CartesianGrid vertical={false} />

              <XAxis
                dataKey="period"
                tickLine={false}
                axisLine={false}
                tickMargin={8}
                minTickGap={32}
                tickFormatter={(value) => {
                  const date = new Date(value);
                  if (isNaN(date.getTime())) return value;
// Helper function: Calculates ISO week number (1-53) for a given date


                  if (timeRange === "7d") {
                    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
                  } else if (timeRange === "8w") {
                    // For weeks, show "Week of [month day]"
                    return `Wk ${getWeek(date)} ${date.toLocaleDateString("en-US", { month: "short", day: "numeric" })}`;
                  } else {  // 12m
                    return date.toLocaleDateString("en-US", { month: "short", year: "numeric" });
                  }
                }}
              />

              <ChartTooltip
                cursor={false}
                content={
                  <ChartTooltipContent
                    labelFormatter={(value) => {
                      const d = new Date(value);
                      if (timeRange === "7d") {
                        return d.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
                      } else if (timeRange === "8w") {
                        return `Week of ${d.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}`;
                      } else {  // 12m
                        return d.toLocaleDateString("en-US", { month: "long", year: "numeric" });
                      }
                    }}
                    formatter={(value, _name, props) => {
                      const { payload } = props as any;
                      const items: ChartItemCount[] = payload?.items || [];

                      const itemsList =
                        items.length > 0 ? (
                          <div
                            key="items"
                            style={{
                              fontFamily: "IBM Plex Mono, monospace",
                              fontSize: "12px",
                            }}
                          >
                            <ul
                              style={{
                                listStyleType: "none",
                                padding: 0,
                                margin: "4px 0 0 0",
                              }}
                            >
                              {items.map((it, idx) => (
                                <li key={`${it.item}-${idx}`}>
                                  {it.item}: {it.count}
                                </li>
                              ))}
                            </ul>
                          </div>
                        ) : (
                          <span key="no-items">No items borrowed</span>
                        );

                      return [<span key="count">{value} transactions</span>, itemsList];
                    }}
                    indicator="dot"
                  />
                }
              />

              <Area
                dataKey="count"
                type="natural"
                fill="url(#fillTransactions)"
                stroke="#22c55e"
                stackId="a"
              />
            </AreaChart>
          </ChartContainer>
        )}
      </CardContent>
    </Card>
  );
}