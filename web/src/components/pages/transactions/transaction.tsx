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
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { List, MoreHorizontal, Trash2 } from "lucide-react";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";
import { DialogTitle, DialogTrigger } from "@radix-ui/react-dialog";
import { Checkbox } from "@/components/ui/checkbox";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";

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
  items: Item[];  // ✅ array not string
  return_date: string | null;
  borrow_date: string;
  status: "borrowed" | "returned" | "overdue";
}


export function Transactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sorting, setSorting] = useState<SortingState>([
    { id: "status", desc: false },
  ]);
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const [pageIndex, setPageIndex] = useState(0);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [isEditMode, setIsEditMode] = useState(false);
  const [filterStatus, setFilterStatus] = useState<"all" | "borrowed" | "returned" | "overdue">("all");
  const pageSize = 10;
  const router = useRouter();
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

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
        } else {
          setError("Failed to fetch user role");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "An error occurred");
      }
    };

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
          const returnDate = transaction.return_date ? new Date(transaction.return_date) : null;
          const status = transaction.status === "borrowed" && returnDate && returnDate < today
            ? "overdue"
            : transaction.status || "borrowed";

          return {
            id: transaction.id,
            borrowerName: transaction.borrower_name || "N/A",
            school_id: transaction.school_id || "N/A",
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

    fetchUserRole();
    fetchTransactions();
  }, [router]);

  // Filter transactions based on selected status
  useEffect(() => {
    if (filterStatus === "all") {
      setFilteredTransactions(transactions);
    } else {
      setFilteredTransactions(
        transactions.filter((t) => t.status.toLowerCase() === filterStatus.toLowerCase())
      );
    }
    setPageIndex(0); // Reset to first page when filter changes
    setRowSelection({});
  }, [filterStatus, transactions]);

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
        setFilteredTransactions(filteredTransactions.filter((t) => t.id !== id));
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

    if (!confirm(`Are you sure you want to delete ${selectedRows.length} transaction(s)?`)) return;

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

        const response = await fetch(`${API_BASE_URL}/api/transactions/${transaction.id}/`, {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });

        if (!response.ok) {
          const errorData = await response.json();
          toast.error(`Failed to delete transaction ${transaction.id}: ${errorData.error || "Error"}`);
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

  const columns: ColumnDef<Transaction>[] = useMemo(() => [
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
                onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
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
      cell: ({ row }: { row: Row<Transaction> }) => <div className="capitalize">{row.getValue("status")}</div>,
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
              <Button variant="outline" size="sm" className="flex items-center gap-1">
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
      cell: ({ row }: { row: Row<Transaction> }) => <div>{row.getValue("school_id")}</div>,
      sortingFn: "alphanumeric",
    },
    {
      accessorKey: "borrowerName",
      header: "Borrower Name",
      cell: ({ row }: { row: Row<Transaction> }) => <div>{row.getValue("borrowerName")}</div>,
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
  ], [isEditMode]);

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
      const newPagination = typeof updater === "function"
        ? updater({ pageIndex, pageSize })
        : updater;
      setPageIndex(newPagination.pageIndex);
    },
    initialState: {
      sorting: [{ id: "status", desc: false }],
    },
  });

  if (loading) {
    return <div className="p-4">Loading transactions...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="container mx-auto p-4">
      <Toaster />
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Transaction History</h1>
        {userRole === "user_web" && (
          <>
            <Button
              onClick={() => setIsEditMode(!isEditMode)}
              variant={isEditMode ? "default" : "outline"}
            >
              {isEditMode ? "Done" : "Edit"}
            </Button>
          </>
        )}
      </div>

      <div className="flex gap-2 mb-4">
        <Button
          onClick={() => setFilterStatus("all")}
          variant={filterStatus === "all" ? "default" : "outline"}
        >
          All
        </Button>
        <Button
          onClick={() => setFilterStatus("borrowed")}
          variant={filterStatus === "borrowed" ? "default" : "outline"}
        >
          Borrowed
        </Button>
        <Button
          onClick={() => setFilterStatus("returned")}
          variant={filterStatus === "returned" ? "default" : "outline"}
        >
          Returned
        </Button>
        <Button
          onClick={() => setFilterStatus("overdue")}
          variant={filterStatus === "overdue" ? "default" : "outline"}
        >
          Overdue
        </Button>
      </div>

      {isEditMode && Object.keys(rowSelection).length > 0 && (
        <div className="mb-4">
          <Button
            variant="destructive"
            onClick={handleDeleteSelected}
          >
            <Trash2 className="mr-2 h-4 w-4" /> Delete Selected
          </Button>
        </div>
      )}

      <div className="rounded-md border">
        <UITable>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead
                    key={header.id}
                    onClick={header.column.getToggleSortingHandler()}
                    className="cursor-pointer"
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
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
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center">
                  No transactions found.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </UITable>
      </div>
      <div className="flex items-center justify-between mt-4">
        <Button
          onClick={() => table.previousPage()}
          disabled={!table.getCanPreviousPage()}
        >
          Previous
        </Button>
        <span>
          Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
        </span>
        <Button
          onClick={() => table.nextPage()}
          disabled={!table.getCanNextPage()}
        >
          Next
        </Button>
      </div>
    </div>
  );
}