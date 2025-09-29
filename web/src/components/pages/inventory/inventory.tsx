"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  ColumnDef,
  SortingState,
  ColumnFiltersState,
  getCoreRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  useReactTable,
  flexRender,
} from "@tanstack/react-table";
import {
  Table,
  TableHeader,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";

type Item = {
  id: number;
  item_name: string;
  condition?: string | null;
  current_transaction: number | null; // Reflects backend Item model's current_transaction
  last_transaction_return_date?: string | null; // Derived from last returned transaction
  image?: string | null;
};

export function InventoryPage() {
  const router = useRouter();
  const [data, setData] = React.useState<Item[]>([]);
  const [loading, setLoading] = React.useState<boolean>(true);
  const [error, setError] = React.useState<string | null>(null);
  const [sorting, setSorting] = React.useState<SortingState>([
    { id: "last_transaction_return_date", desc: true },
  ]);
  const [globalFilter, setGlobalFilter] = React.useState<string>("");
  const [columnFilters, setColumnFilters] = React.useState<ColumnFiltersState>(
    []
  );
  const [selectedRows, setSelectedRows] = React.useState<Set<number>>(
    new Set()
  );
  const [isAddModalOpen, setIsAddModalOpen] = React.useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = React.useState(false);
  const [editItem, setEditItem] = React.useState<Item | null>(null);
  const [newItem, setNewItem] = React.useState({
    item_name: "",
    condition: "Good",
    image: null as File | null,
  });
  const [addError, setAddError] = React.useState<string | null>(null);
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;
  const fetchItems = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setError("Not authenticated. Please login.");
        setLoading(false);
        return;
      }
      const resp = await fetch(`${API_BASE_URL}/api/items/`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      });
      if (!resp.ok) {
        if (resp.status === 401 || resp.status === 403) {
          setError("Unauthorized. Please login again.");
        } else {
          const txt = await resp.text();
          setError(`Failed to fetch items: ${resp.status} ${txt}`);
        }
        setLoading(false);
        return;
      }
      const items = await resp.json();
      // Transform items to derive status and last_transaction_return_date
      const transformedItems: Item[] = items.map((item: any) => ({
        id: item.id,
        item_name: item.item_name,
        condition: item.condition,
        current_transaction: item.current_transaction,
        last_transaction_return_date: item.last_transaction_return_date || null, // From serializer
        image: item.image || null,
      }));
      setData(transformedItems);
      setLoading(false);
    } catch (err: any) {
      setError(err.message || String(err));
      setLoading(false);
    }
  }, [router]);

  React.useEffect(() => {
    fetchItems();
  }, [fetchItems]);
const handleAddItem = async () => {
  setAddError(null);
  try {
    const token = localStorage.getItem("access_token");
    if (!token) {
      setAddError("Not authenticated. Please login.");
      return;
    }

    const formData = new FormData();
    formData.append("item_name", newItem.item_name);
    formData.append("condition", newItem.condition);
    if (newItem.image) {
      formData.append("image", newItem.image);
    }

    const resp = await fetch(`${API_BASE_URL}/api/items/`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    });

    if (!resp.ok) {
      const errData = await resp.json().catch(() => resp.text());
      setAddError(
        `Failed to add item: ${
          typeof errData === "string" ? errData : JSON.stringify(errData)
        }`
      );
      toast("Failed to add item.", {
        description:
          typeof errData === "string" ? errData : JSON.stringify(errData),
        style: {
          background: "var(--destructive)",
          color: "var(--destructive-foreground)",
        },
      });
      return;
    }

    setIsAddModalOpen(false);
    setNewItem({ item_name: "", condition: "Good", image: null });
    fetchItems();
    toast("Item added successfully.", {
      description: `Added ${newItem.item_name} to inventory.`,
    });
  } catch (err: any) {
    setAddError(err.message || String(err));
    toast("Failed to add item.", {
      description: err.message || String(err),
      style: {
        background: "var(--destructive)",
        color: "var(--destructive-foreground)",
        },
      });
    }
  };

  const handleEditItem = async () => {
    if (!editItem) return;
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setAddError("Not authenticated. Please login.");
        return;
      }

      const formData = new FormData();
      formData.append("item_name", editItem.item_name);
      formData.append("condition", editItem.condition || "Good");
      if (newItem.image) {
        formData.append("image", newItem.image);
      }

      const resp = await fetch(
        `${API_BASE_URL}/api/items/${editItem.id}/`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${token}`,
          },
          body: formData,
        }
      );

      if (!resp.ok) {
        const errData = await resp.json().catch(() => resp.text());
        setAddError(
          `Failed to update item: ${
            typeof errData === "string" ? errData : JSON.stringify(errData)
          }`
        );
        toast("Failed to update item.", {
          description:
            typeof errData === "string" ? errData : JSON.stringify(errData),
          style: {
            background: "var(--destructive)",
            color: "var(--destructive-foreground)",
          },
        });
        return;
      }

      setIsEditModalOpen(false);
      setEditItem(null);
      setNewItem({ item_name: "", condition: "Good", image: null });
      fetchItems();
      toast("Item updated successfully.", {
        description: `Updated ${editItem.item_name}.`,
      });
    } catch (err: any) {
      setAddError(err.message || String(err));
      toast("Failed to update item.", {
        description: err.message || String(err),
        style: {
          background: "var(--destructive)",
          color: "var(--destructive-foreground)",
        },
      });
    }
  };

  const handleDeleteItems = async (ids: number[]) => {
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setError("Not authenticated. Please login.");
        return;
      }

      for (const id of ids) {
        const resp = await fetch(`${API_BASE_URL}/api/items/${id}/`, {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        if (!resp.ok) {
          const errData = await resp.json().catch(() => resp.text());
          toast("Failed to delete item.", {
            description: `Item ${id}: ${
              typeof errData === "string" ? errData : JSON.stringify(errData)
            }`,
            style: {
              background: "var(--destructive)",
              color: "var(--destructive-foreground)",
            },
          });
        }
      }
      setSelectedRows(new Set());
      fetchItems();
      toast("Selected items deleted.", {
        description: `${ids.length} item(s) removed from inventory.`,
      });
    } catch (err: any) {
      setError(err.message || String(err));
      toast("Failed to delete items.", {
        description: err.message || String(err),
        style: {
          background: "var(--destructive)",
          color: "var(--destructive-foreground)",
        },
      });
    }
  };

  const columns = React.useMemo<ColumnDef<Item, any>[]>(
    () => [
      {
        id: "select",
        header: ({ table }) => (
          <Checkbox
            checked={table.getIsAllRowsSelected()}
            onCheckedChange={(value) => {
              table.toggleAllRowsSelected(!!value);
              setSelectedRows(
                value ? new Set(data.map((item) => item.id)) : new Set()
              );
            }}
          />
        ),
        cell: ({ row }) => (
          <Checkbox
            checked={selectedRows.has(row.original.id)}
            onCheckedChange={(value) => {
              const newSelected = new Set(selectedRows);
              if (value) {
                newSelected.add(row.original.id);
              } else {
                newSelected.delete(row.original.id);
              }
              setSelectedRows(newSelected);
              row.toggleSelected(!!value);
            }}
          />
        ),
      },
      {
        accessorKey: "item_name",
        header: ({ column }) => (
          <div
            className="flex items-center gap-2 cursor-pointer"
            onClick={() => column.toggleSorting()}
          >
            Item Name
            {column.getIsSorted() && (
              <span className="ml-2 text-xs">{column.getIsSorted()}</span>
            )}
          </div>
        ),
        cell: (info) => <div className="font-regular">{info.getValue()}</div>,
      },
      {
        id: "status",
        accessorFn: (row) =>
          row.current_transaction ? "Borrowed" : "Available",
        header: ({ column }) => (
          <div className="flex items-center">
            <div
              className="flex items-center gap-2 cursor-pointer"
              onClick={() => column.toggleSorting()}
            >
              Status
              {column.getIsSorted() && (
                <span className="ml-2 text-xs">{column.getIsSorted()}</span>
              )}
            </div>
            <Select
              value={
                (column.getFilterValue() as string | undefined) || "__all__"
              }
              onValueChange={(val) =>
                column.setFilterValue(val === "__all__" ? undefined : val)
              }
            >
              <SelectTrigger className="ml-2">
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">All</SelectItem>
                <SelectItem value="Available">Available</SelectItem>
                <SelectItem value="Borrowed">Borrowed</SelectItem>
              </SelectContent>
            </Select>
          </div>
        ),
        cell: (info) => <div>{info.getValue()}</div>,
        filterFn: "equals",
      },
      {
        accessorKey: "condition",
        header: ({ column }) => (
          <div className="flex items-center">
            <div
              className="flex items-center gap-2 cursor-pointer"
              onClick={() => column.toggleSorting()}
            >
              Condition
              {column.getIsSorted() && (
                <span className="ml-2 text-xs">{column.getIsSorted()}</span>
              )}
            </div>
            <Select
              value={
                (column.getFilterValue() as string | undefined) || "__all__"
              }
              onValueChange={(val) =>
                column.setFilterValue(val === "__all__" ? undefined : val)
              }
            >
              <SelectTrigger className="ml-2">
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">All</SelectItem>
                <SelectItem value="Excellent">Excellent</SelectItem>
                <SelectItem value="Good">Good</SelectItem>
                <SelectItem value="Fair">Fair</SelectItem>
                <SelectItem value="Damaged">Damaged</SelectItem>
                <SelectItem value="Broken">Broken</SelectItem>
                <SelectItem value="__null__">N/A</SelectItem>
              </SelectContent>
            </Select>
          </div>
        ),
        cell: (info) => <div>{info.getValue() ?? "N/A"}</div>,
        filterFn: "equals",
      },
      {
        accessorKey: "last_transaction_return_date",
        id: "last_transaction_return_date",
        header: ({ column }) => (
          <div
            className="flex items-center gap-2 cursor-pointer"
            onClick={() => column.toggleSorting()}
          >
            Last Borrowed
            {column.getIsSorted() && (
              <span className="ml-2 text-xs">{column.getIsSorted()}</span>
            )}
          </div>
        ),
        cell: (info) => {
          const val = info.getValue() as string | undefined;
          if (!val) return <div>N/A</div>;
          try {
            const d = new Date(val);
            return <div>{d.toLocaleDateString()}</div>;
          } catch {
            return <div>{val}</div>;
          }
        },
        sortingFn: "datetime",
        sortUndefined: "last",
      },
      {
        accessorKey: "image",
        header: "Image",
        cell: (info) =>
          info.getValue() ? (
            <img
              src={info.getValue()}
              alt="Item"
              className="h-12 w-12 object-cover rounded"
            />
          ) : (
            <div>No Image</div>
          ),
      },
      {
        id: "actions",
        header: "Actions",
        cell: ({ row }) => (
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                setEditItem(row.original);
                setNewItem({
                  item_name: row.original.item_name,
                  condition: row.original.condition || "Good",
                  image: null,
                });
                setIsEditModalOpen(true);
              }}
            >
              Edit
            </Button>
            <Button
              size="sm"
              variant="destructive"
              onClick={() => handleDeleteItems([row.original.id])}
            >
              Delete
            </Button>
          </div>
        ),
      },
    ],
    []
  );

  const table = useReactTable({
    data,
    columns,
    state: { sorting, columnFilters, globalFilter },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onGlobalFilterChange: setGlobalFilter,
  });

  return (
    <div className="container mx-auto py-4">
      <Toaster />
      <div className="mb-4 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Input
            placeholder="Search..."
            value={globalFilter}
            onChange={(e) => setGlobalFilter(e.target.value)}
            className="max-w-sm"
          />
          {selectedRows.size > 0 && (
            <Button
              variant="destructive"
              onClick={() => handleDeleteItems(Array.from(selectedRows))}
            >
              Delete Selected ({selectedRows.size})
            </Button>
          )}
        </div>
        <Dialog open={isAddModalOpen} onOpenChange={setIsAddModalOpen}>
          <DialogTrigger asChild>
            <Button variant="default">Add Item</Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle>Add New Item</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="item_name" className="text-right">
                  Name
                </Label>
                <Input
                  id="item_name"
                  value={newItem.item_name}
                  onChange={(e) =>
                    setNewItem({ ...newItem, item_name: e.target.value })
                  }
                  className="col-span-3"
                />
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="condition" className="text-right">
                  Condition
                </Label>
                <Select
                  value={newItem.condition}
                  onValueChange={(val) =>
                    setNewItem({ ...newItem, condition: val })
                  }
                >
                  <SelectTrigger className="col-span-3">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Excellent">Excellent</SelectItem>
                    <SelectItem value="Good">Good</SelectItem>
                    <SelectItem value="Fair">Fair</SelectItem>
                    <SelectItem value="Damaged">Damaged</SelectItem>
                    <SelectItem value="Broken">Broken</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="image" className="text-right">
                  Image
                </Label>
                <Input
                  id="image"
                  type="file"
                  accept="image/*"
                  onChange={(e) =>
                    setNewItem({
                      ...newItem,
                      image: e.target.files?.[0] || null,
                    })
                  }
                  className="col-span-3"
                />
              </div>
            </div>
            {addError && (
              <div className="text-red-600 text-center">{addError}</div>
            )}
            <DialogFooter>
              <Button type="submit" onClick={handleAddItem}>
                Save
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <Dialog open={isEditModalOpen} onOpenChange={setIsEditModalOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit Item</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="item_name" className="text-right">
                Name
              </Label>
              <Input
                id="item_name"
                value={newItem.item_name}
                onChange={(e) =>
                  setNewItem({ ...newItem, item_name: e.target.value })
                }
                className="col-span-3"
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="condition" className="text-right">
                Condition
              </Label>
              <Select
                value={newItem.condition}
                onValueChange={(val) =>
                  setNewItem({ ...newItem, condition: val })
                }
              >
                <SelectTrigger className="col-span-3">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Excellent">Excellent</SelectItem>
                  <SelectItem value="Good">Good</SelectItem>
                  <SelectItem value="Fair">Fair</SelectItem>
                  <SelectItem value="Damaged">Damaged</SelectItem>
                  <SelectItem value="Broken">Broken</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="image" className="text-right">
                Image
              </Label>
              <Input
                id="image"
                type="file"
                accept="image/*"
                onChange={(e) =>
                  setNewItem({ ...newItem, image: e.target.files?.[0] || null })
                }
                className="col-span-3"
              />
            </div>
          </div>
          {addError && (
            <div className="text-red-600 text-center">{addError}</div>
          )}
          <DialogFooter>
            <Button type="submit" onClick={handleEditItem}>
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {loading ? (
        <div className="rounded-md border p-8 text-center">Loading...</div>
      ) : error ? (
        <div className="rounded-md border p-6 text-center text-red-600">
          {error}
        </div>
      ) : (
        <div className="overflow-hidden rounded-md border shadow-sm">
          <Table>
            <TableHeader>
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                    </TableHead>
                  ))}
                </TableRow>
              ))}
            </TableHeader>
            <TableBody>
              {table.getRowModel().rows.length ? (
                table.getRowModel().rows.map((row) => (
                  <TableRow key={row.id}>
                    {row.getVisibleCells().map((cell) => (
                      <TableCell key={cell.id}>
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
                    className="h-24 text-center"
                  >
                    No items found.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
