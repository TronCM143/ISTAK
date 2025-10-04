"use client";

import React, { useEffect, useMemo, useState } from "react";
import {
  Card,
  CardHeader,
  CardContent,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { RefreshCw } from "lucide-react";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

type ForecastItem = {
  rank: number;
  item: string;        // item name from Prophet
  predicted: number;   // not shown (you asked: image + name only)
  month: string;       // "YYYY-MM"
};

type ForecastResponse = {
  month: string;
  top_k: number;
  results: ForecastItem[];
};

type DbItem = {
  id: string | number;
  item_name: string;
  image?: string | null;
};

function getAuthHeaders(): Record<string, string> {
  if (typeof window === "undefined") return {};
  const token = localStorage.getItem("access_token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function normalizeName(s: string | null | undefined) {
  return (s ?? "").toString().trim().toLowerCase();
}

function formatMonthLabel(ym?: string) {
  if (!ym) return "Next Month";
  const [y, m] = ym.split("-");
  const d = new Date(Number(y), Number(m) - 1, 1);
  return d.toLocaleString("default", { month: "long", year: "numeric" });
}

export default function PredictedTopItemsRow() {
  const [forecast, setForecast] = useState<ForecastResponse | null>(null);
  const [dbItems, setDbItems] = useState<DbItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingItems, setLoadingItems] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchForecast = async () => {
    try {
      setError(null);
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/api/forecast/top-items/`, {
        headers: { "Content-Type": "application/json", ...getAuthHeaders() },
        cache: "no-store",
      });
      if (!res.ok) throw new Error(`Forecast: ${res.status}`);
      const data: ForecastResponse = await res.json();
      setForecast(data);
    } catch (e: any) {
      setError(e?.message ?? "Failed to load forecast");
    } finally {
      setLoading(false);
    }
  };

  // Fetch items (handles flat or paginated DRF)
  const fetchAllItems = async (): Promise<DbItem[]> => {
    const res = await fetch(`${API_BASE_URL}/api/items/?page=1&page_size=1000`, {
      headers: { "Content-Type": "application/json", ...getAuthHeaders() },
      cache: "no-store",
    });
    if (!res.ok) throw new Error(`Items: ${res.status}`);
    const data = await res.json();
    if (Array.isArray(data)) return data as DbItem[];
    if (Array.isArray(data.results)) return data.results as DbItem[];
    return [];
  };

  const refreshAll = async () => {
    await Promise.all([
      (async () => {
        await fetchForecast();
      })(),
      (async () => {
        try {
          setLoadingItems(true);
          const items = await fetchAllItems();
          setDbItems(items);
        } catch (e: any) {
          setError(e?.message ?? "Failed to load items");
        } finally {
          setLoadingItems(false);
        }
      })(),
    ]);
  };

  useEffect(() => {
    refreshAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const itemsByName = useMemo(() => {
    const map = new Map<string, DbItem>();
    for (const it of dbItems) {
      map.set(normalizeName(it.item_name), it);
    }
    return map;
  }, [dbItems]);

  // Build display list: top 5, try to match DB for image; otherwise N/A + placeholder
  const displayList = useMemo(() => {
    const list = forecast?.results?.slice(0, 5) ?? [];
    return list.map((f) => {
      const key = normalizeName(f.item);
      const match = itemsByName.get(key);
      return {
        rank: f.rank,
        name: match ? match.item_name : (f.item || "N/A"),
        image: match?.image ?? null,
      };
    });
  }, [forecast, itemsByName]);

  return (
    <Card className="border-border/60 bg-gradient-to-b from-background/60 to-background flex flex-col" data-slot="card">
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <span className="text-white-400">Predicted to be borrowed next month</span>
          </CardTitle>
          <div className="flex items-center gap-2">
            <Badge
              variant="secondary"
              className="bg-green-500/20 text-green-400 border-green-500/30"
            >
              {formatMonthLabel(forecast?.month)}
            </Badge>
            <Button
              size="sm"
              variant="outline"
              onClick={refreshAll}
              className="border-green-600/40 text-green-500 hover:text-green-400 hover:border-green-500"
            >
              <RefreshCw className="h-4 w-4 mr-2" /> Refresh
            </Button>
          </div>
        </div>
    
      </CardHeader>

      <CardContent className="pt-2">
        {(loading || loadingItems) && (
          <div className="flex gap-4 overflow-x-auto pb-2">
            {Array.from({ length: 5 }).map((_, i) => (
              <div
                key={i}
                className="min-w-[160px] w-[160px] rounded-xl border border-border/60 bg-card/70 p-3"
              >
                <div className="h-28 w-full rounded-lg bg-muted/40 animate-pulse" />
                <div className="h-4 w-3/4 mt-3 rounded bg-muted/40 animate-pulse" />
              </div>
            ))}
          </div>
        )}

        {!loading && !loadingItems && displayList.length === 0 && (
          <div className="text-sm text-muted-foreground">No forecast available.</div>
        )}

        {!loading && !loadingItems && displayList.length > 0 && (
          <div className="flex gap-4 overflow-x-auto pb-2">
            {displayList.map((it) => (
              <div
                key={it.rank}
                className="min-w-[160px] w-[160px] rounded-xl border border-border/60 bg-card/70 p-3 hover:bg-card transition"
              >
                {/* Image */}
                {it.image ? (
                  // If your serializer returns absolute URLs, this just works.
                  // If it returns relative URLs, you can prefix with API_BASE_URL if needed.
                  <img
                    src={it.image}
                    alt={it.name}
                    className="h-28 w-full object-cover rounded-lg"
                    loading="lazy"
                  />
                ) : (
                  <div className="h-28 w-full rounded-lg bg-gradient-to-br from-green-500/10 to-transparent grid place-items-center text-xs text-muted-foreground">
                    No Image
                  </div>
                )}

                {/* Name */}
                <div className="mt-3 text-sm font-medium truncate">
                  {it.name || "N/A"}
                </div>
              </div>
            ))}
          </div>
        )}

        {error && (
          <div className="text-sm text-destructive mt-2">{error}</div>
        )}
      </CardContent>
    </Card>
  );
}
