"use client"

import { useState, useEffect } from "react";
import { IconTrendingUp } from "@tabler/icons-react";
import { TrendingUp } from "lucide-react";
import { Bar, BarChart, CartesianGrid, XAxis } from "recharts";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart";

// Placeholder data (for fallback)
const defaultChartData = [
  { month: "April", borrowed: 12, returned: 5 },
  { month: "May", borrowed: 18, returned: 10 },
  { month: "June", borrowed: 15, returned: 8 },
  { month: "July", borrowed: 20, returned: 12 },
  { month: "August", borrowed: 25, returned: 15 },
  { month: "September", borrowed: 22, returned: 13 },
];

const chartConfig = {
  borrowed: {
    label: "Borrowed",
    color: "#FFC107", // Yellow
  },
  returned: {
    label: "Returned",
    color: "#4CAF50", // Green
  },
} satisfies ChartConfig;

export function SectionCards() {
  const [chartData, setChartData] = useState(defaultChartData);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
    const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;
  useEffect(() => {
    const fetchData = async () => {
      const token = localStorage.getItem("access_token");

      try {
        const resp = await fetch(`${API_BASE_URL}/api/analytics/monthly-transactions/`, {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        });

        if (!resp.ok) {
          if (resp.status === 401 || resp.status === 403) {
            setError("Unauthorized. Please login again.");
          } else {
            const txt = await resp.text();
            setError(`Failed to fetch analytics: ${resp.status} ${txt}`);
          }
          setLoading(false);
          return;
        }

        const data = await resp.json();

        // Adapt API response to chart format
        const formattedData = data.map((item: any) => ({
          month: item.month,       // e.g. "April"
          borrowed: item.borrowed, // number
          returned: item.returned, // number
        }));

        setChartData(formattedData);
        setLoading(false);

      } catch (err: any) {
        setError(`Network error: ${err.message || err}`);
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <div className="*:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card dark:*:data-[slot=card]:bg-card grid grid-cols-1 gap-4 px-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:shadow-xs lg:px-6 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
      {/* Borrowed items card */}
      <Card className="@container/card" data-slot="card">
        <CardHeader>
          <CardDescription>Items Borrowed</CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {loading
              ? "Loading..."
              : error
              ? "N/A"
              : `${chartData.reduce((sum, d) => sum + d.borrowed, 0)} Items`}
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <IconTrendingUp />
              +12.5%
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Expecting more borrowing next month <IconTrendingUp className="size-4" />
          </div>
        </CardFooter>
      </Card>

      {/* Transactions chart card */}
      <Card className="@container/card" data-slot="card">
        <CardHeader>
          <CardTitle>Transaction Trends</CardTitle>
          <CardDescription>
            {loading || error
              ? "Last 6 months"
              : `${chartData[0]?.month} - ${chartData[chartData.length - 1]?.month} 2025`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error ? (
            <div className="text-red-500 text-sm">Error: {error}</div>
          ) : loading ? (
            <div className="text-sm text-muted-foreground">Loading chart...</div>
          ) : (
            <ChartContainer config={chartConfig}>
              <BarChart accessibilityLayer data={chartData}>
                <CartesianGrid vertical={false} />
                <XAxis
                  dataKey="month"
                  tickLine={false}
                  tickMargin={10}
                  axisLine={false}
                  tickFormatter={(value) => value.slice(0, 3)}
                />
                <ChartTooltip
                  cursor={false}
                  content={<ChartTooltipContent indicator="dashed" />}
                />
                <Bar dataKey="borrowed" fill={chartConfig.borrowed.color} radius={4} />
                <Bar dataKey="returned" fill={chartConfig.returned.color} radius={4} />
              </BarChart>
            </ChartContainer>
          )}
        </CardContent>
        <CardFooter className="flex-col items-start gap-2 text-sm">
          <div className="flex gap-2 leading-none font-medium">
            Trending up by 10% this month <TrendingUp className="h-4 w-4" />
          </div>
          <div className="text-muted-foreground leading-none">
            Showing borrowed and returned items for the last 6 months
          </div>
        </CardFooter>
      </Card>
    </div>
  );
}
