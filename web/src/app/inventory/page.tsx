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
  OnChangeFn,
  RowSelectionState,
} from "@tanstack/react-table";
import { QRCodeCanvas } from "qrcode.react";
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
  DialogFooter,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { Pencil, Trash2 } from "lucide-react";

type Item = {
  id: string; // ← change this from number to string
  item_name: string;
  condition: "Good" | "Fair" | "Damaged" | "Lost";
  current_transaction: string | null;
  last_transaction_return_date?: string | null;
  image?: string | null;
  _newFile?: File | null;
};


import { AppSidebar } from "@/components/widgets/app-sidebar";
import { SiteHeader } from "@/components/widgets/site-header";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";

export default function Page() {
  const [rowSelection, setRowSelection] = React.useState<RowSelectionState>({});
 const [selectedItems, setSelectedItems] = React.useState<Set<string>>(new Set());

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

  const [isAddModalOpen, setIsAddModalOpen] = React.useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = React.useState(false);
  const [editItem, setEditItem] = React.useState<Item | null>(null);
  const [newItem, setNewItem] = React.useState<{
    item_name: string;
    condition: "Good" | "Fair" | "Damaged" | "Lost";
    _newFile: File | null;
  }>({
    item_name: "",
    condition: "Good",
    _newFile: null,
  });
  const [addError, setAddError] = React.useState<string | null>(null);
  const [editError, setEditError] = React.useState<string | null>(null);
  const [isPreviewModalOpen, setIsPreviewModalOpen] = React.useState(false);
  const [previewItem, setPreviewItem] = React.useState<Item | null>(null);

  const API_BASE_URL =
    process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

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
         // localStorage.removeItem("access_token");
        } else {
          const txt = await resp.text();
          setError(`Failed to fetch items: ${resp.status} ${txt}`);
        }
        setLoading(false);
        return;
      }
      const items = await resp.json();
      const transformedItems: Item[] = items.map((item: any) => ({
        id: item.id,
        item_name: item.item_name,
        condition: item.condition || "Good",
        current_transaction: item.current_transaction,
        last_transaction_return_date: item.last_transaction_return_date || null,
        image: item.image || null,
        _newFile: null,
      }));
      setData(transformedItems);
      setLoading(false);
    } catch (err: any) {
      setError(err.message || String(err));
      setLoading(false);
    }
  }, [router]);

  React.useEffect(() => {
    const accessToken = localStorage.getItem("access_token");
    const user = localStorage.getItem("user");
    if (!accessToken || !user || JSON.parse(user).role !== "user_web") {
      router.push("/");
    } else {
      fetchItems();
    }
  }, [router, fetchItems]);

  const handleRowSelectionChange: OnChangeFn<RowSelectionState> = (
    updaterOrValue
  ) => {
    const newRowSelection =
      typeof updaterOrValue === "function"
        ? updaterOrValue(rowSelection)
        : updaterOrValue;
    setRowSelection(newRowSelection);
    const selectedRowIndices = Object.keys(newRowSelection)
      .filter((id) => newRowSelection[id])
      .map((id) => parseInt(id));
 const selectedItemIds = selectedRowIndices.map(
  (index) => String(data[index].id)
);
setSelectedItems(new Set(selectedItemIds));

    console.log("Selected Items:", selectedItemIds); // Debug selection
  };

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
      if (newItem._newFile) {
        formData.append("image", newItem._newFile);
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
      setNewItem({ item_name: "", condition: "Good", _newFile: null });
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
    setEditError(null);
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setEditError("Not authenticated. Please login.");
        return;
      }

      const formData = new FormData();
      formData.append("item_name", editItem.item_name);
      formData.append("condition", editItem.condition);
      if (editItem._newFile) {
        formData.append("image", editItem._newFile);
      }

      const resp = await fetch(`${API_BASE_URL}/api/items/${editItem.id}/`, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: formData,
      });

      if (!resp.ok) {
        const errData = await resp.json().catch(() => resp.text());
        setEditError(
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
      fetchItems();
      toast("Item updated successfully.", {
        description: `Updated ${editItem.item_name}.`,
      });
    } catch (err: any) {
      setEditError(err.message || String(err));
      toast("Failed to update item.", {
        description: err.message || String(err),
        style: {
          background: "var(--destructive)",
          color: "var(--destructive-foreground)",
        },
      });
    }
  };

  const handleDeleteItems = async () => {
    const ids = Array.from(selectedItems);
    if (ids.length === 0) return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        toast("Not authenticated. Please login.", {
          style: {
            background: "var(--destructive)",
            color: "var(--destructive-foreground)",
          },
        });
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
          toast(`Failed to delete item ${id}`, {
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
      setSelectedItems(new Set());
      setRowSelection({});
      fetchItems();
      toast("Selected items deleted.", {
        description: `${ids.length} item(s) removed from inventory.`,
      });
    } catch (err: any) {
      toast("Failed to delete items.", {
        description: err.message || String(err),
        style: {
          background: "var(--destructive)",
          color: "var(--destructive-foreground)",
        },
      });
    }
  };

  const downloadQrCode = (item: Item) => {
    const canvas = document.getElementById(
      `qr-${item.id}`
    ) as HTMLCanvasElement;
    if (!canvas) {
      toast.error("QR code image not found. Try again.");
      return;
    }
    const link = document.createElement("a");
    link.href = canvas.toDataURL("image/png");
    link.download = `${item.item_name}_qrcode.png`;
    link.click();
  };

  const handlePrint = async () => {
    const selectedItemsList = table
      .getSelectedRowModel()
      .flatRows.map((row) => row.original);
    if (selectedItemsList.length === 0) {
      toast.error("Please select at least one item to print QR codes.");
      return;
    }

    const printWindow = window.open("", "_blank", "width=800,height=600");
    if (!printWindow) {
      toast.error("Failed to open print window.");
      return;
    }

    const qrHtml = selectedItemsList
      .map(
        (item) => `
      <div style="text-align: center; margin: 20px;">
        <h3 style="font-family: sans-serif;">${item.item_name}</h3>
        <canvas id="print-qr-${item.id}"></canvas>
      </div>
    `
      )
      .join("");

    printWindow.document.write(`
    <html>
      <head>
        <title>Print QR Codes</title>
        <style>
          body { font-family: Arial, sans-serif; text-align: center; }
          @media print {
            body { margin: 0; }
            div { page-break-inside: avoid; }
          }
        </style>
      </head>
      <body>
        ${qrHtml}
        <script>
          function loadQRCodeLib(callback) {
            var script = document.createElement('script');
            script.src = "https://cdn.jsdelivr.net/npm/qrcode@1.5.0/build/qrcode.min.js";
            script.onload = callback;
            document.head.appendChild(script);
          }

          loadQRCodeLib(() => {
            const items = ${JSON.stringify(selectedItemsList)};
            let completed = 0;
            items.forEach((item) => {
              const canvas = document.getElementById('print-qr-' + item.id);
             QRCode.toCanvas(canvas, item.id, { // Removed .toString()
  width: 200,
  margin: 2,
  errorCorrectionLevel: 'H'
}, (error) => {
                completed++;
                if (error) console.error(error);
                if (completed === items.length) {
                  setTimeout(() => {
                    window.print();
                    window.close();
                  }, 500);
                }
              });
            });
          });
        </script>
      </body>
    </html>
  `);

    printWindow.document.close();
  };

  const columns = React.useMemo<ColumnDef<Item, any>[]>(
    () => [
      {
        id: "select",
        header: ({ table }) => (
          <Checkbox
            checked={
              table.getIsAllPageRowsSelected()
                ? true
                : table.getIsSomePageRowsSelected()
                ? "indeterminate"
                : false
            }
            onCheckedChange={(val) => table.toggleAllPageRowsSelected(!!val)}
            aria-label="Select all"
          />
        ),
        cell: ({ row }) => (
          <Checkbox
            checked={row.getIsSelected()}
            onCheckedChange={(val) => row.toggleSelected(!!val)}
            aria-label="Select row"
          />
        ),
        enableSorting: false,
        enableHiding: false,
        size: 48,
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
              value={(column.getFilterValue() as string) || "__all__"}
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
              value={(column.getFilterValue() as string) || "__all__"}
              onValueChange={(val) =>
                column.setFilterValue(val === "__all__" ? undefined : val)
              }
            >
              <SelectTrigger className="ml-2">
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">All</SelectItem>
                <SelectItem value="Good">Good</SelectItem>
                <SelectItem value="Fair">Fair</SelectItem>
                <SelectItem value="Damaged">Damaged</SelectItem>
                   <SelectItem value="Lost">Lost</SelectItem>
              </SelectContent>
            </Select>
          </div>
        ),
        cell: (info) => <div>{info.getValue()}</div>,
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
  id: "qrCodeImage",
  header: "QR Code",
  cell: ({ row }) => {
    const item = row.original;
    const itemId = String(item.id);

    return (
      <div
        className="cursor-pointer flex justify-center"
    onClick={() => {  // ← Insert the onClick here
          setPreviewItem(row.original);
          setIsPreviewModalOpen(true);
        }}

      >
        <QRCodeCanvas
          id={`qr-${itemId}`}
          value={JSON.stringify({
            id: String(item.id),
            name: String(item.item_name || ""),
          })}
          size={60}
          level="H"
          className="max-w-[60px] max-h-[60px]"
        />
      </div>
    );
  },
},

    ],
    []
  );

  const table = useReactTable({
    data,
    columns,
    state: { sorting, columnFilters, globalFilter, rowSelection },
    onRowSelectionChange: handleRowSelectionChange,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onGlobalFilterChange: setGlobalFilter,
  });

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
        <SiteHeader title="Item Management" />
        <div className="flex flex-1 flex-col">
          <div className="@container/main flex flex-1 flex-col gap-2">
            <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
              <div className="px-4 lg:px-6">
                <div className="container mx-auto py-4">
                  <Toaster />
                  <div className="mb-4 flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <Input
                        value={globalFilter}
                        onChange={(e) => setGlobalFilter(e.target.value)}
                        placeholder="Search items..."
                        className="w-[260px]"
                      />
                    </div>

                    <div className="flex items-center gap-2">
                      <Button
                        onClick={() => {
                          setIsAddModalOpen(true);
                        }}
                      >
                        Add Item
                      </Button>

                   {selectedItems.size === 1 && (
  <Button
    variant="secondary"
    onClick={() => {
      const itemId = Array.from(selectedItems)[0]; // ✅ get selected ID
      const item = data.find((i) => String(i.id) === String(itemId)); // ✅ find that item
      if (item) {
        setEditItem({ ...item, _newFile: null });
        setIsEditModalOpen(true);
      }
    }}
  >
    <Pencil className="mr-2 h-4 w-4" /> Edit
  </Button>
)}


                      {selectedItems.size > 0 && (
                        <Button
                          variant="destructive"
                          onClick={handleDeleteItems}
                        >
                          <Trash2 className="mr-2 h-4 w-4" /> Delete
                        </Button>
                      )}

                      <Button
                        variant="default"
                        onClick={handlePrint}
                        disabled={Object.keys(rowSelection).length === 0}
                      >
                        Print QR Codes
                      </Button>

                      {Object.keys(rowSelection).length > 0 && (
                        <div className="flex items-center gap-2">
                          <span className="text-sm text-muted-foreground">
                            {Object.keys(rowSelection).length} selected
                          </span>
                          {/* <Button
                            variant="outline"
                            disabled={Object.keys(rowSelection).length !== 1}
                            onClick={() => {
                              const selectedItem =
                                table.getSelectedRowModel().flatRows[0]
                                  ?.original;
                              if (selectedItem) {
                                setPreviewItemId(selectedItem.id);
                                setIsPreviewModalOpen(true);
                              }
                            }}
                          >
                            Generate QR Code
                          </Button> */}
                          <Button
                            variant="outline"
                            disabled={Object.keys(rowSelection).length === 0}
                            onClick={() => {
                              const selectedItemsList = table
                                .getSelectedRowModel()
                                .flatRows.map((row) => row.original);
                              selectedItemsList.forEach(downloadQrCode);
                            }}
                          >
                            Download QR Code(s)
                          </Button>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Edit Modal */}
                  <Dialog
                    open={isEditModalOpen}
                    onOpenChange={setIsEditModalOpen}
                  >
                    <DialogContent className="sm:max-w-[425px]">
                      <DialogHeader>
                        <DialogTitle>Edit Item</DialogTitle>
                      </DialogHeader>
                      <div className="grid gap-4 py-4">
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label
                            htmlFor="edit_item_name"
                            className="text-right"
                          >
                            Name
                          </Label>
                          <Input
                            id="edit_item_name"
                            value={editItem?.item_name || ""}
                            onChange={(e) =>
                              setEditItem((prev) =>
                                prev
                                  ? { ...prev, item_name: e.target.value }
                                  : null
                              )
                            }
                            className="col-span-3"
                          />
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label
                            htmlFor="edit_condition"
                            className="text-right"
                          >
                            Condition
                          </Label>
                          <Select
                            value={editItem?.condition || "Good"}
                            onValueChange={(val) =>
                              setEditItem((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      condition: val as Item["condition"],
                                    }
                                  : null
                              )
                            }
                          >
                            <SelectTrigger className="col-span-3">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                        
                              <SelectItem value="Good">Good</SelectItem>
                              <SelectItem value="Fair">Fair</SelectItem>
                              <SelectItem value="Damaged">Damaged</SelectItem>
                           <SelectItem value="Lost">Lost</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="edit_image" className="text-right">
                            Image
                          </Label>
                          <Input
                            id="edit_image"
                            type="file"
                            accept="image/*"
                            onChange={(e) =>
                              setEditItem((prev) =>
                                prev
                                  ? {
                                      ...prev,
                                      _newFile: e.target.files?.[0] || null,
                                    }
                                  : null
                              )
                            }
                            className="col-span-3"
                          />
                        </div>
                      </div>
                      {editError && (
                        <div className="text-red-600 text-center">
                          {editError}
                        </div>
                      )}
                      <DialogFooter>
                        <Button
                          type="button"
                          variant="outline"
                          onClick={() => {
                            setIsEditModalOpen(false);
                          }}
                        >
                          Cancel
                        </Button>
                        <Button type="submit" onClick={handleEditItem}>
                          Save
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>

                  {/* Add Item Modal */}
                  <Dialog
                    open={isAddModalOpen}
                    onOpenChange={setIsAddModalOpen}
                  >
                    <DialogContent className="sm:max-w-[425px]">
                      <DialogHeader>
                        <DialogTitle>Add New Item</DialogTitle>
                      </DialogHeader>
                      <div className="grid gap-4 py-4">
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="add_item_name" className="text-right">
                            Name
                          </Label>
                          <Input
                            id="add_item_name"
                            value={newItem.item_name}
                            onChange={(e) =>
                              setNewItem({
                                ...newItem,
                                item_name: e.target.value,
                              })
                            }
                            className="col-span-3"
                          />
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="add_condition" className="text-right">
                            Condition
                          </Label>
                          <Select
                            value={newItem.condition}
                            onValueChange={(val) =>
                              setNewItem({
                                ...newItem,
                                condition: val as Item["condition"],
                              })
                            }
                          >
                            <SelectTrigger className="col-span-3">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                          
                              <SelectItem value="Good">Good</SelectItem>
                              <SelectItem value="Fair">Fair</SelectItem>
                              <SelectItem value="Damaged">Damaged</SelectItem>
                                   <SelectItem value="Lost">Lost</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                          <Label htmlFor="add_image" className="text-right">
                            Image
                          </Label>
                          <Input
                            id="add_image"
                            type="file"
                            accept="image/*"
                            onChange={(e) =>
                              setNewItem({
                                ...newItem,
                                _newFile: e.target.files?.[0] || null,
                              })
                            }
                            className="col-span-3"
                          />
                        </div>
                      </div>
                      {addError && (
                        <div className="text-red-600 text-center">
                          {addError}
                        </div>
                      )}
                      <DialogFooter>
                        <Button
                          type="button"
                          variant="outline"
                          onClick={() => {
                            setIsAddModalOpen(false);
                          }}
                        >
                          Cancel
                        </Button>
                        <Button type="submit" onClick={handleAddItem}>
                          Save
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>

                  {/* QR Preview Modal */}
       <Dialog
  open={isPreviewModalOpen}
  onOpenChange={(open) => {
    setIsPreviewModalOpen(open);
    if (!open) setPreviewItem(null);
  }}
>
  <DialogContent className="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>QR Code Preview</DialogTitle>
    </DialogHeader>

    <div className="flex flex-col items-center justify-center py-4">
      {previewItem ? (
        <>
          <QRCodeCanvas
            key={previewItem.id} // Ensures re-render on item change
            value={JSON.stringify({
              id: previewItem.id,
              name: previewItem.item_name || "",
            })}
            size={200}
            level="H"
          />
          <p className="mt-3 text-lg font-semibold text-center">
            {previewItem.item_name}
          </p>
        </>
      ) : (
        <div className="text-gray-500">No QR code available</div>
      )}
    </div>

    <DialogFooter>
      <Button
        variant="outline"
        onClick={() => {
          setIsPreviewModalOpen(false);
          setPreviewItem(null);
        }}
      >
        Close
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>

                  {loading ? (
                    <div className="rounded-md border p-8 text-center">
                      Loading...
                    </div>
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
                              <TableRow
                                key={row.id}
                                data-state={row.getIsSelected() && "selected"}
                              >
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
                            <TableRow>-
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
              </div>
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}
