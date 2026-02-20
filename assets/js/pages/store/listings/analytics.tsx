import { Head, Link } from "@inertiajs/react";
import { Eye, Heart, Gavel, DollarSign, ArrowLeft, MoreVertical } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Badge } from "@/components/ui/badge";
import { StoreLayout } from "@/features/store-dashboard";
import { formatNaira } from "@/lib/format";
import { BlockBidderDialog } from "@/features/blacklist";
import type { ItemAnalyticsBid } from "@/ash_rpc";

interface Item {
  id: string;
  title: string;
  slug: string;
  currentPrice: string | null;
  startingPrice: string;
  auctionStatus: string;
  publicationStatus: string;
  startTime: string | null;
  endTime: string | null;
  viewCount: number;
  bidCount: number;
  watcherCount: number;
}

interface Stats {
  views: number;
  watchers: number;
  totalBids: number;
  highestBid: string;
}

interface AnalyticsPageProps {
  item: Item;
  bids: ItemAnalyticsBid;
  blacklisted_user_ids: string[];
  stats: Stats;
}

const BID_TYPE_LABELS: Record<string, string> = {
  standard: "Standard",
  proxy: "Proxy",
  max_bid: "Max Bid",
};

export default function AnalyticsPage({
  item,
  bids = [],
  blacklisted_user_ids = [],
  stats,
}: AnalyticsPageProps) {
  const [blockDialogOpen, setBlockDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<{
    id: string;
    username: string | null;
    fullName: string | null;
  } | null>(null);

  const handleBlockUser = (user: {
    id: string;
    username: string | null;
    fullName: string | null;
  }) => {
    setSelectedUser(user);
    setBlockDialogOpen(true);
  };

  const isBlacklisted = (userId: string) => blacklisted_user_ids.includes(userId);

  return (
    <>
      <Head title={`Analytics - ${item.title}`} />
      <StoreLayout>
        <div className="space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div>
              <Link
                href="/store/listings"
                className="inline-flex items-center gap-2 text-sm text-content-secondary hover:text-content mb-2"
              >
                <ArrowLeft className="h-4 w-4" />
                Back to Listings
              </Link>
              <h1 className="text-2xl font-bold text-content">{item.title}</h1>
              <p className="text-sm text-content-secondary mt-1">
                View detailed analytics and bidder information
              </p>
            </div>
            <Link href={`/items/${item.slug}`}>
              <Button variant="outline">View Listing</Button>
            </Link>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Views</CardTitle>
                <Eye className="h-4 w-4 text-content-secondary" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stats.views}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Watchers</CardTitle>
                <Heart className="h-4 w-4 text-content-secondary" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stats.watchers}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Bids</CardTitle>
                <Gavel className="h-4 w-4 text-content-secondary" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stats.totalBids}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Highest Bid</CardTitle>
                <DollarSign className="h-4 w-4 text-content-secondary" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatNaira(stats.highestBid)}</div>
              </CardContent>
            </Card>
          </div>

          {/* Bid History Table */}
          <Card>
            <CardHeader>
              <CardTitle>Bid History</CardTitle>
            </CardHeader>
            <CardContent>
              {bids.length === 0 ? (
                <div className="text-center py-8 text-content-secondary">
                  No bids yet
                </div>
              ) : (
                <div className="rounded-md border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Bidder</TableHead>
                        <TableHead>Amount</TableHead>
                        <TableHead>Type</TableHead>
                        <TableHead>Time</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {bids.map((bid) => {
                        const bidder = bid.user;
                        const displayName = bidder?.fullName || bidder?.username || "Anonymous";
                        const blocked = bidder && isBlacklisted(bidder.id);

                        return (
                          <TableRow key={bid.id}>
                            <TableCell>
                              <div className="flex items-center gap-2">
                                <span>{displayName}</span>
                                {blocked && (
                                  <Badge variant="destructive" className="text-xs">
                                    Blocked
                                  </Badge>
                                )}
                              </div>
                            </TableCell>
                            <TableCell className="font-medium">
                              {formatNaira(bid.amount)}
                            </TableCell>
                            <TableCell>
                              <Badge variant="outline">
                                {BID_TYPE_LABELS[bid.bidType] || bid.bidType}
                              </Badge>
                            </TableCell>
                            <TableCell className="text-content-secondary">
                              {formatDistanceToNow(new Date(bid.bidTime), {
                                addSuffix: true,
                              })}
                            </TableCell>
                            <TableCell className="text-right">
                              {bidder && (
                                <DropdownMenu>
                                  <DropdownMenuTrigger asChild>
                                    <Button variant="ghost" size="icon">
                                      <MoreVertical className="h-4 w-4" />
                                    </Button>
                                  </DropdownMenuTrigger>
                                  <DropdownMenuContent align="end">
                                    <DropdownMenuItem
                                      onClick={() => handleBlockUser(bidder)}
                                      disabled={blocked}
                                      className={blocked ? "opacity-50" : ""}
                                    >
                                      {blocked ? "Already Blocked" : "Block Bidder"}
                                    </DropdownMenuItem>
                                  </DropdownMenuContent>
                                </DropdownMenu>
                              )}
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Block Bidder Dialog */}
        {selectedUser && (
          <BlockBidderDialog
            open={blockDialogOpen}
            onOpenChange={setBlockDialogOpen}
            user={selectedUser}
          />
        )}
      </StoreLayout>
    </>
  );
}
