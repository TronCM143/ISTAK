'use client'

import React, { useState, useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Download, FileText, FileSpreadsheet, Filter, Search, DownloadCloud, X } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Calendar } from '@/components/ui/calendar'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { format } from 'date-fns'
import { CalendarIcon } from 'lucide-react'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL

interface Report {
  id: string
  borrowerName: string
  itemStatus: 'Damaged' | 'Lost' | 'Unreturned' | 'Returned'
  itemName: string
  returnedDate: string | null
  condition: string
}

interface DateRange {
  from: Date | undefined
  to?: Date | undefined
}

const fetchDamagedAndLostItems = async (filters: {
  search?: string
  status?: string
  dateFrom?: string
  dateTo?: string
}) => {
  const token = localStorage.getItem('access_token') // Adjust based on your auth setup
  if (!API_BASE_URL) throw new Error('API_BASE_URL is not defined')
  const response = await fetch(`${API_BASE_URL}/api/reports/damaged-lost-items/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token && { 'Authorization': `Bearer ${token}` }),
    },
    body: JSON.stringify(filters),
  })
  if (!response.ok) {
    if (response.status === 401) throw new Error('Unauthorized: Please log in')
    throw new Error('Failed to fetch reports')
  }
  return response.json() as Promise<Report[]>
}

const exportToPDF = async (data: Report[], filters: {
  searchTerm: string
  statusFilter: string
  dateRange: DateRange
}) => {
  const { jsPDF } = await import('jspdf')
  const autoTable = (await import('jspdf-autotable')).default
  const doc = new jsPDF()
  doc.text('Damaged and Lost Items Report', 14, 15)
  autoTable(doc, {
    startY: 20,
    head: [['Borrower Name', 'Item Status', 'Item Name', 'Returned Date', 'Condition']],
    body: data.map(item => [
      item.borrowerName,
      item.itemStatus,
      item.itemName,
      item.returnedDate ? format(new Date(item.returnedDate), 'PPP') : 'N/A',
      item.condition,
    ]),
    theme: 'striped',
    headStyles: { fillColor: [59, 130, 246] },
  })
  doc.save('damaged-lost-items-report.pdf')
}

const exportToExcel = async (data: Report[], filters: {
  searchTerm: string
  statusFilter: string
  dateRange: DateRange
}) => {
  const XLSX = await import('xlsx')
  const ws = XLSX.utils.json_to_sheet(data.map(item => ({
    'Borrower Name': item.borrowerName,
    'Item Status': item.itemStatus,
    'Item Name': item.itemName,
    'Returned Date': item.returnedDate ? format(new Date(item.returnedDate), 'PPP') : 'N/A',
    Condition: item.condition,
  })))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Reports')
  XLSX.writeFile(wb, 'damaged-lost-items-report.xlsx')
}

const getStatusColor = (status: string) => {
  switch (status?.toLowerCase()) {
    case 'damaged':
      return 'bg-destructive text-destructive-foreground'
    case 'lost':
      return 'bg-yellow-500 text-yellow-foreground'
    case 'unreturned':
      return 'bg-secondary text-secondary-foreground'
    case 'returned':
      return 'bg-success text-success-foreground'
    default:
      return 'bg-muted text-muted-foreground'
  }
}

const getStatusIcon = (status: string) => {
  switch (status?.toLowerCase()) {
    case 'damaged':
      return '⚠️'
    case 'lost':
      return '❌'
    case 'unreturned':
      return '⏳'
    case 'returned':
      return '✅'
    default:
      return 'ℹ️'
  }
}

const Reports = () => {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [sortBy, setSortBy] = useState('date')
  const [dateRange, setDateRange] = useState<DateRange>({ from: undefined, to: undefined })
  const [selectedColumns, setSelectedColumns] = useState<Record<string, boolean>>({
    borrowerName: true,
    itemStatus: true,
    itemName: true,
    returnedDate: true,
    condition: true,
  })
  const [isExportDialogOpen, setIsExportDialogOpen] = useState(false)
  const [exportFormat, setExportFormat] = useState('pdf')

  const { data: reportsData, isLoading, error, refetch } = useQuery({
    queryKey: ['reports', searchTerm, statusFilter, dateRange, sortBy],
    queryFn: () => fetchDamagedAndLostItems({
      search: searchTerm,
      status: statusFilter !== 'all' ? statusFilter : undefined,
      dateFrom: dateRange.from?.toISOString().split('T')[0],
      dateTo: dateRange.to?.toISOString().split('T')[0],
    }),
    staleTime: 5 * 60 * 1000,
    retry: (failureCount, error) => {
      if (error instanceof Error && error.message.includes('Unauthorized')) {
        return false
      }
      return failureCount < 3
    },
  })

  const filteredData = useMemo(() => {
    if (!reportsData) return []
    let data = [...reportsData]
    // Apply filters
    data = data.filter(item => {
      const matchesSearch = item.borrowerName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.itemName.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === 'all' || item.itemStatus.toLowerCase() === statusFilter.toLowerCase()
      const matchesDate = (!dateRange.from || (item.returnedDate && new Date(item.returnedDate) >= dateRange.from)) &&
                          (!dateRange.to || (item.returnedDate && new Date(item.returnedDate) <= dateRange.to))
      return matchesSearch && matchesStatus && matchesDate
    })
    // Apply sorting
    if (sortBy === 'date') {
      data.sort((a, b) => {
        const dateA = a.returnedDate ? new Date(a.returnedDate).getTime() : Number.MAX_SAFE_INTEGER
        const dateB = b.returnedDate ? new Date(b.returnedDate).getTime() : Number.MAX_SAFE_INTEGER
        return dateB - dateA
      })
    } else if (sortBy === 'borrower') {
      data.sort((a, b) => a.borrowerName.localeCompare(b.borrowerName))
    } else if (sortBy === 'item') {
      data.sort((a, b) => a.itemName.localeCompare(b.itemName))
    } else if (sortBy === 'status') {
      data.sort((a, b) => a.itemStatus.localeCompare(b.itemStatus))
    }
    return data
  }, [reportsData, searchTerm, statusFilter, dateRange, sortBy])

  const handleExport = async () => {
    if (!filteredData.length) {
      toast("No data available to export. Please adjust filters.")
      return
    }
    try {
      if (exportFormat === 'pdf') {
        await exportToPDF(filteredData, { searchTerm, statusFilter, dateRange })
      } else {
        await exportToExcel(filteredData, { searchTerm, statusFilter, dateRange })
      }
      setIsExportDialogOpen(false)
      toast("Export Successful")
    } catch (error) {
      console.error('Export failed:', error)
      toast("An error occurred while exporting the report.")
    }
  }

  const clearFilters = () => {
    setSearchTerm('')
    setStatusFilter('all')
    setDateRange({ from: undefined, to: undefined })
    setSortBy('date')
  }

  const handleDateRangeSelect = (selected: DateRange | undefined) => {
    setDateRange(selected || { from: undefined, to: undefined })
  }

  const columns = [
    { key: 'borrowerName', label: 'Borrower Name', visible: selectedColumns.borrowerName },
    { key: 'itemStatus', label: 'Item Status', visible: selectedColumns.itemStatus },
    { key: 'itemName', label: 'Item Name', visible: selectedColumns.itemName },
    { key: 'returnedDate', label: 'Returned Date', visible: selectedColumns.returnedDate },
    { key: 'condition', label: 'Condition', visible: selectedColumns.condition },
  ]

  const visibleColumns = columns.filter(col => col.visible)

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">
          Damaged and Lost Items Report
        </h1>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            className="flex items-center gap-2"
          >
            <DownloadCloud className="h-4 w-4" />
            Refresh
          </Button>
          <Dialog open={isExportDialogOpen} onOpenChange={setIsExportDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="flex items-center gap-2">
                <Download className="h-4 w-4" />
                Export
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-md">
              <DialogHeader>
                <DialogTitle>Export Report</DialogTitle>
                <DialogDescription>
                  Choose format for your report
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="format">Format</Label>
                  <Select value={exportFormat} onValueChange={setExportFormat}>
                    <SelectTrigger id="format">
                      <SelectValue placeholder="Select format" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="pdf">
                        <FileText className="mr-2 h-4 w-4" />
                        PDF
                      </SelectItem>
                      <SelectItem value="excel">
                        <FileSpreadsheet className="mr-2 h-4 w-4" />
                        Excel
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Columns to Include</Label>
                  <div className="space-y-2">
                    {columns.map((col) => (
                      <div key={col.key} className="flex items-center space-x-2">
                        <Checkbox
                          id={col.key}
                          checked={selectedColumns[col.key]}
                          onCheckedChange={(checked) => setSelectedColumns(prev => ({
                            ...prev,
                            [col.key]: checked as boolean
                          }))}
                        />
                        <Label htmlFor={col.key} className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
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
                >
                  Cancel
                </Button>
                <Button onClick={handleExport}>
                  Export {exportFormat.toUpperCase()}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="flex items-center justify-between">
            Filters
            <Badge variant="outline" className="text-xs">
              {filteredData.length} results
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="space-y-2">
              <Label htmlFor="search">Search</Label>
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input
                  id="search"
                  placeholder="Search borrowers or items..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="status">Status</Label>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger id="status">
                  <SelectValue placeholder="All statuses" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="damaged">Damaged</SelectItem>
                  <SelectItem value="lost">Lost</SelectItem>
                  <SelectItem value="unreturned">Unreturned</SelectItem>
                  <SelectItem value="returned">Returned</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Date Range</Label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    className={cn(
                      "w-full justify-start text-left font-normal",
                      !dateRange.from && !dateRange.to && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {dateRange.from ? (
                      dateRange.to ? (
                        <>
                          {format(dateRange.from, 'PPP')} - {format(dateRange.to, 'PPP')}
                        </>
                      ) : (
                        format(dateRange.from, 'PPP')
                      )
                    ) : (
                      <>Pick a date range</>
                    )}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0" align="start">
                  <Calendar
                    mode="range"
                    selected={dateRange}
                    onSelect={handleDateRangeSelect}
                    initialFocus
                    disabled={(date) => date < new Date('2020-01-01') || date > new Date()}
                  />
                </PopoverContent>
              </Popover>
            </div>
            <div className="space-y-2">
              <Label>Sort By</Label>
              <Select value={sortBy} onValueChange={setSortBy}>
                <SelectTrigger>
                  <SelectValue placeholder="Sort by" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="date">Date Returned</SelectItem>
                  <SelectItem value="borrower">Borrower Name</SelectItem>
                  <SelectItem value="item">Item Name</SelectItem>
                  <SelectItem value="status">Status</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="mt-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={clearFilters}
              className="flex items-center gap-2 text-muted-foreground"
            >
              <X className="h-4 w-4" />
              Clear Filters
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
          <CardTitle className="text-base font-semibold">
            Recent Reports ({filteredData.length})
          </CardTitle>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" className="h-8 gap-1">
              <Filter className="h-3 w-3" />
              Filter
            </Button>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-8 space-y-2">
              <div className="text-destructive">{error.message}</div>
              <Button variant="outline" onClick={() => refetch()}>
                Retry
              </Button>
            </div>
          ) : filteredData.length === 0 ? (
            <div className="text-center py-8 space-y-2">
              <div className="text-muted-foreground text-lg">No reports found</div>
              <p className="text-sm text-muted-foreground">Try adjusting your filters or date range.</p>
            </div>
          ) : (
            <ScrollArea className="h-[60vh] rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    {visibleColumns.map((col) => (
                      <TableHead key={col.key} className="text-primary-foreground">
                        {col.label}
                      </TableHead>
                    ))}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredData.map((report: Report) => (
                    <TableRow key={report.id}>
                      {visibleColumns.map((col) => (
                        <TableCell key={col.key} className="text-muted-foreground">
                          {col.key === 'itemStatus' ? (
                            <Badge className={getStatusColor(report.itemStatus)}>
                              {getStatusIcon(report.itemStatus)} {report.itemStatus}
                            </Badge>
                          ) : col.key === 'returnedDate' ? (
                            report.returnedDate ? format(new Date(report.returnedDate), 'PPP') : 'N/A'
                          ) : col.key === 'condition' ? (
                            <Badge variant={report.condition === 'Good' ? 'default' : 'destructive'}>
                              {report.condition}
                            </Badge>
                          ) : (
                            report[col.key as keyof Report] || 'N/A'
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </ScrollArea>
          )}
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-destructive">
              {reportsData?.filter((item: Report) => item.itemStatus === 'Damaged').length || 0}
            </div>
            <p className="text-sm text-muted-foreground">Damaged Items</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-yellow-500">
              {reportsData?.filter((item: Report) => item.itemStatus === 'Lost').length || 0}
            </div>
            <p className="text-sm text-muted-foreground">Lost Items</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-secondary-foreground">
              {reportsData?.filter((item: Report) => item.itemStatus === 'Unreturned').length || 0}
            </div>
            <p className="text-sm text-muted-foreground">Unreturned Items</p>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export default Reports