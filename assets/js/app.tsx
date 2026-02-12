import axios from "axios";

import { createInertiaApp } from "@inertiajs/react";
import { hydrateRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import Layout from "@/components/layouts/layout";
import { AuthProvider } from "@/contexts/auth-context";

axios.defaults.xsrfHeaderName = "x-csrf-token";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60, // 1 minute
      refetchOnWindowFocus: false,
    },
  },
});

createInertiaApp({
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
  setup({ App, el, props }) {
    hydrateRoot(
      el,
      <QueryClientProvider client={queryClient}>
        <App {...props} />
      </QueryClientProvider>
    );
  },
});
