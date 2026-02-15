import { useState } from "react";
import { Head } from "@inertiajs/react";
import { Separator } from "@/components/ui/separator";
import { SettingsLayout, NotificationSection } from "@/features/settings";
import { useAshMutation } from "@/hooks/use-ash-query";
import {
  updateNotificationPreferences,
  buildCSRFHeaders,
  type AngleAccountsNotificationPreferencesInputSchema,
} from "@/ash_rpc";
import { toast } from "sonner";

interface NotificationPreferences {
  [key: string]: boolean;
  push_bidding: boolean;
  push_watchlist: boolean;
  push_payments: boolean;
  push_communication: boolean;
  email_communication: boolean;
  email_marketing: boolean;
  email_security: boolean;
  sms_communication: boolean;
  sms_security: boolean;
}

interface NotificationsUser {
  id: string;
  notification_preferences: NotificationPreferences;
}

interface SettingsNotificationsProps {
  user: NotificationsUser;
}

const PUSH_TOGGLES = [
  {
    key: "push_bidding",
    label: "Bidding",
    description: "Get notified when you're outbid or win an auction",
  },
  {
    key: "push_watchlist",
    label: "Watchlist",
    description: "Get reminders on items on your watchlist",
  },
  {
    key: "push_payments",
    label: "Payments",
    description: "Confirmations when money moves in and out",
  },
  {
    key: "push_communication",
    label: "Communication",
    description: "Alerts from buyers and sellers",
  },
];

const EMAIL_TOGGLES = [
  {
    key: "email_communication",
    label: "Communication",
    description: "Receive emails about your account activity",
  },
  {
    key: "email_marketing",
    label: "Marketing",
    description: "Receive emails about new products, features, and more",
  },
  {
    key: "email_security",
    label: "Security",
    description: "Receive emails about your account security",
  },
];

const SMS_TOGGLES = [
  {
    key: "sms_communication",
    label: "Communication",
    description: "Receive updates about your account activity",
  },
  {
    key: "sms_security",
    label: "Security",
    description: "Receive updates about your account security",
  },
];

// Convert snake_case preferences to camelCase for the RPC input
function toCamelCasePrefs(
  prefs: NotificationPreferences
): AngleAccountsNotificationPreferencesInputSchema {
  return {
    pushBidding: prefs.push_bidding,
    pushWatchlist: prefs.push_watchlist,
    pushPayments: prefs.push_payments,
    pushCommunication: prefs.push_communication,
    emailCommunication: prefs.email_communication,
    emailMarketing: prefs.email_marketing,
    emailSecurity: prefs.email_security,
    smsCommunication: prefs.sms_communication,
    smsSecurity: prefs.sms_security,
  };
}

export default function SettingsNotifications({
  user,
}: SettingsNotificationsProps) {
  const [prefs, setPrefs] = useState<NotificationPreferences>(
    user.notification_preferences
  );

  const { mutate, isPending } = useAshMutation(
    (newPrefs: NotificationPreferences) =>
      updateNotificationPreferences({
        identity: user.id,
        input: { notificationPreferences: toCamelCasePrefs(newPrefs) },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => toast.success("Notification preferences updated"),
      onError: () => {
        setPrefs(user.notification_preferences);
        toast.error("Failed to update notification preferences");
      },
    }
  );

  const handleToggle = (key: string, value: boolean) => {
    const newPrefs = { ...prefs, [key]: value };
    setPrefs(newPrefs);
    mutate(newPrefs);
  };

  return (
    <>
      <Head title="Notification Settings" />
      <SettingsLayout title="Notifications">
        <div className="space-y-6">
          <NotificationSection
            title="Push Notifications"
            toggles={PUSH_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
          <Separator />
          <NotificationSection
            title="Email Notifications"
            toggles={EMAIL_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
          <Separator />
          <NotificationSection
            title="SMS Alerts"
            toggles={SMS_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
        </div>
      </SettingsLayout>
    </>
  );
}
