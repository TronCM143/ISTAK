"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, CheckCircle2, MinusCircle, RefreshCw, Search } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow
} from "@/components/ui/table";
import { Progress } from "@/components/ui/progress";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL!;

type Prediction = {
  item_name: string;
  condition: string | null;
  predicted_risk: number; // 0..1
  reason: string | null;
  last_checked: string; // ISO
};

type RiskLevel = "High" | "Moderate" | "Low";

function toRiskLevel(p: number): RiskLevel {
  if (p >= 0.7) return "High";
  if (p >= 0.4) return "Moderate";
  return "Low";
}

function levelClasses(level: RiskLevel) {
  switch (level) {
    case "High":
      return { badge: "bg-red-500 text-white", bar: "bg-red-500", dot: "bg-red-500" };
    case "Moderate":
      return { badge: "bg-amber-400 text-black", bar: "bg-amber-400", dot: "bg-amber-400" };
    default:
      return { badge: "bg-emerald-500 text-white", bar: "bg-emerald-500", dot: "bg-emerald-500" };
  }
}

export function DamagePredictionCard() {
  const [predictions, setPredictions] = useState<Prediction[]>([]);
  const [filter, setFilter] = useState<RiskLevel | "All">("All");
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  async function fetchData(signal?: AbortSignal) {
    const token = localStorage.getItem("access_token");
    setLoading(true);
    setErr(null);
    try {
      const res = await fetch(`${API_BASE_URL}/api/predictive/insights/`, {
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        signal,
      });
      if (!res.ok) {
        setErr(`Failed: ${res.status}`);
        setPredictions([]);
      } else {
        const data = (await res.json()) as Prediction[];
        setPredictions((data ?? []).map((d) => ({ ...d, predicted_risk: Number(d.predicted_risk ?? 0) })));
      }
    } catch (e: any) {
      if (e?.name !== "AbortError") setErr(e?.message || "Network error");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const controller = new AbortController();
    fetchData(controller.signal);
    return () => controller.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filtered = useMemo(() => {
    const qlc = q.trim().toLowerCase();
    return predictions
      .filter((p) => (filter === "All" ? true : toRiskLevel(p.predicted_risk) === filter))
      .filter((p) => (qlc ? p.item_name.toLowerCase().includes(qlc) : true))
      .sort((a, b) => b.predicted_risk - a.predicted_risk);
  }, [predictions, filter, q]);

  const counts = useMemo(() => {
    const c = { High: 0, Moderate: 0, Low: 0 } as Record<RiskLevel, number>;
    predictions.forEach((p) => c[toRiskLevel(p.predicted_risk)]++);
    return c;
  }, [predictions]);

  const total = predictions.length || 1;
  const pct = (n: number) => Math.round((n / (predictions.length || 1)) * 100);

  return (
    <Card className="flex flex-col h-full">
      <CardHeader className="pb-2">
        <CardTitle>Predicted Damage Risk</CardTitle>
        <CardDescription>Rule-based insights (no ML) using recent borrows, overdue, and prior damage</CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Controls + Summary */}
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          {/* Controls */}
          <div className="flex items-center gap-2 w-full md:max-w-xl">
            <div className="relative w-full">
              <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search item…"
                className="pl-8"
                value={q}
                onChange={(e) => setQ(e.target.value)}
              />
            </div>
            <Button
              variant="outline"
              onClick={() => {
                setFilter((prev) =>
                  prev === "All"
                    ? "High"
                    : prev === "High"
                    ? "Moderate"
                    : prev === "Moderate"
                    ? "Low"
                    : "All"
                );
              }}
              title="Cycle filter"
            >
              {filter === "All" ? "All levels" : `${filter} risk`}
            </Button>
            <Button variant="secondary" onClick={() => fetchData()}>
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </div>

          {/* Counters */}
          <div className="grid grid-cols-3 gap-2 w-full md:w-[420px]">
            <div className="rounded-lg border p-3">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <AlertTriangle className="h-4 w-4 text-red-500" /> High
              </div>
              <div className="mt-1 text-2xl font-semibold">{counts.High}</div>
              <div className="text-xs text-muted-foreground">{pct(counts.High)}% of items</div>
            </div>
            <div className="rounded-lg border p-3">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <MinusCircle className="h-4 w-4 text-amber-400" /> Moderate
              </div>
              <div className="mt-1 text-2xl font-semibold">{counts.Moderate}</div>
              <div className="text-xs text-muted-foreground">{pct(counts.Moderate)}% of items</div>
            </div>
            <div className="rounded-lg border p-3">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <CheckCircle2 className="h-4 w-4 text-emerald-500" /> Low
              </div>
              <div className="mt-1 text-2xl font-semibold">{counts.Low}</div>
              <div className="text-xs text-muted-foreground">{pct(counts.Low)}% of items</div>
            </div>
          </div>
        </div>

        {/* Stacked proportion bar (CSS only) */}
        {/* <div className="rounded-lg border p-3">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">Portfolio Risk Mix</span>
            <span className="text-muted-foreground">{predictions.length} items</span>
          </div>
          <div className="mt-2 h-3 w-full rounded-md bg-muted overflow-hidden">
            <div
              className="h-full bg-red-500"
              style={{ width: `${(counts.High / total) * 100}%` }}
              title={`High • ${pct(counts.High)}%`}
            />
            <div
              className="h-full bg-amber-400"
              style={{ width: `${(counts.Moderate / total) * 100}%` }}
              title={`Moderate • ${pct(counts.Moderate)}%`}
            />
            <div
              className="h-full bg-emerald-500"
              style={{ width: `${(counts.Low / total) * 100}%` }}
              title={`Low • ${pct(counts.Low)}%`}
            />
          </div>
          <div className="mt-2 flex items-center gap-4 text-xs text-muted-foreground">
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-red-500" /> High</span>
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-amber-400" /> Moderate</span>
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-emerald-500" /> Low</span>
          </div>
        </div> */}

        <Separator />

        {/* Content */}
        {loading ? (
          <div className="h-[220px] flex items-center justify-center text-muted-foreground">Loading…</div>
        ) : err ? (
          <div className="h-[220px] flex flex-col items-center justify-center text-red-500">
            <AlertTriangle className="h-5 w-5 mb-1" />
            {err}
          </div>
        ) : filtered.length === 0 ? (
          <div className="h-[220px] flex items-center justify-center text-muted-foreground">
            No items match your filters.
          </div>
        ) : (
          <div className="rounded-md border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[26%]">Item</TableHead>
                  <TableHead className="w-[16%]">Current Condition</TableHead>
                  <TableHead className="w-[14%]">Risk Level</TableHead>
                  <TableHead className="w-[22%]">Risk Score</TableHead>
                  {/* <TableHead className="w-[22%]">Reason</TableHead> */}
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((p) => {
                  const lvl = toRiskLevel(p.predicted_risk);
                  const cls = levelClasses(lvl);
                  const pctScore = Math.round(p.predicted_risk * 100);
                  return (
                    <TableRow key={`${p.item_name}-${p.last_checked}`}>
                      <TableCell className="font-medium">
                        <div className="flex flex-col">
                          <span>{p.item_name}</span>
                          <span className="text-xs text-muted-foreground">
                            {new Date(p.last_checked).toLocaleString()}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell>{p.condition ?? "—"}</TableCell>
                      <TableCell>
                        <Badge className={cls.badge}>{lvl}</Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Progress value={pctScore} className="h-2" />
                          <span className="text-xs text-muted-foreground w-[36px] text-right">
                            {pctScore}%
                          </span>
                        </div>
                      </TableCell>
                      {/* <TableCell>
                        <span className="block max-w-[36ch] truncate" title={p.reason ?? ""}>
                          {p.reason ?? "—"}
                        </span>
                      </TableCell> */}
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>

      <CardFooter className="text-sm text-muted-foreground">
        Predictions are rule-based and refresh on demand. Upgradeable to ML later.
      </CardFooter>
    </Card>
  );
}

export default DamagePredictionCard;
