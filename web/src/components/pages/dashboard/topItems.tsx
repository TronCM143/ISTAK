"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  Card, CardHeader, CardContent, CardTitle, CardDescription,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  ChevronLeft, ChevronRight, Crown, ImageOff, RefreshCw,
} from "lucide-react";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

type ForecastItem = {
  rank: number;
  item: string;        // item name from forecast service
  predicted: number;   // optional score; not required for UI
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

function rankBadgeClasses(rank: number) {
  // 1 = gold, 2 = silver, 3 = bronze, else emerald
  if (rank === 1)
    return "bg-gradient-to-br from-amber-400 to-yellow-500 text-black border-amber-500/40";
  if (rank === 2)
    return "bg-gradient-to-br from-zinc-300 to-slate-400 text-black border-slate-400/40";
  if (rank === 3)
    return "bg-gradient-to-br from-orange-400 to-amber-600 text-black border-amber-600/40";
  return "bg-emerald-500/20 text-emerald-400 border-emerald-500/30";
}

export default function PredictedTopItemsRow() {
  const [forecast, setForecast] = useState<ForecastResponse | null>(null);
  const [dbItems, setDbItems] = useState<DbItem[]>([]);
  const [loadingForecast, setLoadingForecast] = useState(true);
  const [loadingItems, setLoadingItems] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const scrollerRef = useRef<HTMLDivElement | null>(null);

  const fetchForecast = async () => {
    try {
      setError(null);
      setLoadingForecast(true);
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
      setLoadingForecast(false);
    }
  };

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

  // Final display list (top 5)
  const displayList = useMemo(() => {
    const list = forecast?.results?.slice(0, 5) ?? [];
    return list.map((f) => {
      const match = itemsByName.get(normalizeName(f.item));
      return {
        rank: f.rank,
        name: match ? match.item_name : (f.item || "N/A"),
        image: match?.image ?? null,
      };
    });
  }, [forecast, itemsByName]);

  const isLoading = loadingForecast || loadingItems;

  const scrollBy = (delta: number) => {
    const el = scrollerRef.current;
    if (!el) return;
    el.scrollBy({ left: delta, behavior: "smooth" });
  };

  return (
    <Card
      className="border-border/60 bg-gradient-to-b from-background/60 to-background flex flex-col"
      data-slot="card"
    >
      <CardHeader className="pb-0">
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Crown className="h-5 w-5 text-amber-400" />
              <span>Top Borrowed (Next Month)</span>
            </CardTitle>
            <CardDescription className="mt-1">
              Forecasted demand — focus on preparation & availability
            </CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Badge
              variant="secondary"
              className="bg-primary/10 text-primary border-primary/20"
            >
              {formatMonthLabel(forecast?.month)}
            </Badge>
            <Button
              size="sm"
              variant="outline"
              onClick={refreshAll}
              className="border-primary/40 text-primary hover:text-primary/90 hover:border-primary"
            >
              <RefreshCw className="h-4 w-4 mr-2" />
              Refresh
            </Button>
          </div>
        </div>
      </CardHeader>

    <CardContent className="pt-0 -mt-[5px]">
  {/* (Optional) Controls — keep if you still want them, now tighter */}
  <div className="flex items-center justify-end gap-1 mb-1">
    <Button
      size="icon"
      variant="ghost"
      className="h-8 w-8"
      onClick={() => scrollBy(-240)}
      aria-label="Scroll left"
    >
      <ChevronLeft className="h-4 w-4" />
    </Button>
    <Button
      size="icon"
      variant="ghost"
      className="h-8 w-8"
      onClick={() => scrollBy(240)}
      aria-label="Scroll right"
    >
      <ChevronRight className="h-4 w-4" />
    </Button>
  </div>

  {/* Loading skeleton — now grid of 5, no scroll */}
  {isLoading && (
    <div className="grid grid-cols-5 gap-3 sm:gap-4">
      {Array.from({ length: 5 }).map((_, i) => (
        <div
          key={i}
          className="w-full rounded-xl border border-border/60 bg-card/70 p-3"
        >
          <div className="relative overflow-hidden rounded-lg aspect-[3/2] bg-muted/40">
            <div className="absolute inset-0 animate-pulse bg-muted/40" />
          </div>
          <div className="h-4 w-4/5 mt-3 rounded bg-muted/40 animate-pulse" />
        </div>
      ))}
    </div>
  )}

  {/* Error */}
  {!isLoading && error && (
    <div className="text-sm text-destructive">{error}</div>
  )}

  {/* Empty */}
  {!isLoading && !error && displayList.length === 0 && (
    <div className="text-sm text-muted-foreground">
      No forecast available.
    </div>
  )}

  {/* Items — grid of 5, auto-resizes to fit container */}
  {!isLoading && !error && displayList.length > 0 && (
    <div className="grid grid-cols-5 gap-3 sm:gap-4">
      {displayList.map((it) => (
        <div
          key={it.rank}
          className="group w-full rounded-xl border border-border/60 bg-card/70 p-3 hover:bg-card transition"
        >
          <div className="relative overflow-hidden rounded-lg aspect-[3/2]">
            {/* Image or placeholder */}
            {it.image ? (
              <img
                src={it.image}
                alt={it.name}
                className="h-full w-full object-cover rounded-lg transition-transform duration-300 group-hover:scale-[1.02]"
                loading="lazy"
              />
            ) : (
              <div className="h-full w-full rounded-lg bg-gradient-to-br from-primary/10 to-transparent grid place-items-center">
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  <ImageOff className="h-4 w-4" />
                  No Image
                </div>
              </div>
            )}

            {/* Rank badge */}
            <div className="absolute left-2 top-2">
              <Badge className={`border ${rankBadgeClasses(it.rank)} shadow-sm`}>
                #{it.rank}
              </Badge>
            </div>

            {/* Bottom overlay name */}
            <div className="absolute inset-x-0 bottom-0 p-2">
              <div className="rounded-lg bg-black/50 backdrop-blur-sm px-2 py-1">
                <div className="text-sm font-medium text-white truncate">
                  {it.name || "N/A"}
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  )}
</CardContent>

    </Card>
  );
}
