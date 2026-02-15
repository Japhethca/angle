import { createContext, useContext, useLayoutEffect, useState } from "react";

type Theme = "light" | "dark";

interface ThemeContextValue {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

// Always start with "light" for SSR. Corrected after hydration via useLayoutEffect.
export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>("light");

  // Correct theme from localStorage after hydration, before browser paints.
  useLayoutEffect(() => {
    const stored = localStorage.getItem("theme");
    const validTheme: Theme = stored === "dark" ? "dark" : "light";
    if (validTheme !== "light") {
      setTheme(validTheme);
    }
  }, []);

  // Sync DOM class and localStorage whenever theme changes.
  // useLayoutEffect prevents a single-frame flash when correcting from SSR default.
  useLayoutEffect(() => {
    const root = document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
