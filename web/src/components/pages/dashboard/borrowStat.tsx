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

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL!;

export function BorrowedStatsCard() {
  // From API
  const [borrowedTransactions, setBorrowedTransactions] = useState(0); // active borrowed = yellow + red
  const [returnedTransactions, setReturnedTransactions] = useState(0);  // "Available"
  const [overdueTransactions, setOverdueTransactions] = useState(0);    // red
  const [nonOverdueBorrowedTransactions, setNonOverdueBorrowedTransactions] = useState(0); // yellow

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();

    (async () => {
      const token = localStorage.getItem("access_token");
      try {
        setLoading(true);
        setError(null);

        const resp = await fetch(`${API_BASE_URL}/api/inventory/`, {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          signal: controller.signal,
        });

        if (!resp.ok) {
          setError(`Failed: ${resp.status}`);
          setLoading(false);
          return;
        }

        const data = await resp.json();

        // API contract from your view:
        // borrowedTransactions  -> active borrowed (yellow + red)
        // returnedTransactions  -> available
        // overdueTransactions   -> red
        // nonOverdueBorrowedTransactions -> yellow
        setBorrowedTransactions(Number(data.borrowedTransactions ?? 0));
        setReturnedTransactions(Number(data.returnedTransactions ?? 0));
        setOverdueTransactions(Number(data.overdueTransactions ?? 0));
        setNonOverdueBorrowedTransactions(
          Number(data.nonOverdueBorrowedTransactions ?? 0)
        );
        setLoading(false);
      } catch (e: any) {
        if (e?.name !== "AbortError") {
          setError(e?.message || "Network error");
          setLoading(false);
        }
      }
    })();

    return () => controller.abort();
  }, []);

  // Derive consistently from state (guards against any backend mismatch)
  const available = Math.max(0, returnedTransactions);
  const yellow = Math.max(0, nonOverdueBorrowedTransactions);
  const red = Math.max(0, overdueTransactions);
  const borrowedActive = yellow + red; // should equal borrowedTransactions
  const total = available + borrowedActive;

  const pieData = [
    { name: "Available", value: available, fill: "#4CAF50" },
    { name: "Borrowed", value: yellow, fill: "#FFC107" },
    { name: "Overdue", value: red, fill: "#F44336" },
  ];

  const pctBorrowed = total > 0 ? Math.round((borrowedActive / total) * 100) : 0;
  const pctOverdue = borrowedActive > 0 ? Math.round((red / borrowedActive) * 100) : 0;

  return (
    <Card className="flex flex-col h-full" data-slot="card">
      <CardHeader className="items-center pb-0">
        <CardTitle>Transactions for Today</CardTitle>
        <CardDescription>Snapshot (Available, Borrowed, Overdue)</CardDescription>
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
              available: { label: "Available", color: "#4CAF50" },
              borrowed: { label: "Borrowed", color: "#FFC107" },
              overdue: { label: "Overdue", color: "#F44336" },
            }}
            className="w-full h-[320px] p-0"
          >
            <ResponsiveContainer width="100%" height="100%">
              <PieChart margin={{ top: 8, right: 8, bottom: 8, left: 8 }}>
                <Pie
                  data={pieData}
                  dataKey="value"
                  nameKey="name"
                  innerRadius="58%"
                  outerRadius="82%"
                  startAngle={90}
                  endAngle={-270}
                  stroke="none"
                  isAnimationActive
                  minAngle={1}      // helps tiny slices show
                  paddingAngle={1}   // subtle spacing
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
                              {borrowedActive}
                            </tspan>
                            <tspan x={cx} y={cy + 22} className="fill-muted-foreground text-sm">
                              of {total} ({pctBorrowed}%)
                            </tspan>
                            {red > 0 && (
                              <tspan x={cx} y={cy + 40} className="fill-destructive text-xs">
                                {red} overdue ({pctOverdue}%)
                              </tspan>
                            )}
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
          {borrowedActive > 0 ? "Borrowing activity detected" : "No transactions"}
          <TrendingUp className="h-4 w-4" />
        </div>
        <div className="text-muted-foreground leading-none">
          {available} available • {borrowedActive} borrowed • {red} overdue
        </div>
      </CardFooter>
    </Card>
  );
}
