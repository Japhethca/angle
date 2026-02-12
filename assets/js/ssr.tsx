// assets/js/ssr.tsx
import axios from "axios";
import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import Layout from "./components/layouts/layout";
import { AuthProvider } from "./contexts/auth-context";

axios.defaults.xsrfHeaderName = "x-csrf-token";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function render(page: any) {
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: async (name) => {
      const page = await import(`./pages/${name}.tsx`);
      page.default.layout =
        page.default.layout ||
        ((page: React.ReactNode) => (
          <AuthProvider>
            <Layout>{page}</Layout>
          </AuthProvider>
        ));
      return page;
    },
    setup: ({ App, props }) => {
      const queryClient = new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 1000 * 60,
            refetchOnWindowFocus: false,
          },
        },
      });
      return (
        <QueryClientProvider client={queryClient}>
          <App {...props} />
        </QueryClientProvider>
      );
    },
  });
}
