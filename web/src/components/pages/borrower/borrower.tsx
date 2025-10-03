"use client";

import React, { useEffect, useState } from "react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { format } from "date-fns";
import { useRouter } from "next/navigation";

type Borrower = {
  id: number;
  name: string;
  school_id: string;
  image?: string | null;
  current_borrow_date: string | null;
};

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

function getAuthHeaders(): Record<string, string> {
  if (typeof window === "undefined") return {};
  const token = localStorage.getItem("access_token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function normalizeBorrower(b: any): Borrower {
  const name =
    b.name ??
    b.borrower_name ??
    b.full_name ??
    (`${b.first_name ?? ""} ${b.last_name ?? ""}`.trim() || "N/A");

  const schoolId =
    b.school_id ??
    b.borrower_schoolID ??
    b.schoolID ??
    b.schoolId ??
    "N/A";

  const image =
    b.image ??
    b.photo ??
    b.avatar ??
    b.image_url ??
    b.photo_url ??
    null;

  const rawBorrowDate =
    b.current_borrow_date ??
    b.current_transaction?.borrow_date ??
    b.latest_transaction?.borrow_date ??
    null;

  const currentBorrowDate = rawBorrowDate ? String(rawBorrowDate) : "null";

  return {
    id: Number(b.id ?? b.pk ?? 0),
    name,
    school_id: String(schoolId),
    image,
    current_borrow_date: currentBorrowDate,
  };
}

export default function Borrowers() {
  const [borrowers, setBorrowers] = useState<Borrower[]>([]);
  const [filtered, setFiltered] = useState<Borrower[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const router = useRouter();

  useEffect(() => {
    const run = async () => {
      try {
        const token = localStorage.getItem("access_token");
        if (!token) {
          router.replace("/login");
          return;
        }

        const res = await fetch(`${API_BASE_URL}/api/borrowers/`, {
          headers: { "Content-Type": "application/json", ...getAuthHeaders() },
        });

        if (res.status === 401) {
          router.replace("/dashboard");
          return;
        }
        if (!res.ok) throw new Error(`Failed to fetch borrowers: ${res.statusText}`);

        const data = await res.json();
        const normalized: Borrower[] = Array.isArray(data)
          ? data.map(normalizeBorrower)
          : (data.results ?? []).map(normalizeBorrower);

        setBorrowers(normalized);
        setFiltered(normalized);
      } catch (err) {
        setError(err instanceof Error ? err.message : "An error occurred");
      } finally {
        setLoading(false);
      }
    };

    run();
  }, [router]);

  useEffect(() => {
    const q = query.trim().toLowerCase();
    if (!q) {
      setFiltered(borrowers);
    } else {
      setFiltered(
        borrowers.filter((b) =>
          [b.name, b.school_id].some((v) => String(v).toLowerCase().includes(q))
        )
      );
    }
  }, [query, borrowers]);

  if (loading) {
    return (
      <div className="p-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-40 bg-muted/60 rounded animate-pulse" />
        ))}
      </div>
    );
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="p-4 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <h1 className="text-2xl font-semibold tracking-tight">Borrowers</h1>
        <div className="flex items-center gap-2">
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search name or ID..."
            className="w-[260px]"
          />
          <Button variant="outline" onClick={() => setQuery("")}>
            Clear
          </Button>
        </div>
      </div>

      {filtered.length === 0 ? (
        <p className="text-muted-foreground text-sm">No borrowers found.</p>
      ) : (
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((b) => (
            <Card
              key={b.id}
              className="border-border/60 bg-card hover:shadow-md transition"
            >
              <CardHeader className="flex flex-col items-center gap-3">
                <Dialog>
                  <DialogTrigger asChild>
                    <Avatar className="h-24 w-24 cursor-pointer">
                      {b.image ? (
                        <AvatarImage src={b.image} alt={b.name} />
                      ) : (
                        <AvatarFallback>
                          {b.name
                            .split(" ")
                            .map((p) => p[0]?.toUpperCase())
                            .slice(0, 2)
                            .join("") || "NA"}
                        </AvatarFallback>
                      )}
                    </Avatar>
                  </DialogTrigger>
                  <DialogContent className="max-w-md">
                    {b.image ? (
                      <img
                        src={b.image}
                        alt={b.name}
                        className="rounded-lg w-full h-auto object-contain"
                      />
                    ) : (
                      <div className="p-8 text-center text-muted-foreground">
                        No image available
                      </div>
                    )}
                  </DialogContent>
                </Dialog>

                <CardTitle className="text-lg text-center">{b.name}</CardTitle>
                <CardDescription className="text-sm text-muted-foreground">
                  ID: {b.school_id}
                </CardDescription>
              </CardHeader>
              <CardContent className="text-center">
                <div className="text-sm text-muted-foreground">
                  Current Borrow Date:
                </div>
                <div className="text-base font-medium">
                  {b.current_borrow_date && b.current_borrow_date !== "null"
                    ? format(
                        new Date(b.current_borrow_date as string),
                        "MMMM d, yyyy"
                      )
                    : "—"}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
