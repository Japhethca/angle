import { Head, Link } from "@inertiajs/react";
import { Eye, Heart, Gavel, DollarSign, ArrowLeft } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { StoreLayout } from "@/features/store-dashboard";
import { formatNaira } from "@/lib/format";
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
  stats,
}: AnalyticsPageProps) {

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

                        return (
                          <TableRow key={bid.id}>
                            <TableCell>
                              <span>{displayName}</span>
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
      </StoreLayout>
    </>
  );
}
