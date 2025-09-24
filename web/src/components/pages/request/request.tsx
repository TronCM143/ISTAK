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
} from "@/components/ui/dialog";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { format } from "date-fns";

interface RegistrationRequest {
  id: number;
  username: string;
  email: string;
  status: "pending" | "approved" | "rejected";
  created_at: string;
}

export function Request() {
  const [requests, setRequests] = useState<RegistrationRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean;
    requestId: number | null;
    isApproved: boolean;
  }>({ open: false, requestId: null, isApproved: false });
  const router = useRouter();
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://192.168.1.17:8000";

  useEffect(() => {
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
        setLoading(false);
      } catch (err) {
        setError(err instanceof Error ? err.message : "An error occurred");
        setLoading(false);
      }
    };

    fetchRequests();
  }, [router]);

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
          ? `User ID: ${result.user_id}`
          : "Request has been removed.",
      });
    } catch (err) {
      toast(`Error ${isApproved ? "approving" : "rejecting"} request`, {
        description: err instanceof Error ? err.message : "An error occurred",
        style: { background: "var(--destructive)", color: "var(--destructive-foreground)" },
      });
    } finally {
      setConfirmDialog({ open: false, requestId: null, isApproved: false });
    }
  };

  if (loading) {
    return <div className="p-4">Loading registration requests...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="container mx-auto p-4">
      <Toaster />
      <h1 className="text-2xl font-bold mb-4">Pending Registration Requests</h1>
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
    </div>
  );
}