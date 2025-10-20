"use client";

import React, { useEffect, useMemo, useState } from "react";
import {
  Table as UITable,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  Row,
  SortingState,
  useReactTable,
  RowSelectionState,
  Table,
} from "@tanstack/react-table";
import { format } from "date-fns";
import { useRouter } from "next/navigation";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { List, MoreHorizontal, Search, Trash2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Checkbox } from "@/components/ui/checkbox";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { Label } from "@/components/ui/label";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectTrigger,
  SelectContent,
  SelectItem,
  SelectValue,
} from "@/components/ui/select";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";

type Condition = "Good" | "Fair" | "Damaged" | "Lost" | "__keep__";

interface Item {
  id: string | number;
  item_name: string;
  condition?: string | null;
  image?: string | null;
}

interface Transaction {
  id: number;
  borrowerName: string;
  school_id: string;
  borrowerId?: number;
  items: Item[]; // ✅ array not string
  return_date: string | null;
  borrow_date: string;
  status: "borrowed" | "returned" | "overdue";
}

export function Transactions() {
  const [activeTab, setActiveTab] = useState<"transactions" | "returns">("transactions");
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<
    Transaction[]
  >([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sorting, setSorting] = useState<SortingState>([
    { id: "status", desc: false },
  ]);
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const [pageIndex, setPageIndex] = useState(0);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [isEditMode, setIsEditMode] = useState(false);
  const [filterStatus, setFilterStatus] = useState<
    "all" | "borrowed" | "returned" | "overdue"
  >("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [availableItems, setAvailableItems] = useState<Item[]>([]);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [selectedTransaction, setSelectedTransaction] =
    useState<Transaction | null>(null);
  const [returnDateFilter, setReturnDateFilter] = useState<"today" | "week" | "month" | "all">("all");
  const pageSize = 10;
  const router = useRouter();
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

  const [addForm, setAddForm] = useState({
    name: "",
    school_id: "",
    status: "active" as "active" | "inactive",
    borrow_date: "",
    return_date: "",
    selectedItemIds: [] as string[],
  });
  const [addImage, setAddImage] = useState<File | null>(null);

  const [editForm, setEditForm] = useState({
    borrow_date: "",
    return_date: "",
    status: "" as "borrowed" | "returned" | "overdue",
  });
  const [editName, setEditName] = useState("");
  const [editImage, setEditImage] = useState<File | null>(null);
  const [itemConditions, setItemConditions] = useState<{
    [key: string]: string;
  }>({});

  const fetchTransactions = async () => {
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      // Update overdue transactions
      await fetch(`${API_BASE_URL}/api/update_overdue_transactions/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      const response = await fetch(`${API_BASE_URL}/api/transactions/`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (response.status === 401) {
        router.replace("/dashboard");
        return;
      }

      if (!response.ok) {
        throw new Error(`Failed to fetch transactions: ${response.statusText}`);
      }

      const data = await response.json();
      console.log("Raw API response:", data);

      // Transform API response to match Transaction interface
      const transformedTransactions = data.map((transaction: any) => {
        const today = new Date();
        const returnDate = transaction.return_date
          ? new Date(transaction.return_date)
          : null;
        const status =
          transaction.status === "borrowed" && returnDate && returnDate < today
            ? "overdue"
            : transaction.status || "borrowed";

        return {
          id: transaction.id,
          borrowerName: transaction.borrower_name || "N/A",
          school_id: transaction.school_id || "N/A",
          borrowerId: transaction.borrower?.id,
          items: transaction.items || [],
          return_date: transaction.return_date || null,
          borrow_date: transaction.borrow_date || "N/A",
          status,
        };
      });

      console.log("Transformed transactions:", transformedTransactions);
      setTransactions(transformedTransactions);
      setFilteredTransactions(transformedTransactions);
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const fetchUserRole = async () => {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      try {
        const response = await fetch(`${API_BASE_URL}/api/user/`, {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });
        if (response.ok) {
          const data = await response.json();
          setUserRole(data.role);
          if (data.role === "user_web") {
            fetchItems();
          }
        } else {
          setError("Failed to fetch user role");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "An error occurred");
      }
    };

    fetchUserRole();
    fetchTransactions();
  }, [router]);

  const fetchItems = async () => {
    try {
      const token = localStorage.getItem("access_token");
      const response = await fetch(`${API_BASE_URL}/api/items/`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });
      if (response.ok) {
        const data = await response.json();
        setAvailableItems(data);
      }
    } catch (err) {
      console.error("Failed to fetch items:", err);
    }
  };

  // Filter for Transactions tab
  useEffect(() => {
    let filtered = transactions;
    if (activeTab === "transactions") {
      if (filterStatus !== "all") {
        filtered = filtered.filter(
          (t) => t.status.toLowerCase() === filterStatus.toLowerCase()
        );
      }
      if (searchTerm) {
        const lowerSearch = searchTerm.toLowerCase();
        filtered = filtered.filter(
          (t) =>
            t.borrowerName.toLowerCase().includes(lowerSearch) ||
            t.school_id.toLowerCase().includes(lowerSearch) ||
            t.items.some((item) =>
              item.item_name.toLowerCase().includes(lowerSearch)
            )
        );
      }
    } else if (activeTab === "returns") {
      // Filter borrowed/overdue for returns tab
      filtered = filtered.filter(t => t.status === "borrowed" || t.status === "overdue");
      // Date filter on borrow_date
      const today = new Date();
      const oneWeekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
      const oneMonthAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
      const borrowDate = (t: Transaction) => new Date(t.borrow_date);
      switch (returnDateFilter) {
        case "today":
          filtered = filtered.filter(t => borrowDate(t).toDateString() === today.toDateString());
          break;
        case "week":
          filtered = filtered.filter(t => borrowDate(t) >= oneWeekAgo);
          break;
        case "month":
          filtered = filtered.filter(t => borrowDate(t) >= oneMonthAgo);
          break;
        default:
          break;
      }
      if (searchTerm) {
        const lowerSearch = searchTerm.toLowerCase();
        filtered = filtered.filter(
          (t) =>
            t.borrowerName.toLowerCase().includes(lowerSearch) ||
            t.school_id.toLowerCase().includes(lowerSearch) ||
            t.items.some((item) =>
              item.item_name.toLowerCase().includes(lowerSearch)
            )
        );
      }
    }
    setFilteredTransactions(filtered);
    setPageIndex(0); // Reset to first page when filter changes
    setRowSelection({});
  }, [filterStatus, searchTerm, transactions, activeTab, returnDateFilter]);

  const handleReturnSelected = async () => {
    const selectedRows = table.getSelectedRowModel().rows;
    if (selectedRows.length === 0) return;

    if (!confirm(`Return ${selectedRows.length} transaction(s)?`)) return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      const today = format(new Date(), "yyyy-MM-dd");
      const returnPromises = selectedRows.map(async (row) => {
        const transaction = row.original;
        if (transaction.status !== "borrowed" && transaction.status !== "overdue") {
          toast.error(`Cannot return non-borrowed transaction ${transaction.id}`);
          return;
        }

        // Update transaction status and return_date
        const response = await fetch(
          `${API_BASE_URL}/api/transactions/${transaction.id}/`,
          {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ 
              status: "returned", 
              return_date: today 
            }),
          }
        );

        if (!response.ok) {
          const errorData = await response.json();
          toast.error(
            `Failed to return transaction ${transaction.id}: ${
              errorData.error || "Error"
            }`
          );
        }
      });

      await Promise.all(returnPromises);

      // Refresh
      fetchTransactions();
      setRowSelection({});
      toast.success("Selected transactions returned");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const deleteTransaction = async (id: number) => {
    const transaction = transactions.find((t) => t.id === id);
    if (transaction?.status === "returned") {
      toast.error("Cannot delete a returned transaction.");
      return;
    }

    if (!confirm("Are you sure you want to delete this transaction?")) return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/transactions/${id}/`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (response.ok) {
        setTransactions(transactions.filter((t) => t.id !== id));
        setFilteredTransactions(
          filteredTransactions.filter((t) => t.id !== id)
        );
        toast.success("Transaction deleted successfully");
      } else {
        const errorData = await response.json();
        throw new Error(errorData.error || "Failed to delete transaction");
      }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const handleDeleteSelected = async () => {
    const selectedRows = table.getSelectedRowModel().rows;
    if (selectedRows.length === 0) return;

    if (
      !confirm(
        `Are you sure you want to delete ${selectedRows.length} transaction(s)?`
      )
    )
      return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      const deletePromises = selectedRows.map(async (row) => {
        const transaction = row.original;
        if (transaction.status === "returned") {
          toast.error(`Cannot delete returned transaction ${transaction.id}`);
          return;
        }

        const response = await fetch(
          `${API_BASE_URL}/api/transactions/${transaction.id}/`,
          {
            method: "DELETE",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
          }
        );

        if (!response.ok) {
          const errorData = await response.json();
          toast.error(
            `Failed to delete transaction ${transaction.id}: ${
              errorData.error || "Error"
            }`
          );
        }
      });

      await Promise.all(deletePromises);

      // Refresh transactions
      const remainingTransactions = transactions.filter(
        (t) => !selectedRows.some((row) => row.original.id === t.id)
      );
      setTransactions(remainingTransactions);
      setFilteredTransactions(remainingTransactions);
      setRowSelection({});
      toast.success("Selected transactions deleted");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const handleAddOpen = () => {
    setAddForm({
      name: "",
      school_id: "",
      status: "active",
      borrow_date: "",
      return_date: "",
      selectedItemIds: [],
    });
    setAddImage(null);
    setIsAddOpen(true);
  };

  const handleAddSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (
      !addForm.name ||
      !addForm.school_id ||
      !addForm.borrow_date ||
      !addForm.return_date ||
      addForm.selectedItemIds.length === 0
    ) {
      toast.error(
        "Please fill all required fields and select at least one item."
      );
      return;
    }

    const formData = new FormData();
    formData.append("school_id", addForm.school_id);
    formData.append("name", addForm.name);
    formData.append("status", addForm.status);
    formData.append("return_date", addForm.return_date);
    addForm.selectedItemIds.forEach((id) => formData.append("item_ids[]", id));
    if (addImage) formData.append("image", addImage);

    try {
      const token = localStorage.getItem("access_token");
      const response = await fetch(`${API_BASE_URL}/api/borrowing/create/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: formData,
      });

      if (response.ok) {
        toast.success("Transaction added successfully");
        setIsAddOpen(false);
        fetchTransactions(); // Refetch to update list
      } else {
        const errorData = await response.json();
        throw new Error(errorData.error || "Failed to add transaction");
      }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const handleEditSelected = () => {
    const selectedRows = table.getSelectedRowModel().rows;
    if (selectedRows.length !== 1) return;
    const transaction = selectedRows[0].original;
    setSelectedTransaction(transaction);
    setEditName(transaction.borrowerName);
    setEditForm({
      borrow_date: transaction.borrow_date,
      return_date: transaction.return_date || "",
      status: transaction.status,
    });
    setItemConditions(
      transaction.items.reduce(
        (acc, item) => ({ ...acc, [item.id as string]: item.condition || "" }),
        {}
      )
    );
    setEditImage(null);
    setIsEditOpen(true);
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTransaction) return;
    if (!editForm.status) {
      toast.error("Please select transaction status.");
      return;
    }

    const token = localStorage.getItem("access_token");
    try {
      // FIXED: Transaction update - use PATCH for partial
      const tRes = await fetch(
        `${API_BASE_URL}/api/transactions/${selectedTransaction.id}/`,
        {
          method: "PATCH", // Changed from "PUT"
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(editForm),
        }
      );
      if (!tRes.ok) throw new Error("Failed to update transaction");

      // FIXED: Item conditions update - use PATCH for partial
      const itemPromises = selectedTransaction.items.map(async (item) => {
        const newCondition =
          itemConditions[item.id as string] || item.condition;
        if (newCondition && newCondition !== item.condition) {
          const iRes = await fetch(`${API_BASE_URL}/api/items/${item.id}/`, {
            method: "PATCH", // Changed from "PUT"
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ condition: newCondition }),
          });
          if (!iRes.ok) console.error(`Failed to update item ${item.id}`); // Or throw if critical
        }
      });
      await Promise.all(itemPromises);

      toast.success("Transaction updated successfully");
      setIsEditOpen(false);
      setRowSelection({});
      fetchTransactions(); // Refetch to update list
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const columns: ColumnDef<Transaction>[] = useMemo(
    () => [
      ...(isEditMode
        ? [
            {
              id: "select",
              header: ({ table }: { table: Table<Transaction> }) => (
                <Checkbox
                  checked={
                    table.getIsAllPageRowsSelected() ||
                    (table.getIsSomePageRowsSelected() && "indeterminate")
                  }
                  onCheckedChange={(value) =>
                    table.toggleAllPageRowsSelected(!!value)
                  }
                  aria-label="Select all"
                />
              ),
              cell: ({ row }: { row: Row<Transaction> }) => (
                <Checkbox
                  checked={row.getIsSelected()}
                  onCheckedChange={(value) => row.toggleSelected(!!value)}
                  aria-label="Select row"
                />
              ),
              enableSorting: false,
              enableHiding: false,
            },
          ]
        : []),
      {
        accessorKey: "status",
        header: "Status",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <div className="capitalize">{row.getValue("status")}</div>
        ),
        sortingFn: "alphanumeric",
      },
      {
        accessorKey: "return_date",
        header: "Return Date",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <div>
            {row.getValue("return_date")
              ? format(new Date(row.getValue("return_date")), "MMMM d, yyyy")
              : "N/A"}
          </div>
        ),
        sortingFn: "datetime",
      },
      {
        accessorKey: "borrow_date",
        header: "Borrow Date",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <div>
            {row.getValue("borrow_date")
              ? format(new Date(row.getValue("borrow_date")), "MMMM d, yyyy")
              : "N/A"}
          </div>
        ),
        sortingFn: "datetime",
      },
      {
        accessorKey: "items",
        header: "Items",
        cell: ({ row }: { row: Row<Transaction> }) => {
          const items = row.original.items;
          if (!items || items.length === 0) {
            return <span className="text-muted-foreground">N/A</span>;
          }

          // if only 1 item → just show name
          if (items.length === 1) {
            return <span>{items[0].item_name}</span>;
          }

          // if multiple items → show button to open dialog
          return (
            <Dialog>
              <DialogTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="flex items-center gap-1"
                >
                  {items.length} items
                  <MoreHorizontal className="h-4 w-4" />
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-md">
                <DialogHeader>
                  <DialogTitle>Borrowed Items</DialogTitle>
                </DialogHeader>
                <div className="space-y-3">
                  {items.map((it) => (
                    <div
                      key={it.id}
                      className="flex items-center gap-3 border rounded p-2"
                    >
                      {it.image ? (
                        <img
                          src={it.image}
                          alt={it.item_name}
                          className="h-12 w-12 rounded object-cover"
                        />
                      ) : (
                        <div className="h-12 w-12 rounded bg-muted flex items-center justify-center text-xs text-muted-foreground">
                          No Img
                        </div>
                      )}
                      <div className="flex flex-col">
                        <span className="font-medium">{it.item_name}</span>
                        {it.condition && (
                          <span className="text-xs text-muted-foreground">
                            Condition: {it.condition}
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </DialogContent>
            </Dialog>
          );
        },
      },
      {
        accessorKey: "school_id",
        header: "Borrower School ID",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <div>{row.getValue("school_id")}</div>
        ),
        sortingFn: "alphanumeric",
      },
      {
        accessorKey: "borrowerName",
        header: "Borrower Name",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <div>{row.getValue("borrowerName")}</div>
        ),
        sortingFn: "alphanumeric",
      },
      {
        id: "actions",
        cell: ({ row }: { row: Row<Transaction> }) => (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="h-8 w-8 p-0">
                <span className="sr-only">Open menu</span>
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>Actions</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                onClick={() => deleteTransaction(row.original.id)}
                className="text-destructive"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        ),
        enableHiding: false,
      },
    ],
    [isEditMode]
  );

  const table = useReactTable({
    data: filteredTransactions,
    columns,
    state: { sorting, rowSelection, pagination: { pageIndex, pageSize } },
    onSortingChange: setSorting,
    onRowSelectionChange: setRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    onPaginationChange: (updater) => {
      const newPagination =
        typeof updater === "function"
          ? updater({ pageIndex, pageSize })
          : updater;
      setPageIndex(newPagination.pageIndex);
    },
    initialState: {
      sorting: [{ id: "status", desc: false }],
    },
  });

  const selectedCount = Object.keys(rowSelection).length;

  if (loading) {
    return <div className="p-4">Loading transactions...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="container mx-auto p-4 space-y-6">
      <Toaster />

      {/* Page header */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold tracking-tight">
            Transactions
          </h1>
          <p className="text-sm text-muted-foreground">
            Monitor and manage borrow/return activity
          </p>
        </div>

        {userRole === "user_web" && (
          <div className="flex gap-2">
            <Button onClick={handleAddOpen}>Add Transaction</Button>
            <Button
              onClick={() => {
                setIsEditMode(!isEditMode);
                if (!isEditMode) setRowSelection({});
              }}
              variant={isEditMode ? "default" : "outline"}
            >
              {isEditMode ? "Done" : "Edit"}
            </Button>
          </div>
        )}
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as "transactions" | "returns")}>
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="transactions">Transactions</TabsTrigger>
          <TabsTrigger value="returns">Returns</TabsTrigger>
        </TabsList>

        {/* Transactions Tab */}
        <TabsContent value="transactions" className="space-y-4 mt-4">
          {/* Toolbar: search + filters */}
          <div className="w-full rounded-xl border bg-card p-3 sm:p-4">
            <div className="flex flex-col md:flex-row md:items-center gap-3">
              {/* Search */}
              <div className="relative w-full md:max-w-md">
                <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search by name, school ID, or item…"
                  className="pl-8"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>

              {/* Filter segmented control - revised for better look */}
              <div className="md:ml-auto">
         <ToggleGroup type="single" value={returnDateFilter} onValueChange={(v: any) => setReturnDateFilter(v as any)} className="flex">
<ToggleGroupItem value="all" className="px-3 py-1.5">All</ToggleGroupItem>
<ToggleGroupItem value="today" className="px-3 py-1.5">Today</ToggleGroupItem>
<ToggleGroupItem value="week" className="px-3 py-1.5">This Week</ToggleGroupItem>
<ToggleGroupItem value="month" className="px-3 py-1.5">This Month</ToggleGroupItem>
</ToggleGroup>
              </div>
            </div>

            {/* Edit mode bulk actions */}
            {userRole === "user_web" && isEditMode && (
              <div className="mt-3 flex flex-wrap gap-2">
                {selectedCount === 1 && (
                  <Button onClick={handleEditSelected}>Edit Selected</Button>
                )}
                {selectedCount > 0 && (
                  <Button variant="destructive" onClick={handleDeleteSelected}>
                    <Trash2 className="mr-2 h-4 w-4" />
                    Delete Selected ({selectedCount})
                  </Button>
                )}
              </div>
            )}
          </div>

          {/* Table card */}
          <div className="rounded-xl border bg-card overflow-hidden">
            <UITable>
              <TableHeader>
                {table.getHeaderGroups().map((headerGroup) => (
                  <TableRow key={headerGroup.id}>
                    {headerGroup.headers.map((header) => (
                      <TableHead
                        key={header.id}
                        onClick={header.column.getToggleSortingHandler()}
                        className="cursor-pointer select-none"
                      >
                        {header.isPlaceholder
                          ? null
                          : flexRender(
                              header.column.columnDef.header,
                              header.getContext()
                            )}
                        {{
                          asc: " 🔼",
                          desc: " 🔽",
                        }[header.column.getIsSorted() as string] ?? null}
                      </TableHead>
                    ))}
                  </TableRow>
                ))}
              </TableHeader>

              <TableBody>
                {table.getRowModel().rows.length ? (
                  table.getRowModel().rows.map((row) => (
                    <TableRow
                      key={row.id}
                      data-state={row.getIsSelected() && "selected"}
                      className="hover:bg-muted/40"
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell key={cell.id} className="py-3">
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext()
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={columns.length}
                      className="h-24 text-center text-muted-foreground"
                    >
                      No transactions found.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </UITable>
          </div>

          {/* Pagination */}
          <div className="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
            <div className="text-sm text-muted-foreground">
              Page {table.getState().pagination.pageIndex + 1} of{" "}
              {table.getPageCount()}
            </div>

            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                onClick={() => table.previousPage()}
                disabled={!table.getCanPreviousPage()}
              >
                Previous
              </Button>
              <Button
                onClick={() => table.nextPage()}
                disabled={!table.getCanNextPage()}
              >
                Next
              </Button>
            </div>
          </div>
        </TabsContent>

        {/* Returns Tab */}
        <TabsContent value="returns" className="space-y-4 mt-4">
          {/* Toolbar: search + date filters */}
          <div className="w-full rounded-xl border bg-card p-3 sm:p-4">
            <div className="flex flex-col md:flex-row md:items-center gap-3">
              {/* Search */}
              <div className="relative w-full md:max-w-md">
                <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search by name, school ID, or item…"
                  className="pl-8"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>

              {/* Date filter segmented control */}
              <div className="md:ml-auto">
             <ToggleGroup type="single" value={returnDateFilter} onValueChange={(v: any) => setReturnDateFilter(v as any)} className="flex">
<ToggleGroupItem value="all" className="px-3 py-1.5">All</ToggleGroupItem>
<ToggleGroupItem value="today" className="px-3 py-1.5">Today</ToggleGroupItem>
<ToggleGroupItem value="week" className="px-3 py-1.5">This Week</ToggleGroupItem>
<ToggleGroupItem value="month" className="px-3 py-1.5">This Month</ToggleGroupItem>
</ToggleGroup>
              </div>
            </div>

            {/* Returns bulk actions */}
            {userRole === "user_web" && isEditMode && selectedCount > 0 && (
              <div className="mt-3 flex gap-2">
                <Button onClick={handleReturnSelected} variant="default">
                  Return Selected ({selectedCount})
                </Button>
                <Button variant="destructive" onClick={handleDeleteSelected}>
                  <Trash2 className="mr-2 h-4 w-4" />
                  Delete Selected
                </Button>
              </div>
            )}
          </div>

          {/* Same table for returns, filtered above */}
          <div className="rounded-xl border bg-card overflow-hidden">
            <UITable>
              <TableHeader>
                {table.getHeaderGroups().map((headerGroup) => (
                  <TableRow key={headerGroup.id}>
                    {headerGroup.headers.map((header) => (
                      <TableHead
                        key={header.id}
                        onClick={header.column.getToggleSortingHandler()}
                        className="cursor-pointer select-none"
                      >
                        {header.isPlaceholder
                          ? null
                          : flexRender(
                              header.column.columnDef.header,
                              header.getContext()
                            )}
                        {{
                          asc: " 🔼",
                          desc: " 🔽",
                        }[header.column.getIsSorted() as string] ?? null}
                      </TableHead>
                    ))}
                  </TableRow>
                ))}
              </TableHeader>

              <TableBody>
                {table.getRowModel().rows.length ? (
                  table.getRowModel().rows.map((row) => (
                    <TableRow
                      key={row.id}
                      data-state={row.getIsSelected() && "selected"}
                      className="hover:bg-muted/40"
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell key={cell.id} className="py-3">
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext()
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={columns.length}
                      className="h-24 text-center text-muted-foreground"
                    >
                      No items to return found.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </UITable>
          </div>

          {/* Pagination for returns */}
          <div className="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
            <div className="text-sm text-muted-foreground">
              Page {table.getState().pagination.pageIndex + 1} of{" "}
              {table.getPageCount()}
            </div>

            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                onClick={() => table.previousPage()}
                disabled={!table.getCanPreviousPage()}
              >
                Previous
              </Button>
              <Button
                onClick={() => table.nextPage()}
                disabled={!table.getCanNextPage()}
              >
                Next
              </Button>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      {/* Add Transaction Dialog */}
      <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Add Transaction</DialogTitle>
          </DialogHeader>

          <form
            onSubmit={handleAddSubmit}
            className="grid grid-cols-1 sm:grid-cols-2 gap-4 py-4"
          >
            <div className="space-y-2">
              <Label htmlFor="name">Borrower Name</Label>
              <Input
                id="name"
                value={addForm.name}
                onChange={(e) =>
                  setAddForm({ ...addForm, name: e.target.value })
                }
                placeholder="Enter borrower name"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="school_id">School ID</Label>
              <Input
                id="school_id"
                value={addForm.school_id}
                onChange={(e) =>
                  setAddForm({ ...addForm, school_id: e.target.value })
                }
                placeholder="Enter school ID"
                required
              />
            </div>

            <div className="space-y-2">
              <Label>Borrower Status</Label>
              <Select
                value={addForm.status}
                onValueChange={(v) =>
                  setAddForm({ ...addForm, status: v as "active" | "inactive" })
                }
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="inactive">Inactive</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="image">Borrower Image (optional)</Label>
              <Input
                id="image"
                type="file"
                accept="image/*"
                onChange={(e) => setAddImage(e.target.files?.[0] || null)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="borrow_date">Borrow Date</Label>
              <Input
                id="borrow_date"
                type="date"
                value={addForm.borrow_date}
                onChange={(e) =>
                  setAddForm({ ...addForm, borrow_date: e.target.value })
                }
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="return_date">Return Date</Label>
              <Input
                id="return_date"
                type="date"
                value={addForm.return_date}
                onChange={(e) =>
                  setAddForm({ ...addForm, return_date: e.target.value })
                }
                required
              />
            </div>

            <div className="sm:col-span-2 space-y-2">
              <Label>Select Items to Borrow</Label>
              <ScrollArea className="h-40 rounded-md border">
                <div className="space-y-2 p-3">
                  {availableItems.map((item) => (
                    <div key={item.id} className="flex items-center space-x-2">
                      <Checkbox
                        id={`add-item-${item.id}`}
                        checked={addForm.selectedItemIds.includes(
                          item.id.toString()
                        )}
                        onCheckedChange={(checked) => {
                          const ids = checked
                            ? [...addForm.selectedItemIds, item.id.toString()]
                            : addForm.selectedItemIds.filter(
                                (id) => id !== item.id.toString()
                              );
                          setAddForm({ ...addForm, selectedItemIds: ids });
                        }}
                      />
                      <Label htmlFor={`add-item-${item.id}`}>
                        {item.item_name}
                      </Label>
                    </div>
                  ))}
                </div>
              </ScrollArea>
            </div>

            <div className="sm:col-span-2">
              <Button type="submit" className="w-full">
                Add Transaction
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Edit Transaction Dialog */}
      <Dialog open={isEditOpen} onOpenChange={setIsEditOpen}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Edit Transaction</DialogTitle>
          </DialogHeader>

          {selectedTransaction && (
            <form
              onSubmit={handleEditSubmit}
              className="grid grid-cols-1 sm:grid-cols-2 gap-4 py-4"
            >
              <div className="space-y-2">
                <Label>Borrower Name</Label>
                <div className="h-10 px-3 flex items-center rounded-md border bg-muted/40 text-sm">
                  {editName}
                </div>
              </div>

              <div className="space-y-2">
                <Label>School ID</Label>
                <div className="h-10 px-3 flex items-center rounded-md border bg-muted/40 text-sm">
                  {selectedTransaction.school_id}
                </div>
              </div>

              <div className="space-y-2">
                <Label>Borrow Date</Label>
                <div className="h-10 px-3 flex items-center rounded-md border bg-muted/40 text-sm">
                  {editForm.borrow_date ? format(new Date(editForm.borrow_date), "MMMM d, yyyy") : "N/A"}
                </div>
              </div>

              <div className="space-y-2">
                <Label>Return Date</Label>
                <div className="h-10 px-3 flex items-center rounded-md border bg-muted/40 text-sm">
                  {editForm.return_date ? format(new Date(editForm.return_date), "MMMM d, yyyy") : "N/A"}
                </div>
              </div>

              <div className="space-y-2">
                <Label>Transaction Status</Label>
                <Select
                  value={editForm.status}
                  onValueChange={(v) =>
                    setEditForm({
                      ...editForm,
                      status: v as "borrowed" | "returned" | "overdue",
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="borrowed">Borrowed</SelectItem>
                    <SelectItem value="returned">Returned</SelectItem>
                    <SelectItem value="overdue">Overdue</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Update Borrower Image (optional)</Label>
                <Input
                  id="edit-image"
                  type="file"
                  accept="image/*"
                  onChange={(e) => setEditImage(e.target.files?.[0] || null)}
                  disabled
                />
              </div>

              <div className="sm:col-span-2 space-y-2">
                <Label>Item Conditions</Label>
                <ScrollArea className="h-40 rounded-md border">
                  <div className="space-y-2 p-3">
                    {selectedTransaction.items.map((item) => (
                      <div
                        key={item.id}
                        className="flex items-center gap-2 border p-2 rounded-md"
                      >
                        <span className="font-medium flex-1">
                          {item.item_name}
                        </span>

                        <Select
                          value={(itemConditions[item.id as string] as Condition | undefined) ?? "__keep__"}
                          onValueChange={(v: Condition) => {
                            const key = item.id as string;
                            if (v === "__keep__") {
                              // remove override so it truly “keeps current”
                              const { [key]: _omit, ...rest } = itemConditions;
                              setItemConditions(rest);
                            } else {
                              setItemConditions({ ...itemConditions, [key]: v });
                            }
                          }}
                        >
                          <SelectTrigger className="w-[140px]">
                            <SelectValue placeholder="Condition" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="__keep__">Keep Current</SelectItem> {/* ✅ non-empty */}
                            <SelectItem value="Good">Good</SelectItem>
                            <SelectItem value="Fair">Fair</SelectItem>
                            <SelectItem value="Damaged">Damaged</SelectItem>
                            <SelectItem value="Lost">Lost</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    ))}
                  </div>
                </ScrollArea>
              </div>

              <div className="sm:col-span-2">
                <Button type="submit" className="w-full">
                  Update Transaction
                </Button>
              </div>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}