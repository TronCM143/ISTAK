"use client";

import Image from "next/image";
import Link from "next/link";
import * as React from "react";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation"; // Import useRouter for redirection
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
  navMain: [
    {
      title: "Dashboard",
      url: "/dashboard",
      icon: IconDashboard,
    },
    {
      title: "Item Management",
      url: "/inventory",
      icon: IconListDetails,
    },
    {
      title: "Transactions",
      url: "/transaction",
      icon: IconHeartHandshake,
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
  const [user, setUser] = useState({
    name: "Loading...",
    email: "Loading...",
    avatar: "/avatars/shadcn.jpg",
  });
  const router = useRouter(); // Initialize router for redirection

  useEffect(() => {
    const fetchUser = async () => {
      const token = localStorage.getItem("access_token");
      if (!token) {
        router.replace("/login");
        return;
      }

      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        const response = await fetch(`${apiUrl}/api/current-user/`, {
          method: "GET",
          headers: {
            Authorization: `Bearer ${token}`, // Include token in Authorization header
          },
        });
        if (response.ok) {
          const data = await response.json();
          setUser({
            name: data.name,
            email: data.email,
            avatar: data.avatar,
          });
        } else {
          console.error("Failed to fetch user data:", response.statusText);
          router.replace("/login"); // Redirect to login on failure (e.g., invalid token)
        }
      } catch (error) {
        console.error("Error fetching user:", error);
        router.replace("/login"); // Redirect to login on network or other errors
      }
    };

    fetchUser();
  }, [router]);

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
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={data.navMain} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={user} />
      </SidebarFooter>
    </Sidebar>
  );
}