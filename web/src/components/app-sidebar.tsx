"use client"

import Image from "next/image"
import Link from "next/link"
import * as React from "react"
import {
  IconCamera,
  IconChartBar,
  IconDashboard,
  IconDatabase,
  IconFileAi,
  IconFileDescription,
  IconReport,
  IconHelp,
  IconListDetails,
  IconSearch,
  IconSettings,
  IconHeartHandshake,
  IconQrcode,
} from "@tabler/icons-react"

import { NavDocuments } from "@/components/nav-documents"
import { NavMain } from "@/components/nav-main"
import { NavSecondary } from "@/components/nav-secondary"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

const data = {
  user: {
    name: "shadcn",
    email: "m@example.com",
    avatar: "/avatars/shadcn.jpg",
  },
  navMain: [
    {
      title: "Dashboard",
      url: "/dashboard", // 👈 will map to dashboard/page.tsx
      icon: IconDashboard,
    },
    {
      title: "Inventory",
      url: "/inventory", // 👈 will map to inventory/page.tsx
      icon: IconListDetails,
    },
    {
      title: "Requests",
      url: "/requests", // 👈 optional
      icon: IconChartBar,
    },
     {
      title: "Transactions",
      url: "/transaction", // 👈 optional
      icon: IconHeartHandshake  ,
    },
  ],
  documents: [
    {
      name: "Print QR Codes",
      url: "/qrGenerator",
      icon: IconQrcode,
    },
    {
      name: "Reports",
      url: "/reports",
      icon: IconReport,
    },
  ],
  navSecondary: [
    {
      title: "Settings",
      url: "/settings",
      icon: IconSettings,
    },
  ],
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="offcanvas" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              asChild
              className="data-[slot=sidebar-menu-button]:!p-1.5"
            >
              {/* ✅ Use Link for routing */}
              <Link href="/dashboard" className="flex items-center gap-2">
                <Image
                  src="/istak_LOGO.png"
                  alt="Istak Logo"
                  width={24}
                  height={24}
                  className="w-6 h-6"
                />
                <span className="text-base font-bold ">Istak</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        {/* Main nav now uses Link under the hood */}
        <NavMain items={data.navMain} />
        <NavDocuments items={data.documents} />
        <NavSecondary items={data.navSecondary} className="mt-auto" />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={data.user} />
      </SidebarFooter>
    </Sidebar>
  )
}
