'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
  DialogDescription, DialogFooter,
} from '@/components/ui/dialog';
import { toast } from 'sonner';
import { Toaster } from '@/components/ui/sonner';
import { format } from 'date-fns';

interface RegistrationRequest {
  id: number;
  username: string;
  email: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

export function Request() {
  const [requests, setRequests] = useState<RegistrationRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmDialog, setConfirmDialog] = useState({
    open: false,
    requestId: null as number | null,
    isApproved: false,
  });

  const router = useRouter();
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

  // --- Unified authenticated fetch helper ---
  const authFetch = async (url: string, options: RequestInit = {}) => {
    if (typeof window === 'undefined') return null;

    const token = localStorage.getItem('access_token');
    if (!token) {
      router.replace('/login');
      throw new Error('Not authenticated. Please login.');
    }

    const res = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(options.headers || {}),
      },
      cache: 'no-store',
    });

    // if (res.status === 401) {
    //   localStorage.removeItem('access_token');
    //   router.replace('/login');
    //   throw new Error('Unauthorized. Please login again.');
    // }

    if (!res.ok) {
      const text = await res.text();
      throw new Error(text || `Request failed with ${res.status}`);
    }

    return res.json();
  };

  // --- Fetch pending registration requests ---
  useEffect(() => {
    if (typeof window === 'undefined') return;

    const fetchRequests = async () => {
      try {
        setLoading(true);
        const data = await authFetch(`${API_BASE_URL}/api/requests/`);
        const list = Array.isArray(data) ? data : data?.results ?? [];
        setRequests(list.filter((req: RegistrationRequest) => req.status === 'pending'));
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchRequests();
  }, [router]);

  // --- Approve / Reject a request ---
  const handleProcessRequest = async (requestId: number, isApproved: boolean) => {
    try {
      const body = JSON.stringify({ request_id: requestId, is_approved: isApproved });
      const result = await authFetch(`${API_BASE_URL}/api/approve_registration/`, {
        method: 'POST',
        body,
      });

      setRequests((prev) => prev.filter((r) => r.id !== requestId));

      toast(isApproved ? 'User approved successfully' : 'Request rejected', {
        description: isApproved
          ? `User ID: ${result.user_id}`
          : 'Request has been removed.',
      });
    } catch (err) {
      toast(
        `Error ${isApproved ? 'approving' : 'rejecting'} request`,
        {
          description: err instanceof Error ? err.message : 'An error occurred',
          style: {
            background: 'var(--destructive)',
            color: 'var(--destructive-foreground)',
          },
        },
      );
    } finally {
      setConfirmDialog({ open: false, requestId: null, isApproved: false });
    }
  };

  // --- Render ---
  if (loading) return <div className="p-4">Loading registration requests...</div>;
  if (error) return <div className="p-4 text-red-500">Error: {error}</div>;

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
              requests.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>{r.id}</TableCell>
                  <TableCell>{r.username}</TableCell>
                  <TableCell>{r.email}</TableCell>
                  <TableCell>
                    {r.created_at
                      ? format(new Date(r.created_at), 'MMMM d, yyyy h:mm a')
                      : 'N/A'}
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        onClick={() =>
                          setConfirmDialog({ open: true, requestId: r.id, isApproved: true })
                        }
                      >
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() =>
                          setConfirmDialog({ open: true, requestId: r.id, isApproved: false })
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

      {/* Confirm Dialog */}
      <Dialog
        open={confirmDialog.open}
        onOpenChange={(open) =>
          setConfirmDialog((prev) => ({ ...prev, open }))
        }
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {confirmDialog.isApproved ? 'Approve Request' : 'Reject Request'}
            </DialogTitle>
            <DialogDescription>
              Are you sure you want to{' '}
              {confirmDialog.isApproved ? 'approve' : 'reject'} this registration request?{' '}
              {confirmDialog.isApproved
                ? 'This will create a new user account.'
                : 'This action cannot be undone.'}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() =>
                setConfirmDialog({ open: false, requestId: null, isApproved: false })
              }
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
