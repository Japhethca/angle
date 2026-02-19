import { Head } from '@inertiajs/react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Section } from '@/components/layout/section';
import type { PageProps } from '@/features/auth';

interface DashboardProps extends PageProps {
  stats: {
    total_items: number;
    total_bids: number;
    active_auctions: number;
  };
  recent_activity: any[];
}

export default function Dashboard({ stats, recent_activity }: DashboardProps) {

  return (
    <>
      <Head title="Dashboard" />
      <Section fullBleed background="muted" className="min-h-screen py-6">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-content">Dashboard</h1>
          <p className="mt-2 text-sm text-content-secondary">Welcome to your dashboard</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Card>
            <CardHeader>
              <CardTitle>Total Items</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-blue-600">{stats.total_items}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Total Bids</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-green-600">{stats.total_bids}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Active Auctions</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-purple-600">{stats.active_auctions}</p>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Recent Activity</CardTitle>
          </CardHeader>
          <CardContent>
            {recent_activity.length === 0 ? (
              <p className="text-content-secondary">No recent activity</p>
            ) : (
              <div className="space-y-2">
                {recent_activity.map((_, index) => (
                  <div key={index} className="border-b pb-2">
                    {/* Render activity items */}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </Section>
    </>
  );
}