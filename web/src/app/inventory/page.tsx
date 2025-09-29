import { AppSidebar } from "@/components/widgets/app-sidebar"
import { InventoryPage } from "@/components/pages/inventory/inventory";
import { SiteHeader } from "@/components/widgets/site-header"
import {
  SidebarInset,
  SidebarProvider,
} from "@/components/ui/sidebar"


export default function Page() {
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
      <SidebarInset title="Inventory">
        <SiteHeader  title="Item Management" />
        <div className="flex flex-1 flex-col">
          <div className="@container/main flex flex-1 flex-col gap-2">
            <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
                <InventoryPage/>
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
