import { AppSidebar } from "@/components/widgets/app-sidebar"
import { ChartAreaInteractive } from "@/components/widgets/chart-area-interactive"
import { DataTable } from "@/components/widgets/data-table"
import { SectionCards } from "@/components/widgets/section-cards"
import { SiteHeader } from "@/components/widgets/site-header"
import {
  SidebarInset,
  SidebarProvider,
} from "@/components/ui/sidebar"

import data from "./data.json"
import PredictedTopItemsRow from "@/components/pages/dashboard/topItems"

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
      <SidebarInset>
         <SiteHeader title="Dashboard" />
        <div className="flex flex-1 flex-col">
          <div className="@container/main flex flex-1 flex-col gap-2">
            <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
             
     
              <div className="px-4 lg:px-6">
                   <PredictedTopItemsRow/>
                 
              
              </div>
                  <div className="px-4 lg:px-6">
   <SectionCards />
                     </div>
                       <div className="px-4 lg:px-6">
    <ChartAreaInteractive />
                     </div>
            
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
