"use client";

import { useState, useEffect } from "react";
import { TrendingUp } from "lucide-react";
import {
  PieChart,
  Pie,
  Cell,
  Tooltip,
  Label,
  ResponsiveContainer,
} from "recharts";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { ChartContainer } from "@/components/ui/chart";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

export function BorrowedStatsCard() {
  const [borrowed, setBorrowed] = useState(0);
  const [available, setAvailable] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchSnapshot = async () => {
      const token = localStorage.getItem("access_token");
      try {
        setLoading(true);
        setError(null);

        const resp = await fetch(`${API_BASE_URL}/api/inventory/`, {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        });

        if (!resp.ok) {
          setError(`Failed: ${resp.status}`);
          setLoading(false);
          return;
        }

        const data = await resp.json();
        setBorrowed(Number(data.borrowed ?? 0));
        setAvailable(Number(data.available ?? 0));
        setLoading(false);
      } catch (e: any) {
        setError(e?.message || "Network error");
        setLoading(false);
      }
    };

    fetchSnapshot();
  }, []);

  const total = borrowed + available;
  const pct = total > 0 ? Math.round((borrowed / total) * 100) : 0;

  const pieData = [
    { name: "Borrowed", value: borrowed, fill: "var(--chart-1)" },
    { name: "Available", value: available, fill: "var(--chart-2)" },
  ];

  return (
    <Card className="flex flex-col h-full" data-slot="card">
      <CardHeader className="items-center pb-0">
        <CardTitle>Borrowed Items</CardTitle>
        <CardDescription>Snapshot (Borrowed vs Available)</CardDescription>
      </CardHeader>

    <CardContent className="flex-1 p-0">
  {loading ? (
    <div className="h-[220px] flex items-center justify-center text-muted-foreground">
      Loading...
    </div>
  ) : error ? (
    <div className="h-[220px] flex items-center justify-center text-red-500">
      {error}
    </div>
  ) : (
    <ChartContainer
      config={{
        borrowed: { label: "Borrowed", color: "var(--chart-1)" },
        available: { label: "Available", color: "var(--chart-2)" },
      }}
      className="w-full h-[320px] p-0" // <— fixed height, no padding
    >
      <ResponsiveContainer width="100%" height="100%">
        <PieChart margin={{ top: 8, right: 8, bottom: 8, left: 8 }}>
          <Pie
            data={pieData}
            dataKey="value"
            nameKey="name"
            innerRadius="58%"   // % keeps it inside the box
            outerRadius="82%"
            startAngle={90}
            endAngle={-270}
            stroke="none"
            isAnimationActive
          >
            {pieData.map((entry) => (
              <Cell key={entry.name} fill={entry.fill} />
            ))}
            <Label
              content={({ viewBox }) => {
                if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                  const cx = viewBox.cx as number;
                  const cy = viewBox.cy as number;
                  return (
                    <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle">
                      <tspan x={cx} y={cy} className="fill-foreground text-4xl font-bold">
                        {borrowed}
                      </tspan>
                      <tspan x={cx} y={cy + 22} className="fill-muted-foreground text-sm">
                        of {total} ({pct}%)
                      </tspan>
                    </text>
                  );
                }
                return null;
              }}
            />
          </Pie>
          <Tooltip formatter={(val, name) => [String(val), String(name)]} />
        </PieChart>
      </ResponsiveContainer>
    </ChartContainer>
  )}
</CardContent>


      <CardFooter className="flex-col gap-2 text-sm">
        <div className="flex items-center gap-2 leading-none font-medium">
          {borrowed > 0 ? "Borrowing activity detected" : "No items borrowed"}
          <TrendingUp className="h-4 w-4" />
        </div>
        <div className="text-muted-foreground leading-none">
          {borrowed} borrowed • {available} available
        </div>
      </CardFooter>
    </Card>
  );
}
