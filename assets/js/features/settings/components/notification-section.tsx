import { Switch } from "@/components/ui/switch";

interface NotificationToggle {
  key: string;
  label: string;
  description: string;
}

interface NotificationSectionProps {
  title: string;
  toggles: NotificationToggle[];
  values: Record<string, boolean>;
  onToggle: (key: string, value: boolean) => void;
  isPending: boolean;
}

export function NotificationSection({
  title,
  toggles,
  values,
  onToggle,
  isPending,
}: NotificationSectionProps) {
  return (
    <div>
      <h2 className="mb-4 text-base font-semibold text-content">{title}</h2>
      <div className="space-y-1">
        {toggles.map((toggle) => (
          <div
            key={toggle.key}
            className="flex items-center justify-between rounded-xl border border-subtle p-4"
          >
            <div className="mr-4">
              <p className="text-sm font-medium text-content">{toggle.label}</p>
              <p className="text-xs text-content-tertiary">
                {toggle.description}
              </p>
            </div>
            <Switch
              checked={values[toggle.key] ?? true}
              onCheckedChange={(checked) => onToggle(toggle.key, checked)}
              disabled={isPending}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
