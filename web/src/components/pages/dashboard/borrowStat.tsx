"use client"

import { useState, useEffect } from "react"
import { TrendingUp } from "lucide-react"
import { RadialBarChart, RadialBar, PolarGrid, PolarRadiusAxis, Label } from "recharts"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { ChartContainer } from "@/components/ui/chart"
import { Button } from "@/components/ui/button"

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL

type RangeOption = "yesterday" | "today" | "week" | "month"

export function BorrowedStatsCard() {
  const [count, setCount] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedRange, setSelectedRange] = useState<RangeOption>("yesterday")

  useEffect(() => {
    const fetchData = async () => {
      const token = localStorage.getItem("access_token")
      try {
        setLoading(true)
        setError(null)

        const resp = await fetch(
          `${API_BASE_URL}/api/analytics/borrowed-stats/?range=${selectedRange}`,
          {
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${token}`,
            },
          }
        )

        if (!resp.ok) {
          setError(`Failed: ${resp.status}`)
          setLoading(false)
          return
        }

        const data = await resp.json()
        setCount(data.count ?? 0)
        setLoading(false)
      } catch (err: any) {
        setError(err.message || "Network error")
        setLoading(false)
      }
    }
    fetchData()
  }, [selectedRange])

  const chartData = [{ name: "Borrowed", value: count, fill: "var(--chart-1)" }]

  return (
    <Card className="flex flex-col" data-slot="card">
      <CardHeader className="items-center pb-0">
        <CardTitle>Borrowed Items</CardTitle>
        <CardDescription>Snapshot ({selectedRange})</CardDescription>

        <div className="flex gap-2 mt-3">
          {(["yesterday", "today", "week", "month"] as RangeOption[]).map((range) => (
            <Button
              key={range}
              size="sm"
              variant={selectedRange === range ? "default" : "outline"}
              onClick={() => setSelectedRange(range)}
            >
              {range.charAt(0).toUpperCase() + range.slice(1)}
            </Button>
          ))}
        </div>
      </CardHeader>

      <CardContent className="flex-1 pb-0">
        {loading ? (
          <div className="h-[200px] flex items-center justify-center text-muted-foreground">Loading...</div>
        ) : error ? (
          <div className="h-[200px] flex items-center justify-center text-red-500">{error}</div>
        ) : (
          <ChartContainer
            config={{ borrowed: { label: "Borrowed", color: "var(--chart-1)" } }}
            className="mx-auto aspect-square max-h-[250px]"
          >
            <RadialBarChart data={chartData} endAngle={count > 0 ? 360 : 0} innerRadius={80} outerRadius={140}>
              <PolarGrid gridType="circle" radialLines={false} stroke="none" className="first:fill-muted last:fill-background" polarRadius={[86, 74]} />
              <RadialBar dataKey="value" background />
              <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
                <Label
                  content={({ viewBox }) => {
                    if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                      return (
                        <text x={viewBox.cx} y={viewBox.cy} textAnchor="middle" dominantBaseline="middle">
                          <tspan x={viewBox.cx} y={viewBox.cy} className="fill-foreground text-4xl font-bold">
                            {count}
                          </tspan>
                          <tspan x={viewBox.cx} y={(viewBox.cy || 0) + 24} className="fill-muted-foreground">
                            Borrowed
                          </tspan>
                        </text>
                      )
                    }
                  }}
                />
              </PolarRadiusAxis>
            </RadialBarChart>
          </ChartContainer>
        )}
      </CardContent>

      <CardFooter className="flex-col gap-2 text-sm">
        <div className="flex items-center gap-2 leading-none font-medium">
          {count > 0 ? "Borrowing activity detected" : "No items borrowed in this period"}
          <TrendingUp className="h-4 w-4" />
        </div>
        <div className="text-muted-foreground leading-none">
          Showing borrowed items count for {selectedRange}
        </div>
      </CardFooter>
    </Card>
  )
}
