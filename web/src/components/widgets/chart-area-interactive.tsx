"use client"

import * as React from "react"
import { Area, AreaChart, CartesianGrid, XAxis } from "recharts"
import { useRouter } from "next/navigation"
import { useIsMobile } from "@/hooks/use-mobile"
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  ToggleGroup,
  ToggleGroupItem,
} from "@/components/ui/toggle-group"


export const description = "An interactive area chart for total transactions"

interface ChartDataPoint {
  period: string // weekStart or month (e.g., "2025-09-15" or "2025-09")
  count: number
  topItems: { item: string; count: number }[]
}

const chartConfig = {
  transactions: {
    label: "Total Transactions",
    color: "#22c55e",
  },
} satisfies ChartConfig

export function ChartAreaInteractive() {
  const router = useRouter()
  const isMobile = useIsMobile()
  const [timeRange, setTimeRange] = React.useState<"7d" | "30d" | "90d">("90d")
  const [chartData, setChartData] = React.useState<ChartDataPoint[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;
  // Handle Select onValueChange type mis match
  const handleTimeRangeChange = (value: string) => {
    if (value === "7d" || value === "30d" || value === "90d") {
      setTimeRange(value)
    }
  }

  // Fetch analytics data
  React.useEffect(() => {
    const fetchAnalytics = async () => {
      setLoading(true)
      setError(null)
      try {
        const token = localStorage.getItem("access_token") || localStorage.getItem("token")
        if (!token) {
          setError("Not authenticated. Please login.")
          router.push("/login")
          setLoading(false)
          return
        }

        const response = await fetch(`${API_BASE_URL}/api/analytics/transactions/`, {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        })

        if (!response.ok) {
          if (response.status === 401 || response.status === 403) {
            localStorage.removeItem("access_token")
            localStorage.removeItem("token")
            router.push("/login")
          } else {
            setError(`Failed to fetch analytics: ${response.statusText}`)
          }
          setLoading(false)
          return
        }

        const data = await response.json()
        console.log("Fetched analytics:", data)

        // Select data based on timeRange
        let selectedData: ChartDataPoint[] = []
        if (timeRange === "7d") {
          selectedData = data.weekly.map((item: any) => ({
            period: item.week_start,
            count: item.count,
            topItems: item.top_items,
          }))
        } else if (timeRange === "30d") {
          selectedData = data.monthly.map((item: any) => ({
            period: item.month,
            count: item.count,
            topItems: item.top_items,
          }))
        } else if (timeRange === "90d") {
          selectedData = data.three_months.map((item: any) => ({
            period: item.month,
            count: item.count,
            topItems: item.top_items,
          }))
        }

        setChartData(selectedData)
        setLoading(false)
      } catch (err) {
        console.error("Fetch error:", err)
        setError(err instanceof Error ? err.message : "An error occurred")
        setLoading(false)
      }
    }

    fetchAnalytics()
  }, [router, timeRange])

  // Set default time range for mobile
  React.useEffect(() => {
    if (isMobile) {
      setTimeRange("7d")
    }
  }, [isMobile])

  // Filter data by time range (for weekly data, ensure current week)
  const filteredData = chartData.filter((item) => {
    const date = new Date(item.period)
    const referenceDate = new Date("2025-09-22") // Current date
    let daysToSubtract = timeRange === "7d" ? 7 : timeRange === "30d" ? 30 : 90
    const startDate = new Date(referenceDate)
    startDate.setDate(startDate.getDate() - daysToSubtract)
    return date >= startDate
  })

  return (
    <Card className="@container/card">
      <CardHeader>
        <CardTitle>Total Transactions</CardTitle>
        <CardDescription>
          <span className="hidden @[540px]/card:block">
            Total transactions by {timeRange === "7d" ? "week" : "month"}
          </span>
          <span className="@[540px]/card:hidden">Last 3 months</span>
        </CardDescription>
        <CardAction>
          <ToggleGroup
            type="single"
            value={timeRange}
            onValueChange={(value) => value && setTimeRange(value as "7d" | "30d" | "90d")}
            variant="outline"
            className="hidden *:data-[slot=toggle-group-item]:!px-4 @[767px]/card:flex"
          >
            <ToggleGroupItem value="90d">Last 3 months</ToggleGroupItem>
            <ToggleGroupItem value="30d">Last 30 days</ToggleGroupItem>
            <ToggleGroupItem value="7d">Last 7 days</ToggleGroupItem>
          </ToggleGroup>
          <Select value={timeRange} onValueChange={handleTimeRangeChange}>
            <SelectTrigger
              className="flex w-40 **:data-[slot=select-value]:block **:data-[slot=select-value]:truncate @[767px]/card:hidden"
              size="sm"
              aria-label="Select a time range"
            >
              <SelectValue placeholder="Last 3 months" />
            </SelectTrigger>
            <SelectContent className="rounded-xl">
              <SelectItem value="90d" className="rounded-lg">
                Last 3 months
              </SelectItem>
              <SelectItem value="30d" className="rounded-lg">
                Last 30 days
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
        ) : (
          <ChartContainer config={chartConfig} className="aspect-auto h-[250px] w-full">
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
                  const date = new Date(value)
                  return timeRange === "7d"
                    ? date.toLocaleDateString("en-US", { month: "short", day: "numeric" })
                    : date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
                }}
              />
              <ChartTooltip
                cursor={false}
                content={
                  <ChartTooltipContent
                    labelFormatter={(value) => {
                      const startDate = new Date(value)
                      if (timeRange === "7d") {
                        const endDate = new Date(startDate)
                        endDate.setDate(startDate.getDate() + 6)
                        return `${startDate.toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                        })} - ${endDate.toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                        })}`
                      }
                      return startDate.toLocaleDateString("en-US", { month: "long", year: "numeric" })
                    }}
                    formatter={(value, name, props) => {
                      const { payload } = props
                      const topItems = payload.topItems || []
                      const itemsList = topItems.length > 0 ? (
                        <div style={{ fontFamily: 'IBM Plex Mono, monospace', fontSize: '12px' }}>
                          <strong>Top 5 Items:</strong>
                          <ul style={{ listStyleType: 'none', padding: 0, margin: '4px 0 0 0' }}>
                            {topItems.map((item: { item: string; count: number }, index: number) => (
                              <li key={index}>{item.item}: {item.count}</li>
                            ))}
                          </ul>
                        </div>
                      ) : "No items transacted"
                      return [
                        <span key="count">{value} transactions</span>,
                        itemsList,
                      ]
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
  )
}