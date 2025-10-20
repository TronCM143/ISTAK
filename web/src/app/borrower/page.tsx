"use client";

import { AppSidebar } from "@/components/widgets/app-sidebar";
import { SiteHeader } from "@/components/widgets/site-header";
import {
  SidebarInset,
  SidebarProvider,
} from "@/components/ui/sidebar";
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
  return_image?: string | null;
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

  const returnImage =
    b.return_image_url ??
    b.return_image ??
    b.return_photo ??
    null;

  const rawBorrowDate =
    b.current_borrow_date ??
    b.last_borrowed_date ??
    b.current_transaction?.borrow_date ??
    b.latest_transaction?.borrow_date ??
    null;

  const currentBorrowDate = rawBorrowDate ? String(rawBorrowDate) : null;

  console.log("Normalized borrower:", { id: b.id, name, school_id: schoolId, image, return_image: returnImage });

  return {
    id: Number(b.id ?? b.pk ?? 0),
    name,
    school_id: String(schoolId),
    image,
    return_image: returnImage,
    current_borrow_date: currentBorrowDate,
  };
}

export default function Page() {
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
    <SidebarProvider
      style={
        {
          "--sidebar-width": "calc(var(--spacing) * 72)",
          "--header-height": "calc(var(--spacing) * 12)",
        } as React.CSSProperties
      }
    >
      <AppSidebar variant="inset" />
      <SidebarInset>
        <SiteHeader title="Borrower List" />
        <div className="flex flex-1 flex-col">
          <div className="@container/main flex flex-1 flex-col gap-2">
            <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
              <div className="p-4 space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                  <h1 className="text-2xl font-semibold tracking-tight">Borrower List</h1>
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
                          <Avatar className="h-16 w-16">
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
                          <CardTitle className="text-lg text-center">{b.name}</CardTitle>
                          <CardDescription className="text-sm text-muted-foreground">
                            ID: {b.school_id}
                          </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            {/* Borrow Image */}
                            <div className="flex flex-col items-center space-y-2">
                              <h3 className="text-sm font-medium text-muted-foreground">Borrow Image</h3>
                              <Dialog>
                                <DialogTrigger asChild>
                                  <div className="cursor-pointer">
                                    {b.image ? (
                                      <img
                                        src={b.image}
                                        alt={`${b.name} borrow image`}
                                        className="rounded-lg w-full h-24 object-cover"
                                        onError={(e) => {
                                          console.error(`Failed to load borrow image for ${b.name}: ${b.image}`);
                                          e.currentTarget.style.display = "none";
                                          const nextSibling = e.currentTarget.nextElementSibling as HTMLElement;
                                          if (nextSibling) nextSibling.style.display = "block";
                                        }}
                                      />
                                    ) : (
                                      <div className="w-full h-24 flex items-center justify-center text-center text-muted-foreground bg-muted/20 rounded-lg text-xs">
                                        No borrow image
                                      </div>
                                    )}
                                    <div
                                      className="w-full h-24 flex items-center justify-center text-center text-muted-foreground bg-muted/20 rounded-lg text-xs"
                                      style={{ display: "none" }}
                                    >
                                      Failed to load image
                                    </div>
                                  </div>
                                </DialogTrigger>
                                <DialogContent className="max-w-lg">
                                  {b.image ? (
                                    <img
                                      src={b.image}
                                      alt={`${b.name} borrow image preview`}
                                      className="rounded-lg w-full h-auto object-contain max-h-[500px]"
                                      onError={(e) => {
                                        console.error(`Failed to load borrow image preview for ${b.name}: ${b.image}`);
                                        e.currentTarget.style.display = "none";
                                        const nextSibling = e.currentTarget.nextElementSibling as HTMLElement;
                                        if (nextSibling) nextSibling.style.display = "block";
                                      }}
                                    />
                                  ) : (
                                    <div className="p-8 text-center text-muted-foreground bg-muted/20 rounded-lg">
                                      No borrow image available
                                    </div>
                                  )}
                                  <div
                                    className="p-8 text-center text-muted-foreground bg-muted/20 rounded-lg"
                                    style={{ display: "none" }}
                                  >
                                    Failed to load image
                                  </div>
                                </DialogContent>
                              </Dialog>
                            </div>

                            {/* Return Image */}
                            <div className="flex flex-col items-center space-y-2">
                              <h3 className="text-sm font-medium text-muted-foreground">Return Image</h3>
                              <Dialog>
                                <DialogTrigger asChild>
                                  <div className="cursor-pointer">
                                    {b.return_image ? (
                                      <img
                                        src={b.return_image}
                                        alt={`${b.name} return image`}
                                        className="rounded-lg w-full h-24 object-cover"
                                        onError={(e) => {
                                          console.error(`Failed to load return image for ${b.name}: ${b.return_image}`);
                                          e.currentTarget.style.display = "none";
                                          const nextSibling = e.currentTarget.nextElementSibling as HTMLElement;
                                          if (nextSibling) nextSibling.style.display = "block";
                                        }}
                                      />
                                    ) : (
                                      <div className="w-full h-24 flex items-center justify-center text-center text-muted-foreground bg-muted/20 rounded-lg text-xs">
                                        N/A (Not yet returned)
                                      </div>
                                    )}
                                    <div
                                      className="w-full h-24 flex items-center justify-center text-center text-muted-foreground bg-muted/20 rounded-lg text-xs"
                                      style={{ display: "none" }}
                                    >
                                      Failed to load image
                                    </div>
                                  </div>
                                </DialogTrigger>
                                <DialogContent className="max-w-lg">
                                  {b.return_image ? (
                                    <img
                                      src={b.return_image}
                                      alt={`${b.name} return image preview`}
                                      className="rounded-lg w-full h-auto object-contain max-h-[500px]"
                                      onError={(e) => {
                                        console.error(`Failed to load return image preview for ${b.name}: ${b.return_image}`);
                                        e.currentTarget.style.display = "none";
                                        const nextSibling = e.currentTarget.nextElementSibling as HTMLElement;
                                        if (nextSibling) nextSibling.style.display = "block";
                                      }}
                                    />
                                  ) : (
                                    <div className="p-8 text-center text-muted-foreground bg-muted/20 rounded-lg">
                                      N/A (Not yet returned)
                                    </div>
                                  )}
                                  <div
                                    className="p-8 text-center text-muted-foreground bg-muted/20 rounded-lg"
                                    style={{ display: "none" }}
                                  >
                                    Failed to load image
                                  </div>
                                </DialogContent>
                              </Dialog>
                            </div>
                          </div>

                          <div className="text-center space-y-2">
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
                          </div>
                        </CardContent>
                      </Card>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}