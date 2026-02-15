import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { useTheme } from "@/hooks/use-theme";
import { ThemeCard } from "./theme-card";

export function PreferencesForm() {
  const { theme, setTheme } = useTheme();
  const [selectedTheme, setSelectedTheme] = useState(theme);

  // Sync selectedTheme when ThemeProvider corrects after hydration
  useEffect(() => {
    setSelectedTheme(theme);
  }, [theme]);
  const [language, setLanguage] = useState(
    () => (typeof window !== "undefined" ? localStorage.getItem("language") : null) || "en"
  );

  const storedLanguage = typeof window !== "undefined" ? localStorage.getItem("language") || "en" : "en";
  const isDirty = selectedTheme !== theme || language !== storedLanguage;

  const handleSave = () => {
    setTheme(selectedTheme);
    localStorage.setItem("language", language);
    toast.success("Preferences saved");
  };

  return (
    <div className="space-y-8">
      <div className="space-y-2">
        <Label>Language</Label>
        <Select value={language} onValueChange={setLanguage}>
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Select language" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="en">English</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-2">
        <h3 className="font-heading text-base font-medium text-content-secondary">Theme</h3>
        <div className="flex gap-4 lg:gap-8">
          <ThemeCard variant="light" selected={selectedTheme === "light"} onClick={() => setSelectedTheme("light")} />
          <ThemeCard variant="dark" selected={selectedTheme === "dark"} onClick={() => setSelectedTheme("dark")} />
        </div>
      </div>

      <Button
        onClick={handleSave}
        disabled={!isDirty}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90 lg:w-auto"
      >
        Save Changes
      </Button>
    </div>
  );
}
