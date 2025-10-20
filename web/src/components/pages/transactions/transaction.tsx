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
import { MoreHorizontal, Search, Trash2 } from "lucide-react";
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
  items: Item[];
  return_date: string | null;
  borrow_date: string;
  status: "borrowed" | "returned" | "overdue";
}

interface FlattenedItem {
  transactionId: number;
  itemName: string;
  itemId: string | number;
  borrowDate: string;
  returnDate: string | null;
  status: "borrowed" | "returned" | "overdue";
  condition: string;
  borrowerName: string;
  schoolId: string;
}

export function Transactions() {
  const [activeTab, setActiveTab] = useState<"transactions" | "returns">("transactions");
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredData, setFilteredData] = useState<FlattenedItem[]>([]);
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
  const [dateFrom, setDateFrom] = useState<string>("");
  const [dateTo, setDateTo] = useState<string>("");
  const [dateType, setDateType] = useState<"borrow" | "return">("borrow");
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

      setTransactions(transformedTransactions);
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

  // Flattening and filtering
  useEffect(() => {
    const flattened = transactions.flatMap((tx) =>
      tx.items.map((item) => ({
        transactionId: tx.id,
        itemName: item.item_name,
        itemId: item.id,
        borrowDate: tx.borrow_date,
        returnDate: tx.return_date,
        status: tx.status,
        condition: item.condition || "N/A",
        borrowerName: tx.borrowerName,
        schoolId: tx.school_id,
      }))
    );

    let filtered = flattened;

    if (activeTab === "transactions") {
      if (filterStatus !== "all") {
        filtered = filtered.filter(
          (f) => f.status.toLowerCase() === filterStatus.toLowerCase()
        );
      }
    } else if (activeTab === "returns") {
      filtered = filtered.filter(
        (f) => f.status === "borrowed" || f.status === "overdue"
      );
    }

    if (searchTerm) {
      const lowerSearch = searchTerm.toLowerCase();
      filtered = filtered.filter(
        (f) =>
          f.borrowerName.toLowerCase().includes(lowerSearch) ||
          f.schoolId.toLowerCase().includes(lowerSearch) ||
          f.itemName.toLowerCase().includes(lowerSearch)
      );
    }

    if (dateFrom || dateTo) {
      if (dateType === "return") {
        filtered = filtered.filter((f) => f.returnDate);
      }
      if (dateFrom) {
        const from = new Date(dateFrom);
        filtered = filtered.filter((f) => {
          const d = new Date(
            dateType === "borrow" ? f.borrowDate : f.returnDate!
          );
          return d >= from;
        });
      }
      if (dateTo) {
        const to = new Date(dateTo);
        filtered = filtered.filter((f) => {
          const d = new Date(
            dateType === "borrow" ? f.borrowDate : f.returnDate!
          );
          return d <= to;
        });
      }
    }

    setFilteredData(filtered);
    setPageIndex(0);
    setRowSelection({});
  }, [
    transactions,
    activeTab,
    filterStatus,
    searchTerm,
    dateFrom,
    dateTo,
    dateType,
  ]);

  const getUniqueTxIdsFromSelected = (selectedRows: Row<FlattenedItem>[]) => {
    const txIds = new Set(selectedRows.map((row) => row.original.transactionId));
    return Array.from(txIds);
  };

  const handleReturnSelected = async () => {
    const selectedRows = table.getSelectedRowModel().rows;
    if (selectedRows.length === 0) return;

    const txIds = getUniqueTxIdsFromSelected(selectedRows);
    if (txIds.length !== 1) {
      toast.error("Select items from a single transaction to return.");
      return;
    }

    const txId = txIds[0];
    if (!confirm(`Return transaction ${txId}?`)) return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      const today = format(new Date(), "yyyy-MM-dd");
      const response = await fetch(
        `${API_BASE_URL}/api/transactions/${txId}/`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ status: "returned", return_date: today }),
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || "Failed to return transaction");
      }

      fetchTransactions();
      setRowSelection({});
      toast.success("Transaction returned");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const deleteTransaction = async (txId: number) => {
    const transaction = transactions.find((t) => t.id === txId);
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

      const response = await fetch(`${API_BASE_URL}/api/transactions/${txId}/`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (response.ok) {
        fetchTransactions();
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

    const txIds = getUniqueTxIdsFromSelected(selectedRows);
    if (txIds.length !== 1) {
      toast.error("Select items from a single transaction to delete.");
      return;
    }

    const txId = txIds[0];
    await deleteTransaction(txId);
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
        fetchTransactions();
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
    if (selectedRows.length === 0) return;

    const txIds = getUniqueTxIdsFromSelected(selectedRows);
    if (txIds.length !== 1) {
      toast.error("Select items from a single transaction to edit.");
      return;
    }

    const txId = txIds[0];
    const transaction = transactions.find((t) => t.id === txId);
    if (!transaction) return;

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
      const tRes = await fetch(
        `${API_BASE_URL}/api/transactions/${selectedTransaction.id}/`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(editForm),
        }
      );
      if (!tRes.ok) throw new Error("Failed to update transaction");

      const itemPromises = selectedTransaction.items.map(async (item) => {
        const newCondition =
          itemConditions[item.id as string] || item.condition;
        if (newCondition && newCondition !== item.condition) {
          const iRes = await fetch(`${API_BASE_URL}/api/items/${item.id}/`, {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ condition: newCondition }),
          });
          if (!iRes.ok) console.error(`Failed to update item ${item.id}`);
        }
      });
      await Promise.all(itemPromises);

      toast.success("Transaction updated successfully");
      setIsEditOpen(false);
      setRowSelection({});
      fetchTransactions();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const columns: ColumnDef<FlattenedItem>[] = useMemo(
    () => [
      ...(isEditMode
        ? [
            {
              id: "select",
              header: ({ table }: { table: Table<FlattenedItem> }) => (
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
              cell: ({ row }: { row: Row<FlattenedItem> }) => (
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
        accessorKey: "transactionId",
        header: "Transaction ID",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("transactionId")}</div>
        ),
      },
      {
        accessorKey: "itemName",
        header: "Item Name",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("itemName")}</div>
        ),
      },
      {
        accessorKey: "itemId",
        header: "Item ID",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("itemId")}</div>
        ),
      },
      {
        accessorKey: "borrowDate",
        header: "Borrow Date",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>
            {row.getValue("borrowDate")
              ? format(new Date(row.getValue("borrowDate")), "MMMM d, yyyy")
              : "N/A"}
          </div>
        ),
        sortingFn: "datetime",
      },
      {
        accessorKey: "returnDate",
        header: "Return Date",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>
            {row.getValue("returnDate")
              ? format(new Date(row.getValue("returnDate")), "MMMM d, yyyy")
              : "N/A"}
          </div>
        ),
        sortingFn: "datetime",
      },
      {
        accessorKey: "status",
        header: "Status",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div className="capitalize">{row.getValue("status")}</div>
        ),
      },
      {
        accessorKey: "condition",
        header: "Item Condition",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("condition")}</div>
        ),
      },
      {
        accessorKey: "schoolId",
        header: "Borrower School ID",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("schoolId")}</div>
        ),
      },
      {
        accessorKey: "borrowerName",
        header: "Borrower Name",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
          <div>{row.getValue("borrowerName")}</div>
        ),
      },
      {
        id: "actions",
        cell: ({ row }: { row: Row<FlattenedItem> }) => (
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
                onClick={() => deleteTransaction(row.original.transactionId)}
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
    data: filteredData,
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

              {/* Status filter */}
              <Select
                value={filterStatus}
                onValueChange={(v) =>
                  setFilterStatus(v as "all" | "borrowed" | "returned" | "overdue")
                }
              >
                <SelectTrigger className="w-[140px]">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="borrowed">Borrowed</SelectItem>
                  <SelectItem value="returned">Returned</SelectItem>
                  <SelectItem value="overdue">Overdue</SelectItem>
                </SelectContent>
              </Select>

              {/* Date filters */}
              <div className="flex items-center gap-2 md:ml-auto">
             <Select
  value={dateType}
  onValueChange={(value: string) => setDateType(value as "borrow" | "return")}
>
  <SelectTrigger className="w-32">
    <SelectValue />
  </SelectTrigger>
  <SelectContent>
    <SelectItem value="borrow">Borrow Date</SelectItem>
    <SelectItem value="return">Return Date</SelectItem>
  </SelectContent>
</Select>
                <Input
                  type="date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  className="w-36"
                />
                <Input
                  type="date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  className="w-36"
                />
              </div>
            </div>

            {/* Edit mode bulk actions */}
            {userRole === "user_web" && isEditMode && (
              <div className="mt-3 flex flex-wrap gap-2">
                {selectedCount > 0 && (
                  <Button onClick={handleReturnSelected}>Return Selected</Button>
                )}
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

              {/* Date filters */}
              <div className="flex items-center gap-2 md:ml-auto">
             <Select
  value={dateType}
  onValueChange={(value: string) => setDateType(value as "borrow" | "return")}
>
  <SelectTrigger className="w-32">
    <SelectValue />
  </SelectTrigger>
  <SelectContent>
    <SelectItem value="borrow">Borrow Date</SelectItem>
    <SelectItem value="return">Return Date</SelectItem>
  </SelectContent>
</Select>
                <Input
                  type="date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  className="w-36"
                />
                <Input
                  type="date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  className="w-36"
                />
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
                      No items to return found.
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
                            <SelectItem value="__keep__">Keep Current</SelectItem>
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
