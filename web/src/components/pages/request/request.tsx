"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,

} from "@/components/ui/dialog";  // REVISED: Added Tabs for sections

import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { format } from "date-fns";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@radix-ui/react-tabs";

interface RegistrationRequest {
  id: number;
  username: string;
  email: string;
  status: "pending" | "approved" | "rejected";
  created_at: string;
}

interface MobileUser {
  id: number;
  username: string;
  email: string;
  date_joined: string;
}

export function Request() {
  const [requests, setRequests] = useState<RegistrationRequest[]>([]);
  const [mobileUsers, setMobileUsers] = useState<MobileUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingUsers, setLoadingUsers] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean;
    requestId: number | null;
    isApproved: boolean;
  }>({ open: false, requestId: null, isApproved: false });
  const [changePassDialog, setChangePassDialog] = useState<{
    open: boolean;
    userId: number | null;
  }>({ open: false, userId: null });
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [activeTab, setActiveTab] = useState<"pending" | "approved">("pending");
  const router = useRouter();
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://192.168.1.17:8000";

  // Fetch pending requests
  const fetchRequests = async () => {
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setError("Not authenticated. Please login.");
        router.replace("/login");
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/requests/`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (response.status === 401) {
        setError("Unauthorized. Please login again.");
        router.replace("/login");
        return;
      }

      if (!response.ok) {
        throw new Error(`Failed to fetch requests: ${response.statusText}`);
      }

      const data: RegistrationRequest[] = await response.json();
      setRequests(data.filter((req) => req.status === "pending"));
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred");
    }
  };

  // REVISED: Fetch approved mobile users
  const fetchMobileUsers = async () => {
    try {
      setLoadingUsers(true);
      const token = localStorage.getItem("access_token");
      if (!token) return;

      const response = await fetch(`${API_BASE_URL}/api/mobile-users/`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (response.status === 401) {
        router.replace("/login");
        return;
      }

      if (!response.ok) {
        throw new Error(`Failed to fetch mobile users: ${response.statusText}`);
      }

      const data = await response.json();
      setMobileUsers(data.users || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred");
    } finally {
      setLoadingUsers(false);
    }
  };

  // REVISED: Handle approval/rejection
  const handleProcessRequest = async (requestId: number, isApproved: boolean) => {
    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setError("Not authenticated. Please login.");
        router.replace("/login");
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/approve_registration/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ request_id: requestId, is_approved: isApproved }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to ${isApproved ? "approve" : "reject"} request`);
      }

      const result = await response.json();
      setRequests(requests.filter((req) => req.id !== requestId));
      toast(isApproved ? "User approved successfully" : "Request rejected", {
        description: isApproved
          ? `User ID: ${result.user_id}. They are now connected to your account.`
          : "Request has been removed.",
      });
      
      // REVISED: Refresh mobile users list after approval
      if (isApproved) {
        fetchMobileUsers();
      }
    } catch (err) {
      toast(`Error ${isApproved ? "approving" : "rejecting"} request`, {
        description: err instanceof Error ? err.message : "An error occurred",
        style: { background: "var(--destructive)", color: "var(--destructive-foreground)" },
      });
    } finally {
      setConfirmDialog({ open: false, requestId: null, isApproved: false });
    }
  };

  // REVISED: Handle password change
  const handleChangePassword = async () => {
    if (newPassword !== confirmPassword) {
      toast("Passwords do not match", { style: { background: "var(--destructive)" } });
      return;
    }
    if (!changePassDialog.userId) return;

    try {
      const token = localStorage.getItem("access_token");
      if (!token) {
        setError("Not authenticated. Please login.");
        router.replace("/login");
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/change-password/${changePassDialog.userId}/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ password: newPassword }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || "Failed to change password");
      }

      const result = await response.json();
      toast("Password updated successfully", {
        description: result.message,
      });
      setNewPassword("");
      setConfirmPassword("");
      setChangePassDialog({ open: false, userId: null });
    } catch (err) {
      toast("Error changing password", {
        description: err instanceof Error ? err.message : "An error occurred",
        style: { background: "var(--destructive)", color: "var(--destructive-foreground)" },
      });
    }
  };

  useEffect(() => {
    fetchRequests();
    fetchMobileUsers();
  }, [router]);

  if (loading && loadingUsers) {
    return <div className="p-4">Loading...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="container mx-auto p-4">
      <Toaster />
      <h1 className="text-2xl font-bold mb-4">Registration Management</h1>
      
      {/* REVISED: Tabs for Pending and Approved */}
      <Tabs value={activeTab} onValueChange={(value: string) => setActiveTab(value as "pending" | "approved")}>
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="pending">Pending Requests ({requests.length})</TabsTrigger>
          <TabsTrigger value="approved">Approved Mobile Users ({mobileUsers.length})</TabsTrigger>
        </TabsList>

        {/* Pending Requests Tab */}
        <TabsContent value="pending" className="mt-4">
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Username</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Request Time</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {requests.length ? (
                  requests.map((request) => (
                    <TableRow key={request.id}>
                      <TableCell>{request.id}</TableCell>
                      <TableCell>{request.username}</TableCell>
                      <TableCell>{request.email}</TableCell>
                      <TableCell>
                        {request.created_at
                          ? format(new Date(request.created_at), "MMMM d, yyyy h:mm a")
                          : "N/A"}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            onClick={() =>
                              setConfirmDialog({ open: true, requestId: request.id, isApproved: true })
                            }
                          >
                            Approve
                          </Button>
                          <Button
                            size="sm"
                            variant="destructive"
                            onClick={() =>
                              setConfirmDialog({ open: true, requestId: request.id, isApproved: false })
                            }
                          >
                            Reject
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center">
                      No pending registration requests.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        {/* REVISED: Approved Mobile Users Tab */}
        <TabsContent value="approved" className="mt-4">
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Username</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Joined</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {mobileUsers.length ? (
                  mobileUsers.map((user) => (
                    <TableRow key={user.id}>
                      <TableCell>{user.id}</TableCell>
                      <TableCell>{user.username}</TableCell>
                      <TableCell>{user.email}</TableCell>
                      <TableCell>
                        {user.date_joined
                          ? format(new Date(user.date_joined), "MMMM d, yyyy")
                          : "N/A"}
                      </TableCell>
                      <TableCell>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setChangePassDialog({ open: true, userId: user.id })}
                        >
                          Change Password
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center">
                      No approved mobile users yet.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </TabsContent>
      </Tabs>

      {/* Approval/Rejection Confirmation Dialog */}
      <Dialog
        open={confirmDialog.open}
        onOpenChange={(open) =>
          setConfirmDialog({ open, requestId: confirmDialog.requestId, isApproved: confirmDialog.isApproved })
        }
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {confirmDialog.isApproved ? "Approve Request" : "Reject Request"}
            </DialogTitle>
            <DialogDescription>
              Are you sure you want to {confirmDialog.isApproved ? "approve" : "reject"} this registration
              request? {confirmDialog.isApproved ? "This will create a new user account." : "This action cannot be undone."}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setConfirmDialog({ open: false, requestId: null, isApproved: false })}
            >
              Cancel
            </Button>
            <Button
              onClick={() =>
                confirmDialog.requestId &&
                handleProcessRequest(confirmDialog.requestId, confirmDialog.isApproved)
              }
            >
              Confirm
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* REVISED: Change Password Dialog */}
      <Dialog
        open={changePassDialog.open}
        onOpenChange={(open) =>
          setChangePassDialog({ open, userId: changePassDialog.userId })
        }
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Change Password</DialogTitle>
            <DialogDescription>
              Enter a new password for the selected user. This will update their account immediately.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium">New Password</label>
              <Input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="Enter new password"
                minLength={8}
              />
            </div>
            <div>
              <label className="text-sm font-medium">Confirm Password</label>
              <Input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Confirm new password"
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setChangePassDialog({ open: false, userId: null });
                setNewPassword("");
                setConfirmPassword("");
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleChangePassword}
              disabled={newPassword !== confirmPassword || newPassword.length < 8}
            >
              Update Password
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}