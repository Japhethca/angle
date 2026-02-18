import { createContext, useContext, useEffect, useLayoutEffect, useState } from "react";

export type ThemeOption = "light" | "dark" | "system";
type ResolvedTheme = "light" | "dark";

interface ThemeContextValue {
  theme: ThemeOption;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: ThemeOption) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

function getSystemTheme(): ResolvedTheme {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function resolveTheme(theme: ThemeOption): ResolvedTheme {
  return theme === "system" ? getSystemTheme() : theme;
}

// Always start with "light" for SSR. Corrected after hydration via useLayoutEffect.
export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeOption>("light");
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>("light");

  // Correct theme from localStorage after hydration, before browser paints.
  useLayoutEffect(() => {
    const stored = localStorage.getItem("theme");
    const validTheme: ThemeOption =
      stored === "dark" ? "dark" : stored === "system" ? "system" : "light";
    setThemeState(validTheme);
    setResolvedTheme(resolveTheme(validTheme));
  }, []);

  // Sync DOM class and localStorage whenever theme changes.
  useLayoutEffect(() => {
    const resolved = resolveTheme(theme);
    setResolvedTheme(resolved);
    const root = document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(resolved);
    localStorage.setItem("theme", theme);
  }, [theme]);

  // Listen for OS theme changes when in "system" mode.
  useEffect(() => {
    if (theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => {
      const resolved = getSystemTheme();
      setResolvedTheme(resolved);
      const root = document.documentElement;
      root.classList.remove("light", "dark");
      root.classList.add(resolved);
    };
    mql.addEventListener("change", handler);
    return () => mql.removeEventListener("change", handler);
  }, [theme]);

  const setTheme = (newTheme: ThemeOption) => {
    setThemeState(newTheme);
  };

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
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
