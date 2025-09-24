"use client";

import React, { useEffect, useState } from "react";
import {
  Table,
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
  getSortedRowModel,
  Row,
  SortingState,
  useReactTable,
} from "@tanstack/react-table";
import { format } from "date-fns";
import { useRouter } from "next/navigation";

interface Transaction {
  id: number;
  borrowerName: string;
  school_id: string;
  item_name: string;
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
            item_name: transaction.item || "N/A",
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
  }, [filterStatus, transactions]);

  const deleteTransaction = async (id: number) => {
    const transaction = transactions.find((t) => t.id === id);
    if (transaction?.status === "returned") {
      alert("Cannot delete a returned transaction.");
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
        alert("Transaction deleted successfully");
      } else {
        const errorData = await response.json();
        throw new Error(errorData.error || "Failed to delete transaction");
      }
    } catch (err) {
      alert(err instanceof Error ? err.message : "An error occurred");
    }
  };

  const columns: ColumnDef<Transaction>[] = [
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => <div className="capitalize">{row.getValue("status")}</div>,
      sortingFn: "alphanumeric",
    },
    {
      accessorKey: "return_date",
      header: "Return Date",
      cell: ({ row }) => (
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
      cell: ({ row }) => (
        <div>
          {row.getValue("borrow_date")
            ? format(new Date(row.getValue("borrow_date")), "MMMM d, yyyy")
            : "N/A"}
        </div>
      ),
      sortingFn: "datetime",
    },
    {
      accessorKey: "item_name",
      header: "Item Name",
      cell: ({ row }) => <div>{row.getValue("item_name")}</div>,
      sortingFn: "alphanumeric",
    },
    {
      accessorKey: "school_id",
      header: "Borrower School ID",
      cell: ({ row }) => <div>{row.getValue("school_id")}</div>,
      sortingFn: "alphanumeric",
    },
    {
      accessorKey: "borrowerName",
      header: "Borrower Name",
      cell: ({ row }) => <div>{row.getValue("borrowerName")}</div>,
      sortingFn: "alphanumeric",
    },
    ...(isEditMode && userRole === "user_web"
      ? [
          {
            id: "actions",
            header: "Actions",
            cell: ({ row }: { row: Row<Transaction> }) => (
              <Button
                variant="destructive"
                size="sm"
                onClick={() => deleteTransaction(row.original.id)}
                disabled={row.original.status === "returned"}
              >
                Delete
              </Button>
            ),
          },
        ]
      : []),
  ];

  const table = useReactTable({
    data: filteredTransactions,
    columns,
    state: { sorting, pagination: { pageIndex, pageSize } },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    manualPagination: false,
    initialState: {
      sorting: [{ id: "status", desc: false }],
    },
  });

  const getRowClassName = () => {
    return ""; // No colorization, keep table white
  };

  if (loading) {
    return <div className="p-4">Loading transactions...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="container mx-auto p-4">
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Transaction History</h1>
        {userRole === "user_web" && (
          <Button
            onClick={() => setIsEditMode(!isEditMode)}
            variant={isEditMode ? "default" : "outline"}
          >
            {isEditMode ? "Done" : "Edit"}
          </Button>
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

      <div className="rounded-md border">
        <Table>
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
                  className={getRowClassName()}
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
        </Table>
      </div>
      <div className="flex items-center justify-between mt-4">
        <Button
          onClick={() => {
            setPageIndex((prev) => Math.max(prev - 1, 0));
            table.setPageIndex((prev) => Math.max(prev - 1, 0));
          }}
          disabled={pageIndex === 0}
        >
          Previous
        </Button>
        <span>
          Page {pageIndex + 1} of {Math.ceil(filteredTransactions.length / pageSize)}
        </span>
        <Button
          onClick={() => {
            setPageIndex((prev) => prev + 1);
            table.setPageIndex((prev) => prev + 1);
          }}
          disabled={pageIndex >= Math.ceil(filteredTransactions.length / pageSize) - 1}
        >
          Next
        </Button>
      </div>
    </div>
  );
}