'use client';

import Image from 'next/image';
import Link from 'next/link';
import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  IconDashboard,
  IconListDetails,
  IconHeartHandshake,
  IconReport,
  IconChartBar,
  IconAlien,
} from '@tabler/icons-react';
import { NavMain } from '@/components/widgets/nav-main';
import { NavUser } from '@/components/widgets/nav-user';
import {
  Sidebar,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
} from '@/components/ui/sidebar';

const navData = {
  navMain: [
    { title: 'Dashboard', url: '/dashboard', icon: IconDashboard },
    { title: 'Item Management', url: '/inventory', icon: IconListDetails },
    { title: 'Transactions', url: '/transaction', icon: IconHeartHandshake },
    { title: 'Reports', url: '/reports', icon: IconReport },
    { title: 'Requests', url: '/request', icon: IconChartBar },
    { title: 'Borrower', url: '/borrower', icon: IconAlien },
  ],
};

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const [user, setUser] = useState({
    name: 'Loading...',
    email: 'Loading...',
    avatar: '/avatars/shadcn.jpg',
  });
  const [checkingAuth, setCheckingAuth] = useState(true);
  const router = useRouter();

  useEffect(() => {
    // Run only on client
    if (typeof window === 'undefined') return;

    const token = localStorage.getItem('access_token');
    if (!token) {
      router.replace('/login');
      return;
    }

    const fetchUser = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        const response = await fetch(`${apiUrl}/api/current-user/`, {
          headers: { Authorization: `Bearer ${token}` },
        });

        if (response.ok) {
          const data = await response.json();
          setUser({
            name: data.name ?? 'Unknown',
            email: data.email ?? 'No email',
            avatar: data.avatar ?? '/avatars/shadcn.jpg',
          });
        } else if (response.status === 401) {
          // Token expired or invalid
          // localStorage.removeItem('access_token');
          // router.replace('/login');
        } else {
          console.error('Failed to fetch user data:', response.statusText);
        }
      } catch (error) {
        console.error('Error fetching user:', error);
      } finally {
        setCheckingAuth(false);
      }
    };

    fetchUser();
  }, [router]);

  if (checkingAuth) {
    // Prevent flashing login redirects or rendering while checking token
    return null;
  }

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
        <NavMain items={navData.navMain} />
      </SidebarContent>

      <SidebarFooter>
        <NavUser user={user} />
      </SidebarFooter>
    </Sidebar>
  );
}
