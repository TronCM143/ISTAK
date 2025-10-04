"use client";

import Image from "next/image";
import Link from "next/link";
import * as React from "react";
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
  IconAlien,
} from "@tabler/icons-react";
import { NavMain } from "@/components/widgets/nav-main";
import { NavUser } from "@/components/widgets/nav-user";
import {
  Sidebar,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
} from "@/components/ui/sidebar";

const data = {
  user: {
    name: "kariktan",
    email: "ndmu.edu.com",
    avatar: "/avatars/shadcn.jpg",
  },
  navMain: [
    {
      title: "Dashboard",
      url: "/dashboard",
      icon: IconDashboard,
    },
    {
      title: "Item  Management",
      url: "/inventory",
      icon: IconListDetails,
    },
  
    {
      title: "Transactions",
      url: "/transaction",
      icon: IconHeartHandshake,
    },


    {
      title: "Print QR Codes",
      url: "/qrGenerator",
      icon: IconQrcode,
    },
    {
      title: "Reports",
      url: "/reports",
      icon: IconReport,
    },
      {
      title: "Requests",
      url: "/request",
      icon: IconChartBar,
    },
     {
      title: "Borrower",
      url: "/borrower",
      icon: IconAlien,
    },
  
    ],
};

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
              <Link href="/dashboard" className="flex items-center gap-2">
                <Image
                  src="/fullLogo.png"
                  alt="Istak Logo"
                  width={100}
                  height={24}
                  className="w-30 h-7"
                />
             {/* <span className="text-base font-bold">Istak</span> */}
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={data.navMain} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={data.user} />
      </SidebarFooter>
    </Sidebar>
  );
}