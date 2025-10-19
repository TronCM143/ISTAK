"use client";
import React, { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { ReactNode } from "react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Download,
  FileSpreadsheet,
  FileText,
  Search,
  DownloadCloud,
  X,
  Calendar as CalendarIcon,
  Filter,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

type TxStatus = "borrowed" | "returned" | "overdue";

async function fetchImageAsDataURL(
  url: string
): Promise<{ dataUrl: string; type: "PNG" | "JPEG" } | null> {
  try {
    const res = await fetch(url, { mode: "cors" });
    const blob = await res.blob();
    const reader = new FileReader();
    const dataUrl: string = await new Promise((resolve, reject) => {
      reader.onloadend = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
    const type = dataUrl.startsWith("data:image/png") ? "PNG" : "JPEG";
    return { dataUrl, type };
  } catch {
    return null;
  }
}

interface TransactionReport {
  id: string;
  borrowerName: string;
  schoolId: string;
  borrowerImage: string | null;
  borrowDate: string | null;
  returnDate?: string | null;
  items: Array<{
    itemName: string;
    condition: string;
  }>;
  status: TxStatus;
}

interface DateRange {
  from: Date | undefined;
  to?: Date | undefined;
}

const getConditionColor = (condition: string) => {
  switch (condition?.toLowerCase()) {
    case "damaged":
    case "lost":
      return "bg-destructive text-destructive-foreground";
    case "fair":
      return "bg-yellow-500 text-yellow-foreground";
    case "good":
      return "bg-green-500 text-green-foreground";
    case "overdue":
      return "bg-orange-500 text-orange-foreground";
    default:
      return "bg-muted text-muted-foreground";
  }
};

const getConditionIcon = (condition: string) => {
  switch (condition?.toLowerCase()) {
    case "damaged":
      return "⚠️";
    case "lost":
      return "🚫";
    case "fair":
      return "⏳";
    case "good":
      return "✅";
    case "overdue":
      return "⏰";
    default:
      return "ℹ️";
  }
};

// Safe date formatting
const safeFormatDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return "N/A";
  const date = new Date(dateStr);
  if (isNaN(date.getTime())) return "Invalid Date";
  return format(date, "MMM dd, yyyy");
};

// Safe getTime for sort
const safeGetTime = (dateStr: string | null | undefined): number => {
  if (!dateStr) return 0;
  const date = new Date(dateStr);
  return isNaN(date.getTime()) ? 0 : date.getTime();
};

// -------- FETCH (accept multiple filters) --------
const fetchTransactionReports = async (filters: {
  search?: string;
  statuses?: string[];
  conditions?: string[];
  dateFrom?: string;
  dateTo?: string;
  dateType?: "borrow" | "return" | "both";
}) => {
  const token =
    typeof window !== "undefined" ? localStorage.getItem("access_token") : null;
  if (!API_BASE_URL) throw new Error("API_BASE_URL is not defined");

  const response = await fetch(`${API_BASE_URL}/api/reports/transactions/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token && { Authorization: `Bearer ${token}` }),
    },
    body: JSON.stringify(filters),
  });
  if (!response.ok) {
    if (response.status === 401) throw new Error("Unauthorized: Please log in");
    throw new Error("Failed to fetch transaction reports");
  }
  return (await response.json()) as TransactionReport[];
};

// -------- EXPORTS --------
const exportToPDF = async (
  data: TransactionReport[],
  _filters: {
    searchTerm: string;
    selectedFilters: string[];
    dateRange: DateRange;
  }
) => {
  const { jsPDF } = await import("jspdf");
  const autoTable = (await import("jspdf-autotable")).default;

  // Preload images -> base64 (aligned by row index)
  const images = await Promise.all(
    data.map(async (row) => {
      if (!row.borrowerImage) return null;
      return await fetchImageAsDataURL(row.borrowerImage);
    })
  );

  const doc = new jsPDF();
  const title = `Transactions Report`;
  doc.text(title, 14, 15);

  autoTable(doc, {
    startY: 20,
    head: [
      [
        "Borrower Image",
        "Borrower Name",
        "School ID",
        "Borrow Date",
        "Return Date",
        "Items",
        "Condition",
        "Days Past Due",
      ],
    ],
    body: data.map((item) => [
      item.borrowerImage ? "" : "N/A", // empty cell; we'll draw the image ourselves
      item.borrowerName,
      item.schoolId,
      safeFormatDate(item.borrowDate),
      safeFormatDate(item.returnDate),
      item.items.map((i) => i.itemName).join(", "),
      item.items.map((i) => `${i.condition}`).join(", ") || "N/A",
    ]),
    theme: "striped",
    headStyles: { fillColor: [59, 130, 246] },

    // 👇 draw image into the first column of each body row
    didDrawCell: (hookData: any) => {
      const { section, row, column, cell } = hookData;
      if (section === "body" && column.index === 0) {
        const img = images[row.index];
        if (img) {
          // fit image inside the cell with small padding
          const maxW = Math.min(14, cell.width - 4);
          const maxH = Math.min(14, cell.height - 4);
          doc.addImage(
            img.dataUrl,
            img.type,
            cell.x + 2,
            cell.y + 2,
            maxW,
            maxH
          );
        }
      }
    },
  });

  doc.save(`transactions-report.pdf`);
};

const exportToExcel = async (
  data: TransactionReport[],
  _filters: {
    searchTerm: string;
    selectedFilters: string[];
    dateRange: DateRange;
  }
) => {
  const XLSX = await import("xlsx");
  const rows = data.map((item) => ({
    "Borrower Name": item.borrowerName,
    "School ID": item.schoolId,
    "Borrow Date": safeFormatDate(item.borrowDate),
    "Return Date": safeFormatDate(item.returnDate),
    Items: item.items.map((i) => i.itemName).join(", "),
    Conditions: item.items.map((i) => `${i.condition}`).join(", "),
    Status: item.status,
  }));

  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Transactions");
  XLSX.writeFile(wb, `transactions-report.xlsx`);
};

// Status & condition option lists
const STATUS_OPTIONS = [
  { value: "all", label: "All" },
  { value: "overdue", label: "Overdue" },
  { value: "available", label: "Returned" }, // UI = returned
  { value: "borrowed", label: "Borrowed" },
];

const CONDITION_OPTIONS = [

   { value: "good", label: "Good" },
  { value: "damaged", label: "Damaged" },
  { value: "fair", label: "Fair" },
  { value: "lost", label: "Lost" },
];

// -------- Component --------
const Reports = () => {
  const [preview, setPreview] = useState<{ open: boolean; src: string; alt: string }>({
  open: false,
  src: "",
  alt: "",
});
const openPreview = (src: string, alt: string) => setPreview({ open: true, src, alt });



  const [searchTerm, setSearchTerm] = useState("");
  const [sortBy, setSortBy] = useState<
    "borrower" | "schoolId" | "borrowDate" | "condition"
  >("borrower");

  const [selectedStatus, setSelectedStatus] = useState<string[]>(["all"]);
  const [selectedConditions, setSelectedConditions] = useState<string[]>([]);
  const [dateType, setDateType] = useState<"borrow" | "return" | "both">(
    "borrow"
  );

  const [dateRange, setDateRange] = useState<DateRange>({
    from: undefined,
    to: undefined,
  });

  const [selectedColumns, setSelectedColumns] = useState<
    Record<string, boolean>
  >({
    borrowerImage: true,
    borrowerName: true,
    schoolId: true,
    borrowDate: true,
    items: true,
    condition: true,
  });

  const [isExportDialogOpen, setIsExportDialogOpen] = useState(false);
  const [exportFormat, setExportFormat] = useState<"pdf" | "excel">("pdf");

  // Map status for backend (available => returned)
  const normalizedStatuses = useMemo(() => {
    if (selectedStatus.includes("all")) return ["all"];
    return selectedStatus.map((s) => (s === "available" ? "returned" : s));
  }, [selectedStatus]);

  const normalizedConditions = useMemo(() => {
    return selectedConditions.length ? selectedConditions : [];
  }, [selectedConditions]);

  const {
    data: reportsData,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: [
      "transactionReports",
      searchTerm,
      `S:${normalizedStatuses.join(",")}`,
      `C:${normalizedConditions.join(",")}`,
      dateRange.from?.toLocaleDateString(),
      dateRange.to?.toLocaleDateString(),
      dateType,
    ],
    queryFn: () =>
      fetchTransactionReports({
        search: searchTerm || undefined,
        statuses: normalizedStatuses,
        conditions: normalizedConditions,
        dateFrom: dateRange.from
          ? dateRange.from.toLocaleDateString("en-CA") // → "YYYY-MM-DD" in local time
          : undefined,

        dateTo: dateRange.to
          ? dateRange.to.toLocaleDateString("en-CA")
          : undefined,
        dateType,
      }),
    staleTime: 5 * 60 * 1000,
    retry: (failureCount, err) => {
      if (err instanceof Error && err.message.includes("Unauthorized"))
        return false;
      return failureCount < 3;
    },
  });

  const selectedFiltersForExport = useMemo(() => {
    const statuses = selectedStatus.includes("all")
      ? ["all"]
      : selectedStatus.map((s) => (s === "available" ? "returned" : s));
    return [...statuses, ...selectedConditions];
  }, [selectedStatus, selectedConditions]);

  const toggleStatus = (val: string) => {
    setSelectedStatus((prev) => {
      if (val === "all") return ["all"];
      const next = new Set(prev.filter((p) => p !== "all"));
      if (next.has(val)) next.delete(val);
      else next.add(val);
      return next.size ? Array.from(next) : ["all"];
    });
  };

  const toggleCondition = (val: string) => {
    setSelectedConditions((prev) => {
      const next = new Set(prev);
      if (next.has(val)) next.delete(val);
      else next.add(val);
      return Array.from(next);
    });
  };

  const filteredData = useMemo(() => {
    if (!reportsData) return [];
    let data = [...reportsData];

    // STATUS filtering
    if (!selectedStatus.includes("all")) {
      const statusSet = new Set(
        selectedStatus.map((s) => (s === "available" ? "returned" : s))
      );

      data = data.filter((tx) => {
        const s = tx.status.toLowerCase();
        const wantsOverdue = statusSet.has("overdue");

        const statusMatchDirect = statusSet.has(s);
        const statusMatchOverdue = wantsOverdue && s === "overdue";

        return statusMatchDirect || statusMatchOverdue;
      });
    }

    // CONDITION filtering
    if (selectedConditions.length) {
      const condSet = new Set(selectedConditions.map((c) => c.toLowerCase()));
      data = data.filter((tx) =>
        tx.items.some((i) => condSet.has(i.condition.toLowerCase()))
      );
    }

    // Sorting
    if (sortBy === "borrower") {
      data.sort((a, b) => a.borrowerName.localeCompare(b.borrowerName));
    } else if (sortBy === "schoolId") {
      data.sort((a, b) => a.schoolId.localeCompare(b.schoolId));
    } else if (sortBy === "borrowDate") {
      data.sort(
        (a, b) => safeGetTime(a.borrowDate) - safeGetTime(b.borrowDate)
      );
    } else if (sortBy === "condition") {
      data.sort((a, b) => {
        const aCond = a.items[0]?.condition || "";
        const bCond = b.items[0]?.condition || "";
        return aCond.localeCompare(bCond);
      });
    }

    return data;
  }, [reportsData, selectedStatus, selectedConditions, sortBy]);

  const handleExport = async () => {
    if (!filteredData.length) {
      toast("No data available to export. Please adjust filters.");
      return;
    }
    try {
      if (exportFormat === "pdf") {
        await exportToPDF(filteredData, {
          searchTerm,
          selectedFilters: selectedFiltersForExport,
          dateRange,
        });
      } else {
        await exportToExcel(filteredData, {
          searchTerm,
          selectedFilters: selectedFiltersForExport,
          dateRange,
        });
      }
      setIsExportDialogOpen(false);
      toast("Export Successful");
    } catch (error) {
      console.error("Export failed:", error);
      toast("An error occurred while exporting the report.");
    }
  };

  const clearFilters = () => {
    setSearchTerm("");
    setSelectedStatus(["all"]);
    setSelectedConditions([]);
    setDateRange({ from: undefined, to: undefined });
    setSortBy("borrower");
  };

  const columns = [
    {
      key: "borrowerImage",
      label: "Borrower Image",
      visible: selectedColumns.borrowerImage,
    },
    {
      key: "borrowerName",
      label: "Borrower Name",
      visible: selectedColumns.borrowerName,
    },
    { key: "schoolId", label: "School ID", visible: selectedColumns.schoolId },
    {
      key: "borrowDate",
      label: "Borrow Date",
      visible: selectedColumns.borrowerDate,
    },
    { key: "returnDate", label: "Return Date", visible: true },
    { key: "items", label: "Items Borrowed", visible: selectedColumns.items },
    {
      key: "condition",
      label: "Condition",
      visible: selectedColumns.condition,
    },
  ];

  const visibleColumns = columns.filter((col) => col.visible);

  const stats = useMemo(
    () => ({
        good:
        reportsData?.filter((item) =>
          item.items.some((i) => i.condition.toLowerCase() === "good")
        ).length || 0,
      damaged:
        reportsData?.filter((item) =>
          item.items.some((i) => i.condition.toLowerCase() === "damaged")
        ).length || 0,
      fair:
        reportsData?.filter((item) =>
          item.items.some((i) => i.condition.toLowerCase() === "fair")
        ).length || 0,
      lost:
        reportsData?.filter((item) =>
          item.items.some((i) => i.condition.toLowerCase() === "lost")
        ).length || 0,
      overdue:
        reportsData?.filter((item) => item.status === "overdue").length || 0,
    }),
    [reportsData]
  );

  // Render cell helper
  const renderCellContent = (
    report: TransactionReport,
    colKey: string
  ): ReactNode => {
    if (colKey === "borrowerImage") {
  return report.borrowerImage ? (
    <button
      type="button"
      onClick={() => openPreview(report.borrowerImage as string, report.borrowerName)}
      className="group relative"
      aria-label={`Preview image of ${report.borrowerName}`}
    >
      <img
        src={report.borrowerImage}
        alt={report.borrowerName}
        className="h-10 w-10 rounded object-cover ring-1 ring-border group-hover:ring-primary transition"
      />
    </button>
  ) : (
    <div className="h-10 w-10 rounded bg-muted flex items-center justify-center text-xs text-muted-foreground">
      No Img
    </div>
  );
}

    if (colKey === "items") {
      return (
        <div className="space-y-1">
          {report.items.map((item, idx) => (
            <div key={idx} className="text-sm">
              {item.itemName}
            </div>
          ))}
        </div>
      );
    }
    if (colKey === "condition") {
      return (
        <div className="space-y-1">
          {report.items.map((item, idx) => (
            <Badge
              key={idx}
              className={`${getConditionColor(item.condition)} text-black`}
            >
              {getConditionIcon(item.condition)} {item.condition}
            </Badge>
          ))}
        </div>
      );
    }

    if (colKey === "borrowDate") {
      return safeFormatDate(report.borrowDate);
    }
    if (colKey === "returnDate") {
      return safeFormatDate(report.returnDate);
    }
    // Primitive fields
    const value =
      report[
        colKey as keyof Omit<
          TransactionReport,
          "items" | "borrowerImage" | "condition" | "borrowDate"
        >
      ];
    return (value as ReactNode) || "N/A";
  };

const minDate = new Date("2020-01-01");
// Block future dates only when filtering by "borrow"; allow when "return" or "both"
const isFutureDisabled = () => false;


const DISPLAY_FMT = "MM/dd/yy"; // e.g., 01/03/25

const DatePickers = () => (
  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
    {/* START */}
    <div className="space-y-1">
      <Popover>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            className={cn(
              "h-9 w-full justify-start text-left font-normal",
              !dateRange.from && "text-muted-foreground"
            )}
          >
            <CalendarIcon className="mr-2 h-4 w-4" />
            {dateRange.from ? format(dateRange.from, DISPLAY_FMT) : "Pick start"}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-auto p-0" align="start">
          <Calendar
            mode="single"
            selected={dateRange.from}
            onSelect={(d) =>
              setDateRange((prev) => ({
                from: d ?? undefined,
                // if new start goes after current end, clear the end
                to: prev.to && d && d > prev.to ? undefined : prev.to,
              }))
            }
            initialFocus
            disabled={(d) =>
              d < minDate ||
              isFutureDisabled() ||
              (!!dateRange.to && d > dateRange.to) // prevent start > end
            }
          />
        </PopoverContent>
      </Popover>
    </div>

    {/* END */}
    <div className="space-y-1">
      <Popover>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            className={cn(
              "h-9 w-full justify-start text-left font-normal",
              !dateRange.to && "text-muted-foreground"
            )}
          >
            <CalendarIcon className="mr-2 h-4 w-4" />
            {dateRange.to ? format(dateRange.to, DISPLAY_FMT) : "Pick end"}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-auto p-0" align="start">
          <Calendar
            mode="single"
            selected={dateRange.to}
            onSelect={(d) =>
              setDateRange((prev) => ({ ...prev, to: d ?? undefined }))
            }
            initialFocus
            disabled={(d) =>
              d < minDate ||
              isFutureDisabled() ||
              (!!dateRange.from && d < dateRange.from) // prevent end < start
            }
          />
        </PopoverContent>
      </Popover>
    </div>
  </div>
);


  return (
    <div className="space-y-6 p-4 sm:p-6">
      {/* HEADER */}
      <div className="flex flex-col sm:flex-row flex-wrap items-start sm:items-center justify-between gap-3">
        <h1 className="text-xl font-semibold text-foreground">
          Transaction Reports
        </h1>
        <div className="flex gap-2 w-full sm:w-auto">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            className="h-9 gap-2 flex-1 sm:flex-none"
          >
            <DownloadCloud className="h-4 w-4" />
            Refresh
          </Button>
          <Dialog
            open={isExportDialogOpen}
            onOpenChange={setIsExportDialogOpen}
          >
            <DialogTrigger asChild>
              <Button size="sm" className="h-9 gap-2 flex-1 sm:flex-none">
                <Download className="h-4 w-4" />
                Export Selected
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-md">
              <DialogHeader>
                <DialogTitle>Export Report</DialogTitle>
                <DialogDescription>
                  Choose format for your selected data
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="format">Format</Label>
                  <div className="flex gap-2">
                    <Button
                      variant={exportFormat === "pdf" ? "default" : "outline"}
                      onClick={() => setExportFormat("pdf")}
                      size="sm"
                      className="h-9"
                    >
                      <FileText className="mr-2 h-4 w-4" />
                      PDF
                    </Button>
                    <Button
                      variant={exportFormat === "excel" ? "default" : "outline"}
                      onClick={() => setExportFormat("excel")}
                      size="sm"
                      className="h-9"
                    >
                      <FileSpreadsheet className="mr-2 h-4 w-4" />
                      Excel
                    </Button>
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Columns to Include</Label>
                  <div className="space-y-2">
                    {columns.map((col) => (
                      <div
                        key={col.key}
                        className="flex items-center space-x-2"
                      >
                        <Checkbox
                          id={col.key}
                          checked={selectedColumns[col.key]}
                          onCheckedChange={(checked) =>
                            setSelectedColumns((prev) => ({
                              ...prev,
                              [col.key]: checked as boolean,
                            }))
                          }
                        />
                        <Label
                          htmlFor={col.key}
                          className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                        >
                          {col.label}
                        </Label>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              <DialogFooter className="gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsExportDialogOpen(false)}
                  className="h-9"
                >
                  Cancel
                </Button>
                <Button onClick={handleExport} className="h-9">
                  Export {exportFormat.toUpperCase()}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* FILTERS */}
  {/* FILTERS (Refined) */}
<Card>
  <CardHeader className="pb-2">
    <div className="flex items-center justify-between gap-2">
      <CardTitle className="flex items-center gap-2 text-base">
        <Filter className="h-4 w-4" />
        Filters
      </CardTitle>

      <div className="flex items-center gap-2">
        <Badge variant="outline" className="text-xs">
          {filteredData.length} results
        </Badge>
        <Button
          variant="ghost"
          size="sm"
          onClick={clearFilters}
          className="h-8 text-muted-foreground"
        >
          <X className="h-4 w-4 mr-1" />
          Reset
        </Button>
      </div>
    </div>
  </CardHeader>

  <CardContent className="pt-2">
    {/* Grid container: 1 col mobile, 2 cols ≥sm */}
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">

      {/* Search — full width (span both cols on desktop for breathing room) */}
      <div className="sm:col-span-2 space-y-1">
        <Label htmlFor="search" className="text-sm">Search</Label>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            id="search"
            placeholder="Borrower, school ID, or item..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10 h-9"
          />
        </div>
      </div>

      {/* Date Type */}
      <div className="space-y-1">
        <Label className="text-sm">Date Type</Label>
        <div className="flex flex-wrap gap-2">
          {(["borrow", "return", "both"] as const).map((type) => (
            <Button
              key={type}
              variant={dateType === type ? "default" : "outline"}
              size="sm"
              className="h-8 px-3 capitalize"
              onClick={() => setDateType(type)}
            >
              {type}
            </Button>
          ))}
        </div>
        <p className="text-xs text-muted-foreground">
          Choose which dates the range should filter.
        </p>
      </div>

      {/* Date Range */}
      <div className="space-y-1">
        <Label className="text-sm">Date Range</Label>
        <div className="h-9 flex items-center">
          <DatePickers />
        </div>
      </div>

      {/* Status */}
      <div className="space-y-1">
        <Label className="text-sm">Transaction Status</Label>
        <div className="flex flex-wrap gap-2">
          {STATUS_OPTIONS.map((opt) => {
            const active = selectedStatus.includes(opt.value);
            return (
              <Button
                key={opt.value}
                type="button"
                size="sm"
                variant={active ? "default" : "outline"}
                onClick={() => toggleStatus(opt.value)}
                aria-pressed={active}
                className="h-8 px-3"
              >
                {opt.label}
              </Button>
            );
          })}
        </div>
      </div>

      {/* Condition */}
      <div className="space-y-1">
        <Label className="text-sm">Item Condition</Label>
        <div className="flex flex-wrap gap-2">
          {CONDITION_OPTIONS.map((opt) => {
            const active = selectedConditions.includes(opt.value);
            return (
              <Button
                key={opt.value}
                type="button"
                size="sm"
                variant={active ? "default" : "outline"}
                onClick={() => toggleCondition(opt.value)}
                aria-pressed={active}
                className="h-8 px-3"
              >
                {opt.label}
              </Button>
            );
          })}
        </div>
      </div>
    </div>
  </CardContent>
</Card>


      {/* TABLE */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle className="text-base font-semibold">
            Transactions{" "}
            <span className="text-muted-foreground">
              ({filteredData.length})
            </span>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-8 space-y-2">
              <div className="text-destructive">{(error as Error).message}</div>
              <Button variant="outline" onClick={() => refetch()}>
                Retry
              </Button>
            </div>
          ) : filteredData.length === 0 ? (
            <div className="text-center py-8 space-y-2">
              <div className="text-muted-foreground text-lg">
                No transactions found
              </div>
              <p className="text-sm text-muted-foreground">
                Try adjusting your filters or date range.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <ScrollArea className="max-h-[70vh] rounded-md border w-full">
                <div className="min-w-full">
                  <Table>
                    <TableHeader className="sticky top-0 bg-background z-10">
                      <TableRow>
                        {visibleColumns.map((col) => (
                          <TableHead key={col.key} className="whitespace-nowrap">
                            {col.label}
                          </TableHead>
                        ))}
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredData.map((report: TransactionReport) => (
                        <TableRow key={report.id}>
                          {visibleColumns.map((col) => (
                            <TableCell
                              key={col.key}
                              className="align-top text-muted-foreground"
                            >
                              {renderCellContent(report, col.key)}
                            </TableCell>
                          ))}
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </ScrollArea>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={preview.open} onOpenChange={(o) => setPreview((p) => ({ ...p, open: o }))}>
  <DialogContent className="max-w-3xl p-0 sm:p-0 bg-background/95">
    <div className="relative">
      {/* Large preview */}
      <img
        src={preview.src}
        alt={preview.alt}
        className="max-h-[80vh] w-full object-contain select-none"
        draggable={false}
      />

      {/* Caption (optional) */}
      <div className="absolute bottom-2 left-2 text-xs text-foreground/90 bg-background/70 px-2 py-1 rounded">
        {preview.alt}
      </div>
    </div>
  </DialogContent>
</Dialog>

    </div>
  );
};

export default Reports;