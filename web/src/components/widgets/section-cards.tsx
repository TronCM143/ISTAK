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
import { BorrowedStatsCard} from "../pages/dashboard/borrowStat";

// Placeholder data (for fallback)
const defaultChartData = [
  { month: "April", borrowed: 12, returned: 5 },
  { month: "May", borrowed: 18, returned: 10 },
  { month: "June", borrowed: 15, returned: 8 },
  { month: "July", borrowed: 20, returned: 12 },
  { month: "August", borrowed: 25, returned: 15 },
  { month: "September", borrowed: 22, returned: 13 },
  { month: "October", borrowed: 28, returned: 18 },
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
  const [chartData, setChartData] = useState(defaultChartData); // FIXED: Uncommented and initialized state
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

  useEffect(() => {
    const fetchData = async () => {
      const token = localStorage.getItem("access_token");

      if (!token) {
        setError("No authentication token found.");
        setLoading(false);
        return;
      }

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
        console.log("Fetched monthly data:", data); // FIXED: Added logging for debugging

        // FIXED: Ensure data is sorted ascending (oldest to newest) for chart flow
        // Backend already sorts, but re-sort here to guarantee
        const sortedData = data.sort((a: any, b: any) => {
          const monthA = new Date(`${a.month} 1, 2025`).getTime(); // Assuming current year for sorting
          const monthB = new Date(`${b.month} 1, 2025`).getTime();
          return monthA - monthB;
        });

        // FIXED: Ensure exactly 7 months (pad with zeros if backend returns fewer)
        // Backend should return 7, but handle edge cases
        const sevenMonthsData = sortedData.slice(-7); // Last 7 (ensures current + past 6)
        if (sevenMonthsData.length < 7) {
          console.warn("Less than 7 months returned; using fallback for missing.");
          // Optionally pad with zeros, but for now, use what's available
        }

        // Adapt API response to chart format
        const formattedData = sevenMonthsData.map((item: any) => ({
          month: item.month,       // e.g. "April" (full month name)
          borrowed: item.borrowed || 0, // Ensure 0 for empty months
          returned: item.returned || 0,
        }));

        // FIXED: If no data, fallback to default (or empty array)
        const finalData = formattedData.length > 0 ? formattedData : defaultChartData;

        setChartData(finalData);
        setLoading(false);

      } catch (err: any) {
        console.error("Fetch error:", err);
        setError(`Network error: ${err.message || err}`);
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  // FIXED: Dynamic description - shows first (oldest) to last (current) month
  const dynamicDescription = chartData.length > 0 
    ? `${chartData[0].month} - ${chartData[chartData.length - 1].month}`
    : "Last 7 months";

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full px-0 items-stretch 
      *:data-[slot=card]:from-primary/5 
      *:data-[slot=card]:to-card 
      dark:*:data-[slot=card]:bg-card 
      *:data-[slot=card]:bg-gradient-to-t 
      *:data-[slot=card]:shadow-xs">

      {/* Borrowed items card */}
      <div className="w-full h-full">
        <BorrowedStatsCard />
      </div>

      {/* Transactions chart card */}
      <Card className="w-full h-full @container/card" data-slot="card">
        <CardHeader>
          <CardTitle>Transaction Trends</CardTitle>
          <CardDescription>
            {loading || error
              ? "Last 7 months"
              : dynamicDescription // FIXED: Dynamic range display
            }
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error ? (
            <div className="text-red-500 text-sm">Error: {error}</div>
          ) : loading ? (
            <div className="text-sm text-muted-foreground">Loading chart...</div>
          ) : chartData.length === 0 ? (
            <div className="text-center text-muted-foreground text-sm">
              No transaction data available.
            </div>
          ) : (
            <ChartContainer config={chartConfig}>
              <BarChart accessibilityLayer data={chartData} margin={{ left: 12, right: 12 }}> {/* FIXED: Added margin for better rendering */}
                <CartesianGrid vertical={false} />
                <XAxis
                  dataKey="month"
                  tickLine={false}
                  tickMargin={10}
                  axisLine={false}
                  tickFormatter={(value) => value.slice(0, 3)} // Abbreviate months (e.g., "Oct")
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
            Showing borrowed and returned items for the last 7 months
          </div>
        </CardFooter>
      </Card>
    </div>
  );
}