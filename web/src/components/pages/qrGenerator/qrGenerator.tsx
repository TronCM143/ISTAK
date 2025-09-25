"use client"

import { useState, useEffect, useMemo } from "react"
import { useRouter } from "next/navigation"
import { ColumnDef, useReactTable, getCoreRowModel, getSortedRowModel, getFilteredRowModel, flexRender, SortingState, ColumnFiltersState } from "@tanstack/react-table"
import { QRCodeCanvas } from "qrcode.react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog"
import { toast } from "sonner"
import { Checkbox } from "@/components/ui/checkbox"
import Link from "next/link"

interface Item {
  id: number
  item_name: string
}

export  function QrGenerator() {
  const router = useRouter()
  const [data, setData] = useState<Item[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])
  const [globalFilter, setGlobalFilter] = useState("")
  const [rowSelection, setRowSelection] = useState({})
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [isOperationLoading, setIsOperationLoading] = useState(false)
  const [isPreviewModalOpen, setIsPreviewModalOpen] = useState(false)
  const [previewItemId, setPreviewItemId] = useState<number | null>(null)
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;


  useEffect(() => {
    const accessToken = localStorage.getItem("access_token")
    const user = localStorage.getItem("user")
    if (!accessToken || !user || JSON.parse(user).role !== "user_web") {
      router.push("/")
    } else {
      fetchItems()
    }
  }, [router])

  const fetchItems = async () => {
    setLoading(true)
    setError(null)
    try {
      const token = localStorage.getItem("access_token")
      const response = await fetch(`${API_BASE_URL}/api/items/`, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      })
      if (!response.ok) {
        throw new Error("Failed to fetch items")
      }
      const items = await response.json()
      setData(items)
    } catch (err: any) {
      setError(err.message || "Failed to fetch items")
      toast.error("Failed to fetch items")
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteItems = async () => {
    setIsOperationLoading(true)
    setDeleteError(null)
    try {
      const token = localStorage.getItem("access_token")
      const selectedItems = table.getSelectedRowModel().flatRows.map((row) => row.original)
      
      for (const item of selectedItems) {
        const resp = await fetch(`${API_BASE_URL}/api/items/${item.id}/`, {
          method: "DELETE",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        })
        if (!resp.ok) {
          const errData = await resp.text()
          setDeleteError(`Failed to delete item ${item.item_name}: ${resp.status} ${errData}`)
          toast.error(`Failed to delete ${item.item_name}`)
          setIsOperationLoading(false)
          return
        }
      }
      toast.success("Item(s) deleted successfully!")
      setIsDeleteModalOpen(false)
      setRowSelection({})
      await fetchItems()
    } catch (err: any) {
      setDeleteError(err.message || String(err))
      toast.error("Failed to delete item(s)")
    } finally {
      setIsOperationLoading(false)
    }
  }

  const downloadQrCode = (item: Item) => {
    const canvas = document.getElementById(`qr-${item.id}`) as HTMLCanvasElement
    if (!canvas) {
      toast.error("QR code image not found. Try again.")
      return
    }
    const link = document.createElement("a")
    link.href = canvas.toDataURL("image/png")
    link.download = `${item.item_name}_qrcode.png`
    link.click()
  }

  const handlePrint = () => {
    window.print()
  }

  const columns = useMemo<ColumnDef<Item, any>[]>(
    () => [
      {
        id: "select",
        header: ({ table }) => (
          <Checkbox
            checked={table.getIsAllRowsSelected()}
            onCheckedChange={table.getToggleAllRowsSelectedHandler()}
          />
        ),
        cell: ({ row }) => (
          <Checkbox
            checked={row.getIsSelected()}
            disabled={!row.getCanSelect()}
            onCheckedChange={row.getToggleSelectedHandler()}
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
            {column.getIsSorted() ? (
              <span className="ml-2 text-xs">{column.getIsSorted()}</span>
            ) : null}
          </div>
        ),
        cell: (info) => <div className="font-regular">{info.getValue()}</div>,
      },
      {
        id: "qrCodeImage",
        header: "QR Code",
        cell: ({ row }) => {
          const itemId = String(row.original.id)
          return (
            <div
              className="cursor-pointer flex justify-center"
              onClick={() => {
                setPreviewItemId(row.original.id)
                setIsPreviewModalOpen(true)
              }}
            >
              <QRCodeCanvas
                id={`qr-${row.original.id}`}
                value={itemId}
                size={60}
                level="H"
                className="max-w-[60px] max-h-[60px]"
              />
            </div>
          )
        },
      },
    ],
    []
  )

  const table = useReactTable({
    data,
    columns,
    state: { sorting, columnFilters, globalFilter, rowSelection },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onGlobalFilterChange: setGlobalFilter,
    onRowSelectionChange: setRowSelection,
  })

  return (
    <div className="container mx-auto py-1">
   

      <div className="mb-4 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Input
            placeholder="Search items..."
            value={globalFilter}
            onChange={(e) => setGlobalFilter(e.target.value)}
            className="max-w-xs"
            disabled={isOperationLoading}
          />
          <Button
            variant="default"
            onClick={handlePrint}
            disabled={isOperationLoading}
          >
            Print
          </Button>
          {Object.keys(rowSelection).length > 0 && (
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">
                {Object.keys(rowSelection).length} selected
              </span>
              <Button
                variant="outline"
                disabled={Object.keys(rowSelection).length !== 1 || isOperationLoading}
                onClick={() => {
                  const selectedItem = table.getSelectedRowModel().flatRows[0]?.original
                  if (selectedItem) {
                    setPreviewItemId(selectedItem.id)
                    setIsPreviewModalOpen(true)
                  }
                }}
              >
                Generate QR Code
              </Button>
              <Button
                variant="outline"
                disabled={Object.keys(rowSelection).length === 0 || isOperationLoading}
                onClick={() => {
                  const selectedItems = table.getSelectedRowModel().flatRows.map((row) => row.original)
                  selectedItems.forEach(downloadQrCode)
                }}
              >
                Download QR Code(s)
              </Button>
              <Button
                variant="destructive"
                disabled={isOperationLoading}
                onClick={() => setIsDeleteModalOpen(true)}
              >
                Delete
              </Button>
            </div>
          )}
        </div>
      </div>

      <Dialog open={isPreviewModalOpen} onOpenChange={setIsPreviewModalOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>QR Code Preview</DialogTitle>
          </DialogHeader>
          <div className="flex justify-center py-4">
            {previewItemId ? (
              <QRCodeCanvas
                value={String(previewItemId)}
                size={200}
                level="H"
              />
            ) : (
              <div>No QR code available</div>
            )}
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsPreviewModalOpen(false)}
              disabled={isOperationLoading}
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={isDeleteModalOpen} onOpenChange={setIsDeleteModalOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Deletion</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete {Object.keys(rowSelection).length} item(s)? This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          {deleteError && <div className="text-red-600 text-center">{deleteError}</div>}
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsDeleteModalOpen(false)}
              disabled={isOperationLoading}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteItems}
              disabled={isOperationLoading}
            >
              {isOperationLoading ? "Deleting..." : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {loading ? (
        <div className="rounded-md border p-8 text-center">Loading...</div>
      ) : error ? (
        <div className="rounded-md border p-6 text-center text-red-600">{error}</div>
      ) : (
        <div className="overflow-hidden rounded-md border dark:bg-neutral-1000 shadow-sm">
          <Table>
            <TableHeader className="dark:bg-neutral-900">
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
                      {header.isPlaceholder ? null : flexRender(header.column.columnDef.header, header.getContext())}
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
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={columns.length} className="h-24 text-center">
                    No items found.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  )
}