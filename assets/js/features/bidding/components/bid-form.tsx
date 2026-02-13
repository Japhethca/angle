import { useState } from "react";
import { router } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { PermissionGuard, CanPlaceBids, usePermissions } from "@/features/auth";

interface BidFormProps {
  item: {
    id: string;
    title: string;
    current_price: number;
    created_by_id: string;
  };
  userBid?: {
    amount: number;
    bid_time: string;
  };
}

export function BidForm({ item, userBid }: BidFormProps) {
  const { hasPermission, user } = usePermissions();
  const [bidAmount, setBidAmount] = useState(userBid?.amount || item.current_price + 1);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isOwner = item.created_by_id === user?.id;
  const canBid = hasPermission("place_bids") && !isOwner;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!canBid) {
      setError("You don't have permission to place bids");
      return;
    }

    if (bidAmount <= item.current_price) {
      setError(`Bid must be higher than current price of $${item.current_price}`);
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await router.post(`/api/items/${item.id}/bids`, {
        amount: bidAmount,
        bid_type: "standard",
      });
      
      // Reset form on success
      setBidAmount(item.current_price + 1);
    } catch (err: any) {
      setError(err.response?.data?.message || "Failed to place bid");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Place Your Bid</CardTitle>
        <CardDescription>
          Current price: <span className="font-semibold text-green-600">${item.current_price}</span>
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isOwner ? (
          <Alert>
            <AlertDescription>
              You cannot bid on your own item.
            </AlertDescription>
          </Alert>
        ) : (
          <CanPlaceBids fallback={
            <Alert>
              <AlertDescription>
                You need bidding permissions to place bids. Contact an administrator.
              </AlertDescription>
            </Alert>
          }>
            <form onSubmit={handleSubmit} className="space-y-4">
              {userBid && (
                <div className="bg-blue-50 p-4 rounded-md">
                  <p className="text-sm text-blue-800">
                    Your current bid: <span className="font-semibold">${userBid.amount}</span>
                    <br />
                    <span className="text-xs">Placed on {new Date(userBid.bid_time).toLocaleString()}</span>
                  </p>
                </div>
              )}

              <div>
                <label htmlFor="bidAmount" className="block text-sm font-medium text-gray-700">
                  Your Bid ($)
                </label>
                <Input
                  id="bidAmount"
                  type="number"
                  step="0.01"
                  min={item.current_price + 0.01}
                  value={bidAmount}
                  onChange={(e) => setBidAmount(parseFloat(e.target.value) || 0)}
                  disabled={isSubmitting}
                  required
                  className="mt-1"
                />
                <p className="text-xs text-gray-500 mt-1">
                  Minimum bid: ${(item.current_price + 0.01).toFixed(2)}
                </p>
              </div>

              {error && (
                <Alert variant="destructive">
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}

              <Button
                type="submit"
                disabled={isSubmitting || bidAmount <= item.current_price}
                className="w-full"
              >
                {isSubmitting ? "Placing Bid..." : `Place Bid - $${bidAmount.toFixed(2)}`}
              </Button>
            </form>
          </CanPlaceBids>
        )}

        {/* Admin/Management Actions */}
        <PermissionGuard permission="manage_bids">
          <div className="mt-6 pt-4 border-t border-gray-200">
            <h4 className="text-sm font-medium text-gray-900 mb-3">Management Actions</h4>
            <div className="flex space-x-2">
              <Button variant="outline" size="sm">
                View All Bids
              </Button>
              <Button variant="outline" size="sm">
                Cancel Auction
              </Button>
            </div>
          </div>
        </PermissionGuard>
      </CardContent>
    </Card>
  );
}